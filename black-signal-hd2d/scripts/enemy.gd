extends RefCounted
const Cover = preload("res://scripts/cover.gd")
## Animated 2D combat unit. Positions and combat geometry are entirely planar.
const NAMES = ["РЕЙДЕР","ОХРАННИК","КИБЕРБРУТ","НЕТРАННЕР","КИБЕРПЁС","ДРОН"]
const IDS = ["raider","guard","brute","hacker","hound","drone"]
# health in pistol hits; walking speed, running speed, attack range, damage, cooldown, render height
const STATS = [
 [3,1.6,3.7,2.3,12,1.25,1.78],
 [4,1.3,2.5,11.5,8,1.65,1.90],
 [8,0.9,2.1,6.0,19,2.1,2.25],
 [3,1.4,2.9,13.0,7,1.9,1.65],
 [3,2.0,4.6,2.6,14,1.3,1.05],
 [4,2.0,3.3,10.0,6,1.45,0.68]
]
const BODY_WIDTH=[0.66,0.78,1.16,0.61,0.69,1.40]
const COLLISION_RADIUS=[0.32,0.39,0.58,0.31,0.44,0.70]
const HIT_DURATION: float=0.24
const HIT_STUN_DURATION: float=0.18
const FOOT_ANCHOR: float=209.0
const DURATIONS = [1.65,0.95,0.65,0.88,1.10]
const FRAME_W: float = 192.0
const FRAME_H: float = 224.0
const FRAMES: int = 18
const IDLE: int = 0
const WALK: int = 1
const RUN: int = 2
const ATTACK: int = 3
const DEATH: int = 4
var kind: int
var p: Vector2
var spawn: Vector2
var hp: int
var max_hp: int
var clip: int = IDLE
var time: float = 0.0
var prior_clip: int = IDLE
var prior_time: float = 0.0
var blend: float = 1.0
var cool: float = 0.0
var hit_flash: float = 0.0
var hit_stun: float = 0.0
var attack_flash: float = 0.0
var attack_done: bool = false
var age: float = 0.0
var activated: bool = false
var patrol_direction: float = 1.0
var texture: Texture2D
var heading: Vector2=Vector2(0,-1)
const FRONT: int=0
const SIDE: int=1
const BACK: int=2
const DIR_FRAMES: int=12

func _init(type_id: int=0, at: Vector2=Vector2.ZERO) -> void:
 kind=clampi(type_id,0,5);p=at;spawn=at
 max_hp=int(STATS[kind][0]);hp=max_hp
 time=float(kind)*0.13
 cool=0.6+float(kind)*0.22
 # Cache via Godot ResourceLoader; only load these once a game is started.
 texture=load("res://assets/mobs/"+str(IDS[kind])+"_combat.webp") as Texture2D

func display_name() -> String:
 return str(NAMES[kind])

func height() -> float:
 return float(STATS[kind][6])

func width() -> float:
 return float(BODY_WIDTH[kind])

func radius() -> float:
 return float(COLLISION_RADIUS[kind])

func altitude() -> float:
 if kind!=5:return 0.0
 if not living():return maxf(0.0,1.16*(1.0-time/float(DURATIONS[DEATH])))
 return 1.16+sin(age*3.2)*0.045

func living() -> bool:
 return hp>0

func set_clip(next: int) -> void:
 if next==clip: return
 prior_clip=clip;prior_time=time;blend=0.0
 var carry: float=time/float(DURATIONS[clip]) if clip<ATTACK and next<ATTACK and clip!=IDLE and next!=IDLE else 0.0
 clip=next;time=carry*float(DURATIONS[next]);attack_done=false

func take_hit() -> bool:
 if not living(): return false
 hp-=1;hit_flash=HIT_DURATION;activated=true
 if hp<=0:
  hp=0;hit_stun=0.0;set_clip(DEATH);return true
 # A nonlethal shot briefly stops pursuit, making hits readable and giving
 # the player a genuine repositioning window, without extending attack range.
 hit_stun=HIT_STUN_DURATION
 # Preserve a short post-hit recovery even when an idle enemy's attack
 # cooldown was already zero. A stagger should never end in an instant hit.
 cool=maxf(cool,0.30)
 # A confirmed shot interrupts an uncommitted windup. Once the active frame
 # has fired, damage cannot be undone; cooldown still prevents an instant retry.
 if clip==ATTACK and not attack_done:
  set_clip(IDLE)
  cool=maxf(cool,0.45)
 return false

func update(dt: float, player: Vector2, player_alive: bool, obstacles: Array[Rect2]=[]) -> int:
 dt=clampf(dt,0.0,0.10)
 age+=dt;hit_flash=maxf(0.0,hit_flash-dt);attack_flash=maxf(0.0,attack_flash-dt)
 blend=minf(1.0,blend+dt/0.075)
 if prior_clip<ATTACK: prior_time=fposmod(prior_time+dt,float(DURATIONS[prior_clip]))
 time+=dt;cool=maxf(0.0,cool-dt)
 if clip==DEATH:
  time=minf(time,float(DURATIONS[DEATH]));return 0
 if not player_alive:
  set_clip(IDLE);return 0
 if hit_stun>0.0:
  hit_stun=maxf(0.0,hit_stun-dt)
  if clip!=ATTACK or not attack_done:
   set_clip(IDLE)
   return 0
 var movement_origin: Vector2=p
 var rel: Vector2=player-p
 var distance: float=rel.length()
 var reach: float=float(STATS[kind][3])
 # Flying drones are above low crates; ground troops need actual line of sight.
 var blocked: bool=kind!=5 and Cover.segment_blocked(p,player,obstacles)
 if distance<22.0:activated=true
 elif distance>39.0:activated=false
 if clip==ATTACK:
  # Lock facing during the telegraph: players can evade by sidestepping.
  # Do not rotate the attack sprite to track a moving target after windup.
  var damage: int=0
  # Telegraph first; the attack deals damage exactly once at its active frame.
  if time>=float(DURATIONS[ATTACK])*0.48 and not attack_done:
   attack_done=true;attack_flash=0.13
   # A target behind the committed strike direction cannot be hit.
   var facing_target: bool=distance>0.001 and heading.dot(rel.normalized())>=0.5
   if distance<=reach+0.65 and not blocked and facing_target:damage=int(STATS[kind][4])
  if time>=float(DURATIONS[ATTACK]):
   cool=float(STATS[kind][5]);set_clip(IDLE)
  return damage
 if not activated:
  # Slow sentry patrol around its spawn point.
  if fposmod(age+float(kind)*0.47,5.0)<2.0:
   # Patrol in depth rather than sideways; turn toward player when aggroed.
   if absf(p.y-spawn.y)>1.0:patrol_direction=-signf(p.y-spawn.y)
   heading=Vector2(0,patrol_direction)
   set_clip(WALK)
   var patrol_step: Vector2=heading*float(STATS[kind][1])*0.24*dt
   var patrol_next: Vector2=Cover.move_circle(p,patrol_step,radius(),obstacles)
   if patrol_next.distance_squared_to(p)>0.0000001:p=patrol_next
   else:set_clip(IDLE)
  else:set_clip(IDLE)
 elif distance<=reach and cool<=0.0 and not blocked:
  if distance>0.01:heading=rel.normalized()
  set_clip(ATTACK)
 elif distance>reach*0.86 or blocked:
  var running: bool=distance>reach+3.4
  set_clip(RUN if running else WALK)
  var speed: float=float(STATS[kind][2] if running else STATS[kind][1])
  # When cover blocks a shot inside weapon range, approach to find a flank.
  var standoff: float=0.0 if blocked else reach*0.81
  var step: float=minf(speed*dt,maxf(0.0,distance-standoff))
  if step>0.0001:
   var before: Vector2=p
   var candidate: Vector2=Cover.move_circle(p,rel.normalized()*step,radius(),obstacles)
   # A stopped enemy should flank the obstacle rather than clip through it.
   if candidate.distance_squared_to(p)<step*step*0.10 and blocked:
    candidate=Cover.nearest_unblocked_flank(p,player,radius(),step,obstacles,kind%2==0)
   if candidate.distance_squared_to(before)>0.0000001:
    heading=(candidate-before).normalized()
    p=candidate
 else:
  if distance>0.01:heading=rel.normalized()
  set_clip(IDLE)
 p.x=clampf(p.x,-5.35,5.35)
 # Locomotion animation must be driven by actual collision-resolved travel.
 # This prevents running-in-place against crates and shimmering walk cycles.
 if clip==WALK or clip==RUN:
  var expected_speed: float=float(STATS[kind][2] if clip==RUN else STATS[kind][1])
  var traveled: float=p.distance_to(movement_origin)
  var speed_ratio: float=clampf(traveled/maxf(0.0001,expected_speed*dt),0.0,1.0)
  # A freshly selected WALK/RUN clip can start at phase zero. Subtracting
  # unused dt without clamping wraps a negative phase to the *last* frame,
  # causing a visible footfall snap on slow/obstructed movement.
  time=maxf(0.0,time-dt*(1.0-speed_ratio))
  if speed_ratio<0.05:set_clip(IDLE)
 if clip<ATTACK:time=fposmod(time,float(DURATIONS[clip]))
 return 0

func frame_for(state: int,t: float) -> int:
 var phase: float=t/float(DURATIONS[state])
 var frame: int=floori(phase*float(FRAMES))
 return posmod(frame,FRAMES) if state<ATTACK else clampi(frame,0,FRAMES-1)

func source_rect(state: int,t: float) -> Rect2:
 var idx: int=state*FRAMES+frame_for(state,t)
 return Rect2(Vector2(float(idx%6)*FRAME_W,float(floori(float(idx)/6.0))*FRAME_H),Vector2(FRAME_W,FRAME_H))

# Keep a small directional deadband so tiny camera/heading changes do not
# rapidly alternate between distinct authored silhouettes at view boundaries.
var last_view: int=SIDE
# Keep the side-facing silhouette stable near a perpendicular camera angle.
var last_side_right: bool=true
const SIDE_FLIP_DEADBAND: float=0.12

func view_for(to_camera: Vector2) -> int:
 if to_camera.length_squared()<0.000001:return last_view
 var alignment: float=heading.dot(to_camera.normalized())
 if last_view==FRONT and alignment>0.28:return FRONT
 if last_view==BACK and alignment< -0.46:return BACK
 if alignment>0.44:last_view=FRONT
 elif alignment< -0.62:last_view=BACK
 elif alignment<0.28 and alignment> -0.46:last_view=SIDE
 return last_view

func packed_rect(view: int,state: int,t: float) -> Rect2:
 var idx: int=0
 var phase: float=t/(HIT_DURATION if state==5 else float(DURATIONS[state]))
 if view==FRONT or state==5:
  var n: int=posmod(floori(phase*12.0),12) if state<ATTACK else clampi(floori(phase*12.0),0,11)
  idx=state*12+n
 elif view==BACK and state!=DEATH:
  var n: int=posmod(floori(phase*12.0),12)
  if state==IDLE or state==ATTACK:n=0
  idx=102+(12 if state==RUN else 0)+n
 else:
  var n: int=posmod(floori(phase*6.0),6) if state<ATTACK else clampi(floori(phase*6.0),0,5)
  idx=72+state*6+n
 return Rect2(Vector2(float(idx%8)*FRAME_W,float(floori(float(idx)/8.0))*FRAME_H),Vector2(FRAME_W,FRAME_H))

func draw_pose(canvas: CanvasItem,foot: Vector2,dst: Rect2,view: int,state: int,t: float,tint: Color,camera_right: Vector2) -> void:
 var flip: float=1.0
 if view==SIDE and state!=5:
  var authored_right: bool=kind==1 or kind==2 or kind==3
  var lateral: float=heading.dot(camera_right.normalized()) if camera_right.length_squared()>0.000001 else 0.0
  if lateral>SIDE_FLIP_DEADBAND:last_side_right=true
  elif lateral< -SIDE_FLIP_DEADBAND:last_side_right=false
  flip=1.0 if last_side_right==authored_right else -1.0
 canvas.draw_set_transform(foot,0,Vector2(flip,1.0))
 canvas.draw_texture_rect_region(texture,dst,packed_rect(view,state,t),tint)
 canvas.draw_set_transform(Vector2.ZERO)

func paint(canvas: CanvasItem,foot: Vector2,pixels_per_meter: float,to_camera: Vector2,camera_right: Vector2) -> void:
 if texture==null:return
 # All views use the same baseline and fixed world scale; never rescale to fit a pose.
 var art_scale: float=height()*pixels_per_meter/(74.0 if kind==5 else 184.0)
 var h: float=FRAME_H*art_scale
 var w: float=FRAME_W*art_scale
 var origin: Vector2=foot-Vector2(0,altitude()*pixels_per_meter)
 var view: int=view_for(to_camera)
 var dst:=Rect2(Vector2(-w*0.5,-FOOT_ANCHOR*art_scale),Vector2(w,h))
 if kind==5 and not living() and time>=float(DURATIONS[DEATH]):return
 if hit_flash>0.0 and living() and view==FRONT and clip!=ATTACK:
  draw_pose(canvas,origin,dst,view,5,HIT_DURATION-hit_flash,Color.WHITE,camera_right)
  return
 # A dual-sprite crossfade draws two different silhouettes simultaneously.
 # On a small mobile screen this reads as ghost limbs / temporal shimmer.
 # Show one authored pose at a time; locomotion phase is carried in set_clip().
 var tint: Color=Color(1.0,0.86,0.86,1.0) if hit_flash>0.0 else Color.WHITE
 draw_pose(canvas,origin,dst,view,clip,time,tint,camera_right)

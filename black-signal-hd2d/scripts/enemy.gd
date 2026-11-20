extends RefCounted
## Animated 2D combat unit. Positions and combat geometry are entirely planar.
const NAMES = ["РЕЙДЕР","ОХРАННИК","КИБЕРБРУТ","НЕТРАННЕР","КИБЕРПЁС","ДРОН"]
const IDS = ["raider","guard","brute","hacker","hound","drone"]
# health in pistol hits; walking speed, running speed, attack range, damage, cooldown, render height
const STATS = [
 [3,1.6,3.7,2.3,12,1.25,1.85],
 [4,1.3,2.5,11.5,8,1.65,1.88],
 [8,0.9,2.1,6.0,19,2.1,2.42],
 [3,1.4,2.9,13.0,7,1.9,1.78],
 [3,2.0,4.6,2.6,14,1.3,1.35],
 [4,2.0,3.3,10.0,6,1.45,1.58]
]
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
var attack_flash: float = 0.0
var attack_done: bool = false
var age: float = 0.0
var activated: bool = false
var patrol_direction: float = 1.0
var texture: Texture2D
var direction_texture: Texture2D
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
 texture=load("res://assets/mobs/"+str(IDS[kind])+".webp") as Texture2D
 direction_texture=load("res://assets/mobs/"+str(IDS[kind])+"_direction.webp") as Texture2D

func display_name() -> String:
 return str(NAMES[kind])

func height() -> float:
 return float(STATS[kind][6])

func living() -> bool:
 return hp>0

func set_clip(next: int) -> void:
 if next==clip: return
 prior_clip=clip;prior_time=time;blend=0.0
 var carry: float=time/float(DURATIONS[clip]) if clip<ATTACK and next<ATTACK and clip!=IDLE and next!=IDLE else 0.0
 clip=next;time=carry*float(DURATIONS[next]);attack_done=false

func take_hit() -> bool:
 if not living(): return false
 hp-=1;hit_flash=0.15;activated=true
 if hp<=0:
  hp=0;set_clip(DEATH);return true
 return false

func update(dt: float, player: Vector2, player_alive: bool) -> int:
 dt=clampf(dt,0.0,0.10)
 age+=dt;hit_flash=maxf(0.0,hit_flash-dt);attack_flash=maxf(0.0,attack_flash-dt)
 blend=minf(1.0,blend+dt/0.075)
 if prior_clip<ATTACK: prior_time=fposmod(prior_time+dt,float(DURATIONS[prior_clip]))
 time+=dt;cool=maxf(0.0,cool-dt)
 if clip==DEATH:
  time=minf(time,float(DURATIONS[DEATH]));return 0
 if not player_alive:
  set_clip(IDLE);return 0
 var rel: Vector2=player-p
 var distance: float=rel.length()
 var reach: float=float(STATS[kind][3])
 if distance<22.0:activated=true
 elif distance>39.0:activated=false
 if clip==ATTACK:
  if distance>0.01:heading=rel.normalized()
  var damage: int=0
  # Telegraph first; the attack deals damage exactly once at its active frame.
  if time>=float(DURATIONS[ATTACK])*0.48 and not attack_done:
   attack_done=true;attack_flash=0.13
   if distance<=reach+0.65:damage=int(STATS[kind][4])
  if time>=float(DURATIONS[ATTACK]):
   cool=float(STATS[kind][5]);set_clip(IDLE)
  return damage
 if not activated:
  # Slow sentry patrol around its spawn point.
  if absf(p.x-spawn.x)>0.85:patrol_direction=-signf(p.x-spawn.x)
  if fposmod(age+float(kind)*0.47,5.0)<2.0:
   heading=Vector2(patrol_direction,0)
   set_clip(WALK);p.x=clampf(p.x+patrol_direction*float(STATS[kind][1])*0.24*dt,-5.35,5.35)
  else:set_clip(IDLE)
 elif distance<=reach and cool<=0.0:
  if distance>0.01:heading=rel.normalized()
  set_clip(ATTACK)
 elif distance>reach*0.86:
  var running: bool=distance>reach+3.4
  set_clip(RUN if running else WALK)
  var speed: float=float(STATS[kind][2] if running else STATS[kind][1])
  var step: float=minf(speed*dt,maxf(0.0,distance-reach*0.81))
  if step>0.0001:
   heading=rel.normalized()
   p+=heading*step
 else:
  if distance>0.01:heading=rel.normalized()
  set_clip(IDLE)
 p.x=clampf(p.x,-5.35,5.35)
 if clip<ATTACK:time=fposmod(time,float(DURATIONS[clip]))
 return 0

func frame_for(state: int,t: float) -> int:
 var phase: float=t/float(DURATIONS[state])
 var frame: int=floori(phase*float(FRAMES))
 return posmod(frame,FRAMES) if state<ATTACK else clampi(frame,0,FRAMES-1)

func source_rect(state: int,t: float) -> Rect2:
 var idx: int=state*FRAMES+frame_for(state,t)
 return Rect2(Vector2(float(idx%6)*FRAME_W,float(floori(float(idx)/6.0))*FRAME_H),Vector2(FRAME_W,FRAME_H))

func view_for(to_camera: Vector2) -> int:
 var alignment: float=heading.dot(to_camera.normalized())
 if alignment>0.54:return FRONT
 if alignment< -0.54:return BACK
 return SIDE

func directional_rect(view: int,state: int,t: float) -> Rect2:
 var row: int=state
 var phase: float=t/float(DURATIONS[state])
 var n: int=posmod(floori(phase*DIR_FRAMES),DIR_FRAMES) if state<ATTACK else clampi(floori(phase*DIR_FRAMES),0,DIR_FRAMES-1)
 if view==BACK:
  row=5 if state==RUN else 4
  # Rear standing and attack keep a planted pose. Side death uses its own atlas.
  if state==IDLE or state==ATTACK:n=0
 var idx: int=row*DIR_FRAMES+n
 return Rect2(Vector2(float(idx%6)*FRAME_W,float(floori(float(idx)/6.0))*FRAME_H),Vector2(FRAME_W,FRAME_H))

func draw_pose(canvas: CanvasItem,foot: Vector2,dst: Rect2,view: int,state: int,t: float,tint: Color,camera_right: Vector2) -> void:
 var use_direction: bool=direction_texture!=null and view!=SIDE and state!=DEATH
 var flip: float=1.0
 if not use_direction:
  var authored_right: bool=kind==1 or kind==2 or kind==3
  flip=1.0 if (heading.dot(camera_right)>0.0)==authored_right else -1.0
 canvas.draw_set_transform(foot,0,Vector2(flip,1.0))
 if use_direction:
  canvas.draw_texture_rect_region(direction_texture,dst,directional_rect(view,state,t),tint)
 else:
  canvas.draw_texture_rect_region(texture,dst,source_rect(state,t),tint)
 canvas.draw_set_transform(Vector2.ZERO)

func paint(canvas: CanvasItem,foot: Vector2,projected_height: float,to_camera: Vector2,camera_right: Vector2) -> void:
 if texture==null:return
 var h: float=projected_height*1.23
 var w: float=h*FRAME_W/FRAME_H
 var lift: float=sin(age*3.2)*h*0.035 if kind==5 and living() else 0.0
 var origin: Vector2=foot+Vector2(0,lift)
 var view: int=view_for(to_camera)
 var dst:=Rect2(Vector2(-w*0.5,-h),Vector2(w,h))
 var a: float=blend*blend*(3.0-2.0*blend)
 var tint: Color=Color(1.0,0.68,0.68,1.0) if hit_flash>0.0 else Color.WHITE
 if a<1.0:
  var old_tint: Color=tint;old_tint.a=1.0-a
  draw_pose(canvas,origin,dst,view,prior_clip,prior_time,old_tint,camera_right)
 tint.a=a
 draw_pose(canvas,origin,dst,view,clip,time,tint,camera_right)

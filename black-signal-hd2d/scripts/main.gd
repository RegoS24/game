extends Node2D
## Pure CanvasItem projection: all locations are Vector2, all art is 2D.
const Animator = preload("res://scripts/rin_animator.gd")
const RIN_HEIGHT: float=1.68
const Mob = preload("res://scripts/enemy.gd")
const Mission = preload("res://scripts/mission.gd")
const BUILDING_FACADES: Texture2D=preload("res://assets/buildings/facades.webp")
const Cover = preload("res://scripts/cover.gd")
const W: float = 1280.0
const H: float = 720.0
const F: float = 540.0
const HORIZON: float = 207.0
const NEAR: float = 0.65
const LOBBY = preload("res://assets/lobby.webp")
const LOADING = preload("res://assets/loading.webp")
var font: Font = ThemeDB.fallback_font
const GOLD = Color("f0d49e")
const CYAN = Color("6ad9da")
const PINK = Color("f252ad")
var anim = Animator.new()
var mission = Mission.new()
var mode: String = "lobby"
var loading_time: float = 0.0
var pos: Vector2 = Vector2(0,-10)
var yaw: float = 0.0
var yaw_target: float = 0.0
var pitch: float=0.0
var pitch_target: float=0.0
const PITCH_MIN: float=-0.36
const PITCH_MAX: float=0.62
const RETICLE_Y: float=HORIZON+70.0
var gyro_enabled: bool=true
var gyro_sensitivity: float=1.0
var gyro_swap: bool=false
var gyro_invert_pitch: bool=false
var gyro_invert_yaw: bool=false
var gyro_rate: Vector2=Vector2.ZERO
var gyro_bias: Vector3=Vector3.ZERO
var gyro_calibration: float=0.0
var gyro_calibration_sum: Vector3=Vector3.ZERO
var gyro_samples: int=0
const GYRO_LEVELS: Array[float]=[0.5,1.0,1.5,2.0,2.5]
const GYRO_CONFIG: String="user://aim_settings.cfg"
var camera: Vector2 = Vector2.ZERO
var forward: Vector2 = Vector2(0,1)
var right: Vector2 = Vector2(1,0)
var motion: Vector2 = Vector2.ZERO
var touch_joy: Vector2 = Vector2.ZERO
var joy_id: int = -1
var aim_id: int = -1
var mouse_look: bool = false
var sprint_latch: bool = false
var shoot_hold: bool = false
var fire_id: int = -1
var shot_cool: float = 0.0
var shot_flash: float = 0.0
var reload_time: float = 0.0
var ammo: int = 12
var reserve: int = 108
var kills: int = 0
var world: Array[Dictionary] = []
var cover_rects: Array[Rect2] = []
var targets: Array[Mob] = []
const MED_STATIONS: Array[Vector2]=[Vector2(-4.3,23.0),Vector2(4.3,74.0),Vector2(-4.3,119.0)]
const MED_RANGE: float=2.1
const MED_HEAL: int=35
var used_med_stations: Dictionary={}
var player_hp: int = 100
var player_hurt: float = 0.0
var encounter_clear: bool = false
var battle_time: float = 0.0
const ENEMY_COUNT: int = 6
var clock: float = 0.0
var ui_status: String = ""
var ui_timer: float = 0.0
var action_rects: Dictionary = {"fire":Rect2(1146,444,104,104),"jump":Rect2(1156,575,80,62),"crouch":Rect2(1058,575,88,62),"prone":Rect2(960,575,88,62),"sprint":Rect2(220,575,84,62),"reload":Rect2(1150,350,100,58),"back":Rect2(16,16,115,39),"pause":Rect2(16,64,115,42),"interact":Rect2(895,140,174,60)}
const JOY := Vector2(115,590)
const GYRO_RECTS: Dictionary={"gyro":Rect2(395,60,126,42),"sensitivity":Rect2(530,60,113,42),"center":Rect2(652,60,114,42),"invert":Rect2(775,60,98,42),"axis":Rect2(882,60,101,42),"yaw_sign":Rect2(992,60,101,42)}

func _ready() -> void:
 Engine.max_fps = 90
 texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 load_aim_settings()
 mission.load_record()
 # Avoid allocating all enemy textures while the lobby is being loaded.
 if DisplayServer.get_name() != "headless" and OS.has_feature("mobile"):
  get_window().mode = Window.MODE_FULLSCREEN
 print("BLACK_SIGNAL_LOBBY_READY")
 if "--smoke" in OS.get_cmdline_user_args():
  run_smoke.call_deferred()

func build_world() -> void:
 world.clear(); targets.clear(); cover_rects.clear(); used_med_stations.clear()
 for z in range(-4,13):
  for x in [-1,1]:
   var zz: float = float(z)*19.0+float(x)*1.7
   world.append({"p":Vector2(float(x)*12.5,zz),"kind":"building","height":float(12+(abs(z*13+x*7)%9)),"side":x,"id":z,"style":posmod(abs(z*7+x*3),6)})
   world.append({"p":Vector2(float(x)*6.8,zz+5.0),"kind":"light","height":5.2,"side":x,"id":z})
   if z%2 == 0:
    var side_crate: Vector2=Vector2(float(x)*5.2,zz+9.0)
    world.append({"p":side_crate,"kind":"crate","height":1.3,"width":1.2,"side":x,"id":z})
    cover_rects.append(Rect2(side_crate-Vector2(0.6,0.60),Vector2(1.2,1.20)))
 # Purposeful mid-road barriers introduce a real flank-and-cover choice.
 var barriers: Array[Vector2]=[Vector2(2.1,17.0),Vector2(-2.1,40.0),Vector2(2.2,61.0),Vector2(-2.1,84.0),Vector2(2.1,108.0)]
 for i in range(barriers.size()):
  var spot: Vector2=barriers[i]
  world.append({"p":spot,"kind":"crate","height":1.6,"width":1.8,"side":0,"id":100+i})
  cover_rects.append(Rect2(spot-Vector2(.9,.7),Vector2(1.8,1.4)))
 # Six separate encounters spaced along the avenue. All six use original illustrated atlases.
 for i in range(MED_STATIONS.size()):
  world.append({"p":MED_STATIONS[i],"kind":"med_station","id":i})
 for i in range(ENEMY_COUNT):
  var lane: float=-0.58 if i==0 else (-3.5 if i%2==0 else 3.5)
  targets.append(Mob.new(i,Vector2(lane,3.5+float(i)*22.0)))

func start_game() -> void:
 mode = "loading"; loading_time = 0.65
 pos = Vector2(0,-10); yaw = 0.0; yaw_target = 0.0; motion = Vector2.ZERO
 pitch=0.0;pitch_target=0.0;gyro_rate=Vector2.ZERO
 begin_gyro_calibration()
 anim = Animator.new(); touch_joy = Vector2.ZERO; joy_id = -1; aim_id = -1
 kills = 0; ammo = 12; reserve = 108; reload_time = 0.0; shoot_hold = false
 player_hp=100;player_hurt=0.0;encounter_clear=false;battle_time=0.0
 mission.begin()
 sprint_latch = false; fire_id = -1; shot_cool = 0.0; shot_flash = 0.0
 build_world(); update_camera()
 print("BLACK_SIGNAL_MOBS_READY: ",targets.size())

func load_aim_settings() -> void:
 var cfg:=ConfigFile.new()
 if cfg.load(GYRO_CONFIG)!=OK:return
 gyro_enabled=bool(cfg.get_value("aim","gyro",true))
 gyro_sensitivity=clampf(float(cfg.get_value("aim","sensitivity",1.0)),0.5,2.5)
 gyro_swap=bool(cfg.get_value("aim","swap",false))
 gyro_invert_pitch=bool(cfg.get_value("aim","invert_pitch",false))
 gyro_invert_yaw=bool(cfg.get_value("aim","invert_yaw",false))

func save_aim_settings() -> void:
 var cfg:=ConfigFile.new()
 cfg.set_value("aim","gyro",gyro_enabled)
 cfg.set_value("aim","sensitivity",gyro_sensitivity)
 cfg.set_value("aim","swap",gyro_swap)
 cfg.set_value("aim","invert_pitch",gyro_invert_pitch)
 cfg.set_value("aim","invert_yaw",gyro_invert_yaw)
 cfg.save(GYRO_CONFIG)

func begin_gyro_calibration() -> void:
 gyro_calibration=0.55
 gyro_calibration_sum=Vector3.ZERO
 gyro_samples=0
 gyro_bias=Vector3.ZERO
 gyro_rate=Vector2.ZERO

func look_delta(delta: Vector2) -> void:
 yaw_target+=delta.x*0.004
 pitch_target=clampf(pitch_target+delta.y*0.004,PITCH_MIN,PITCH_MAX)

func gyro_axes(raw: Vector3) -> Vector2:
 # Godot reports device-axis radians/sec. Landscape orientation is fixed.
 # Expose axis swap and sign switches for device-dependent sensor orientation.
 var a:=Vector2(-raw.y,-raw.x)
 if gyro_swap:a=Vector2(-raw.x,-raw.y)
 if gyro_invert_pitch:a.y=-a.y
 if gyro_invert_yaw:a.x=-a.x
 return a

func apply_gyro_delta(raw: Vector3,dt: float) -> void:
 var sample: Vector2=gyro_axes(raw)
 if absf(sample.x)<0.018:sample.x=0.0
 if absf(sample.y)<0.018:sample.y=0.0
 gyro_rate=gyro_rate.lerp(sample,1.0-exp(-dt*24.0))
 yaw_target+=gyro_rate.x*dt*gyro_sensitivity
 pitch_target=clampf(pitch_target+gyro_rate.y*dt*gyro_sensitivity,PITCH_MIN,PITCH_MAX)

func update_gyro(dt: float) -> void:
 if not OS.has_feature("mobile") or not gyro_enabled:
  gyro_rate=Vector2.ZERO
  return
 var raw: Vector3=Input.get_gyroscope()
 var step: float=minf(dt,0.05)
 if gyro_calibration>0.0:
  if raw.length()<0.18:
   gyro_calibration_sum+=raw
   gyro_samples+=1
  gyro_calibration-=step
  if gyro_calibration<=0.0 and gyro_samples>0:
   gyro_bias=gyro_calibration_sum/float(gyro_samples)
  return
 apply_gyro_delta(raw-gyro_bias,step)

func gyro_action(key: String) -> void:
 match key:
  "gyro":
   gyro_enabled=not gyro_enabled
   begin_gyro_calibration()
   announce("ГИРОСКОП ВКЛЮЧЁН" if gyro_enabled else "ГИРОСКОП ВЫКЛЮЧЕН")
  "sensitivity":
   var index: int=0
   for i in range(GYRO_LEVELS.size()):
    if is_equal_approx(GYRO_LEVELS[i],gyro_sensitivity):index=i
   gyro_sensitivity=GYRO_LEVELS[(index+1)%GYRO_LEVELS.size()]
  "center":
   pitch_target=0.0;pitch=0.0
   yaw_target=yaw
   begin_gyro_calibration()
   announce("КАЛИБРОВКА — ДЕРЖИ ТЕЛЕФОН РОВНО")
  "invert":gyro_invert_pitch=not gyro_invert_pitch
  "axis":gyro_swap=not gyro_swap
  "yaw_sign":gyro_invert_yaw=not gyro_invert_yaw
 save_aim_settings()

func view_horizon() -> float:
 # Vertical off-axis projection; crosshair and all projected targets share it.
 return HORIZON-tan(pitch)*F

func reticle() -> Vector2:
 return Vector2(W*0.5,RETICLE_Y)

func update_camera() -> void:
 forward = Vector2(sin(yaw),cos(yaw))
 right = Vector2(cos(yaw),-sin(yaw))
 camera = pos-forward*4.3-right*0.58

func _process(dt: float) -> void:
 clock += dt
 if mode == "loading":
  loading_time -= dt
  if loading_time <= 0.0:
   mode = "game"
   print("BLACK_SIGNAL_CITY_READY")
 if mode == "game":
  battle_time+=dt
  player_hurt=maxf(0.0,player_hurt-dt)
  var input_vector := touch_joy
  input_vector.x += float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A))
  input_vector.y += float(Input.is_physical_key_pressed(KEY_W))-float(Input.is_physical_key_pressed(KEY_S))
  input_vector = input_vector.limit_length(1.0)
  var strength: float=input_vector.length()
  input_vector = Vector2.ZERO if strength<0.10 else input_vector.normalized()*clampf((strength-0.10)/0.90,0.0,1.0)
  var sprint: bool = (sprint_latch or Input.is_physical_key_pressed(KEY_SHIFT)) and anim.stance=="stand" and anim.target_stance=="stand" and anim.transition.is_empty()
  update_gyro(dt)
  yaw = lerp_angle(yaw,yaw_target,1.0-exp(-dt*18.0))
  pitch=lerpf(pitch,pitch_target,1.0-exp(-dt*22.0))
  update_camera()
  var stance_speed: float=(5.8 if sprint else 3.1)*anim.speed_factor()
  var goal: Vector2 = (right*input_vector.x+forward*input_vector.y)*stance_speed
  motion = motion.lerp(goal,1.0-exp(-dt*(10.5 if goal.length()>motion.length() else 8.0)))
  var previous_pos: Vector2=pos
  pos=Cover.move_circle(pos,motion*dt,0.31,cover_rects)
  pos.x = clampf(pos.x,-5.9,5.9); pos.y = clampf(pos.y,-65.0,215.0)
  # Animate actual displacement, not requested velocity: feet stop at cover/walls.
  var real_speed: float=pos.distance_to(previous_pos)/maxf(dt,0.0001)
  anim.tick(dt,minf(1.0,real_speed/maxf(0.1,stance_speed)),sprint and real_speed>3.5 and anim.stance=="stand")
  update_camera()
  shot_cool = maxf(0,shot_cool-dt); shot_flash = maxf(0,shot_flash-dt)
  if reload_time > 0.0:
   reload_time -= dt
   if reload_time <= 0.0:
    var n: int = mini(12-ammo,reserve); ammo += n; reserve -= n
  if shoot_hold: fire()
  # A short arrival grace period lets the player orient before the first attack.
  if battle_time>2.0:
   update_enemies(dt)
  ui_timer = maxf(0,ui_timer-dt)
 queue_redraw()

func update_enemies(dt: float) -> void:
 for mob in targets:
  var damage: int=mob.update(dt,pos,player_hp>0,cover_rects)
  if damage>0 and player_hp>0:
   if anim.stance=="prone" and mob.kind!=0 and mob.kind!=4: damage=maxi(1,roundi(float(damage)*0.65))
   elif anim.stance=="crouch" and mob.kind!=0 and mob.kind!=4:damage=maxi(1,roundi(float(damage)*0.8))
   player_hp=maxi(0,player_hp-damage);player_hurt=0.24
   if player_hp==0:
    shoot_hold=false;touch_joy=Vector2.ZERO;mode="defeat"
    announce("РИН ВЫВЕДЕНА ИЗ БОЯ")
    break
 # Soft separation keeps living enemies from stacking on the same point.
 for i in range(targets.size()):
  if not targets[i].living():continue
  for j in range(i+1,targets.size()):
   if not targets[j].living():continue
   var diff: Vector2=targets[i].p-targets[j].p
   var distance: float=diff.length()
   var required: float=targets[i].radius()+targets[j].radius()+0.12
   if distance<required and distance>0.01:
    var push: Vector2=diff.normalized()*(required-distance)*minf(0.5,dt*4.0)
    targets[i].p=Cover.move_circle(targets[i].p,push,targets[i].radius(),cover_rects)
    targets[j].p=Cover.move_circle(targets[j].p,-push,targets[j].radius(),cover_rects)

func announce(message: String) -> void:
 ui_status = message; ui_timer = 2.3

func fire() -> void:
 if mode!="game" or player_hp<=0 or shot_cool>0.0 or reload_time>0.0 or anim.jumping: return
 if ammo<=0: reload(); return
 ammo -= 1; shot_cool = 0.22; shot_flash = 0.08
 var best: int=aim_target()
 if best >= 0:
  var target: Mob=targets[best]
  if target.take_hit():
   kills+=1
   if kills==ENEMY_COUNT:
    if mission.register_kills(kills):announce("СЕКТОР ОЧИЩЕН — К ЭВАКУАЦИИ")
    else:announce("ВСЕ ВРАГИ УСТРАНЕНЫ — ПРОДОЛЖАЙ ЗАДАНИЕ")
   else:announce(target.display_name()+" УНИЧТОЖЕН")
  else:announce("ПОПАДАНИЕ")
 if ammo == 0: reload()

func nearest_med_station() -> int:
 if player_hp<=0 or player_hp>=100:return -1
 for i in range(MED_STATIONS.size()):
  if not used_med_stations.has(i) and pos.distance_to(MED_STATIONS[i])<=MED_RANGE:return i
 return -1

func use_med_station() -> bool:
 var index: int=nearest_med_station()
 if index<0:return false
 used_med_stations[index]=true
 player_hp=mini(100,player_hp+MED_HEAL)
 announce("АПТЕЧКА +%d HP"%MED_HEAL)
 return true

func interact_mission() -> void:
 if mode!="game" or player_hp<=0:return
 if not mission.in_range(pos) and use_med_station():return
 var result: String=mission.interact(pos,kills,battle_time)
 if result.is_empty():return
 announce(result)
 if mission.phase==Mission.Phase.COMPLETE:
  encounter_clear=true;mode="victory";shoot_hold=false;touch_joy=Vector2.ZERO
  print("BLACK_SIGNAL_CHAPTER01_COMPLETE: ",mission.mission_elapsed)

func aim_target() -> int:
 var best: int=-1
 var nearest: float=55.0
 var cross: Vector2=reticle()
 for i in range(targets.size()):
  var mob: Mob=targets[i]
  if not mob.living():continue
  var dep: float=local_of(mob.p).y
  if dep<=NEAR or dep>=nearest:continue
  if mob.kind!=5 and Cover.segment_blocked(pos,mob.p,cover_rects):continue
  var foot: Vector2=project(mob.p)
  var screen_h: float=mob.height()*F/dep
  var radius: float=mob.width()*0.5*F/dep+5.0
  var bottom: float=foot.y-mob.altitude()*F/dep+4.0
  if absf(cross.x-foot.x)<=radius and cross.y>=bottom-screen_h-8.0 and cross.y<=bottom:
   nearest=dep;best=i
 return best

func reload() -> void:
 if ammo<12 and reserve>0 and reload_time<=0: reload_time=1.5


# Android may suspend the process while the player is holding FIRE or moving.
# Pause immediately on focus loss/backgrounding; never resume combat automatically.
func _notification(what: int) -> void:
 if what==NOTIFICATION_APPLICATION_PAUSED or what==NOTIFICATION_WM_WINDOW_FOCUS_OUT:
  if mode=="game":toggle_pause()
 elif what==NOTIFICATION_APPLICATION_RESUMED:
  if mode=="paused":
   shoot_hold=false
   fire_id=-1
   joy_id=-1
   aim_id=-1
   touch_joy=Vector2.ZERO
   motion=Vector2.ZERO
   begin_gyro_calibration()

func toggle_pause() -> void:
 if mode=="game":
  mode="paused";shoot_hold=false;fire_id=-1;touch_joy=Vector2.ZERO;joy_id=-1;aim_id=-1;motion=Vector2.ZERO
 elif mode=="paused":
  mode="game";begin_gyro_calibration()

func activate(key: String) -> void:
 match key:
  "pause":toggle_pause()
  "jump": anim.request_jump()
  "crouch": anim.request_crouch()
  "prone": anim.request_prone()
  "sprint": sprint_latch = not sprint_latch
  "reload": reload()
  "fire": fire()
  "interact": interact_mission()
  "back": mode="lobby"; shoot_hold=false; touch_joy=Vector2.ZERO

func _input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo:
  if mode=="lobby" and event.keycode==KEY_ENTER: start_game(); return
  if mode=="victory" and event.keycode==KEY_ENTER: start_game(); return
  if mode=="paused":
   if event.physical_keycode==KEY_ESCAPE or event.physical_keycode==KEY_P:toggle_pause()
   return
  if mode!="game": return
  match event.physical_keycode:
   KEY_P: toggle_pause()
   KEY_SPACE: activate("jump")
   KEY_C: activate("crouch")
   KEY_Z: activate("prone")
   KEY_R: activate("reload")
   KEY_E: activate("interact")
   KEY_ESCAPE: activate("back")
   KEY_LEFT: yaw_target-=0.2
   KEY_RIGHT: yaw_target+=0.2
   KEY_UP: pitch_target=clampf(pitch_target-0.12,PITCH_MIN,PITCH_MAX)
   KEY_DOWN: pitch_target=clampf(pitch_target+0.12,PITCH_MIN,PITCH_MAX)
 if event is InputEventScreenTouch:
  if event.pressed: press_at(event.position,event.index)
  else: release_at(event.index)
 elif event is InputEventScreenDrag:
  drag_at(event.position,event.relative,event.index)
 elif event is InputEventMouseButton and not OS.has_feature("mobile"):
  if event.button_index==MOUSE_BUTTON_LEFT:
   if event.pressed: press_at(event.position,99)
   else: release_at(99)
  elif event.button_index==MOUSE_BUTTON_RIGHT: mouse_look=event.pressed
 elif event is InputEventMouseMotion and not OS.has_feature("mobile"):
  if mouse_look: look_delta(event.relative)
  else: drag_at(event.position,event.relative,99)

func press_at(p: Vector2,id: int) -> void:
 if mode=="paused":
  if Rect2(460,410,360,72).has_point(p) or Rect2(action_rects["pause"]).has_point(p):toggle_pause()
  elif Rect2(action_rects["back"]).has_point(p):mode="lobby"
  return
 if mode=="defeat" or mode=="victory":
  if Rect2(460,410,360,72).has_point(p):start_game()
  elif Rect2(16,16,115,39).has_point(p):mode="lobby"
  return
 if mode=="lobby":
  if Rect2(945,540,310,92).has_point(p): start_game()
  return
 if mode!="game": return
 for k in GYRO_RECTS:
  if Rect2(GYRO_RECTS[k]).has_point(p):
   gyro_action(str(k));return
 for k in action_rects:
  if Rect2(action_rects[k]).has_point(p):
   activate(str(k))
   if k=="fire": shoot_hold=true; fire_id=id
   return
 if p.distance_to(JOY)<120.0:
  joy_id=id; touch_joy=Vector2(p.x-JOY.x,JOY.y-p.y).limit_length(69.0)/69.0
 elif p.x>380:
  aim_id=id

func release_at(id: int) -> void:
 if id==joy_id: joy_id=-1; touch_joy=Vector2.ZERO
 if id==aim_id: aim_id=-1
 if id==fire_id: fire_id=-1; shoot_hold=false

func drag_at(p: Vector2, delta: Vector2,id: int) -> void:
 if id==joy_id: touch_joy=Vector2(p.x-JOY.x,JOY.y-p.y).limit_length(69.0)/69.0
 if id==aim_id: look_delta(delta)

func local_of(p: Vector2) -> Vector2:
 var rel := p-camera
 return Vector2(rel.dot(right),rel.dot(forward))

func project(p: Vector2,height: float = 0.0) -> Vector2:
 var v := local_of(p); var dep: float = maxf(NEAR,v.y)
 return Vector2(W*0.5+v.x*F/dep,view_horizon()+(3.1-height)*F/dep)

func ground_poly(points: Array[Vector2], color: Color) -> void:
 var loc: Array[Vector2] = []
 for p in points: loc.append(local_of(p))
 var clipped: PackedVector2Array = []
 for i in range(loc.size()):
  var a: Vector2=loc[i]; var b: Vector2=loc[(i+1)%loc.size()]
  if a.y>=NEAR: clipped.append(a)
  if (a.y>=NEAR)!=(b.y>=NEAR): clipped.append(a.lerp(b,(NEAR-a.y)/(b.y-a.y)))
 if clipped.size()<3: return
 var screen: PackedVector2Array = []
 for p in clipped: screen.append(Vector2(W*.5+p.x*F/p.y,view_horizon()+3.1*F/p.y))
 if Geometry2D.triangulate_polygon(screen).size()>0:
  draw_colored_polygon(screen,color)

func text_at(p: Vector2, value: String, size: int=18, color: Color=Color.WHITE) -> void:
 draw_string(font,p,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func panel(rect: Rect2, color: Color=Color(0.03,0.05,0.09,0.78), edge: Color=Color(0.55,0.70,0.78,0.35)) -> void:
 draw_rect(rect,color); draw_rect(rect,edge,false,1.3)

func button(rect: Rect2, text: String, active: bool=false) -> void:
 panel(rect,Color(0.32,0.11,0.26,0.87) if active else Color(0.04,0.07,0.12,0.79),PINK if active else Color(0.65,0.73,0.8,0.65))
 var size: int=16; var width: float=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
 text_at(rect.get_center()+Vector2(-width*0.5,6),text,size,GOLD if active else Color.WHITE)

func draw_city() -> void:
 # Painted-looking 2D sky silhouette and perspective strips. No 3D geometry.
 var horizon: float=view_horizon()
 var sky_h: float=clampf(horizon,0.0,H)
 for i in range(32):
  var v: float=float(i)/32.0
  if sky_h>0.0:draw_rect(Rect2(0,v*sky_h,W,sky_h/32+1),Color("080f24").lerp(Color("30234b"),v))
 for i in range(42):
  var x: float=fposmod(float(i)*97.0-yaw*100.0,1450.0)-85.0
  var h: float=30.0+float((i*137)%145)
  draw_rect(Rect2(x,horizon-h,35+float((i*31)%50),h),Color("111829"))
  draw_line(Vector2(x+5,horizon-h+4),Vector2(x+5,horizon-6),Color(0.24,0.63,0.74,0.22),2)
 draw_rect(Rect2(0,sky_h,W,H-sky_h),Color("18222f"))
 # Draw road, sidewalk, lane edges and dashed markings using math on Vector2 coordinates.
 ground_poly([Vector2(-10,-120),Vector2(10,-120),Vector2(10,320),Vector2(-10,320)],Color("313849"))
 ground_poly([Vector2(-5.9,-120),Vector2(5.9,-120),Vector2(5.9,320),Vector2(-5.9,320)],Color("202533"))
 for s in [-1,1]:
  var f: float=float(s)*5.9
  ground_poly([Vector2(f-.07,-120),Vector2(f+.07,-120),Vector2(f+.07,320),Vector2(f-.07,320)],Color("a7a7ac"))
 var start_strip: int=maxi(-16,floori(pos.y/5.0)-16)
 var end_strip: int=mini(70,ceili(pos.y/5.0)+33)
 for i in range(start_strip,end_strip):
  var z: float=float(i)*5.0
  if local_of(Vector2(0,z)).y < -10: continue
  ground_poly([Vector2(-.08,z),Vector2(.08,z),Vector2(.08,z+2.6),Vector2(-.08,z+2.6)],Color("878c9a"))
  for s in [-1,1]:
   var x: float=float(s)*7.5
   ground_poly([Vector2(x-1.1,z),Vector2(x+1.1,z),Vector2(x+1.1,z+.045),Vector2(x-1.1,z+.045)],Color("566171"))
 var drawlist: Array[Dictionary] = []
 for o in world:
  var dep: float=local_of(o["p"]).y
  if dep>NEAR and dep<160:
   drawlist.append({"o":o,"depth":dep})
 for t in targets:
  var dep: float=local_of(t.p).y
  if dep>NEAR and dep<100.0:drawlist.append({"o":{"p":t.p,"kind":"mob","mob":t},"depth":dep})
 if mission.has_marker():
  var objective_pos: Vector2=mission.marker_position()
  var objective_depth: float=local_of(objective_pos).y
  if objective_depth>NEAR and objective_depth<160.0:
   drawlist.append({"o":{"p":objective_pos,"kind":"mission"},"depth":objective_depth})
 drawlist.sort_custom(func(a,b): return a["depth"]>b["depth"])
 for entry in drawlist: draw_prop(entry["o"],entry["depth"])
 # Fine rain, subtle on-screen vignette lines.
 for i in range(46):
  var x: float=fposmod(float(i)*139.3+clock*75,W+60)-30
  var y: float=fposmod(float(i)*93.1+clock*360,H)
  draw_line(Vector2(x,y),Vector2(x-5,y+16),Color(0.68,0.76,0.86,0.13),0.9,true)

func draw_prop(o: Dictionary, dep: float) -> void:
 var p: Vector2=project(o["p"]); var scale_factor: float=F/dep; var kind: String=o["kind"]
 if p.x<-2000 or p.x>W+2000: return
 if kind=="building":
  # 24 authored-like original procedural facade textures (6 archetypes x 4 views).
  # The game is still a 2.5D CanvasItem renderer, not a mesh-based 3D world.
  var building_h: float=float(o["height"])*scale_factor
  var building_w: float=13.5*scale_factor
  var dest:=Rect2(p-Vector2(building_w*.5,building_h),Vector2(building_w,building_h))
  if dest.end.x<0.0 or dest.position.x>W or dest.end.y<0.0 or dest.position.y>H:return
  var facade_dir: Vector2=Vector2(-float(o["side"]),0.0)
  var to_eye: Vector2=pos-Vector2(o["p"])
  var facing: float=facade_dir.dot(to_eye.normalized()) if to_eye.length_squared()>0.0001 else 1.0
  var view: int=0 if facing>0.36 else (2 if facing< -0.50 else (1 if to_eye.y>0 else 3))
  var style: int=int(o["style"])
  var source:=Rect2(Vector2(float(view)*256.0,float(style)*384.0),Vector2(256.0,384.0))
  draw_texture_rect_region(BUILDING_FACADES,dest,source)
 elif kind=="light":
  var end:Vector2=p-Vector2(0,5.2*scale_factor)
  draw_line(p,end,Color("151c27"),maxf(1,scale_factor*.12)); draw_line(end,end+Vector2(-float(o["side"])*.9*scale_factor,0),CYAN,maxf(1,scale_factor*.1))
  for k in range(5,0,-1): draw_circle(end,scale_factor*float(k)*.14,Color(0.31,0.80,0.87,0.035))
 elif kind=="crate":
  var crate_w: float=float(o.get("width",1.2))
  var crate_h: float=float(o.get("height",1.3))
  var r:=Rect2(p-Vector2(crate_w*.5,crate_h)*scale_factor,Vector2(crate_w,crate_h)*scale_factor)
  draw_rect(r,Color("364350"));draw_rect(r,Color("141d2b"),false,maxf(1.0,scale_factor*.07))
  draw_line(r.position,r.end,Color("69788a"),maxf(1.0,scale_factor*.05))
  draw_line(r.position+Vector2(0,r.size.y),r.position+Vector2(r.size.x,0),Color("8c9eb1"),maxf(1.0,scale_factor*.05))
 elif kind=="med_station":
  var consumed: bool=used_med_stations.has(int(o["id"]))
  var med_color: Color=Color("4b6570") if consumed else Color("56e8aa")
  var med_rect:=Rect2(p-Vector2(0.36,0.95)*scale_factor,Vector2(0.72,0.95)*scale_factor)
  draw_rect(med_rect,Color("132b33"))
  draw_rect(med_rect,med_color,false,maxf(1.0,scale_factor*.05))
  draw_line(med_rect.get_center()+Vector2(-0.18,0),med_rect.get_center()+Vector2(0.18,0),med_color,maxf(2.0,scale_factor*.09))
  draw_line(med_rect.get_center()+Vector2(0,-0.18),med_rect.get_center()+Vector2(0,0.18),med_color,maxf(2.0,scale_factor*.09))
 elif kind=="mission":
  var scan: bool=mission.phase==Mission.Phase.SCAN
  var glow: Color=CYAN if scan else GOLD
  var ph: float=(1.6 if scan else 3.2)*scale_factor
  var pw: float=(0.8 if scan else 1.4)*scale_factor
  var rect:=Rect2(p-Vector2(pw*.5,ph),Vector2(pw,ph))
  draw_rect(rect,Color(0.02,0.10,0.16,0.87))
  draw_rect(rect,glow,false,maxf(1.0,scale_factor*.06))
  var beacon_pt: Vector2=p-Vector2(0,ph*1.30)
  draw_circle(beacon_pt,clampf(scale_factor*.26,3.0,30.0),Color(glow.r,glow.g,glow.b,.32))
  draw_arc(beacon_pt,clampf(scale_factor*.20,2.0,22.0),0.0,TAU,24,glow,2.0,true)
  if scale_factor>8.0:text_at(beacon_pt+Vector2(-64,-17),"ТЕРМИНАЛ" if scan else "ЭВАКУАЦИЯ",14,glow)
 elif kind=="mob":
  draw_enemy(o["mob"],p,scale_factor)

func draw_enemy(mob: Mob,foot: Vector2,scale_factor: float) -> void:
 var h: float=mob.height()*scale_factor
 var top: float=foot.y-(mob.height()+mob.altitude())*scale_factor
 if foot.x+h<0.0 or foot.x-h>W or foot.y<0.0 or top>H:return
 var shadow: float=maxf(2.0,mob.radius()*scale_factor)
 draw_set_transform(foot,0,Vector2(1.0,0.26))
 draw_circle(Vector2.ZERO,shadow,Color(0.02,0.02,0.05,0.48))
 draw_set_transform(Vector2.ZERO)
 mob.paint(self,foot,scale_factor,camera-mob.p,right)
 if not mob.living():return
 if mob.attack_flash>0.0 and mob.kind!=0 and mob.kind!=4:
  draw_line(foot-Vector2(0,mob.altitude()*scale_factor+h*0.53),project(pos,1.15),Color(1.0,0.35,0.30,mob.attack_flash*4.0),1.8,true)
 var bar_w: float=clampf(h*0.65,20.0,90.0)
 var bar_p: Vector2=Vector2(foot.x-bar_w*0.5,top-10.0)
 draw_rect(Rect2(bar_p,Vector2(bar_w,4)),Color("291b31"))
 draw_rect(Rect2(bar_p,Vector2(bar_w*float(mob.hp)/float(mob.max_hp),4)),PINK)
 if h>52.0:
  text_at(bar_p+Vector2(0,-5),mob.display_name(),clampi(roundi(h*.12),12,17),Color("e7cbdc"))

func _draw() -> void:
 if mode=="lobby":
  draw_texture_rect(LOBBY,Rect2(0,0,W,H),false)
  panel(Rect2(0,0,W,H),Color(0.015,0.02,0.06,0.25),Color.TRANSPARENT)
  panel(Rect2(925,478,345,190));text_at(Vector2(949,510),"СЕКТОР 07 • ТРЕНИРОВКА",20,GOLD);text_at(Vector2(950,534),"Одиночный / камера TPP • 2D",15,CYAN)
  button(Rect2(945,540,310,92),"НАЧАТЬ",true)
  panel(Rect2(18,610,410,74));text_at(Vector2(32,637),"BLACK SIGNAL / HD2D",20,GOLD);text_at(Vector2(32,662),"Глава 01 • Сигнал и эвакуация",15)
  if mission.best_seconds>=0:text_at(Vector2(32,594),"Рекорд прохождения: %.1f с"%mission.best_seconds,15,CYAN)
  return
 if mode=="loading":
  draw_texture_rect(LOADING,Rect2(0,0,W,H),false);return
 draw_city()
 var foot: Vector2=project(pos)
 var sc: float=(F/4.3)*RIN_HEIGHT/164.0
 var shadow_scale: float=1.0-anim.jump_lift()/150.0
 draw_set_transform(foot,0,Vector2(shadow_scale,.30*shadow_scale));draw_circle(Vector2.ZERO,31,Color(0.01,0.02,0.04,0.60*shadow_scale));draw_set_transform(Vector2.ZERO)
 var recoil := Vector2(-shot_flash*30.0,shot_flash*55.0)
 anim.paint(self,foot,sc,recoil)
 if shot_flash>0:
  draw_circle(foot+Vector2(-38,-105),12*shot_flash/.08,Color("ffda9a"));draw_line(foot+Vector2(-38,-105),reticle(),Color(1,.8,.4,shot_flash*5),2)
 draw_hud()
 if mode=="paused":
  panel(Rect2(0,0,W,H),Color(0.01,0.02,0.05,0.72),Color.TRANSPARENT)
  panel(Rect2(390,240,500,290))
  text_at(Vector2(535,304),"ПАУЗА",32,GOLD)
  text_at(Vector2(445,355),"Бой, таймер и управление остановлены",17,CYAN)
  button(Rect2(460,410,360,72),"ПРОДОЛЖИТЬ",true)
  button(action_rects["back"],"ЛОББИ")
  return
 if player_hurt>0.0:draw_rect(Rect2(0,0,W,H),Color(0.8,0.04,0.08,player_hurt*0.40))
 if mode=="defeat":
  panel(Rect2(0,0,W,H),Color(0.02,0.02,0.05,0.75),Color.TRANSPARENT)
  panel(Rect2(390,245,500,275));text_at(Vector2(480,310),"СИГНАЛ ПОТЕРЯН",30,PINK)
  text_at(Vector2(477,363),"Уничтожено: "+str(kills)+" / "+str(ENEMY_COUNT),22,GOLD)
  button(Rect2(460,410,360,72),"ПОВТОРИТЬ",true);button(action_rects["back"],"ЛОББИ")
 elif mode=="victory":
  panel(Rect2(0,0,W,H),Color(0.015,0.025,0.06,0.78),Color.TRANSPARENT)
  panel(Rect2(382,208,516,336))
  text_at(Vector2(440,269),"ГЛАВА 01 ЗАВЕРШЕНА",30,CYAN)
  text_at(Vector2(456,318),"СИГНАЛ ВОССТАНОВЛЕН",19,GOLD)
  text_at(Vector2(456,366),"Время: %.1f с   •   Устранено: %d"%[mission.mission_elapsed,kills],19)
  text_at(Vector2(456,400),"Лучшее: %.1f с   •   Проходов: %d"%[mission.best_seconds,mission.completed_runs],17,CYAN)
  button(Rect2(460,410,360,72),"ПОВТОРИТЬ",true)
  button(action_rects["back"],"ЛОББИ")

func draw_hud() -> void:
 button(action_rects["back"],"ЛОББИ")
 button(action_rects["pause"],"ПАУЗА")
 panel(Rect2(151,16,228,74));text_at(Vector2(165,41),"RIN  /  SECTOR 07",19,GOLD);text_at(Vector2(165,65),"Мобы: "+str(kills)+" / "+str(ENEMY_COUNT),17,CYAN)
 panel(Rect2(380,120,503,61))
 text_at(Vector2(394,147),mission.objective_text(kills),16,CYAN)
 text_at(Vector2(394,169),"Время: %.1f с   •   Лучшее: %s"%[battle_time,"—" if mission.best_seconds<0 else "%.1f с"%mission.best_seconds],13,GOLD)
 var deg: int=posmod(int(rad_to_deg(yaw)),360);text_at(Vector2(575,35),"N  ·  %03d°"%deg,20,GOLD);draw_line(Vector2(460,47),Vector2(820,47),Color(0.8,0.8,0.86,.6),1)
 panel(Rect2(1110,16,144,130));text_at(Vector2(1120,37),"СЕКТОР 07",14,GOLD);draw_rect(Rect2(1154,46,55,90),Color("354257"));draw_line(Vector2(1181,46),Vector2(1181,136),Color("808d9d"),1)
 for t in targets:
  if t.living() and absf(t.p.y-pos.y)<120.0:
   var a:Vector2=t.p;draw_circle(Vector2(1181+a.x*3,clampf(136-(a.y-pos.y)*.7,48,135)),3,PINK)
 draw_circle(Vector2(1181+pos.x*3,126),4,CYAN)
 if mission.has_marker():
  var waypoint: Vector2=mission.marker_position()
  draw_circle(Vector2(1181+waypoint.x*3,clampf(136-(waypoint.y-pos.y)*.7,48,135)),6,GOLD)
 draw_circle(JOY,80,Color(0.01,0.04,0.07,0.45));draw_arc(JOY,80,0,TAU,72,Color(0.85,0.9,1,.52),2,true);draw_circle(JOY+Vector2(touch_joy.x,-touch_joy.y)*55,35,Color(0.52,0.62,0.72,0.46));draw_arc(JOY+Vector2(touch_joy.x,-touch_joy.y)*55,35,0,TAU,48,Color(0.87,0.91,1,.5),1.4,true)
 if mission.in_range(pos):button(action_rects["interact"],"ВЗАИМОДЕЙСТВ.",true)
 elif nearest_med_station()>=0:button(action_rects["interact"],"ЛЕЧЕНИЕ +35",true)
 button(action_rects["fire"],"ОГОНЬ",shoot_hold);button(action_rects["reload"],"ПЕРЕЗАР.",reload_time>0);button(action_rects["jump"],"ПРЫЖОК",anim.jumping);button(action_rects["crouch"],"ПРИСЕСТЬ",anim.target_stance=="crouch");button(action_rects["prone"],"ЛЕЧЬ",anim.target_stance=="prone");button(action_rects["sprint"],"БЕГ",sprint_latch)
 panel(Rect2(430,595,425,95));text_at(Vector2(449,621),"K-9   /   "+anim.state_label(),17,GOLD);text_at(Vector2(449,654),"%02d  /  %d"%[ammo,reserve],28);draw_rect(Rect2(449,669,386,6),Color("392334"));draw_rect(Rect2(449,669,386*float(player_hp)/100.0,6),CYAN if player_hp>30 else PINK);text_at(Vector2(700,653),str(player_hp)+" HP",16,CYAN)
 if reload_time>0: draw_rect(Rect2(449,680,386*(1-reload_time/1.5),4),GOLD)
 if ui_timer>0: text_at(Vector2(540,123),ui_status,21,GOLD)
 button(GYRO_RECTS["gyro"],"ГИРО "+("ВКЛ" if gyro_enabled else "ВЫКЛ"),gyro_enabled)
 button(GYRO_RECTS["sensitivity"],"×%.1f"%gyro_sensitivity)
 button(GYRO_RECTS["center"],"ЦЕНТР")
 button(GYRO_RECTS["invert"],"ВЕРТ. ±",gyro_invert_pitch)
 button(GYRO_RECTS["axis"],"ОСИ XY",gyro_swap)
 button(GYRO_RECTS["yaw_sign"],"ГОР. ±",gyro_invert_yaw)
 var aim: Vector2=reticle()
 var aim_color: Color=PINK if aim_target()>=0 else Color(1,1,1,.76)
 draw_arc(aim,13,0,TAU,32,aim_color,1.4,true)
 draw_line(aim-Vector2(22,0),aim-Vector2(6,0),aim_color,1.3,true)
 draw_line(aim+Vector2(6,0),aim+Vector2(22,0),aim_color,1.3,true)
 draw_line(aim-Vector2(0,22),aim-Vector2(0,6),aim_color,1.3,true)
 draw_line(aim+Vector2(0,6),aim+Vector2(0,22),aim_color,1.3,true)

func run_smoke() -> void:
 start_game(); mode="game"
 anim.tick(.03,1.0,false)
 assert(anim.clip=="walk")
 anim.tick(.03,1.0,true);assert(anim.clip=="run")
 anim.request_jump();anim.tick(.03,1.0,true);assert(anim.jumping)
 for i in range(100): anim.tick(.016,0,false)
 assert(not anim.jumping and anim.clip=="idle")
 assert(anim.index_for("walk",89.9)==0)
 assert(anim.index_for("jump",100)==71)
 # Check each clip's nominal sampling rate and packed-page layout.
 assert(Engine.max_fps==90 and Animator.ANIMATION_FPS==90.0)
 var frame_total: int=0
 for name in Animator.COUNT:
  var count: int=int(Animator.COUNT[name])
  frame_total+=count
  var intervals: int=count if anim.is_loop(name) else count-1
  assert(absf(float(intervals)/float(Animator.DURATION[name])-90.0)<0.001)
  var layout: Array=Animator.LAYOUT[name]
  var pages: Array=Animator.SHEETS[name]
  assert(pages.size()==ceili(float(count)/float(layout[5])))
  assert(int(layout[6])>=8)
  for page in pages:
   assert(page.get_width()<=4096 and page.get_height()<=4096)
 assert(frame_total==742)
 var cadence=Animator.new()
 cadence.set_clip("run",0.0)
 cadence.moving=1.0
 for i in range(72):
  cadence.advance_gait(1.0/90.0)
  assert(cadence.frame_index()==(i+1)%72)
 print("RIN90_CADENCE_OK: eight clips at 90 samples per second")
 # Verify full two-leg gait cycles are traversed, including both opposite peaks.
 for gait in ["run","crouch_walk","crawl"]:
  var tester=Animator.new()
  tester.set_clip(gait,0.0)
  tester.moving=1.0
  var count: int=int(Animator.COUNT[gait])
  var quadrant: float=float(Animator.DURATION[gait])/4.0
  for step in range(4):
   for substep in range(10):tester.advance_gait(quadrant/10.0)
   assert(tester.frame_index()==int((step+1)*count/4.0)%count)

 assert(anim.jump_lift()==0.0)
 anim.request_crouch()
 for i in range(100): anim.tick(.016,0,false)
 assert(anim.stance=="crouch" and anim.frame_index()==int(Animator.COUNT["crouch"])-1)
 for i in range(70):anim.tick(.016,0.85,false)
 assert(anim.clip=="crouch_walk" and anim.state_label()=="ХОДЬБА В ПРИСЕДЕ")
 var crouch_frame: int=anim.frame_index()
 anim.tick(.10,0.85,false)
 assert(anim.frame_index()!=crouch_frame)
 for i in range(70):anim.tick(.016,0.0,false)
 assert(anim.clip=="crouch" and anim.stance=="crouch")
 anim.request_prone()
 for i in range(100): anim.tick(.016,0,false)
 assert(anim.stance=="prone")
 for i in range(70):anim.tick(.016,0.9,false)
 assert(anim.clip=="crawl" and anim.state_label()=="ПОЛЗАНИЕ")
 var crawl_frame: int=anim.frame_index()
 anim.tick(.10,0.9,false)
 assert(anim.frame_index()!=crawl_frame)
 for i in range(70):anim.tick(.016,0.0,false)
 assert(anim.clip=="prone" and anim.stance=="prone")
 anim.request_prone()
 for i in range(180): anim.tick(.016,0,false)
 assert(anim.stance=="stand" and anim.clip=="idle")
 assert(BUILDING_FACADES.get_width()==1024 and BUILDING_FACADES.get_height()==2304)
 var types: Dictionary={}
 for o in world:
  if o["kind"]=="building":types[int(o["style"])]=true
 assert(types.size()==6)
 print("BLACK_SIGNAL_BUILDING_SMOKE_OK: six facade styles, four directional views")
 assert(targets.size()==ENEMY_COUNT)
 assert(cover_rects.size()>5)
 for unit in targets:
  assert(not Cover.circle_overlaps(unit.p,unit.radius(),cover_rects))
 # Combat and movement must respect true-world geometry.
 var blockers: Array[Rect2]=[Rect2(Vector2(-.5,-.75),Vector2(1.0,1.50))]
 assert(Cover.segment_blocked(Vector2(-2,0),Vector2(2,0),blockers))
 assert(not Cover.segment_blocked(Vector2(-2,2),Vector2(2,2),blockers))
 var halted: Vector2=Cover.move_circle(Vector2(-2,0),Vector2(4,0),.3,blockers)
 assert(halted.x<-.79 and not Cover.circle_overlaps(halted,.3,blockers))
 var slid: Vector2=Cover.move_circle(Vector2(-.81,0),Vector2(.8,1.4),.3,blockers)
 assert(slid.y>1.0 and not Cover.circle_overlaps(slid,.3,blockers))
 var blocked_guard: Mob=Mob.new(1,Vector2(0,10))
 blocked_guard.set_clip(Mob.ATTACK)
 var covered_damage: int=0
 var cover_wall: Array[Rect2]=[Rect2(Vector2(-1,4.0),Vector2(2,2.0))]
 for step in range(70):
  covered_damage+=blocked_guard.update(.016,Vector2(0,0),true,cover_wall)
 assert(covered_damage==0)
 assert(not Cover.segment_blocked(Vector2(0,10),Vector2(0,0),[]))
 # Patrol and pursuit both use physical world collision; enemies must approach, not retreat.
 var patrol: Mob=Mob.new(0,Vector2(0,0))
 patrol.activated=false
 patrol.age=0.0
 var patrol_block: Array[Rect2]=[Rect2(Vector2(-1,0.4),Vector2(2,0.5))]
 for step in range(90):
  patrol.update(.016,Vector2(0,50),true,patrol_block)
  assert(not Cover.circle_overlaps(patrol.p,patrol.radius(),patrol_block))
 var hunter: Mob=Mob.new(0,Vector2(0,0))
 var prey: Vector2=Vector2(0,12)
 var before_distance: float=hunter.p.distance_to(prey)
 for step in range(70):hunter.update(.016,prey,true)
 assert(hunter.p.distance_to(prey)<before_distance-1.0)
 assert(hunter.heading.dot((prey-hunter.p).normalized())>0.9)
 assert(hunter.view_for((prey-hunter.p).normalized())==Mob.FRONT)
 print("BLACK_SIGNAL_ENEMY_BEHAVIOR_OK: chase direction, facing and patrol collisions")
 print("BLACK_SIGNAL_COVER_SMOKE_OK: collision, sliding, hitscan and enemy cover")
 for i in range(ENEMY_COUNT):
  var unit: Mob=targets[i]
  assert(unit.kind==i and unit.max_hp>0 and unit.texture!=null)
  assert(unit.texture.get_width()==1536 and unit.texture.get_height()==3584)
  assert(unit.width()>0.0 and unit.height()>0.0)
  unit.heading=Vector2(0,-1)
  assert(unit.view_for(Vector2(0,-1))==Mob.FRONT)
  assert(unit.view_for(Vector2(1,0))==Mob.SIDE)
  assert(unit.view_for(Vector2(0,1))==Mob.BACK)
  assert(unit.packed_rect(Mob.BACK,Mob.RUN,.5).end.y<=3584.0)
  assert(unit.packed_rect(Mob.FRONT,5,.2).end.y<=3584.0)
  assert(unit.frame_for(Mob.DEATH,9.0)==17)
  assert(unit.packed_rect(Mob.FRONT,Mob.DEATH,9.0).end.y<=3584.0)
  var old_hp: int=unit.hp
  assert(unit.take_hit()==false and unit.hp==old_hp-1)
  unit.set_clip(Mob.IDLE)
  unit.cool=0.0
  unit.update(.016,unit.p+Vector2(0,0.5),true)
  assert(unit.clip==Mob.ATTACK)
  var damage: int=0
  for n in range(90):damage+=unit.update(.016,unit.p+Vector2(0,0.5),true)
  assert(damage==int(Mob.STATS[i][4]))
  while unit.living():unit.take_hit()
  assert(unit.clip==Mob.DEATH and unit.hp==0)
  for n in range(100):unit.update(.016,pos,true)
  assert(unit.frame_for(unit.clip,unit.time)==17)
 # Requested velocity can remain high against cover; animation must follow displacement.
 var movement_wall: Array[Rect2]=[Rect2(Vector2(0.0,0.0),Vector2(2.0,2.0))]
 var blocked_start:=Vector2(-0.31,1.0)
 var blocked_end: Vector2=Cover.move_circle(blocked_start,Vector2(0.25,0.0),0.31,movement_wall)
 assert(blocked_end.distance_to(blocked_start)<0.01)
 var free_end: Vector2=Cover.move_circle(blocked_start,Vector2(-0.25,0.0),0.31,movement_wall)
 assert(free_end.distance_to(blocked_start)>0.20)
 print("BLACK_SIGNAL_MOVEMENT_SMOKE_OK: blocked footfalls and free movement")
 # Medical stations: one use, capped health, no waste at full health, reset per run.
 assert(MED_STATIONS.size()==3)
 pos=MED_STATIONS[0];player_hp=55
 assert(nearest_med_station()==0 and use_med_station() and player_hp==90)
 assert(not use_med_station() and used_med_stations.size()==1)
 pos=MED_STATIONS[1];player_hp=90
 assert(use_med_station() and player_hp==100)
 pos=MED_STATIONS[2];assert(nearest_med_station()==-1)
 player_hp=50;assert(use_med_station() and player_hp==85)
 start_game();mode="game"
 assert(used_med_stations.is_empty() and player_hp==100)
 print("BLACK_SIGNAL_MEDICAL_SMOKE_OK: proximity, single use, HP cap and run reset")
 # Pause must freeze the combat state and clear held touch controls.
 mode="game";touch_joy=Vector2(0.8,0.2);shoot_hold=true;fire_id=2;joy_id=1;aim_id=3;motion=Vector2(1,0)
 var pause_hp: int=player_hp
 var pause_pos: Vector2=pos
 var pause_ammo: int=ammo
 var pause_time: float=battle_time
 toggle_pause()
 assert(mode=="paused" and not shoot_hold and fire_id==-1 and joy_id==-1 and aim_id==-1)
 assert(touch_joy==Vector2.ZERO and motion==Vector2.ZERO)
 _process(0.1)
 assert(player_hp==pause_hp and pos==pause_pos and ammo==pause_ammo and battle_time==pause_time)
 toggle_pause()
 assert(mode=="game" and gyro_calibration>0.0)
 print("BLACK_SIGNAL_PAUSE_SMOKE_OK: gameplay frozen, touch reset, resume recalibrates gyro")
 # Android backgrounding must freeze gameplay and require explicit resume.
 touch_joy=Vector2(0.7,0.4);shoot_hold=true;fire_id=7;joy_id=8;aim_id=9
 var background_hp: int=player_hp
 var background_ammo: int=ammo
 var background_pos: Vector2=pos
 var background_time: float=battle_time
 _notification(NOTIFICATION_APPLICATION_PAUSED)
 assert(mode=="paused" and not shoot_hold and fire_id==-1 and joy_id==-1 and aim_id==-1)
 _process(0.2)
 assert(player_hp==background_hp and ammo==background_ammo and pos==background_pos and battle_time==background_time)
 _notification(NOTIFICATION_APPLICATION_RESUMED)
 assert(mode=="paused" and gyro_calibration>0.0)
 toggle_pause()
 assert(mode=="game")
 _notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)
 assert(mode=="paused")
 toggle_pause()
 print("BLACK_SIGNAL_ANDROID_LIFECYCLE_OK: background/focus loss pauses; no auto-resume")
 # Objective tests must not modify player records in user://.
 var quest=Mission.new()
 quest.begin()
 assert(quest.phase==Mission.Phase.SCAN)
 assert(quest.interact(Vector2.ZERO,0,1.0,false)=="")
 assert(quest.interact(Mission.TERMINAL,0,2.0,false)!="")
 assert(quest.phase==Mission.Phase.ELIMINATE)
 assert(not quest.register_kills(5))
 assert(quest.register_kills(6))
 assert(quest.phase==Mission.Phase.EXTRACT)
 assert(quest.interact(Mission.TERMINAL,6,50.0,false)=="")
 assert(quest.interact(Mission.EXFIL,5,55.0,false)=="")
 assert(quest.interact(Mission.EXFIL,6,65.0,false)!="")
 assert(quest.phase==Mission.Phase.COMPLETE and quest.completed_runs==1)
 assert(quest.best_seconds==65.0)
 print("BLACK_SIGNAL_MISSION_SMOKE_OK: objective order, range, kill gate, finish")

 start_game();mode="game"
 assert(mission.phase==Mission.Phase.SCAN)
 assert(targets[2].height()>targets[1].height() and targets[4].height()<RIN_HEIGHT and targets[5].altitude()>1.0)
 # Align held aim with the actual center of the first unit, not a stale fixed height.
 yaw=0.0;yaw_target=0.0;update_camera()
 var first: Mob=targets[0]
 var dep: float=local_of(first.p).y
 pitch=atan((HORIZON+(3.1-first.height()*0.5)*F/dep-reticle().y)/F);pitch_target=pitch
 assert(aim_target()==0)
 var baseline_pitch: float=pitch
 var old_foot: Vector2=project(targets[0].p)
 look_delta(Vector2(0,100))
 assert(pitch_target>baseline_pitch)
 pitch=pitch_target
 assert(project(targets[0].p).y<old_foot.y and aim_target()!=0)
 pitch=baseline_pitch;pitch_target=0.0
 gyro_swap=false;gyro_invert_pitch=false;gyro_invert_yaw=false;gyro_rate=Vector2.ZERO
 apply_gyro_delta(Vector3(-1,-1,0),0.05)
 assert(pitch_target>0.0 and yaw_target>0.0)
 pitch_target=0.0;yaw_target=0.0;gyro_rate=Vector2.ZERO
 fire();assert(ammo==11 and targets[0].hp==targets[0].max_hp-1)
 print("BLACK_SIGNAL_SMOKE_OK: six scaled front/side/rear mobs + front hit reaction + vertical aim and gyro; pure 2D")
 get_tree().quit()

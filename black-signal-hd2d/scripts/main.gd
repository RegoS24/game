extends Node2D
## Pure CanvasItem projection: all locations are Vector2, all art is 2D.
const Animator = preload("res://scripts/rin_animator.gd")
const Mob = preload("res://scripts/enemy.gd")
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
var mode: String = "lobby"
var loading_time: float = 0.0
var pos: Vector2 = Vector2(0,-10)
var yaw: float = 0.0
var yaw_target: float = 0.0
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
var targets: Array[Mob] = []
var player_hp: int = 100
var player_hurt: float = 0.0
var encounter_clear: bool = false
var battle_time: float = 0.0
const ENEMY_COUNT: int = 6
var clock: float = 0.0
var ui_status: String = ""
var ui_timer: float = 0.0
var action_rects: Dictionary = {"fire":Rect2(1146,444,104,104),"jump":Rect2(1156,575,80,62),"crouch":Rect2(1058,575,88,62),"prone":Rect2(960,575,88,62),"sprint":Rect2(220,575,84,62),"reload":Rect2(1150,350,100,58),"back":Rect2(16,16,115,39)}
const JOY := Vector2(115,590)

func _ready() -> void:
 Engine.max_fps = 60
 texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
 # Avoid allocating all enemy textures while the lobby is being loaded.
 if DisplayServer.get_name() != "headless" and OS.has_feature("mobile"):
  get_window().mode = Window.MODE_FULLSCREEN
 print("BLACK_SIGNAL_LOBBY_READY")
 if "--smoke" in OS.get_cmdline_user_args():
  run_smoke.call_deferred()

func build_world() -> void:
 world.clear(); targets.clear()
 for z in range(-4,13):
  for x in [-1,1]:
   var zz: float = float(z)*19.0+float(x)*1.7
   world.append({"p":Vector2(float(x)*12.5,zz),"kind":"building","height":float(12+(abs(z*13+x*7)%9)),"side":x,"id":z})
   world.append({"p":Vector2(float(x)*6.8,zz+5.0),"kind":"light","height":5.2,"side":x,"id":z})
   if z%2 == 0:
    world.append({"p":Vector2(float(x)*5.2,zz+9.0),"kind":"crate","height":1.3,"side":x,"id":z})
 # Six separate encounters spaced along the avenue. All six use original illustrated atlases.
 for i in range(ENEMY_COUNT):
  var lane: float=0.0 if i==0 else (-3.5 if i%2==0 else 3.5)
  targets.append(Mob.new(i,Vector2(lane,3.5+float(i)*22.0)))

func start_game() -> void:
 mode = "loading"; loading_time = 0.65
 pos = Vector2(0,-10); yaw = 0.0; yaw_target = 0.0; motion = Vector2.ZERO
 anim = Animator.new(); touch_joy = Vector2.ZERO; joy_id = -1; aim_id = -1
 kills = 0; ammo = 12; reserve = 108; reload_time = 0.0; shoot_hold = false
 player_hp=100;player_hurt=0.0;encounter_clear=false;battle_time=0.0
 sprint_latch = false; fire_id = -1; shot_cool = 0.0; shot_flash = 0.0
 build_world(); update_camera()

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
  var sprint: bool = sprint_latch or Input.is_physical_key_pressed(KEY_SHIFT)
  yaw = lerp_angle(yaw,yaw_target,1.0-exp(-dt*18.0))
  update_camera()
  var goal: Vector2 = (right*input_vector.x+forward*input_vector.y)*(5.8 if sprint else 3.1)*anim.speed_factor()
  motion = motion.lerp(goal,1.0-exp(-dt*(10.5 if goal.length()>motion.length() else 8.0)))
  pos += motion*dt
  pos.x = clampf(pos.x,-5.9,5.9); pos.y = clampf(pos.y,-65.0,215.0)
  var real_speed: float=motion.length()
  anim.tick(dt,minf(1.0,real_speed/(5.8 if sprint else 3.1)),sprint and real_speed>3.5 and anim.stance=="stand")
  update_camera()
  shot_cool = maxf(0,shot_cool-dt); shot_flash = maxf(0,shot_flash-dt)
  if reload_time > 0.0:
   reload_time -= dt
   if reload_time <= 0.0:
    var n: int = mini(12-ammo,reserve); ammo += n; reserve -= n
  if shoot_hold: fire()
  # A short arrival grace period lets the player orient before the first attack.
  if battle_time>2.0 and not encounter_clear:
   update_enemies(dt)
  ui_timer = maxf(0,ui_timer-dt)
 queue_redraw()

func update_enemies(dt: float) -> void:
 for mob in targets:
  var damage: int=mob.update(dt,pos,player_hp>0)
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
   if distance<0.9 and distance>0.01:
    var push: Vector2=diff.normalized()*(0.9-distance)*minf(0.5,dt*4.0)
    targets[i].p+=push;targets[j].p-=push

func announce(message: String) -> void:
 ui_status = message; ui_timer = 2.3

func fire() -> void:
 if mode!="game" or player_hp<=0 or shot_cool>0.0 or reload_time>0.0 or anim.jumping: return
 if ammo<=0: reload(); return
 ammo -= 1; shot_cool = 0.22; shot_flash = 0.08
 var best: int = -1; var nearest: float = 50.0
 for i in range(targets.size()):
  if not targets[i].living(): continue
  var rel: Vector2 = targets[i].p-pos
  var depth: float = rel.dot(forward)
  if depth>0 and depth<nearest and absf(rel.dot(right))<1.2+depth*0.025:
   nearest=depth; best=i
 if best >= 0:
  var target: Mob=targets[best]
  if target.take_hit():
   kills+=1
   if kills==ENEMY_COUNT:
    encounter_clear=true;announce("СЕКТОР ОЧИЩЕН")
   else:announce(target.display_name()+" УНИЧТОЖЕН")
  else:announce("ПОПАДАНИЕ")
 if ammo == 0: reload()

func reload() -> void:
 if ammo<12 and reserve>0 and reload_time<=0: reload_time=1.5

func activate(key: String) -> void:
 match key:
  "jump": anim.request_jump()
  "crouch": anim.request_crouch()
  "prone": anim.request_prone()
  "sprint": sprint_latch = not sprint_latch
  "reload": reload()
  "fire": fire()
  "back": mode="lobby"; shoot_hold=false; touch_joy=Vector2.ZERO

func _input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo:
  if mode=="lobby" and event.keycode==KEY_ENTER: start_game(); return
  if mode!="game": return
  match event.physical_keycode:
   KEY_SPACE: activate("jump")
   KEY_C: activate("crouch")
   KEY_Z: activate("prone")
   KEY_R: activate("reload")
   KEY_ESCAPE: activate("back")
   KEY_LEFT: yaw_target-=0.2
   KEY_RIGHT: yaw_target+=0.2
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
  if mouse_look: yaw_target+=event.relative.x*0.004
  else: drag_at(event.position,event.relative,99)

func press_at(p: Vector2,id: int) -> void:
 if mode=="defeat":
  if Rect2(460,410,360,72).has_point(p):start_game()
  elif Rect2(16,16,115,39).has_point(p):mode="lobby"
  return
 if mode=="lobby":
  if Rect2(945,540,310,92).has_point(p): start_game()
  return
 if mode!="game": return
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
 if id==aim_id: yaw_target+=delta.x*0.004

func local_of(p: Vector2) -> Vector2:
 var rel := p-camera
 return Vector2(rel.dot(right),rel.dot(forward))

func project(p: Vector2,height: float = 0.0) -> Vector2:
 var v := local_of(p); var dep: float = maxf(NEAR,v.y)
 return Vector2(W*0.5+v.x*F/dep,HORIZON+(3.1-height)*F/dep)

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
 for p in clipped: screen.append(Vector2(W*.5+p.x*F/p.y,HORIZON+3.1*F/p.y))
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
 for i in range(32):
  var v: float=float(i)/32.0; draw_rect(Rect2(0,v*HORIZON,W,HORIZON/32+1),Color("080f24").lerp(Color("30234b"),v))
 for i in range(42):
  var x: float=fposmod(float(i)*97.0-yaw*100.0,1450.0)-85.0
  var h: float=30.0+float((i*137)%145)
  draw_rect(Rect2(x,HORIZON-h,35+float((i*31)%50),h),Color("111829"))
  draw_line(Vector2(x+5,HORIZON-h+4),Vector2(x+5,HORIZON-6),Color(0.24,0.63,0.74,0.22),2)
 draw_rect(Rect2(0,HORIZON,W,H-HORIZON),Color("18222f"))
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
  var h: float=float(o["height"])*scale_factor; var w: float=13.5*scale_factor
  var r := Rect2(p-Vector2(w*.5,h),Vector2(w,h)); var accent: Color=PINK if int(o["id"])%3==0 else CYAN
  draw_rect(r,Color("1d2332")); draw_rect(r,Color("090e1d"),false,maxf(1.0,scale_factor*.13))
  draw_rect(Rect2(r.position,Vector2(w*.11,h)),Color("111727")); draw_rect(Rect2(r.position+Vector2(w*.82,0),Vector2(w*.18,h)),Color("121a26"))
  if r.end.x<0.0 or r.position.x>W or r.end.y<0.0 or r.position.y>H: return
  var rows:int=mini(12,int(float(o["height"])/1.5)) if scale_factor>9.0 else mini(4,int(float(o["height"])/3.0))
  for k in range(rows):
   for j in range(4):
    var q:=Rect2(r.position+Vector2(w*.18+float(j)*w*.15,h*.05+float(k)*h*.073),Vector2(w*.095,h*.042))
    draw_rect(q,Color("c87f70") if (j+k+int(o["id"]))%4==0 else Color("233e56"))
  draw_rect(Rect2(r.position+Vector2(w*.12,h*.74),Vector2(w*.68,h*.075)),Color("111424")); draw_rect(Rect2(r.position+Vector2(w*.12,h*.74),Vector2(w*.68,h*.075)),accent,false,maxf(1,scale_factor*.08))
  if scale_factor>12:
   text_at(r.position+Vector2(w*.16,h*.797),"LOTOS" if int(o["id"])%3==0 else "SECTOR 07",clampi(int(scale_factor*.32),9,38),accent)
  draw_rect(Rect2(r.position+Vector2(w*.2,h*.86),Vector2(w*.50,h*.14)),Color("101725")); draw_line(r.position+Vector2(w*.2,h*.86),r.position+Vector2(w*.7,h*.86),accent,maxf(1,scale_factor*.06))
 elif kind=="light":
  var end:Vector2=p-Vector2(0,5.2*scale_factor)
  draw_line(p,end,Color("151c27"),maxf(1,scale_factor*.12)); draw_line(end,end+Vector2(-float(o["side"])*.9*scale_factor,0),CYAN,maxf(1,scale_factor*.1))
  for k in range(5,0,-1): draw_circle(end,scale_factor*float(k)*.14,Color(0.31,0.80,0.87,0.035))
 elif kind=="crate":
  var r:=Rect2(p-Vector2(.6,1.3)*scale_factor,Vector2(1.2,1.3)*scale_factor); draw_rect(r,Color("364350"));draw_rect(r,Color("141d2b"),false,2);draw_line(r.position,r.end,Color("69788a"),2)
 elif kind=="mob":
  draw_enemy(o["mob"],p,scale_factor)

func draw_enemy(mob: Mob,foot: Vector2,scale_factor: float) -> void:
 var h: float=mob.height()*scale_factor
 if foot.x+h<0.0 or foot.x-h>W or foot.y+h<0.0 or foot.y-h>H:return
 var shadow: float=maxf(2.0,h*(0.33 if mob.kind>=4 else 0.22))
 draw_set_transform(foot,0,Vector2(1.0,0.26))
 draw_circle(Vector2.ZERO,shadow,Color(0.02,0.02,0.05,0.48))
 draw_set_transform(Vector2.ZERO)
 mob.paint(self,foot,h,(pos-mob.p).dot(right)>0.0)
 if not mob.living():return
 if mob.attack_flash>0.0 and mob.kind!=0 and mob.kind!=4:
  draw_line(foot-Vector2(0,h*0.53),project(pos,1.15),Color(1.0,0.35,0.30,mob.attack_flash*4.0),1.8,true)
 var bar_w: float=clampf(h*0.65,20.0,90.0)
 var bar_p: Vector2=foot-Vector2(bar_w*0.5,h*1.18)
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
  panel(Rect2(18,610,410,74));text_at(Vector2(32,637),"BLACK SIGNAL / HD2D",20,GOLD);text_at(Vector2(32,662),"Шесть типов противников • predemo",15)
  return
 if mode=="loading":
  draw_texture_rect(LOADING,Rect2(0,0,W,H),false);return
 draw_city()
 var foot: Vector2=project(pos)
 var sc: float=(F/4.3)*1.95/164.0
 var shadow_scale: float=1.0-anim.jump_lift()/150.0
 draw_set_transform(foot,0,Vector2(shadow_scale,.30*shadow_scale));draw_circle(Vector2.ZERO,31,Color(0.01,0.02,0.04,0.60*shadow_scale));draw_set_transform(Vector2.ZERO)
 var recoil := Vector2(-shot_flash*30.0,shot_flash*55.0)
 anim.paint(self,foot,sc,recoil)
 if shot_flash>0:
  draw_circle(foot+Vector2(-38,-105),12*shot_flash/.08,Color("ffda9a"));draw_line(foot+Vector2(-38,-105),Vector2(W*.5,HORIZON+70),Color(1,.8,.4,shot_flash*5),2)
 draw_hud()
 if player_hurt>0.0:draw_rect(Rect2(0,0,W,H),Color(0.8,0.04,0.08,player_hurt*0.40))
 if mode=="defeat":
  panel(Rect2(0,0,W,H),Color(0.02,0.02,0.05,0.75),Color.TRANSPARENT)
  panel(Rect2(390,245,500,275));text_at(Vector2(480,310),"СИГНАЛ ПОТЕРЯН",30,PINK)
  text_at(Vector2(477,363),"Уничтожено: "+str(kills)+" / "+str(ENEMY_COUNT),22,GOLD)
  button(Rect2(460,410,360,72),"ПОВТОРИТЬ",true);button(action_rects["back"],"ЛОББИ")
 elif encounter_clear:
  panel(Rect2(480,92,320,65))
  text_at(Vector2(520,132),"СЕКТОР ОЧИЩЕН",23,CYAN)

func draw_hud() -> void:
 button(action_rects["back"],"ЛОББИ")
 panel(Rect2(151,16,228,74));text_at(Vector2(165,41),"RIN  /  SECTOR 07",19,GOLD);text_at(Vector2(165,65),"Мобы: "+str(kills)+" / "+str(ENEMY_COUNT),17,CYAN)
 var deg: int=posmod(int(rad_to_deg(yaw)),360);text_at(Vector2(575,35),"N  ·  %03d°"%deg,20,GOLD);draw_line(Vector2(460,47),Vector2(820,47),Color(0.8,0.8,0.86,.6),1)
 panel(Rect2(1110,16,144,130));text_at(Vector2(1120,37),"СЕКТОР 07",14,GOLD);draw_rect(Rect2(1154,46,55,90),Color("354257"));draw_line(Vector2(1181,46),Vector2(1181,136),Color("808d9d"),1)
 for t in targets:
  if t.living() and absf(t.p.y-pos.y)<120.0:
   var a:Vector2=t.p;draw_circle(Vector2(1181+a.x*3,clampf(136-(a.y-pos.y)*.7,48,135)),3,PINK)
 draw_circle(Vector2(1181+pos.x*3,126),4,CYAN)
 draw_circle(JOY,80,Color(0.01,0.04,0.07,0.45));draw_arc(JOY,80,0,TAU,72,Color(0.85,0.9,1,.52),2,true);draw_circle(JOY+Vector2(touch_joy.x,-touch_joy.y)*55,35,Color(0.52,0.62,0.72,0.46));draw_arc(JOY+Vector2(touch_joy.x,-touch_joy.y)*55,35,0,TAU,48,Color(0.87,0.91,1,.5),1.4,true)
 button(action_rects["fire"],"ОГОНЬ",shoot_hold);button(action_rects["reload"],"ПЕРЕЗАР.",reload_time>0);button(action_rects["jump"],"ПРЫЖОК",anim.jumping);button(action_rects["crouch"],"ПРИСЕСТЬ",anim.target_stance=="crouch");button(action_rects["prone"],"ЛЕЧЬ",anim.target_stance=="prone");button(action_rects["sprint"],"БЕГ",sprint_latch)
 panel(Rect2(430,595,425,95));text_at(Vector2(449,621),"K-9   /   "+anim.state_label(),17,GOLD);text_at(Vector2(449,654),"%02d  /  %d"%[ammo,reserve],28);draw_rect(Rect2(449,669,386,6),Color("392334"));draw_rect(Rect2(449,669,386*float(player_hp)/100.0,6),CYAN if player_hp>30 else PINK);text_at(Vector2(700,653),str(player_hp)+" HP",16,CYAN)
 if reload_time>0: draw_rect(Rect2(449,680,386*(1-reload_time/1.5),4),GOLD)
 if ui_timer>0: text_at(Vector2(540,123),ui_status,21,GOLD)
 var aim:=Vector2(W*.5,HORIZON+70);draw_arc(aim,13,0,TAU,32,Color(1,1,1,.65),1.4,true);draw_line(aim-Vector2(18,0),aim+Vector2(18,0),Color(1,1,1,.55),1);draw_line(aim-Vector2(0,18),aim+Vector2(0,18),Color(1,1,1,.55),1)

func run_smoke() -> void:
 start_game(); mode="game"
 anim.tick(.03,1.0,false)
 assert(anim.clip=="walk")
 anim.tick(.03,1.0,true);assert(anim.clip=="run")
 anim.request_jump();anim.tick(.03,1.0,true);assert(anim.jumping)
 for i in range(100): anim.tick(.016,0,false)
 assert(not anim.jumping and anim.clip=="idle")
 assert(anim.index_for("walk",59.9)==0)
 assert(anim.index_for("jump",100)==47)
 assert(anim.jump_lift()==0.0)
 anim.request_crouch()
 for i in range(100): anim.tick(.016,0,false)
 assert(anim.stance=="crouch" and anim.frame_index()==int(Animator.COUNT["crouch"])-1)
 anim.request_prone()
 for i in range(100): anim.tick(.016,0,false)
 assert(anim.stance=="prone")
 anim.request_prone()
 for i in range(180): anim.tick(.016,0,false)
 assert(anim.stance=="stand" and anim.clip=="idle")
 assert(targets.size()==ENEMY_COUNT)
 for i in range(ENEMY_COUNT):
  var unit: Mob=targets[i]
  assert(unit.kind==i and unit.max_hp>0 and unit.texture!=null)
  assert(unit.texture.get_width()==1152 and unit.texture.get_height()==3360)
  assert(unit.frame_for(Mob.DEATH,9.0)==17)
  assert(unit.source_rect(Mob.DEATH,9.0).end.y<=3360.0)
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
 start_game();mode="game"
 fire();assert(ammo==11 and targets[0].hp==targets[0].max_hp-1)
 print("BLACK_SIGNAL_SMOKE_OK: walk run jump crouch prone stand fire; six mobs + 540 frames + attacks + death; pure 2D")
 get_tree().quit()

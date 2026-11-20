extends Node3D

const CITY = preload("res://city.gd")
const ACTOR = preload("res://actor.gd")
const HEROES = {"rin":"РИН","kai":"КАЙ","vega":"ВЕГА","nox":"НОКС"}
const GUNS = {
	"pistol":{"title":"K-9","clip":12,"rate":.30,"damage":26,"reserve":72},
	"smg":{"title":"VEX","clip":24,"rate":.105,"damage":18,"reserve":120},
	"rifle":{"title":"MANTIS","clip":30,"rate":.15,"damage":36,"reserve":150},
	"shotgun":{"title":"BULL","clip":6,"rate":.72,"damage":62,"reserve":30},
	"plasma":{"title":"ION","clip":10,"rate":.48,"damage":58,"reserve":40}}
var city
var player: CharacterBody3D
var visual
var camera: Camera3D
var env_node: WorldEnvironment
var layer: CanvasLayer
var ui: Control
var mode = "loading"
var modal = false
var hero = "rin"
var weapon = "rifle"
var slots = ["rifle","smg","pistol"]
var mags = {}
var reserves = {}
var hp = 100.0
var cash = 100
var kits = 3
var armor = false
var grenades = 2
var mission = 0
var kills = 0
var enemies = []
var npcs = []
var loot = []
var projectiles = []
var recoil = 0.0
var cooldown = 0.0
var reload_time = 0.0
var healing = 0.0
var yaw = 0.0
var pitch = -.10
var aim = false
var sprint = false
var stance = false
var firing = false
var single = false
var fired = false
var look_sens = .004
var auto_aim = true
var joy = Vector2.ZERO
var joy_id = -1
var look_id = -1
var joy_start = Vector2.ZERO
var fire_ids = []
var touch_actions = {}
var hud_label: Label
var ammo_label: Label
var mission_label: Label
var prompt_label: Label
var health_bar: ProgressBar
var info_label: Label
var stick: Control
var map_label: Label
var progress: ProgressBar
var loading_label: Label
var toast_until = 0.0
var clock = 0.0
var rng = RandomNumberGenerator.new()

func _ready():
	rng.seed=7126
	layer=CanvasLayer.new()
	add_child(layer)
	ui=Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	show_loading()
	await get_tree().process_frame
	setup_environment()
	city=CITY.new()
	add_child(city)
	city.build_ground()
	update_loading(.16,"Дорожная сеть и освещение")
	for i in range(5):
		await get_tree().process_frame
		city.build_block(i)
		update_loading(.22+float(i)*.115,"Сектор 07 · квартал "+str(i+1))
	city.market()
	create_player()
	create_npc("nyx",Vector3(-5,0,5),"НИКС")
	create_npc("vega",Vector3(-7,0,-8),"МАРА")
	for i in range(7):
		create_npc(["kai","vega","nox"][i%3],Vector3((1 if i%2==0 else -1)*7.6,0,-45+i*11),"")
	for id in GUNS:
		mags[id]=GUNS[id]["clip"]
		reserves[id]=GUNS[id]["reserve"]
	camera=Camera3D.new()
	camera.fov=67
	camera.near=.12
	camera.far=220
	add_child(camera)
	camera.current=true
	load_profile()
	update_loading(1.0,"Нокс-Сити готов")
	await get_tree().process_frame
	show_lobby()
	print("BS3D_LOBBY_READY")
	if "--smoke" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		start_game()
		await get_tree().create_timer(.8).timeout
		assert(is_instance_valid(player) and is_instance_valid(camera) and enemies.size()==6)
		assert(player.get_child_count()>0 and city.get_child_count()>100)
		print("BS3D_SMOKE_PASS")
		get_tree().quit()

func setup_environment():
	env_node=WorldEnvironment.new()
	var env=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("11172c")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("9faad9")
	env.ambient_light_energy=.57
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env.fog_enabled=true
	env.fog_light_color=Color("37405b")
	env.fog_density=.009
	env_node.environment=env
	add_child(env_node)
	var moon=DirectionalLight3D.new()
	moon.rotation_degrees=Vector3(-40,-28,0)
	moon.light_color=Color("bdc7ff")
	moon.light_energy=.83
	moon.shadow_enabled=true
	add_child(moon)

func body_at(pos: Vector3, id: String) -> CharacterBody3D:
	var b=CharacterBody3D.new()
	var col=CollisionShape3D.new()
	var cap=CapsuleShape3D.new()
	cap.radius=.32
	cap.height=1.80
	col.shape=cap
	col.position.y=.92
	b.add_child(col)
	b.position=pos
	add_child(b)
	var a=ACTOR.new()
	b.add_child(a)
	a.create(city,id)
	b.set_meta("actor",a)
	return b

func create_player():
	player=body_at(Vector3(0,.05,15),hero)
	player.collision_layer=2
	player.collision_mask=1
	visual=player.get_meta("actor")

func change_hero(id: String):
	hero=id
	if is_instance_valid(visual):
		player.remove_child(visual)
		visual.queue_free()
	visual=ACTOR.new()
	player.add_child(visual)
	visual.create(city,hero)
	visual.set_weapon(weapon)
	player.set_meta("actor",visual)
	save_profile()

func create_npc(id: String,pos: Vector3,title: String):
	var n=Node3D.new()
	n.position=pos
	add_child(n)
	var a=ACTOR.new()
	n.add_child(a)
	a.create(city,id)
	a.gun.visible=false
	if title!="":
		var l=Label3D.new()
		l.text=title
		l.font_size=48
		l.pixel_size=.0055
		l.position.y=2.22
		l.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		n.add_child(l)
	npcs.append({"node":n,"actor":a,"start":pos,"title":title,"phase":rng.randf_range(0,6)})

func create_enemy(pos: Vector3):
	var n=body_at(pos,"guard")
	n.collision_layer=4
	n.collision_mask=1
	var a=n.get_meta("actor")
	a.set_weapon("rifle")
	enemies.append({"node":n,"actor":a,"hp":90.0,"cool":rng.randf_range(.4,1.5)})

func clear_world_combat():
	for e in enemies:
		e.node.queue_free()
	enemies.clear()
	for item in loot: item.node.queue_free()
	loot.clear()
	for p in projectiles: p.node.queue_free()
	projectiles.clear()

func start_game():
	clear_world_combat()
	mode="play"
	modal=false
	player.position=Vector3(0,.06,15)
	player.velocity=Vector3.ZERO
	yaw=0
	pitch=-.11
	hp=100
	mission=0
	kills=0
	kits=3
	cooldown=0
	reload_time=0
	healing=0
	for id in GUNS:
		mags[id]=GUNS[id]["clip"]
		reserves[id]=GUNS[id]["reserve"]
	for pos in [Vector3(1,.1,-13),Vector3(-3,.1,-24),Vector3(4,.1,-30),Vector3(0,.1,-36),Vector3(-3,.1,-45),Vector3(4,.1,-53)]:
		create_enemy(pos)
	make_loot(Vector3(2,.1,13),"ammo",36)
	make_loot(Vector3(-3,.1,14),"armor",1)
	make_loot(Vector3(2,.1,8),"kit",1)
	visual.set_weapon(weapon)
	show_hud()
	print("BS3D_CITY_READY")

func style(fill: String, border: String, width: int=1) -> StyleBoxFlat:
	var s=StyleBoxFlat.new()
	s.bg_color=Color(fill)
	s.border_color=Color(border)
	s.set_border_width_all(width)
	s.set_corner_radius_all(4)
	s.content_margin_left=12
	s.content_margin_right=12
	s.content_margin_top=8
	s.content_margin_bottom=8
	return s

func clear_ui():
	for n in ui.get_children():
		ui.remove_child(n)
		n.queue_free()
	touch_actions.clear()
	joy=Vector2.ZERO
	joy_id=-1
	look_id=-1
	fire_ids.clear()
	firing=false

func place(c: Control, rect: Vector4, margin: Vector4=Vector4.ZERO):
	ui.add_child(c)
	c.anchor_left=rect.x
	c.anchor_top=rect.y
	c.anchor_right=rect.z
	c.anchor_bottom=rect.w
	c.offset_left=margin.x
	c.offset_top=margin.y
	c.offset_right=margin.z
	c.offset_bottom=margin.w
	return c

func text_at(msg: String, rect: Vector4, size: int=20, color: String="e7e4f1", align: int=HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l=Label.new()
	l.text=msg
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",Color(color))
	l.add_theme_color_override("font_outline_color",Color("06091b"))
	l.add_theme_constant_override("outline_size",4)
	l.horizontal_alignment=align
	l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	place(l,rect)
	return l

func panel_at(rect: Vector4, color: String="111927df", border: String="4a587b89"):
	var p=Panel.new()
	p.add_theme_stylebox_override("panel",style(color,border))
	p.mouse_filter=Control.MOUSE_FILTER_IGNORE
	place(p,rect)
	return p

func btn(msg: String,rect: Vector4,callback: Callable, primary: bool=false, action: String="") -> Button:
	var b=Button.new()
	b.text=msg
	b.focus_mode=Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size",24 if primary else 17)
	b.add_theme_stylebox_override("normal",style("b32c70f6" if primary else "1a2437dd","f582cf" if primary else "63758eaa",2 if primary else 1))
	b.add_theme_stylebox_override("hover",style("ce528e" if primary else "384b65","f2cae9"))
	b.add_theme_stylebox_override("pressed",style("70234e","f582cf"))
	b.pressed.connect(callback)
	place(b,rect)
	if action!="": touch_actions[action]=b
	else: touch_actions["button_"+str(b.get_instance_id())]=b
	return b

func show_loading():
	clear_ui()
	var bg=ColorRect.new()
	bg.color=Color("080c19")
	place(bg,Vector4(0,0,1,1))
	bg.mouse_filter=Control.MOUSE_FILTER_IGNORE
	text_at("BLACK",Vector4(.0,.29,1,.43),76,"f4e8f4",HORIZONTAL_ALIGNMENT_CENTER)
	text_at("S I G N A L",Vector4(0,.43,1,.53),34,"fc4a9d",HORIZONTAL_ALIGNMENT_CENTER)
	text_at("N O X   C I T Y   /   2 1 8 6",Vector4(0,.57,1,.64),18,"82dbed",HORIZONTAL_ALIGNMENT_CENTER)
	loading_label=text_at("Инициализация Godot 3D",Vector4(.20,.74,.80,.80),19,"d5d2e3",HORIZONTAL_ALIGNMENT_CENTER)
	progress=ProgressBar.new()
	progress.max_value=1.0
	progress.show_percentage=false
	progress.add_theme_stylebox_override("background",style("1f2840","4b5977"))
	progress.add_theme_stylebox_override("fill",style("d94a9b","fb90d7"))
	place(progress,Vector4(.20,.82,.80,.846))

func update_loading(v: float,msg: String):
	progress.value=v
	loading_label.text=msg+"  ·  "+str(int(v*100))+"%"

func show_lobby():
	mode="lobby"
	modal=false
	clear_ui()
	player.position=Vector3(0,.05,15)
	player.rotation.y=PI
	visual.gun.visible=true
	panel_at(Vector4(0,0,1,.125),"101626df","53618155")
	text_at("BLACK SIGNAL",Vector4(.024,.014,.30,.070),34,"f5edf7")
	text_at("N O X   C I T Y  /  2 1 8 6",Vector4(.026,.068,.32,.108),13,"ea5dba")
	text_at("₡  "+str(cash)+"     /     OFFLINE",Vector4(.55,.02,.79,.10),20,"f1d3a2",HORIZONTAL_ALIGNMENT_RIGHT)
	btn("НАСТРОЙКИ",Vector4(.81,.025,.98,.10),show_settings)
	panel_at(Vector4(.023,.16,.255,.29))
	text_at(HEROES[hero]+"  ·  УР. 01",Vector4(.037,.17,.245,.22),24,"edf3fb")
	text_at("ОПЕРАТИВНИК",Vector4(.037,.22,.24,.27),14,"91ceec")
	btn("ЗАДАНИЯ",Vector4(.024,.34,.222,.415),show_missions)
	btn("ПЕРСОНАЖИ",Vector4(.024,.43,.222,.505),show_operators)
	btn("АРСЕНАЛ",Vector4(.024,.52,.222,.595),show_inventory)
	btn("ТРЕНИРОВКА",Vector4(.024,.61,.222,.685),start_game)
	panel_at(Vector4(.76,.19,.98,.405))
	text_at("ОПЕРАЦИЯ 07",Vector4(.776,.205,.965,.25),17,"f8bfdc")
	text_at("ТЕНИ\nСЕКТОРА 07",Vector4(.776,.255,.965,.345),24,"f6eff6")
	text_at("СЮЖЕТ  /  PvE",Vector4(.776,.35,.965,.394),14,"9ddbea")
	panel_at(Vector4(.74,.64,.98,.77))
	text_at("НОКС-СИТИ",Vector4(.758,.65,.96,.695),20,"c0d7e8")
	text_at("ОДИНОЧНАЯ МИССИЯ",Vector4(.758,.70,.96,.755),15,"aab7ce")
	btn("▶  НАЧАТЬ",Vector4(.74,.79,.98,.9),start_game,true)
	panel_at(Vector4(.25,.92,.98,.995),"101626e8")
	btn("РЮКЗАК",Vector4(.255,.927,.425,.99),show_inventory)
	btn("ОРУЖИЕ",Vector4(.438,.927,.60,.99),show_inventory)
	btn("ОПЕРАТИВНИК",Vector4(.613,.927,.797,.99),show_operators)
	btn("ЗАДАНИЯ",Vector4(.808,.927,.973,.99),show_missions)

func overlay(title: String):
	modal=true
	clear_ui()
	panel_at(Vector4(0,0,1,1),"09101cdd","151e31")
	text_at(title,Vector4(.05,.04,.80,.14),35,"f3e4f6")
	btn("×  НАЗАД",Vector4(.81,.04,.96,.115),close_modal)

func close_modal():
	modal=false
	if mode=="play": show_hud()
	else: show_lobby()

func show_operators():
	overlay("ОПЕРАТИВНИКИ")
	var i=0
	for id in HEROES:
		var x=.07+float(i)*.225
		panel_at(Vector4(x,.20,x+.20,.73),"20293cde")
		text_at(["01","02","03","04"][i],Vector4(x+.02,.23,x+.18,.29),36,"f56eb4")
		text_at(HEROES[id],Vector4(x+.02,.35,x+.18,.42),27,"eef1fa")
		text_at(["ХАКЕР","РАЗВЕДЧИК","ШТУРМОВИК","КИБЕРНЕТИК"][i],Vector4(x+.02,.43,x+.19,.52),15,"9fc9de")
		btn("ВЫБРАН" if hero==id else "ВЫБРАТЬ",Vector4(x+.01,.61,x+.19,.70),func(): change_hero(id);close_modal(),hero==id)
		i+=1

func set_weapon(id: String):
	weapon=id
	visual.set_weapon(id)
	reload_time=0
	cooldown=.18
	fired=false
	save_profile()
	if mode=="play" and not modal: update_hud()

func show_inventory():
	overlay("ИНВЕНТАРЬ  /  СНАРЯЖЕНИЕ")
	panel_at(Vector4(.045,.16,.29,.90))
	text_at("РЮКЗАК",Vector4(.06,.17,.28,.245),23,"d5c8ea")
	text_at("Аптечки   ×"+str(kits)+"\nГранаты   ×"+str(grenades)+"\nБроня   "+("НАДЕТА" if armor else "НЕТ")+"\nКредиты   "+str(cash),Vector4(.06,.26,.28,.58),19,"e1e5f2")
	panel_at(Vector4(.31,.16,.95,.90))
	text_at("ОРУЖИЕ / ПРЕСЕТЫ",Vector4(.33,.17,.92,.245),22,"f3d8a6")
	var i=0
	for id in GUNS:
		var y=.26+i*.117
		text_at(GUNS[id]["title"]+"    "+str(mags[id])+" / "+str(reserves[id]),Vector4(.34,y,.65,y+.09),22)
		btn("В РУКАХ" if weapon==id else "ЭКИПИРОВАТЬ",Vector4(.67,y,.93,y+.078),func(): set_weapon(id);show_inventory(),weapon==id)
		i+=1

func show_missions():
	overlay("СЮЖЕТ  /  ТЕНИ СЕКТОРА 07")
	panel_at(Vector4(.06,.18,.94,.86))
	text_at("НОКС-СИТИ • 03:17",Vector4(.085,.2,.91,.28),28,"e7add9")
	text_at("Корпорация Helix похитила память жителей.\nНайди информатора Никс, зачисти дороги\nи доберись до узла передачи.\n\nI. Связаться с Никс\nII. Уничтожить шесть стражей\nIII. Активировать архив",Vector4(.085,.31,.91,.78),25)

func show_settings():
	overlay("НАСТРОЙКИ")
	panel_at(Vector4(.06,.18,.94,.82))
	text_at("Чувствительность камеры",Vector4(.09,.21,.58,.30),23)
	btn("−",Vector4(.63,.21,.73,.30),func(): look_sens=maxf(.001,look_sens-.001);show_settings())
	btn("+",Vector4(.83,.21,.93,.30),func(): look_sens=minf(.009,look_sens+.001);show_settings())
	text_at(str(snappedf(look_sens*1000,1)),Vector4(.74,.21,.82,.30),23,"f9d69b",HORIZONTAL_ALIGNMENT_CENTER)
	text_at("Помощь в прицеливании",Vector4(.09,.36,.65,.46),23)
	btn("ВКЛ" if auto_aim else "ВЫКЛ",Vector4(.74,.36,.93,.46),func(): auto_aim=not auto_aim;show_settings())
	text_at("Горизонтальный режим  /  Нативный 3D\nGodot 4 · OpenGL ES · Android",Vector4(.09,.57,.91,.75),21,"96bbd1")

func show_hud():
	clear_ui()
	modal=false
	panel_at(Vector4(.015,.02,.27,.16),"131d2abe")
	hud_label=text_at(HEROES[hero]+"  •  01",Vector4(.026,.023,.26,.076),23,"eef1ff")
	health_bar=ProgressBar.new()
	health_bar.max_value=100
	health_bar.show_percentage=false
	health_bar.add_theme_stylebox_override("background",style("252f43","53617a"))
	health_bar.add_theme_stylebox_override("fill",style("cbd7ed","f1d7ef"))
	place(health_bar,Vector4(.027,.081,.25,.105))
	mission_label=text_at("",Vector4(.025,.112,.40,.162),16,"ffe5a1")
	map_label=text_at("СЕКТОР 07",Vector4(.38,.025,.62,.08),20,"ecdef8",HORIZONTAL_ALIGNMENT_CENTER)
	panel_at(Vector4(.82,.02,.985,.155),"101a28cc")
	text_at("NOX CITY\nSECTOR 07",Vector4(.832,.025,.973,.09),17,"d8e0ec",HORIZONTAL_ALIGNMENT_CENTER)
	btn("КАРТА",Vector4(.835,.095,.97,.149),show_map,false,"map")
	prompt_label=text_at("",Vector4(.28,.66,.72,.73),22,"ffe1a7",HORIZONTAL_ALIGNMENT_CENTER)
	info_label=text_at("",Vector4(.30,.20,.70,.25),20,"eed3ef",HORIZONTAL_ALIGNMENT_CENTER)
	var cross=text_at("+",Vector4(.48,.46,.52,.54),34,"e0e6f2",HORIZONTAL_ALIGNMENT_CENTER)
	cross.modulate.a=.83
	var joybase=Panel.new()
	joybase.add_theme_stylebox_override("panel",style("17283c80","c9d7ef80",2))
	place(joybase,Vector4(.035,.67,.17,.91))
	joybase.mouse_filter=Control.MOUSE_FILTER_IGNORE
	stick=Panel.new()
	stick.add_theme_stylebox_override("panel",style("52647ea0","c1cfe2",2))
	place(stick,Vector4(.079,.747,.126,.831))
	stick.mouse_filter=Control.MOUSE_FILTER_IGNORE
	btn("ОГОНЬ",Vector4(.025,.48,.105,.60),func():pass,false,"fire_left")
	btn("БЕГ",Vector4(.18,.74,.245,.84),func():sprint=not sprint,false,"sprint")
	btn("ПРИЦЕЛ",Vector4(.81,.50,.89,.61),func():aim=not aim,false,"aim")
	btn("ОГОНЬ",Vector4(.90,.59,.982,.76),func():pass,true,"fire")
	btn("РЫВОК",Vector4(.815,.64,.885,.75),func():jump(),false,"jump")
	btn("ПРИСЕСТЬ",Vector4(.815,.79,.895,.91),func():stance=not stance,false,"stance")
	btn("ЛЕЧЕНИЕ",Vector4(.72,.59,.807,.70),heal,false,"heal")
	btn("ДЕЙСТВИЕ",Vector4(.72,.72,.807,.82),interact,false,"interact")
	btn("ПРЫЖОК",Vector4(.90,.79,.982,.91),jump,false,"jump_right")
	panel_at(Vector4(.30,.80,.70,.985),"111928dc")
	ammo_label=text_at("",Vector4(.31,.803,.69,.855),26,"f7dba4",HORIZONTAL_ALIGNMENT_CENTER)
	for i in range(3):
		var x=.305+i*.132
		btn(GUNS[slots[i]]["title"],Vector4(x,.858,x+.126,.913),func():set_weapon(slots[i]),false,"slot"+str(i))
	btn("РЮКЗАК",Vector4(.305,.924,.428,.982),show_inventory,false,"inventory")
	btn("АВТО / ОДИН.",Vector4(.438,.924,.563,.982),func():single=not single,false,"mode")
	btn("ЗАРЯДИТЬ",Vector4(.573,.924,.695,.982),reload,false,"reload")
	btn("ПАУЗА",Vector4(.72,.925,.81,.985),show_pause,false,"pause")
	update_hud()

func show_map():
	overlay("КАРТА  /  НОКС-СИТИ")
	panel_at(Vector4(.22,.18,.78,.88),"263547ee")
	panel_at(Vector4(.46,.23,.54,.83),"131c29","7a8d9b")
	for i in range(5):
		var y=.24+i*.116
		panel_at(Vector4(.27,y,.44,y+.09),"546075")
		panel_at(Vector4(.56,y,.73,y+.09),"46586d")
	var yy=.23+clampf((player.position.z+80)/160,0,1)*.6
	panel_at(Vector4(.487,yy,.513,minf(.85,yy+.025)),"f9e3a2","f9e3a2")
	text_at("● ВЫ",Vector4(.08,.35,.21,.50),21,"f9e3a2")
	text_at("АРХИВ",Vector4(.80,.35,.96,.50),18,"b1ecf8")

func show_pause():
	overlay("ПАУЗА")
	btn("ПРОДОЛЖИТЬ",Vector4(.33,.25,.67,.36),close_modal,true)
	btn("НАСТРОЙКИ",Vector4(.33,.39,.67,.50),show_settings)
	btn("В ЛОББИ",Vector4(.33,.53,.67,.64),func():clear_world_combat();show_lobby())

func update_hud():
	if mode!="play" or modal or not is_instance_valid(hud_label):return
	hud_label.text=HEROES[hero]+" · "+str(int(hp))+" HP"
	health_bar.value=hp
	ammo_label.text=("ПЕРЕЗАРЯДКА" if reload_time>0 else GUNS[weapon]["title"]+"   "+str(mags[weapon])+" / "+str(reserves[weapon])) + ("  • ОДИН." if single else "  • АВТО")
	mission_label.text=["Найти Никс","Стражи Helix "+str(kills)+"/6","Добраться до архива","ОПЕРАЦИЯ ВЫПОЛНЕНА"][mission]
	var deg=int(fposmod(rad_to_deg(-yaw),360))
	map_label.text="N  ·  "+str(deg)+"°  ·  SECTOR 07"

func notify(msg: String):
	if is_instance_valid(info_label):
		info_label.text=msg
		toast_until=clock+3

func make_loot(pos: Vector3,kind: String,count: int):
	var m=city.box(self,pos+Vector3(0,.17,0),Vector3(.38,.28,.42),city.material("e7bd76" if kind=="ammo" else "75e3c0",.9))
	loot.append({"node":m,"kind":kind,"count":count})

func interact():
	if modal or mode!="play": return
	for item in loot.duplicate():
		if player.position.distance_to(item.node.position)<2.7:
			if item.kind=="ammo": reserves[weapon]+=item.count
			elif item.kind=="armor": armor=true
			elif item.kind=="kit": kits+=item.count
			item.node.queue_free()
			loot.erase(item)
			notify("ПРЕДМЕТ ПОДОБРАН")
			update_hud()
			return
	if player.position.distance_to(Vector3(-5,0,5))<4.5 and mission==0:
		mission=1
		notify("НИКС: зачисти улицу, затем найди архив.")
	elif mission==2 and player.position.z<-57:
		mission=3
		cash+=350
		notify("ОПЕРАЦИЯ ЗАВЕРШЕНА · +350 КРЕДИТОВ")
		save_profile()
	update_hud()

func heal():
	if kits>0 and hp<100 and healing<=0:
		healing=2.0
		notify("ЛЕЧЕНИЕ…")

func jump():
	if is_instance_valid(player) and player.is_on_floor(): player.velocity.y=5.0

func reload():
	if mags[weapon]<GUNS[weapon]["clip"] and reserves[weapon]>0 and reload_time<=0:
		reload_time=1.45
		firing=false

func shoot():
	if cooldown>0 or reload_time>0 or healing>0: return
	if mags[weapon]<=0:
		reload()
		return
	mags[weapon]-=1
	cooldown=GUNS[weapon]["rate"]
	recoil=1
	var origin=player.position+Vector3(0,1.3,0)
	var dir=-Basis(Vector3.UP,yaw).z
	var best=null
	var score=0.89 if auto_aim else .994
	for e in enemies:
		var diff=e.node.position+Vector3(0,1.1,0)-origin
		var dot=dir.dot(diff.normalized())
		if diff.length()<34 and dot>score:
			var query=PhysicsRayQueryParameters3D.create(origin,origin+diff,1)
			if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				best=e
				score=dot
	var dest=origin+dir*45
	if best!=null:
		dest=best.node.position+Vector3(0,1.1,0)
		best.hp-=GUNS[weapon]["damage"]
		if best.hp<=0:
			kill_enemy(best)
	var mid=(origin+dest)/2
	var tracer=city.box(self,mid,Vector3(.025,.025,origin.distance_to(dest)),city.material("ffd787",2))
	tracer.look_at(dest,Vector3.UP)
	projectiles.append({"node":tracer,"time":.07})
	update_hud()

func kill_enemy(e):
	make_loot(e.node.position,"ammo",18)
	e.node.queue_free()
	enemies.erase(e)
	kills+=1
	cash+=35
	if kills>=6 and mission<=1:
		mission=2
		notify("Улица очищена. Направляйся к архиву на север.")
	update_hud()

func enemy_update(dt: float):
	for e in enemies.duplicate():
		var n: CharacterBody3D=e.node
		var diff=player.position-n.position
		diff.y=0
		var dist=diff.length()
		var speed=0.0
		if dist<27:
			n.rotation.y=atan2(-diff.x,-diff.z)
			if dist>7:
				speed=2.1
				n.velocity=diff.normalized()*speed+Vector3(0,n.velocity.y,0)
			else: n.velocity=Vector3(0,n.velocity.y,0)
			e.cool-=dt
			if e.cool<=0 and dist<15:
				e.cool=1.35
				var q=PhysicsRayQueryParameters3D.create(n.position+Vector3(0,1.3,0),player.position+Vector3(0,1.3,0),1)
				if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
					hp=maxf(0,hp-(6 if armor else 9))
					notify("ПОЛУЧЕН УРОН")
		else: n.velocity=Vector3.ZERO
		if not n.is_on_floor(): n.velocity.y-=12*dt
		n.move_and_slide()
		e.actor.animate(dt,speed,true,0.0)
	if hp<=0:
		hp=100
		player.position=Vector3(0,.05,15)
		notify("ВОССТАНОВЛЕНИЕ В УБЕЖИЩЕ")

func _physics_process(dt: float):
	if not is_instance_valid(camera) or not is_instance_valid(player): return
	clock+=dt
	for n in npcs:
		var ofs=sin(clock*.42+n.phase)*1.25 if n.title=="" else 0.0
		n.node.position=n.start+Vector3(0,0,ofs)
		n.actor.animate(dt, .55 if n.title=="" else 0.0,false,0.0)
	if mode=="lobby":
		visual.animate(dt,0,false,0)
		camera.position=Vector3(.2,1.75,11.4)
		camera.look_at(player.position+Vector3(0,1.12,0),Vector3.UP)
		return
	if mode!="play" or modal: return
	cooldown=maxf(0,cooldown-dt)
	recoil=maxf(0,recoil-dt*7)
	if healing>0:
		healing=maxf(0,healing-dt)
		if healing<=0:
			kits-=1
			hp=minf(100,hp+50)
			notify("ЗДОРОВЬЕ ВОССТАНОВЛЕНО")
	if reload_time>0:
		reload_time=maxf(0,reload_time-dt)
		if reload_time<=0:
			var n=min(GUNS[weapon]["clip"]-mags[weapon],reserves[weapon])
			mags[weapon]+=n
			reserves[weapon]-=n
	var axis=joy
	axis+=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	if axis.length()>1:axis=axis.normalized()
	var dir=Basis(Vector3.UP,yaw)*Vector3(axis.x,0,axis.y)
	var speed=6.0 if sprint or Input.is_physical_key_pressed(KEY_SHIFT) else 3.6
	if stance:speed=1.8
	if aim:speed*=.65
	player.velocity.x=dir.x*speed
	player.velocity.z=dir.z*speed
	if not player.is_on_floor():player.velocity.y-=14*dt
	# Keep the character aligned with the third-person camera; strafe in combat.
	player.rotation.y=lerp_angle(player.rotation.y,yaw,minf(1,dt*14))
	player.move_and_slide()
	visual.animate(dt,dir.length()*speed,aim or firing,recoil,"crouch" if stance else "stand")
	var pivot=player.position+Vector3(0,1.5 if not stance else 1.2,0)
	var back=Basis(Vector3.UP,yaw)*Vector3(.55,2.0 if not aim else 1.1,4.8 if not aim else 2.75)
	var desired=pivot+back
	var query=PhysicsRayQueryParameters3D.create(pivot,desired,1)
	var hit=get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): desired=hit.position+hit.normal*.23
	camera.position=camera.position.lerp(desired,minf(1,dt*14))
	var front=-Basis(Vector3.UP,yaw).z
	camera.look_at(pivot+front*8+Vector3(0,pitch*8,0),Vector3.UP)
	camera.fov=lerpf(camera.fov,54 if aim else 67,minf(1,dt*8))
	var trigger=firing or Input.is_physical_key_pressed(KEY_F)
	if trigger and (not single or not fired): shoot()
	fired=trigger
	enemy_update(dt)
	for tr in projectiles.duplicate():
		tr.time-=dt
		if tr.time<=0:
			tr.node.queue_free()
			projectiles.erase(tr)
	var msg=""
	for item in loot:
		if player.position.distance_to(item.node.position)<2.7:msg="ДЕЙСТВИЕ · "+("БОЕПРИПАСЫ" if item.kind=="ammo" else "БРОНЯ" if item.kind=="armor" else "АПТЕЧКА")
	if msg=="" and mission==0 and player.position.distance_to(Vector3(-5,0,5))<4.5:msg="ДЕЙСТВИЕ · НИКС"
	if mission==2 and player.position.z<-57:msg="ДЕЙСТВИЕ · АРХИВ"
	prompt_label.text=msg
	if clock>toast_until:info_label.text=""
	update_hud()

func _input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			for key in touch_actions:
				var b: Button=touch_actions[key]
				if is_instance_valid(b) and b.get_global_rect().has_point(event.position):
					if key.begins_with("fire") and mode=="play" and not modal:
						fire_ids.append(event.index)
						firing=true
					else: b.pressed.emit()
					get_viewport().set_input_as_handled()
					return
			if mode=="play" and not modal:
				if event.position.x<ui.size.x*.27:
					joy_id=event.index
					joy_start=event.position
				else:look_id=event.index
				get_viewport().set_input_as_handled()
		else:
			fire_ids.erase(event.index)
			firing=not fire_ids.is_empty()
			if event.index==joy_id:
				joy_id=-1
				joy=Vector2.ZERO
			if event.index==look_id:look_id=-1
	elif event is InputEventScreenDrag and mode=="play" and not modal:
		if event.index==joy_id:
			joy=(event.position-joy_start)/65.0
			if joy.length()>1:joy=joy.normalized()
		elif event.index==look_id:
			yaw-=event.relative.x*look_sens
			pitch=clampf(pitch-event.relative.y*look_sens*.9,-.48,.37)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:
			if modal:close_modal()
			elif mode=="play":show_pause()
		elif mode=="play" and not modal:
			match event.keycode:
				KEY_E:interact()
				KEY_I:show_inventory()
				KEY_R:reload()
				KEY_Q:heal()
				KEY_SPACE:jump()
				KEY_C:stance=not stance
				KEY_1:set_weapon(slots[0])
				KEY_2:set_weapon(slots[1])
				KEY_3:set_weapon(slots[2])

func _unhandled_input(event):
	if mode!="play" or modal:return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw-=event.relative.x*look_sens
		pitch=clampf(pitch-event.relative.y*look_sens,-.48,.37)
	elif event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:firing=event.pressed

func save_profile():
	var f=FileAccess.open("user://profile.json",FileAccess.WRITE)
	if f:f.store_string(JSON.stringify({"hero":hero,"weapon":weapon,"cash":cash}))

func load_profile():
	if FileAccess.file_exists("user://profile.json"):
		var f=FileAccess.open("user://profile.json",FileAccess.READ)
		if f:
			var data=JSON.parse_string(f.get_as_text())
			if data is Dictionary:
				cash=int(data.get("cash",100))
				var id=str(data.get("hero","rin"))
				if HEROES.has(id):change_hero(id)
				var gun_id=str(data.get("weapon","rifle"))
				if GUNS.has(gun_id):set_weapon(gun_id)

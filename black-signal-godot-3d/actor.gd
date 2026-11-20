extends Node3D
var city
var body_root: Node3D
var arms: Array[Node3D] = []
var legs: Array[Node3D] = []
var gun: Node3D
var flash: MeshInstance3D
var character_id = "rin"
var phase = 0.0
var color_sets = {
	"rin":["634080","a575bc","f1eff7","e7c5ca","ded9ed","292535","67dbe2"],
	"kai":["263d52","59778f","a6bac8","c99c83","25212d","202b38","f55f66"],
	"vega":["763943","b36678","ead7bd","c39178","b4553c","332739","ffbd6a"],
	"nox":["384e4b","648b83","a8bec0","b5c3c9","627b80","242c3b","6ceac6"],
	"nyx":["233c46","597881","cad8da","bd958c","3b485b","28323e","71dae7"],
	"guard":["323b4e","637183","8896ae","b4a5a1","1c2531","202737","ff4d6e"]
}

func mat(c: String, metal: float = 0.0, glow: float = 0.0):
	return city.material(c,glow,metal)

func ball(p: Node3D, at: Vector3, dims: Vector3, c: Material):
	var s = SphereMesh.new()
	s.radius = .5
	s.height = 1
	s.radial_segments = 16
	s.rings = 8
	var instance = city.mesh_at(p,s,at,c)
	instance.scale = dims
	return instance

func part(p: Node3D, at: Vector3, dims: Vector3, c: Material):
	return city.box(p,at,dims,c)

func pivot(p: Node3D, pos: Vector3) -> Node3D:
	var n = Node3D.new()
	n.position = pos
	p.add_child(n)
	return n

func create(geom, id: String):
	city = geom
	character_id = id
	var palette = color_sets.get(id,color_sets["guard"])
	var coat = mat(palette[0])
	var trim = mat(palette[1],.25)
	var glove = mat(palette[2])
	var skin = mat(palette[3])
	var hair = mat(palette[4],.12)
	var pants = mat(palette[5])
	var glow = mat(palette[6],.15,1.2)
	var rubber = mat("191827",.05)
	body_root = pivot(self,Vector3.ZERO)
	ball(body_root,Vector3(0,1.20,0),Vector3(.52,.62,.32),coat)
	ball(body_root,Vector3(0,.91,0),Vector3(.44,.30,.32),pants)
	part(body_root,Vector3(0,.99,-.01),Vector3(.44,.09,.34),rubber)
	part(body_root,Vector3(0,.99,-.19),Vector3(.11,.07,.05),trim)
	part(body_root,Vector3(0,1.26,-.17),Vector3(.04,.39,.025),trim)
	if id != "rin":
		for x in [-.16,.16]:
			part(body_root,Vector3(x,1.34,-.17),Vector3(.16,.26,.055),rubber)
			part(body_root,Vector3(x,1.39,-.21),Vector3(.10,.035,.022),glow)
	else:
		ball(body_root,Vector3(-.22,1.40,.01),Vector3(.19,.25,.27),glow)
		for i in range(4):
			ball(body_root,Vector3(-.19,1.29-i*.105,-.18),Vector3(.14,.19,.11),glow)
		for x in [-.3,.3]:
			part(body_root,Vector3(x,.83,0),Vector3(.055,.16,.16),rubber)
	ball(body_root,Vector3(0,1.56,0),Vector3(.14,.21,.15),skin)
	ball(body_root,Vector3(0,1.731,-.009),Vector3(.31,.39,.30),skin)
	ball(body_root,Vector3(0,1.81,.045),Vector3(.36,.32,.34),hair)
	# Sculpted hair pieces and facial geometry, real meshes, never billboards.
	for i in range(5):
		var x = -.136+i*.068
		var lock = ball(body_root,Vector3(x,1.84,-.126),Vector3(.09,.20,.08),hair)
		lock.rotation.z = -.26+i*.13
	for x in [-.068,.068]:
		ball(body_root,Vector3(x,1.746,-.147),Vector3(.067,.034,.026),mat("e8e6f1"))
		ball(body_root,Vector3(x,1.745,-.164),Vector3(.031,.031,.015),mat("272337"))
	ball(body_root,Vector3(0,1.705,-.153),Vector3(.055,.062,.053),skin)
	ball(body_root,Vector3(0,1.666,-.145),Vector3(.073,.014,.017),mat("a96883"))
	if id=="rin" or id=="kai":
		var frame = mat("915ac4" if id=="rin" else "c94758",.5)
		for x in [-.078,.078]:
			for y in [1.718,1.778]:
				part(body_root,Vector3(x,y,-.171),Vector3(.132,.012,.014),frame)
			for dx in [-.063,.063]:
				part(body_root,Vector3(x+dx,1.748,-.171),Vector3(.012,.064,.014),frame)
		part(body_root,Vector3(0,1.748,-.171),Vector3(.032,.012,.015),frame)
	if id=="rin" or id=="vega":
		for i in range(5):
			var lock = ball(body_root,Vector3(-.13+i*.065,1.41,.13),Vector3(.13,.73,.12),hair)
			lock.rotation.z = -.14+i*.065
	if id=="rin":
		for x in [-.118,.118]:
			var ear = CylinderMesh.new()
			ear.top_radius=0.0
			ear.bottom_radius=.082
			ear.height=.19
			ear.radial_segments=5
			var e=city.mesh_at(body_root,ear,Vector3(x,2.00,.015),hair)
			e.rotation.z = -x*2
	elif id=="nox" or id=="guard":
		part(body_root,Vector3(0,1.75,-.15),Vector3(.29,.105,.06),rubber)
		part(body_root,Vector3(0,1.755,-.187),Vector3(.23,.027,.015),glow)
	for side in [-1,1]:
		var a = pivot(body_root,Vector3(side*.28,1.40,0))
		arms.append(a)
		ball(a,Vector3(0,-.13,0),Vector3(.18,.31,.18),coat)
		ball(a,Vector3(0,-.36,0),Vector3(.16,.29,.16),coat)
		part(a,Vector3(0,-.23,-.077),Vector3(.11,.055,.03),trim)
		ball(a,Vector3(0,-.51,0),Vector3(.125,.15,.12),glove)
		var leg = pivot(body_root,Vector3(side*.13,.87,0))
		legs.append(leg)
		ball(leg,Vector3(0,-.22,0),Vector3(.22,.46,.22),pants)
		ball(leg,Vector3(0,-.56,0),Vector3(.17,.33,.18),pants)
		part(leg,Vector3(0,-.44,-.09),Vector3(.16,.12,.065),rubber)
		ball(leg,Vector3(0,-.75,-.055),Vector3(.24,.19,.38),glove)
		part(leg,Vector3(0,-.82,-.05),Vector3(.23,.05,.34),rubber)
	gun = pivot(body_root,Vector3(.20,1.24,-.48))
	set_weapon("rifle")

func set_weapon(id: String):
	for child in gun.get_children():
		child.queue_free()
	var metal = mat("333b4a",.8)
	var core = mat("171d2a",.65)
	var accent = mat("c963ed" if id=="plasma" else "7fd5e0",.4,1.0)
	var length = .31 if id=="pistol" else (.78 if id=="smg" else 1.02)
	part(gun,Vector3(0,0,-length*.18),Vector3(.115,.14,length*.66),metal)
	part(gun,Vector3(0,.085,-length*.12),Vector3(.09,.04,length*.52),core)
	part(gun,Vector3(0,-.11,.08),Vector3(.08,.21,.13),core)
	if id!="pistol":
		part(gun,Vector3(0,-.15,-.09),Vector3(.09,.24,.16),metal)
		part(gun,Vector3(0,0,length*.26),Vector3(.085,.13,.32),core)
	part(gun,Vector3(0,.005,-length*.59),Vector3(.055,.057,length*.45),metal)
	part(gun,Vector3(.063,.022,-length*.23),Vector3(.013,.028,length*.23),accent)
	flash = ball(gun,Vector3(0,0,-length*.83),Vector3(.19,.19,.32),mat("ffc878",0,3))
	flash.visible=false

func animate(dt: float, speed: float, aim: bool, recoil: float, stance: String="stand"):
	phase += dt*(7.0+speed*1.5)
	var walking=clampf(speed/4.0,0.0,1.0)
	var amt=sin(phase)*.60*walking
	for i in range(legs.size()):
		legs[i].rotation.x=lerp_angle(legs[i].rotation.x,(amt if i==0 else -amt),minf(1.0,dt*15))
	for i in range(arms.size()):
		var goal=1.17 if aim else (0.85+amt*.12)
		arms[i].rotation.x=lerp_angle(arms[i].rotation.x,goal,minf(1.0,dt*14))
		arms[i].rotation.z= .16 if i==0 else -.16
	body_root.position.y=lerpf(body_root.position.y,(-.28 if stance=="crouch" else 0.0)+abs(sin(phase))*.035*walking,minf(1,dt*12))
	gun.position.z=-.44+recoil*.13
	gun.rotation.x=-recoil*.23
	if is_instance_valid(flash): flash.visible=recoil>.70

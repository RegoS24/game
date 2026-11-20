extends Node3D
const FACADE = preload("res://facade.gdshader")
const ROAD = preload("res://road.gdshader")
var mats = {}
var rng = RandomNumberGenerator.new()

func material(hex: String, glow: float = 0.0, metal: float = 0.0) -> StandardMaterial3D:
	var key = hex + str(glow) + str(metal)
	if mats.has(key):
		return mats[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.metallic = metal
	m.roughness = 0.28 if metal > 0.4 else 0.72
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = Color(hex)
		m.emission_energy_multiplier = glow
	mats[key] = m
	return m

func mesh_at(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, collide: bool = false) -> MeshInstance3D:
	var b = BoxMesh.new()
	b.size = size
	var mi = mesh_at(parent,b,pos,mat)
	if collide:
		var body = StaticBody3D.new()
		var shape = CollisionShape3D.new()
		var bs = BoxShape3D.new()
		bs.size = size
		shape.shape = bs
		body.add_child(shape)
		body.position = pos
		parent.add_child(body)
	return mi

func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var c = CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 10
	return mesh_at(parent,c,pos,mat)

func sign_at(parent: Node3D, msg: String, pos: Vector3, tint: Color, yaw: float = 0.0, size: int = 80):
	var l = Label3D.new()
	l.text = msg
	l.font_size = size
	l.pixel_size = 0.012
	l.position = pos
	l.rotation.y = yaw
	l.modulate = tint
	l.outline_size = 6
	l.outline_modulate = Color(0.02,0.015,0.04)
	l.no_depth_test = false
	parent.add_child(l)

func build_ground():
	rng.seed = 218607
	var road = ShaderMaterial.new()
	road.shader = ROAD
	box(self,Vector3(0,-0.27,0),Vector3(112,0.50,180),road,true)
	var curb = material("495262",0.0,0.2)
	var pavement = material("282d3b",0.0,0.2)
	for side in [-1,1]:
		box(self,Vector3(side*8.1,0.06,0),Vector3(3.2,0.22,162),pavement,true)
		box(self,Vector3(side*6.55,0.1,0),Vector3(0.22,0.27,162),curb)
	for z in range(-78,80,8):
		box(self,Vector3(0,0.008,z),Vector3(.13,.015,3.2),material("aaa08b"))
		for x in [-5.85,5.85]:
			box(self,Vector3(x,0.009,z),Vector3(.09,.018,7.8),material("4f6272"))
	for z in [-60,-20,20,60]:
		for x in range(-5,6):
			box(self,Vector3(x,0.012,z),Vector3(.46,.02,2.4),material("8793a2"))
	for z in range(-76,77,16):
		for side in [-1,1]:
			streetlight(Vector3(side*7.8,0.16,z),side,z)
	for x in [-55.0,55.0]:
		box(self,Vector3(x,2,0),Vector3(1,4,180),material("121826"),true)
	for z in [-89.0,89.0]:
		box(self,Vector3(0,2,z),Vector3(112,4,1),material("121826"),true)

func streetlight(at: Vector3, side: int, z: int):
	var n = Node3D.new()
	n.position = at
	add_child(n)
	var iron = material("303c4d",0.0,0.75)
	cylinder(n,Vector3(0,2,0),.095,4,iron)
	box(n,Vector3(-side*.6,4,0),Vector3(1.2,.12,.12),iron)
	box(n,Vector3(-side*1.1,3.91,0),Vector3(.5,.12,.3),material("ffe4ba",1.4))
	if abs(z) < 68:
		var light = OmniLight3D.new()
		light.position = Vector3(-side*1.1,3.7,0)
		light.light_color = Color("f3c7a6") if side < 0 else Color("73e0ff")
		light.light_energy = 2.1
		light.omni_range = 8.0
		n.add_child(light)

func build_block(index: int):
	var z = -62.0 + float(index)*29.0
	for side in [-1,1]:
		var h = rng.randf_range(13,29)
		var name_list = ["LOTOS BAR","NEURAL // 24","BLACK SIGNAL","HELIX","NIGHT MARKET"]
		var colors = ["e954c8","28cde9","ffac65","95afef","ed4e94"]
		building(Vector3(side*18.1,0,z),Vector3(15.0,h,24.0),colors[index%5],name_list[index%5],side)
		building(Vector3(side*39.0,0,z+1.4),Vector3(18,rng.randf_range(23,48),23),colors[(index+2)%5],"NOX",side)
		for k in range(3):
			var zz = z-9.0+k*8.1
			box(self,Vector3(side*9.15,.38,zz),Vector3(.65,.5,.7),material("33394a",0.0,.6))
			box(self,Vector3(side*9.15,.67,zz),Vector3(.58,.08,.58),material(colors[index%5],.75))
		if index%2 == 0:
			car(Vector3(side*4.9,.08,z+6),side,colors[index%5])
		if side == -1 and index%2 == 1:
			blossom(Vector3(-8.6,.1,z-5))

func building(at: Vector3, size: Vector3, neon: String, title: String, side: int):
	var sm = ShaderMaterial.new()
	sm.shader = FACADE
	sm.set_shader_parameter("wall_color",Color("182333") if side==1 else Color("251d31"))
	sm.set_shader_parameter("window_color",Color(neon))
	box(self,at+Vector3(0,size.y/2,0),size,sm,true)
	var edge_x = at.x-side*size.x/2
	var trim = material("394455",0.0,.60)
	var lit = material(neon,1.45,.12)
	var black = material("101827",0.0,.5)
	# Layered foundation, entrance awning, façade strips, roof equipment.
	box(self,Vector3(edge_x,1.75,at.z),Vector3(.14,3.5,size.z),black)
	box(self,Vector3(edge_x-side*.65,3.75,at.z),Vector3(1.45,.28,size.z*.94),trim)
	box(self,Vector3(edge_x-side*1.39,3.67,at.z),Vector3(.06,.08,size.z*.94),lit)
	for i in range(5):
		var zz = at.z-size.z/2+2.3+float(i)*(size.z-4.6)/4.0
		box(self,Vector3(edge_x-side*.08,1.65,zz),Vector3(.13,2.65,2.7),material("365364",.16,.65))
		box(self,Vector3(edge_x-side*.19,1.8,zz-1.4),Vector3(.24,3.5,.16),trim)
	for zz in [-size.z/2+.4,size.z/2-.4]:
		box(self,Vector3(edge_x-side*.1,size.y/2,at.z+zz),Vector3(.22,size.y,.22),lit)
	for y in range(7,int(size.y),6):
		box(self,Vector3(edge_x-side*.13,y,at.z),Vector3(.35,.19,size.z),trim)
	box(self,at+Vector3(0,size.y+.4,0),Vector3(size.x+.5,.65,size.z+.5),trim)
	for k in range(3):
		box(self,at+Vector3(rng.randf_range(-4,4),size.y+1.25,-6+k*6),Vector3(2.2,1.6,3),black)
	var yaw = -PI/2.0 if side == 1 else PI/2.0
	sign_at(self,title,Vector3(edge_x-side*.2,5.6,at.z),Color(neon).lightened(.28),yaw,90)
	sign_at(self,"SECTOR 07",Vector3(at.x, size.y-1,at.z+size.z/2+.06),Color("a8bde4"),0,62)
	if abs(at.z)<34 and abs(at.x)<25:
		var light = OmniLight3D.new()
		light.position = Vector3(edge_x-side*1.5,3.7,at.z)
		light.light_color = Color(neon)
		light.light_energy = 2.3
		light.omni_range = 10
		add_child(light)

func car(at: Vector3, side: int, neon: String):
	var n = Node3D.new()
	n.position = at
	if side < 0: n.rotation.y = PI
	add_child(n)
	var paint = material("48465c",0.0,.78)
	box(n,Vector3(0,.55,0),Vector3(1.85,.53,4.2),paint,true)
	box(n,Vector3(0,1.0,-.1),Vector3(1.62,.55,2.1),material("173445",0.0,.85))
	box(n,Vector3(0,1.31,-.14),Vector3(1.62,.12,1.6),paint)
	box(n,Vector3(0,.58,2.14),Vector3(1.65,.12,.05),material("ff3468",2.0))
	box(n,Vector3(0,.55,-2.14),Vector3(1.55,.14,.05),material("d0f5ff",1.7))
	for x in [-.95,.95]:
		for z in [-1.25,1.25]:
			var wheel = cylinder(n,Vector3(x,.31,z),.34,.28,material("101017"))
			wheel.rotation.z = PI/2

func blossom(at: Vector3):
	var trunk = material("3e303b")
	cylinder(self,at+Vector3(0,1.28,0),.15,2.56,trunk)
	var petal = material("d861aa",.18)
	for i in range(7):
		var s = SphereMesh.new()
		s.radius = 0.72
		s.height = 1.32
		s.radial_segments = 10
		s.rings = 6
		var pos = at+Vector3(cos(i*TAU/7)*.92,2.8+sin(i*2)*.35,sin(i*TAU/7)*.85)
		mesh_at(self,s,pos,petal)

func market():
	var wood = material("46313c",0.0,.2)
	var neon = material("ff7b4c",1.6)
	var center = Vector3(-8.9,.15,-5)
	box(self,center+Vector3(0,.65,0),Vector3(1.6,1.3,3.5),wood,true)
	box(self,center+Vector3(0,2.6,0),Vector3(2.5,.24,4),material("873655"))
	box(self,center+Vector3(.8,2.35,0),Vector3(.08,.12,3.9),neon)
	for z in [-1.6,1.6]:
		box(self,center+Vector3(0,1.9,z),Vector3(.12,1.4,.12),wood)
	sign_at(self,"RAMEN",center+Vector3(1.3,2.38,0),Color("ffe6a3"),PI/2,65)
	for z in [-1.0,0.0,1.0]:
		cylinder(self,center+Vector3(1.7,.35,z),.18,.65,material("3b394a",0,.6))
		cylinder(self,center+Vector3(1.7,.72,z),.29,.12,material("9c4863"))

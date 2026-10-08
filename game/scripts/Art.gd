extends RefCounted
static var mats:Dictionary={}
static func material(id:String,color:Color,metallic:=0.0,glow:=0.0) -> StandardMaterial3D:
	if mats.has(id):return mats[id]
	var m:=StandardMaterial3D.new();m.albedo_color=color;m.metallic=metallic;m.roughness=0.78 if metallic<0.5 else 0.43
	if id in ["concrete","metal","floor","flesh","glove"]:
		m.albedo_texture=load("res://assets/textures/"+id+".png");m.uv1_triplanar=true;m.uv1_scale=Vector3.ONE*0.45
	if glow>0:m.emission_enabled=true;m.emission=color;m.emission_energy_multiplier=glow;m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mats[id]=m;return m
static func mesh(parent:Node3D,shape:Mesh,pos:Vector3,mat:Material,scale_v:=Vector3.ONE) -> MeshInstance3D:
	var n:=MeshInstance3D.new();n.mesh=shape;n.material_override=mat;n.position=pos;n.scale=scale_v;n.visibility_range_end=65;n.visibility_range_end_margin=4;parent.add_child(n);return n
static func box(parent:Node3D,pos:Vector3,size:Vector3,mat:Material,collision:=false) -> MeshInstance3D:
	var s:=BoxMesh.new();s.size=size;var n=mesh(parent,s,pos,mat)
	if collision:
		var b:=StaticBody3D.new();b.collision_layer=1;b.collision_mask=0;parent.add_child(b);b.position=pos
		var c:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;c.shape=shape;b.add_child(c)
	return n
static func ellipsoid(parent:Node3D,pos:Vector3,scale_v:Vector3,mat:Material) -> MeshInstance3D:
	var s:=SphereMesh.new();s.radius=0.5;s.height=1;s.radial_segments=12;s.rings=8;return mesh(parent,s,pos,mat,scale_v)
static func cylinder(parent:Node3D,pos:Vector3,radius:float,height:float,mat:Material,top:=-1.0) -> MeshInstance3D:
	var s:=CylinderMesh.new();s.top_radius=radius if top<0 else top;s.bottom_radius=radius;s.height=height;s.radial_segments=12;return mesh(parent,s,pos,mat)
static func text(parent:Node3D,words:String,pos:Vector3,size:=42,color:=Color(0.83,0.89,0.87),yaw:=0.0) -> Label3D:
	var l:=Label3D.new();l.text=words;l.font_size=size;l.pixel_size=0.012;l.modulate=color;l.outline_size=4;l.position=pos;l.rotation.y=yaw;l.visibility_range_end=38;parent.add_child(l);return l
static func creature(parent:Node3D,kind:String) -> Dictionary:
	var root:=Node3D.new();parent.add_child(root)
	var flesh=material("flesh",Color(0.86,0.92,0.90));var dark=material("hide",Color(0.08,0.105,0.11),0.2);var bone=material("bone",Color(0.58,0.59,0.46));var glow=material("infected",Color(1,0.27,0.075),0,1)
	var elite=kind=="elite";root.scale=Vector3.ONE*(1.7 if elite else (0.89 if kind=="ambusher" else 1.0))
	ellipsoid(root,Vector3(0,1.24,0),Vector3(0.72,0.93,0.46),flesh).rotation.x=-0.19
	ellipsoid(root,Vector3(0,0.91,0.04),Vector3(0.46,0.38,0.36),dark)
	ellipsoid(root,Vector3(0,1.68,-0.17),Vector3(0.40,0.52,0.37),flesh)
	ellipsoid(root,Vector3(0,1.52,-0.34),Vector3(0.27,0.14,0.16),dark)
	for x in [-0.115,0.115]:ellipsoid(root,Vector3(x,1.76,-0.335),Vector3(0.085,0.055,0.04),glow)
	for x in [-0.10,-0.05,0.0,0.05,0.10]:cylinder(root,Vector3(x,1.52,-0.414),0.015,0.085,bone,0.002)
	for i in range(5):
		ellipsoid(root,Vector3(0,1.13+i*0.10,-0.21),Vector3(0.54-i*0.03,0.055,0.14),bone).rotation.z=sin(i)*0.08
		cylinder(root,Vector3(0,1.13+i*0.11,0.24),0.07,0.15,bone,0.02).rotation.x=0.6
	var arms:Array=[];var legs:Array=[]
	for side in [-1.0,1.0]:
		var arm:=Node3D.new();root.add_child(arm);arm.position=Vector3(side*0.36,1.5,0);arm.rotation.z=side*0.18
		ellipsoid(arm,Vector3(0,-0.22,0),Vector3(0.22,0.57,0.23),flesh)
		ellipsoid(arm,Vector3(side*0.02,-0.64,-0.10),Vector3(0.15,0.48,0.18),flesh)
		ellipsoid(arm,Vector3(side*0.02,-0.88,-0.16),Vector3(0.19,0.20,0.16),dark)
		for i in range(4):cylinder(arm,Vector3(-0.065+i*0.045,-1.04,-0.19),0.025,0.23,bone,0.002).rotation.x=-0.25
		arms.append(arm)
		var leg:=Node3D.new();root.add_child(leg);leg.position=Vector3(side*0.21,0.84,0.04)
		ellipsoid(leg,Vector3(0,-0.21,0),Vector3(0.27,0.55,0.28),flesh)
		ellipsoid(leg,Vector3(0,-0.59,0.08),Vector3(0.14,0.45,0.18),dark)
		ellipsoid(leg,Vector3(0,-0.77,-0.08),Vector3(0.22,0.13,0.36),flesh);legs.append(leg)
		if elite:
			for i in range(4):cylinder(root,Vector3(side*(0.28+i*0.045),1.65-i*0.08,0.1),0.10,0.55,bone,0).rotation.z=side*-0.7
	if kind=="ambusher":
		root.rotation.x=-0.18
		for i in range(4):ellipsoid(root,Vector3(0,1.1+i*0.14,0.27),Vector3(0.22,0.16,0.16),glow)
	if elite:ellipsoid(root,Vector3(0,1.43,-0.24),Vector3(0.34,0.32,0.13),glow)
	return {"root":root,"arms":arms,"legs":legs}
static func weapon(parent:Node3D,shotgun:bool) -> Node3D:
	var root:=Node3D.new();parent.add_child(root)
	var steel=material("gunsteel",Color(0.11,0.15,0.17),0.75);var edge=material("gunedge",Color(0.29,0.33,0.33),0.8);var grip=material("glove",Color(1,1,1));var sleeve=material("sleeve",Color(0.20,0.27,0.28))
	if shotgun:
		box(root,Vector3(0,0,-0.04),Vector3(0.09,0.105,0.32),steel)
		for y in [-0.018,0.052]:cylinder(root,Vector3(0,y,-0.42),0.032,0.66,steel).rotation.x=PI/2
		var pump=cylinder(root,Vector3(0,-0.018,-0.31),0.05,0.21,grip);pump.rotation.x=PI/2;pump.name="Pump"
		for z in range(7):cylinder(root,Vector3(0,-0.018,-0.23-z*0.025),0.053,0.006,edge).rotation.x=PI/2
		box(root,Vector3(0,0.095,-0.72),Vector3(0.017,0.034,0.03),edge)
		box(root,Vector3(0,-0.045,0.21),Vector3(0.07,0.13,0.25),grip).rotation.x=-0.18
	else:
		box(root,Vector3(0,0.02,-0.13),Vector3(0.075,0.07,0.27),edge).name="Slide"
		box(root,Vector3(0,-0.035,-0.13),Vector3(0.058,0.052,0.20),steel)
		box(root,Vector3(0,-0.12,-0.018),Vector3(0.064,0.18,0.09),grip).rotation.x=0.16
		cylinder(root,Vector3(0,0.013,-0.275),0.023,0.027,steel).rotation.x=PI/2
		for z in [-0.235,-0.024]:box(root,Vector3(0,0.063,z),Vector3(0.02,0.018,0.022),steel)
		for z in range(7):box(root,Vector3(0.039,0.024,-0.09-z*0.008),Vector3(0.004,0.047,0.003),steel)
	for side in [-1.0,1.0]:
		var hp=Vector3(side*0.055,-0.13,0.03) if not shotgun else (Vector3(0.015,-0.115,0.08) if side>0 else Vector3(-0.015,-0.10,-0.31))
		ellipsoid(root,hp,Vector3(0.095,0.11,0.145),grip)
		for i in range(4):ellipsoid(root,hp+Vector3(side*-0.02,0.017+i*0.017,-0.064),Vector3(0.08,0.022,0.025),grip).rotation.z=side*0.2
		ellipsoid(root,hp+Vector3(side*-0.035,0.052,0.01),Vector3(0.045,0.036,0.08),grip)
		var arm=ellipsoid(root,hp+Vector3(side*0.08,-0.16,0.18),Vector3(0.115,0.34,0.20),sleeve);arm.rotation.x=-0.65;arm.rotation.z=side*0.25
	return root

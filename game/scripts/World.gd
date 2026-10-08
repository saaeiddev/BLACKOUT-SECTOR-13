extends Node3D
const Art=preload("res://scripts/Art.gd")
const Audio=preload("res://scripts/Services.gd")
const Enemy=preload("res://scripts/Enemy.gd")
var game
var grid:=AStarGrid2D.new()
var cells:Dictionary={}
var doors:Dictionary={}
var items:Dictionary={}
var lights:Array=[]
var obstacles:Array=[]
var clock:=0.0
var light_clock:=0.0
var layout:Array=[Rect2(-8,-14,16,28),Rect2(-4,-62,8,48),Rect2(-32,-36,28,8),Rect2(-50,-46,20,28),Rect2(-30,-20,8,24),Rect2(-48,-8,26,20),Rect2(4,-34,18,16),Rect2(-22,-96,44,34),Rect2(20,-84,22,8),Rect2(40,-100,30,42),Rect2(50,-124,8,26),Rect2(32,-170,46,46),Rect2(76,-152,24,8),Rect2(98,-164,20,32),Rect2(-150,0,104,8),Rect2(-118,-22,20,46),Rect2(-160,-12,24,26),Rect2(4,-50,78,8),Rect2(80,-56,26,28)]
var region_names=["SECURITY ENTRANCE","MAINTENANCE SPINE","AUXILIARY ACCESS","GENERATOR 04","SERVICE CORRIDOR","ELECTRICAL STORES","SECURITY OFFICE","RESEARCH LABORATORY","TRANSFER AIRLOCK","CONTAINMENT","REACTOR ACCESS","REACTOR CHAMBER","EVACUATION ROUTE","LIFT 13","WEST SERVICE TUNNEL","ARCHIVE ANNEX","WEST SWITCHGEAR","EAST POWER BUS","SUBSTATION 02"]
func build(g) -> void:
	game=g
	var concrete=Art.material("concrete",Color(0.9,0.95,1));var metal=Art.material("metal",Color(0.92,0.96,1),0.55);var floor_mat=Art.material("floor",Color(0.9,0.98,1),0.48);var yellow=Art.material("safety",Color(0.8,0.44,0.10));var dark=Art.material("dark",Color(0.075,0.10,0.12),0.45)
	grid.region=Rect2i(-84,-88,150,103);grid.cell_size=Vector2(2,2);grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;grid.default_compute_heuristic=AStarGrid2D.HEURISTIC_OCTILE;grid.update()
	for x in range(-84,66):
		for z in range(-88,15):
			var c=Vector2i(x,z);var p=Vector2(x*2+1,z*2+1);var inside=false
			for room in layout:
				if room.has_point(p):inside=true;break
			grid.set_point_solid(c,not inside)
			if inside:cells[c]=true
	for c in cells:
		var center=Vector3(c.x*2+1,0,c.y*2+1)
		for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if cells.has(c+d):continue
			var p=center+Vector3(d.x,2.25,d.y);var s=Vector3(0.24,4.5,2) if d.x!=0 else Vector3(2,4.5,0.24)
			Art.box(self,p,s,concrete,true);Art.box(self,p+Vector3(0,-1.25,0),Vector3(s.x+0.04,0.13,s.z+0.04),yellow);Art.box(self,p+Vector3(0,1.68,0),Vector3(s.x+0.07,0.18,s.z+0.07),dark);Art.box(self,p+Vector3(0,-2.08,0),Vector3(s.x+0.10,0.28,s.z+0.10),metal)
	for i in range(layout.size()):
		var r:Rect2=layout[i];var c=r.get_center()
		Art.box(self,Vector3(c.x,-0.17,c.y),Vector3(r.size.x,0.34,r.size.y),floor_mat,true)
		Art.box(self,Vector3(c.x,4.6,c.y),Vector3(r.size.x,0.18,r.size.y),dark,true)
		for z in range(int(r.position.y)+3,int(r.end.y),8):
			for x in range(int(r.position.x)+3,int(r.end.x),10):lamp(Vector3(x,4.2,z),Color(0.58,0.78,0.91) if i%3!=0 else Color(1,0.36,0.16),1.8)
		for x in [r.position.x+0.55,r.position.x+0.95]:
			Art.cylinder(self,Vector3(x,3.65,c.y),0.11,r.size.y,metal).rotation.x=PI/2
			for z in range(int(r.position.y)+2,int(r.end.y),5):Art.box(self,Vector3(x,3.65,z),Vector3(0.30,0.35,0.075),dark)
	signage("SECTOR 13\nSECURITY / RESTRICTED",Vector3(0,2.9,-13.82),0)
	signage("AUX POWER  <    |    LABORATORY  ^",Vector3(0,2.65,-37),0)
	signage("GENERATOR 04\nTWO FEEDERS REQUIRED",Vector3(-40,2.85,-45.8),0)
	signage("ELECTRICAL STORES\nFEEDER A  /  FOLLOW WEST TUNNEL",Vector3(-36,2.7,-7.8),0)
	signage("SECURITY OFFICE",Vector3(21.8,2.7,-26),PI/2)
	signage("RESEARCH LABORATORY\nLEVEL 3 AUTHORIZATION",Vector3(0,3.15,-61.8),0)
	signage("CONTAINMENT\nNO UNAUTHORIZED ENTRY",Vector3(55,3,-99.8),0)
	signage("REACTOR 13\nISOLATE ALL THREE REGULATORS",Vector3(55,3.2,-169.8),0)
	signage("EVACUATION LIFT\nSURFACE ACCESS",Vector3(108,3,-163.8),0)
	for z in range(-54,10,4):Art.box(self,Vector3(0,0.009,z),Vector3(0.13,0.012,2),yellow)
	for x in range(-44,-8,4):Art.box(self,Vector3(x,0.009,-32),Vector3(2,0.012,0.13),yellow)
	for x in [-6.5,6.5]:
		for z in [7.0,4.0,1.0]:cabinet(Vector3(x,0,z),metal,dark)
	desk(Vector3(-4,0,-7),metal,dark)
	for z in [-22,-30,-39]:cabinet(Vector3(-47,0,z),metal,dark)
	for x in [-43,-39,-35]:cabinet(Vector3(x,0,9),metal,dark)
	for z in [-24,-29]:desk(Vector3(17,0,z),metal,dark)
	for x in [-15,-7,7,15]:
		for z in [-70,-85]:
			desk(Vector3(x,0,z),metal,dark)
			for dx in [-0.7,0.6]:
				var tube=Art.cylinder(self,Vector3(x+dx,1.6,z),0.15,0.5,Art.material("labglass",Color(0.19,0.43,0.43),0.4));Art.cylinder(self,tube.position+Vector3(0,0.27,0),0.16,0.07,dark)
	for z in [-68,-80,-92]:
		for x in [43,67]:
			Art.box(self,Vector3(x,1.35,z),Vector3(1.1,2.7,2.2),dark,true);obstacles.append(Rect2(x-0.9,z-1.4,1.8,2.8))
			Art.box(self,Vector3(x+(0.58 if x<55 else -0.58),1.4,z),Vector3(0.025,1.6,1.2),Art.material("tankglass",Color(0.04,0.17,0.16),0.6))
			Art.text(self,"C-"+str(z+100)+"\nSEALED",Vector3(x,2.9,z),22,Color(0.32,0.85,0.64),PI/2)
	for x in [-43,-37]:
		Art.box(self,Vector3(x,0.8,-39),Vector3(3.2,1.6,4),metal,true);obstacles.append(Rect2(x-2,-41.4,4,4.8))
		for z in [-40,-38]:Art.cylinder(self,Vector3(x,1.7,z),0.65,0.9,dark).rotation.z=PI/2
		for k in range(9):Art.box(self,Vector3(x-1.63,1.0,-40.6+k*0.4),Vector3(0.035,0.6,0.12),yellow)
	Art.cylinder(self,Vector3(55,0.4,-148),5.1,0.8,metal)
	Art.box(self,Vector3(55,1.7,-148),Vector3(6.8,3.4,6.8),dark,true).visible=false;obstacles.append(Rect2(50.8,-152.2,8.4,8.4))
	Art.cylinder(self,Vector3(55,2.2,-148),3.6,3.6,Art.material("core",Color(0.15,0.62,0.77),0,0.65))
	for k in range(10):
		var a=k*TAU/10;var p=Vector3(55+cos(a)*4,2.2,-148+sin(a)*4);Art.cylinder(self,p,0.23,4.2,metal);Art.ellipsoid(self,p+Vector3(0,1.1,0),Vector3(0.52,0.34,0.52),yellow)
	lamp(Vector3(55,3.8,-148),Color(0.18,0.67,1),4.0)
	Art.box(self,Vector3(108,0.07,-156),Vector3(7,0.14,2),metal,true);Art.box(self,Vector3(108,0.15,-159),Vector3(7,0.30,4),metal,true);Art.box(self,Vector3(108,2,-162.8),Vector3(6.5,4,0.3),dark)
	for x in [104.5,111.5]:Art.box(self,Vector3(x,2,-162),Vector3(0.15,4,0.12),Art.material("exitlight",Color(0.2,1,0.65),0,1.5))
	gate("lab",Vector3(0,0,-58),Vector3(7.8,3.8,0.35),"SECURITY KEYCARD REQUIRED")
	gate("airlock",Vector3(31,0,-80),Vector3(0.35,3.8,7.8),"TRANSFER AIRLOCK")
	gate("reactor",Vector3(54,0,-111),Vector3(7.8,3.8,0.35),"CONTAINMENT LOCKDOWN")
	gate("evac",Vector3(88,0,-148),Vector3(0.35,3.8,7.8),"REACTOR MUST BE STABLE")
	interactable("kit","TAKE PISTOL + FLASHLIGHT",Vector3(-4,1.45,-6.6),"kit")
	interactable("feeder_a","RESET FEEDER A",Vector3(-153,1.5,5),"terminal")
	interactable("feeder_b","RESET FEEDER B",Vector3(101,1.5,-33),"terminal")
	interactable("generator","RESTORE AUXILIARY POWER",Vector3(-34,1.5,-25),"terminal")
	interactable("keycard","TAKE SECURITY KEYCARD",Vector3(17,1.5,-23.8),"keycard")
	interactable("lab","UNLOCK LABORATORY",Vector3(2.8,1.5,-56.5),"terminal")
	interactable("shotgun","TAKE PUMP SHOTGUN",Vector3(-15,1.52,-84.4),"shotgun")
	interactable("lockdown","START CONTAINMENT PURGE",Vector3(62,1.5,-64),"terminal")
	interactable("regulator_a","ISOLATE REGULATOR A",Vector3(36,1.5,-131),"terminal")
	interactable("regulator_b","ISOLATE REGULATOR B",Vector3(72,1.5,-165),"terminal")
	interactable("regulator_c","ISOLATE REGULATOR C",Vector3(38,1.5,-165),"terminal")
	interactable("lift","CALL EVACUATION LIFT",Vector3(111,1.5,-158),"terminal")
	var supplies=[Vector3(5,0.65,-10),Vector3(-26,0.65,0),Vector3(-44,0.65,-21),Vector3(12,0.65,-31),Vector3(-3,0.65,-44),Vector3(18,0.65,-66),Vector3(-17,0.65,-93),Vector3(55,0.65,-62),Vector3(65,0.65,-96),Vector3(36,0.65,-127),Vector3(74,0.65,-139),Vector3(35,0.65,-162),Vector3(103,0.65,-138),Vector3(-70,0.65,5),Vector3(-108,0.65,16),Vector3(-152,0.65,-8),Vector3(42,0.65,-46),Vector3(99,0.65,-52)]
	for i in range(supplies.size()):interactable("supply_"+str(i),"TAKE AMMUNITION + MEDKIT",supplies[i],"supply")
	for i in range(6):interactable("log_"+str(i),"READ FIELD RECORD "+str(i+1),[Vector3(5,1.1,2),Vector3(-43,1.1,8),Vector3(17,1.5,-28),Vector3(7,1.5,-69),Vector3(67,1.1,-91),Vector3(37,1.1,-133)][i],"log")
	signage("WEST SWITCHGEAR / FEEDER A",Vector3(-153,2.9,-11.8),0)
	signage("SUBSTATION 02 / FEEDER B",Vector3(93,2.9,-55.8),0)
	for x in [-112,-104]:
		for z in [-17,-11,17]:cabinet(Vector3(x,0,z),metal,dark)
	for x in [86,93,100]:cabinet(Vector3(x,0,-54),metal,dark)
	for x in [-156,-148,-140]:cabinet(Vector3(x,0,-10),metal,dark)
	for z in [-133,-160]:
		for x in [44,66]:
			Art.box(self,Vector3(x,0.65,z),Vector3(2.4,1.3,2.4),metal,true)
			obstacles.append(Rect2(x-1.6,z-1.6,3.2,3.2))
			for dx in [-0.8,0.8]:Art.box(self,Vector3(x+dx,1.33,z),Vector3(0.10,0.04,2.4),yellow)
	# Crossbeams, vent housings and warning chevrons give the modular kit a consistent scale.
	for ri in range(layout.size()):
		var rr:Rect2=layout[ri]
		for zz in range(int(rr.position.y)+4,int(rr.end.y),10):
			Art.box(self,Vector3(rr.get_center().x,4.34,zz),Vector3(rr.size.x,0.28,0.18),metal)
			if rr.size.x>12:
				Art.box(self,Vector3(rr.end.x-0.14,2.9,zz),Vector3(0.15,0.75,1.35),dark)
				for k in range(6):Art.box(self,Vector3(rr.end.x-0.25,2.63+k*0.10,zz),Vector3(0.09,0.035,1.25),metal)
	for r in obstacles:block_rect(r,true)
	sync_gates(true);spawn_population()
func lamp(pos:Vector3,color:Color,energy:float) -> void:
	Art.box(self,pos,Vector3(1.7,0.085,0.26),Art.material("lamp_"+color.to_html(),color,0,1))
	var l:=OmniLight3D.new();l.position=pos+Vector3(0,-0.3,0);l.light_color=color;l.light_energy=energy;l.omni_range=12;l.omni_attenuation=1.1;l.shadow_enabled=false;add_child(l);lights.append(l)
func signage(words:String,pos:Vector3,yaw:float) -> void:
	var n:=Node3D.new();add_child(n);n.position=pos;n.rotation.y=yaw;Art.box(n,Vector3.ZERO,Vector3(5.6,1.25,0.08),Art.material("signboard",Color(0.025,0.065,0.075),0.2));Art.text(n,words,Vector3(0,0,0.065),32,Color(0.83,0.87,0.79))
func cabinet(pos:Vector3,metal:Material,dark:Material) -> void:
	Art.box(self,pos+Vector3(0,1.1,0),Vector3(1.3,2.2,0.85),metal,true);obstacles.append(Rect2(pos.x-0.85,pos.z-0.65,1.7,1.3));Art.box(self,pos+Vector3(0,1.1,0.44),Vector3(0.035,2.1,0.015),dark);Art.box(self,pos+Vector3(0.34,1.2,0.47),Vector3(0.08,0.3,0.045),dark)
	for y in range(4):Art.box(self,pos+Vector3(0,1.7+y*0.08,0.44),Vector3(0.8,0.02,0.02),dark)
func desk(pos:Vector3,metal:Material,dark:Material) -> void:
	Art.box(self,pos+Vector3(0,1.14,0),Vector3(2.6,0.15,1.25),metal,true);obstacles.append(Rect2(pos.x-1.6,pos.z-0.9,3.2,1.8))
	for dx in [-1.1,1.1]:Art.box(self,pos+Vector3(dx,0.56,0),Vector3(0.12,1.12,0.9),dark,true)
	Art.box(self,pos+Vector3(0.5,1.53,-0.32),Vector3(0.72,0.50,0.12),dark);Art.box(self,pos+Vector3(0.5,1.55,-0.245),Vector3(0.61,0.36,0.015),Art.material("screen",Color(0.08,0.42,0.40),0,0.3));Art.box(self,pos+Vector3(0.5,1.25,0.12),Vector3(0.65,0.035,0.22),dark)
func gate(id:String,pos:Vector3,size:Vector3,label:String) -> void:
	var n:=Node3D.new();add_child(n);n.position=pos;var b:=StaticBody3D.new();n.add_child(b);b.collision_layer=1;b.collision_mask=0
	var c:=CollisionShape3D.new();var s:=BoxShape3D.new();s.size=size;c.shape=s;c.position.y=size.y/2;b.add_child(c);Art.box(n,Vector3(0,size.y/2,0),size,Art.material("door",Color(0.16,0.22,0.25),0.65))
	var wide=size.x>size.z;var board:=Node3D.new();n.add_child(board);board.position=Vector3(0,2.3,0.21) if wide else Vector3(-0.21,2.3,0);board.rotation.y=0 if wide else -PI/2;Art.text(board,label,Vector3.ZERO,24,Color(1,0.6,0.24))
	for side in [-1,1]:Art.box(n,Vector3(side*(size.x/2+0.1) if wide else 0,2,0 if wide else side*(size.z/2+0.1)),Vector3(0.18,4,0.18),Art.material("safety",Color(0.8,0.44,0.10)))
	var r=Rect2(pos.x-size.x/2-0.2,pos.z-size.z/2-0.2,size.x+0.4,size.z+0.4);doors[id]={"node":n,"body":b,"rect":r,"open":false};block_rect(r,true)
func set_gate(id:String,open:bool,instant:=false) -> void:
	var d=doors[id]
	if d.open==open:return
	d.open=open;d.body.collision_layer=0 if open else 1;block_rect(d.rect,not open)
	if instant:d.node.position.y=4.3 if open else 0
	else:Audio.sound(game,"door",d.node.global_position,-6);create_tween().tween_property(d.node,"position:y",4.3 if open else 0,1.4)
func sync_gates(instant:=false) -> void:
	set_gate("lab",game.stage>=4,instant);set_gate("airlock",game.stage!=6,instant);set_gate("reactor",game.stage>=7,instant);set_gate("evac",game.stage>=8,instant)
func interactable(id:String,label:String,pos:Vector3,type:String) -> void:
	if id in game.collected and type!="terminal":return
	var n:=Node3D.new();add_child(n);n.position=pos;var accent=Art.material("pickup",Color(0.25,0.83,0.67),0,0.3);var shell=Art.material("metal",Color(0.92,0.96,1),0.55)
	if type=="terminal":
		Art.box(n,Vector3(0,-0.4,0),Vector3(0.5,1.1,0.45),shell);Art.box(n,Vector3.ZERO,Vector3(0.58,0.36,0.08),accent);Art.text(n,label,Vector3(0,0.35,0.04),19,Color(0.65,1,0.81))
	elif type in ["kit","shotgun"]:
		Art.box(n,Vector3(0,-0.12,0),Vector3(0.95,0.15,0.55),shell);var w=Art.weapon(n,type=="shotgun");w.rotation.z=PI/2;w.scale=Vector3.ONE*0.8;Art.box(n,Vector3(0,-0.04,0.27),Vector3(0.8,0.045,0.035),accent)
	elif type=="supply":
		Art.box(n,Vector3.ZERO,Vector3(0.65,0.36,0.4),Art.material("supply",Color(0.21,0.33,0.25),0.4));Art.box(n,Vector3(0,0.195,0),Vector3(0.35,0.015,0.075),accent);Art.box(n,Vector3(0,0.195,0),Vector3(0.075,0.015,0.28),accent)
	else:Art.box(n,Vector3.ZERO,Vector3(0.28,0.045,0.2),accent);Art.text(n,"ACCESS 13" if type=="keycard" else "FIELD RECORD",Vector3(0,0.25,0),16)
	var a:=Area3D.new();n.add_child(a);a.collision_layer=8;a.collision_mask=0;a.set_meta("interact_id",id);a.set_meta("prompt",label);var c:=CollisionShape3D.new();var s:=BoxShape3D.new();s.size=Vector3(0.95,0.75,0.8);c.shape=s;a.add_child(c);items[id]=n
func collect(id:String) -> void:
	if items.has(id) and is_instance_valid(items[id]) and not id.begins_with("regulator") and id not in ["generator","feeder_a","feeder_b","lab","lockdown","lift"]:items[id].queue_free();items.erase(id)
func cell_of(pos:Vector3) -> Vector2i:return Vector2i(floori(pos.x/2),floori(pos.z/2))
func block_rect(rect:Rect2,solid:bool) -> void:
	for x in range(floori(rect.position.x/2),ceili(rect.end.x/2)):
		for z in range(floori(rect.position.y/2),ceili(rect.end.y/2)):
			var c=Vector2i(x,z)
			if cells.has(c):grid.set_point_solid(c,solid)
func walkable(pos:Vector3) -> bool:
	var c=cell_of(pos);return cells.has(c) and not grid.is_point_solid(c)
func nearest_cell(pos:Vector3) -> Vector2i:
	var c=cell_of(pos)
	if cells.has(c) and not grid.is_point_solid(c):return c
	for radius in range(1,5):
		for dx in range(-radius,radius+1):
			for dz in range(-radius,radius+1):
				var p=c+Vector2i(dx,dz)
				if cells.has(p) and not grid.is_point_solid(p):return p
	return c
func route(from:Vector3,to:Vector3) -> PackedVector3Array:
	var a=nearest_cell(from);var b=nearest_cell(to);var out:=PackedVector3Array()
	if not cells.has(a) or not cells.has(b):return out
	for c in grid.get_id_path(a,b,true):out.append(Vector3(c.x*2+1,0,c.y*2+1))
	return out
func region_at(p:Vector3) -> String:
	for i in range(layout.size()):
		if layout[i].has_point(Vector2(p.x,p.z)):return region_names[i]
	return "SECTOR 13"
func spawn_population() -> void:
	var population=[["m1","stalker",Vector3(0,0,-22)],["m2","stalker",Vector3(-21,0,-32)],["m3","ambusher",Vector3(-36,0,4)],["m4","stalker",Vector3(-46,0,-32)],["m5","stalker",Vector3(-39,0,-22)],["m6","ambusher",Vector3(0,0,-48)],["m7","stalker",Vector3(13,0,-25)],["m8","stalker",Vector3(-26,0,-13)],["l1","stalker",Vector3(0,0,-73)],["l2","stalker",Vector3(13,0,-78)],["l3","ambusher",Vector3(-17,0,-91)],["l4","stalker",Vector3(-7,0,-92)],["l5","ambusher",Vector3(19,0,-93)],["l6","stalker",Vector3(29,0,-80)],["c1","stalker",Vector3(54,0,-81)],["c2","stalker",Vector3(63,0,-87)],["c3","ambusher",Vector3(48,0,-94)],["r1","stalker",Vector3(43,0,-128)],["r2","ambusher",Vector3(69,0,-133)],["r3","stalker",Vector3(39,0,-156)],["r4","stalker",Vector3(68,0,-159)],["elite","elite",Vector3(55,0,-163)],["e1","ambusher",Vector3(100,0,-140)],["e2","stalker",Vector3(110,0,-135)]]
	population.append_array([["w1","stalker",Vector3(-63,0,4)],["w2","ambusher",Vector3(-85,0,4)],["w3","stalker",Vector3(-110,0,15)],["w4","ambusher",Vector3(-107,0,-14)],["w5","stalker",Vector3(-128,0,4)],["w6","stalker",Vector3(-147,0,-5)],["w7","ambusher",Vector3(-151,0,9)],["s1","stalker",Vector3(20,0,-46)],["s2","stalker",Vector3(45,0,-46)],["s3","ambusher",Vector3(70,0,-46)],["s4","stalker",Vector3(92,0,-51)],["s5","ambusher",Vector3(99,0,-35)]])
	for data in population:spawn_enemy(data[0],data[1],data[2])
func spawn_enemy(id:String,kind:String,pos:Vector3):
	if id in game.dead:return null
	var e=Enemy.new();add_child(e);e.setup(game,id,kind,pos)
	if not walkable(pos):
		var c=nearest_cell(pos);e.position=Vector3(c.x*2+1,0,c.y*2+1)
	return e
func _process(delta:float) -> void:
	clock+=delta;light_clock+=delta
	if not is_instance_valid(game) or not is_instance_valid(game.player) or light_clock<0.15:return
	light_clock=0
	for l in lights:
		l.visible=l.global_position.distance_squared_to(game.player.global_position)<35*35
		if l.visible:l.light_energy=(1.65 if game.stage>=2 else 1.1)*(0.94+0.06*sin(clock*3+l.position.x))*float(Audio.settings.gamma)

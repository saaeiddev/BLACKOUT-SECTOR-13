extends CharacterBody3D
const Art=preload("res://scripts/Art.gd")
const Audio=preload("res://scripts/Services.gd")
var game
var eid:=""
var kind:="stalker"
var health:=90.0
var rig:Dictionary
var alive:=true
var state:="patrol"
var target:=Vector3.ZERO
var home:=Vector3.ZERO
var path:=PackedVector3Array()
var nav_timer:=0.0
var lost_timer:=0.0
var cooldown:=0.0
var attack_timer:=0.0
var attack_type:=0
var attack_done:=false
var attack_target:=Vector3.ZERO
var anim:=0.0
var audio_timer:=0.0
var stumble:=0.0
var patrol_timer:=0.0
func setup(g,id:String,type:String,pos:Vector3) -> void:
	game=g;eid=id;kind=type;position=pos;home=pos;target=pos
	health=1450 if kind=="elite" else (66 if kind=="ambusher" else 90)
	if game.difficulty=="Easy":health*=0.82
	collision_layer=4;collision_mask=1|2
	var c:=CollisionShape3D.new();var s:=CapsuleShape3D.new();s.radius=0.5 if kind=="elite" else 0.32;s.height=2.9 if kind=="elite" else 1.9;c.position.y=s.height/2;c.shape=s;add_child(c)
	rig=Art.creature(self,kind);floor_snap_length=0.45;set_meta("enemy",true);add_to_group("enemies");audio_timer=randf_range(2,6)
func can_see() -> bool:
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(global_position+Vector3(0,1.45,0),game.player.global_position+Vector3(0,1.2,0),1)).is_empty()
func hear(pos:Vector3,radius:float) -> void:
	if alive and global_position.distance_to(pos)<radius:target=pos;state="investigate";lost_timer=7;nav_timer=0
func take_damage(amount:float,_point:Vector3) -> void:
	if not alive:return
	health-=amount;stumble=0.15;target=game.player.global_position;state="pursue";lost_timer=7
	if health<=0:
		alive=false;collision_layer=0;collision_mask=1;state="dead";game.enemy_died(self);Audio.sound(game,"growl",global_position,-8,0.65)
		var t=create_tween();t.tween_property(rig.root,"rotation:x",-PI/2,0.4);t.parallel().tween_property(rig.root,"position:y",0.22,0.4);t.tween_interval(16);t.tween_callback(queue_free)
func _physics_process(delta:float) -> void:
	if not is_instance_valid(game.player) or not game.playing or not alive:return
	var distance=global_position.distance_to(game.player.global_position)
	if distance>44:return
	cooldown-=delta;nav_timer-=delta;audio_timer-=delta;stumble=maxf(0,stumble-delta);anim+=delta
	if audio_timer<0:Audio.sound(game,"growl",global_position,-11,1.2 if kind=="ambusher" else 0.8);audio_timer=randf_range(5,10)
	var sees=distance<22 and can_see()
	if sees:target=game.player.global_position;state="pursue";lost_timer=6
	else:
		lost_timer-=delta
		if lost_timer<=0 and state!="attack":state="patrol"
	if state=="patrol":
		patrol_timer-=delta
		if patrol_timer<=0:
			var p=home+Vector3(randf_range(-4,4),0,randf_range(-4,4))
			if game.world.walkable(p):target=p
			patrol_timer=5
	if attack_timer>0:
		attack_timer-=delta;velocity.x=0;velocity.z=0
		var windup=0.72 if kind=="elite" else (0.55 if kind=="ambusher" else 0.5)
		var duration=1.45 if kind=="elite" else 1.05;var elapsed=duration-attack_timer
		if ((kind=="ambusher") or (kind=="elite" and attack_type==1)) and elapsed>windup and elapsed<windup+0.4:
			var charge=(attack_target-global_position).normalized();velocity.x=charge.x*8;velocity.z=charge.z*8
		for arm in rig.arms:arm.rotation.x=-1.8*sin(clampf(elapsed/windup,0,1)*PI/2) if elapsed<windup else 0.9
		if elapsed>=windup and not attack_done:
			var charge_attack=kind=="ambusher" or (kind=="elite" and attack_type==1)
			if distance<(1.95 if charge_attack or kind!="elite" else 3.6) and can_see():
				game.player.damage(25 if kind=="elite" else (15 if kind=="ambusher" else 18));attack_done=true
			if not charge_attack or elapsed>windup+0.4:attack_done=true
			if attack_done:Audio.sound(game,"attack",global_position,-5,0.7 if kind=="elite" else 1)
		if attack_timer<=0:cooldown=1.6 if kind=="elite" else 1.3
	else:
		var attack_range=4.5 if kind=="elite" else (4.0 if kind=="ambusher" else 1.65)
		if sees and distance<attack_range and cooldown<=0:
			attack_timer=1.45 if kind=="elite" else 1.05;attack_done=false;attack_type=randi()%2;attack_target=game.player.global_position;Audio.sound(game,"attack",global_position,-9,0.65)
			if kind=="elite":game.warning_ring(global_position,3.6)
			return
		if nav_timer<=0:path=game.world.route(global_position,target);nav_timer=randf_range(0.65,1.0)
		while not path.is_empty() and Vector2(global_position.x,global_position.z).distance_to(Vector2(path[0].x,path[0].z))<0.55:path.remove_at(0)
		var dir:=Vector3.ZERO
		if not path.is_empty():dir=path[0]-global_position;dir.y=0;dir=dir.normalized()
		if sees and distance<3:dir=(target-global_position).normalized();dir.y=0
		if dir.length()>0.1:rotation.y=lerp_angle(rotation.y,atan2(-dir.x,-dir.z),delta*7)
		var speed=3.2 if kind=="ambusher" else (1.7 if kind=="elite" else 1.5)
		if state=="patrol":speed*=0.48
		if stumble>0:speed*=0.18
		if distance<1.1:speed=0
		velocity.x=dir.x*speed;velocity.z=dir.z*speed
		for i in range(rig.legs.size()):rig.legs[i].rotation.x=sin(anim*speed*4+i*PI)*0.36
		for i in range(rig.arms.size()):rig.arms[i].rotation.x=sin(anim*speed*4+i*PI)*0.25
		rig.root.position.y=absf(sin(anim*speed*4))*0.03
	velocity.y-=20*delta;move_and_slide()

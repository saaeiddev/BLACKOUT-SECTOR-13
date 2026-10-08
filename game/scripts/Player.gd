extends CharacterBody3D

const Art=preload("res://scripts/Art.gd")
const Audio=preload("res://scripts/Services.gd")
var game
var camera:Camera3D
var collider:CollisionShape3D
var flashlight:SpotLight3D
var weapon_root:Node3D
var guns:Array=[]
var flash:OmniLight3D
var health:=100.0
var medkits:=2
var has_pistol:=false
var has_shotgun:=false
var selected:=0
var mag:Array=[12,6]
var reserve:Array=[48,18]
var capacity:Array=[12,6]
var pitch:=0.0
var fire_timer:=0.0
var reload_timer:=0.0
var reload_weapon:=0
var switch_timer:=0.0
var recoil:=0.0
var bob_time:=0.0
var step_time:=0.0
var hurt_timer:=0.0
var stamina:=100.0
var crouched:=false
var prompt_id:=""
var prompt_text:=""
var muzzle_flash_timer:=0.0
var aiming:=false
var focused:=true
var input_delay:=0.0

func setup(g) -> void:
	game=g;collision_layer=2;collision_mask=1|4;floor_snap_length=0.35;floor_max_angle=deg_to_rad(46)
	collider=CollisionShape3D.new();var c:=CapsuleShape3D.new();c.radius=0.28;c.height=1.78;collider.shape=c;collider.position.y=0.89;add_child(collider)
	camera=Camera3D.new();camera.position.y=1.61;camera.near=0.025;camera.far=90;camera.fov=Audio.settings.fov;add_child(camera)
	flashlight=SpotLight3D.new();flashlight.light_color=Color(0.90,0.94,0.84);flashlight.light_energy=4.5;flashlight.spot_range=24;flashlight.spot_angle=32;flashlight.spot_attenuation=0.9;flashlight.spot_angle_attenuation=0.6;flashlight.position=Vector3(0.18,-0.12,-0.13);flashlight.shadow_enabled=true;flashlight.visible=false;camera.add_child(flashlight)
	weapon_root=Node3D.new();camera.add_child(weapon_root)
	guns=[Art.weapon(weapon_root,false),Art.weapon(weapon_root,true)]
	for gun in guns:
		gun.visible=false
		for n in gun.get_children():
			if n is GeometryInstance3D:n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash=OmniLight3D.new();flash.light_color=Color(1,0.59,0.18);flash.light_energy=4;flash.omni_range=7;flash.position=Vector3(0.21,-0.14,-0.8);flash.visible=false;camera.add_child(flash)
	var tip:=MeshInstance3D.new();var s:=SphereMesh.new();s.radius=0.04;s.height=0.12;tip.mesh=s;tip.material_override=Art.material("muzzle",Color(1,0.7,0.18),0,3);flash.add_child(tip)

func inventory() -> Dictionary:
	return {"health":health,"medkits":medkits,"has_pistol":has_pistol,"has_shotgun":has_shotgun,"selected":selected,"mag":mag.duplicate(),"reserve":reserve.duplicate()}

func restore(data:Dictionary) -> void:
	health=clampf(float(data.health),1,100);medkits=clampi(int(data.medkits),0,9)
	has_pistol=bool(data.has_pistol);has_shotgun=bool(data.has_shotgun)
	mag=[clampi(int(data.mag[0]),0,12),clampi(int(data.mag[1]),0,6)]
	reserve=[clampi(int(data.reserve[0]),0,240),clampi(int(data.reserve[1]),0,90)]
	selected=clampi(int(data.get("selected",0)),0,1)
	if selected==1 and not has_shotgun:selected=0
	flashlight.visible=has_pistol;sync_guns()

func sync_guns() -> void:
	guns[0].visible=has_pistol and selected==0;guns[1].visible=has_shotgun and selected==1

func damage(amount:float) -> void:
	if not game.playing or health<=0:return
	if game.difficulty=="Easy":amount*=0.5
	health=maxf(0,health-amount);hurt_timer=0.55
	Audio.sound(game,"hit",null,-6)
	if health<=0:game.die()

func reload() -> void:
	if not has_pistol or reload_timer>0 or switch_timer>0 or mag[selected]>=capacity[selected] or reserve[selected]<=0:return
	reload_weapon=selected;reload_timer=1.55 if selected==0 else 2.25
	Audio.sound(game,"reload",null,-6,0.85 if selected==1 else 1.0)

func finish_reload() -> void:
	var needed=capacity[reload_weapon]-int(mag[reload_weapon]);var count=mini(needed,int(reserve[reload_weapon]))
	mag[reload_weapon]+=count;reserve[reload_weapon]-=count

func switch_weapon(n:int) -> void:
	if n==selected or (n==0 and not has_pistol) or (n==1 and not has_shotgun):return
	selected=n;reload_timer=0;switch_timer=0.32;sync_guns()

func heal() -> void:
	if medkits<=0:game.toast("No medkits. Look for green supply cases.");return
	if health>=100:game.toast("Health is already full.");return
	medkits-=1;health=minf(100,health+60);Audio.sound(game,"pickup",null,-8);game.toast("MEDKIT USED  +60 HEALTH")

func fire() -> void:
	if not has_pistol or reload_timer>0 or switch_timer>0 or fire_timer>0 or health<=0:return
	if mag[selected]<=0:
		Audio.sound(game,"empty",null,-7);fire_timer=0.28
		if reserve[selected]>0:reload()
		return
	mag[selected]-=1;fire_timer=0.24 if selected==0 else 0.86;recoil=0.065 if selected==0 else 0.13;muzzle_flash_timer=0.05
	Audio.sound(game,"pistol" if selected==0 else "shotgun",null,-5,randf_range(0.96,1.03))
	game.noise(global_position,32 if selected==0 else 40)
	# Check from the body to the camera and muzzle first: never shoot through a nearby wall.
	var origin=camera.global_position
	var muzzle=camera.to_global(Vector3(0.20,-0.13,-0.82 if selected==1 else -0.60))
	var blocked=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,muzzle,1,[get_rid()]))
	if not blocked.is_empty():game.impact(blocked.position,blocked.normal,false);return
	for pellet in range(8 if selected==1 else 1):
		var spread=(0.023 if aiming else 0.042) if selected==1 else (0.001 if aiming else 0.006)
		var dir=(-camera.global_basis.z+camera.global_basis.x*randf_range(-spread,spread)+camera.global_basis.y*randf_range(-spread,spread)).normalized()
		var hit=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,origin+dir*75,1|4,[get_rid()]))
		if not hit.is_empty():
			var enemy=hit.collider.has_meta("enemy")
			if enemy:
				var damage_value=13.0 if selected==1 else 34.0
				if selected==1:damage_value*=clampf(1.3-origin.distance_to(hit.position)/24,0.25,1)
				hit.collider.take_damage(damage_value,hit.position);game.hit_timer=0.18
			game.impact(hit.position,hit.normal,enemy)

func _unhandled_input(event:InputEvent) -> void:
	if not game.playing or get_tree().paused or not focused:return
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		var sens=float(Audio.settings.sensitivity)*0.0019
		rotate_y(-event.relative.x*sens)
		pitch=clampf(pitch-event.relative.y*sens*(-1 if Audio.settings.invert_y else 1),-1.48,1.48)
	if event.is_action_pressed("reload"):reload()
	if event.is_action_pressed("flashlight") and has_pistol:flashlight.visible=not flashlight.visible;Audio.sound(game,"empty",null,-12)
	if event.is_action_pressed("interact") and not prompt_id.is_empty():game.interact(prompt_id)
	if event.is_action_pressed("pistol"):switch_weapon(0)
	if event.is_action_pressed("shotgun"):switch_weapon(1)
	if event.is_action_pressed("heal"):heal()

func _physics_process(delta:float) -> void:
	if not game.playing:return
	input_delay=maxf(0,input_delay-delta)
	var old_reload=reload_timer;reload_timer=maxf(0,reload_timer-delta)
	if old_reload>0 and reload_timer==0:finish_reload()
	fire_timer=maxf(0,fire_timer-delta);switch_timer=maxf(0,switch_timer-delta);hurt_timer=maxf(0,hurt_timer-delta);muzzle_flash_timer=maxf(0,muzzle_flash_timer-delta)
	flash.visible=muzzle_flash_timer>0
	var input_vec=Input.get_vector("left","right","forward","back") if focused and input_delay<=0 else Vector2.ZERO
	var wants_crouch=Input.is_action_pressed("crouch")
	if not wants_crouch and crouched:
		var q:=PhysicsShapeQueryParameters3D.new();var c:=CapsuleShape3D.new();c.radius=0.285;c.height=1.78;q.shape=c;q.transform=Transform3D(Basis.IDENTITY,global_position+Vector3(0,0.94,0));q.collision_mask=1
		wants_crouch=not get_world_3d().direct_space_state.intersect_shape(q,1).is_empty()
	crouched=wants_crouch
	collider.shape.height=1.1 if crouched else 1.78;collider.position.y=collider.shape.height/2
	var sprinting=Input.is_action_pressed("sprint") and stamina>1 and input_vec.length()>0.1 and not crouched and not Input.is_action_pressed("aim")
	stamina=clampf(stamina+(-17 if sprinting else 16)*delta,0,100)
	aiming=Input.is_action_pressed("aim") and has_pistol and reload_timer<=0
	var speed=6.0 if sprinting else (2.0 if crouched else 3.9)
	if aiming:speed*=0.72
	var dir=basis*Vector3(input_vec.x,0,input_vec.y)
	velocity.x=move_toward(velocity.x,dir.x*speed,delta*23)
	velocity.z=move_toward(velocity.z,dir.z*speed,delta*23)
	if is_on_floor():
		velocity.y=-0.5
		if Input.is_action_just_pressed("jump") and not crouched:velocity.y=6
	else:velocity.y-=19*delta
	# A bounded step-up only when the upper capsule is clear.
	if is_on_floor() and dir.length()>0.1:
		var motion=Vector3(velocity.x,0,velocity.z)*delta
		if test_move(global_transform,motion):
			var raised=global_transform;raised.origin.y+=0.28
			if not test_move(raised,motion) and not test_move(global_transform,Vector3(0,0.28,0)):
				global_position.y+=0.28
	move_and_slide()
	if global_position.y < -8:game.restart_checkpoint()
	var moving=Vector2(velocity.x,velocity.z).length()
	if moving>0.5 and is_on_floor():
		bob_time+=delta*(12 if sprinting else 8);step_time+=delta
		if step_time>(0.31 if sprinting else 0.48):
			step_time=0;Audio.sound(game,"step",global_position,-12,randf_range(0.85,1.15))
			if sprinting:game.noise(global_position,11)
	var bob=sin(bob_time)*0.024 if Audio.settings.head_bob and moving>0.5 and is_on_floor() else 0.0
	camera.position.y=lerpf(camera.position.y,(1.0 if crouched else 1.61)+bob,delta*13)
	recoil=move_toward(recoil,0,delta*0.7)
	camera.rotation.x=pitch+(recoil*0.2 if Audio.settings.camera_shake else 0.0)
	camera.fov=lerpf(camera.fov,float(Audio.settings.fov)-(13 if aiming else 0),delta*10)
	var near_hit=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position-camera.global_basis.z*1.05,1,[get_rid()]))
	var retract=0.25 if not near_hit.is_empty() else 0.0
	var rest=Vector3(0.21,-0.24,-0.35) if selected==0 else Vector3(0.22,-0.22,-0.24)
	if aiming:rest=Vector3(0,-0.08,-0.32 if selected==0 else -0.24)
	rest.z+=recoil+retract
	if reload_timer>0:rest.y-=0.19;rest.x+=0.07*sin(reload_timer*7)
	if switch_timer>0:rest.y-=switch_timer
	weapon_root.position=weapon_root.position.lerp(rest+Vector3(bob*0.25,bob*0.5,0),minf(1,delta*16))
	weapon_root.rotation.x=recoil*1.7+(0.35*sin(reload_timer*4) if reload_timer>0 else 0.0)
	weapon_root.rotation.z=0.35 if reload_timer>0 else 0.0
	var slide=guns[0].get_node_or_null("Slide")
	if slide!=null:slide.position.z=-0.13+recoil*0.6
	var pump=guns[1].get_node_or_null("Pump")
	if pump!=null:pump.position.z=-0.31+(sin((0.86-fire_timer)*PI*3)*0.07 if fire_timer>0 else 0.0)
	if focused and input_delay<=0 and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and Input.is_action_pressed("fire"):fire()
	update_interaction()

func update_interaction() -> void:
	prompt_id="";prompt_text=""
	var q=PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position-camera.global_basis.z*3.3,1|8,[get_rid()]);q.collide_with_areas=true
	var h=get_world_3d().direct_space_state.intersect_ray(q)
	if not h.is_empty() and h.collider.has_meta("interact_id"):
		prompt_id=h.collider.get_meta("interact_id");prompt_text=h.collider.get_meta("prompt")

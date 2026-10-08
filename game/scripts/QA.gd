extends Node

const Services=preload("res://scripts/Services.gd")
const Enemy=preload("res://scripts/Enemy.gd")
var game
var mode:=""
var checks:Array=[]
var failures:=0
var tick:=0
var path:=PackedVector3Array()
var target_key:=""
var path_clock:=0.0
var stuck_clock:=0.0
var last_pos:=Vector3.ZERO
var stage_start:=0.0
var last_stage:=-1
var campaign_clock:=0.0
var finished:=false

func setup(g,m:String) -> void:
	game=g;mode=m;process_mode=Node.PROCESS_MODE_ALWAYS
	if mode in ["--qa-campaign","--qa-campaign-easy"]:
		game.difficulty="Easy" if mode.ends_with("easy") else "Normal";game.start_campaign(false);game.player.input_delay=0;last_pos=game.player.position
	elif mode=="--qa-reload":call_deferred("reload_test")
	else:call_deferred("smoke")

func check(name:String,ok:bool,detail:="") -> void:
	checks.append({"test":name,"status":"PASS" if ok else "FAIL","detail":detail})
	print("QA ","PASS " if ok else "FAIL ",name," ",detail)
	if not ok:failures+=1

func frames(n:int) -> void:
	for i in range(n):await get_tree().physics_frame

func screenshot(name:String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	var dir=OS.get_environment("BLACKOUT_QA_DIR")
	if not dir.is_empty():
		DirAccess.make_dir_recursive_absolute(dir)
		var result=get_viewport().get_texture().get_image().save_png(dir+"/"+name+".png")
		print("SCREENSHOT ",name," ",result)

func aim_at(point:Vector3) -> void:
	var d=(point-game.player.camera.global_position).normalized()
	game.player.rotation.y=atan2(-d.x,-d.z);game.player.pitch=asin(clampf(d.y,-1,1));game.player.camera.rotation.x=game.player.pitch

func key_event(code:int) -> void:
	var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=true;Input.parse_input_event(e)
	var up:=InputEventKey.new();up.keycode=code;up.physical_keycode=code;up.pressed=false;Input.parse_input_event(up)

func finish() -> void:
	finished=true
	for action in Services.KEYS.keys()+["fire","aim"]:Input.action_release(action)
	var dir=OS.get_environment("BLACKOUT_QA_DIR")
	if not dir.is_empty():
		DirAccess.make_dir_recursive_absolute(dir);var f=FileAccess.open(dir+"/"+mode.trim_prefix("--")+".json",FileAccess.WRITE)
		f.store_string(JSON.stringify({"build":"1.0.0","mode":mode,"platform":OS.get_name(),"renderer":RenderingServer.get_video_adapter_name(),"checks":checks,"failures":failures},"\t"))
	print("QA_FINISHED ",mode," failures=",failures)
	game.quit_game(0 if failures==0 else 1)

func smoke() -> void:
	await frames(3)
	check("Main menu created",game.ui.menu_name=="main")
	await screenshot("01-main-menu")
	game.ui.settings_menu("main");await frames(2)
	check("Settings four-tab interface",game.ui.menu_name=="settings")
	await screenshot("02-settings")
	game.ui.credits();await frames(2);check("Credits open",game.ui.menu_name=="credits")
	game.start_campaign(false);await frames(20)
	game.ui.confirm_new("Normal");check("New Game confirms overwrite",game.ui.menu_name=="overwrite");game.ui.play_hud();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var p=game.player;var start=p.position
	Input.action_press("forward");await frames(70);Input.action_release("forward");await frames(3)
	check("WASD movement and grounded collision",p.position.z<start.z-3 and p.is_on_floor(),str(p.position))
	Input.action_press("crouch");await frames(3);check("Crouch height",p.collider.shape.height<1.2);Input.action_release("crouch");await frames(3);check("Stand clearance",p.collider.shape.height>1.7)
	p.position=Vector3(-4,0.04,-3.9);p.velocity=Vector3.ZERO;aim_at(game.world.items.kit.position);await frames(3)
	check("Equipment interaction ray",p.prompt_id=="kit",p.prompt_id)
	key_event(KEY_E);await frames(3);check("Equipment objective and flashlight",game.stage==1 and p.has_pistol and p.flashlight.visible)
	await screenshot("03-security-entrance")
	p.position=Vector3(-1,0.04,-6);p.velocity=Vector3.ZERO
	var enemy=game.world.spawn_enemy("qa_target","stalker",Vector3(-1,0,-11));enemy.set_physics_process(false)
	aim_at(enemy.global_position+Vector3(0,1.5,0));await frames(2)
	var rounds=int(p.mag[0]);p.fire();await frames(16);p.fire();await frames(16);p.fire();await frames(16)
	check("Pistol ray damage and death",not enemy.alive and int(p.mag[0])==rounds-3)
	var total=int(p.mag[0])+int(p.reserve[0]);p.reload();p.reload();await frames(100)
	check("Reload conservation and duplicate rejection",int(p.mag[0])==12 and int(p.mag[0])+int(p.reserve[0])==total)
	p.has_shotgun=true;p.switch_weapon(1);await frames(24)
	var e2=game.world.spawn_enemy("qa_shotgun","stalker",Vector3(-1,0,-10));e2.set_physics_process(false);aim_at(e2.global_position+Vector3(0,1.4,0));await frames(2);p.fire();await frames(55)
	check("Shotgun pellets and shell consumption",e2.health<90 and int(p.mag[1])==5)
	p.reload();await frames(10);p.switch_weapon(0);await frames(150)
	check("Reload canceled on weapon switch",int(p.mag[1])==5)
	for actor in get_tree().get_nodes_in_group("enemies"):actor.set_physics_process(false)
	p.position=Vector3(0,0.04,-4);p.velocity=Vector3.ZERO;p.health=100
	var attacker=game.world.spawn_enemy("qa_melee","stalker",Vector3(1.4,0,-4))
	await frames(15);check("Enemy attack has a visible wind-up",p.health==100 and attacker.attack_timer>0)
	await frames(35);check("Enemy damage follows wind-up",p.health<100);attacker.take_damage(1000,attacker.position)
	p.position=Vector3(0,0.04,12.5);p.velocity=Vector3.ZERO
	var hidden=Enemy.new();game.world.add_child(hidden);hidden.setup(game,"qa_behind_wall","stalker",Vector3(0,0,18));hidden.set_physics_process(false)
	aim_at(hidden.global_position+Vector3(0,1.5,0));await frames(3);var hp=hidden.health;p.fire();await frames(20);check("Solid wall blocks shots",hidden.health==hp)
	p.health=32;p.medkits=1;p.heal();check("Medkit consumption",p.health==92 and p.medkits==0)
	game.pause();check("Pause releases mouse",get_tree().paused and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE);game.resume();await frames(2)
	if DisplayServer.get_name()!="headless":check("Resume captures mouse",not get_tree().paused and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED)
	else:checks.append({"test":"Graphical mouse capture","status":"NOT TESTED","detail":"Headless invocation"})
	game._notification(NOTIFICATION_APPLICATION_FOCUS_OUT);check("Focus-loss handler pauses safely",get_tree().paused and not p.focused);game.resume()
	var old=Services.settings.sensitivity;Services.settings.sensitivity=1.35;Services.write_json(Services.PREFS,Services.settings);check("Settings written",Services.read_json(Services.PREFS).sensitivity==1.35);Services.settings.sensitivity=old
	var event:=InputEventKey.new();event.physical_keycode=KEY_T;event.keycode=KEY_T;Services.rebind("reload",event);check("Key rebinding",Services.key_label("reload")=="T");Services.settings.bindings={};Services.install_bindings();Services.write_json(Services.PREFS,Services.settings)
	p.position=Vector3(0,0.04,-7);p.velocity=Vector3.ZERO;aim_at(Vector3(0,1.5,-22));game.checkpoint()
	check("Checkpoint serializes equipment and defeated actors",Services.valid_save()!=null and "qa_target" in Services.valid_save().dead)
	var saved=Services.valid_save();var f=FileAccess.open(Services.SAVE,FileAccess.WRITE);f.store_string("{not valid json");f.close();check("Corrupt save handled",Services.valid_save()==null);Services.write_json(Services.SAVE,saved)
	# Additional real rendered scene views use explicit QA positions, not fabricated art.
	game.stage=5;game.world.sync_gates(true);game.radio("Dispatch: Containment access lies through the east transfer corridor.",8)
	p.position=Vector3(0,0.04,-77);p.velocity=Vector3.ZERO;p.switch_weapon(1);aim_at(Vector3(-15,1.5,-84.4));await frames(25);await screenshot("04-laboratory")
	game.stage=7;game.world.sync_gates(true);game.radio("Isolate the three regulators and stop the containment elite.",8)
	p.position=Vector3(44,0.04,-136);p.velocity=Vector3.ZERO;aim_at(Vector3(55,2,-148));await frames(6);await screenshot("05-reactor")
	game.pause();game.ui.journal();await frames(6);await screenshot("06-journal-map")
	game.resume();game.stage=1;game.world.sync_gates(true);p.position=Vector3(0,0.04,-7);p.velocity=Vector3.ZERO;p.health=1;game.checkpoint();p.damage(500)
	check("Death and restart screen",game.ui.menu_name=="death");game.restart_checkpoint();await frames(3);check("Checkpoint restart",game.stage==1 and game.player.has_pistol and game.player.health>=75)
	finish()

func reload_test() -> void:
	check("Valid checkpoint after process restart",Services.valid_save()!=null)
	game.start_campaign(true);await frames(5)
	check("Process restart restores mission, equipment, defeated actors",game.stage==1 and game.player.has_pistol and "qa_target" in game.dead)
	check("Door lock restored",not game.world.doors.lab.open)
	finish()

func movement(dir:Vector3) -> void:
	for a in ["forward","back","left","right"]:Input.action_release(a)
	if dir.length()<0.05:return
	var local=game.player.basis.inverse()*dir.normalized()
	if local.z<0:Input.action_press("forward",-local.z)
	else:Input.action_press("back",local.z)
	if local.x<0:Input.action_press("left",-local.x)
	else:Input.action_press("right",local.x)

func _physics_process(delta:float) -> void:
	if finished or mode not in ["--qa-campaign","--qa-campaign-easy"]:return
	tick+=1;campaign_clock+=delta;path_clock-=delta
	if game.ui.menu_name=="ending":
		check("Whole campaign through actual movement, interactions and weapon rays",true,"Simulation seconds: "+str(snappedf(campaign_clock,0.1))+"; killed="+str(game.dead.size()));finish();return
	if not game.playing:
		check("Campaign bot survives",false,"Stopped stage "+str(game.stage)+" health "+str(game.player.health));finish();return
	if campaign_clock>1600:
		check("Campaign completion timeout",false,str(game.stage)+" "+str(game.player.position)+" target "+game.target_id());finish();return
	var p=game.player
	if game.stage!=last_stage:
		last_stage=game.stage;stage_start=campaign_clock;path_clock=0;print("BOT_STAGE ",last_stage," t=",campaign_clock," position=",p.position)
	if tick%600==0:print("BOT_PROGRESS stage=",game.stage," t=",campaign_clock," position=",p.position," health=",p.health," ammo=",p.mag," reserve=",p.reserve," target=",target_key)
	if p.health<55 and p.medkits>0:p.heal()
	var enemy=null;var nearest=24.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.alive:continue
		var d=p.position.distance_to(e.position)
		if d<nearest and e.can_see():nearest=d;enemy=e
	if enemy!=null and p.has_pistol:
		p.switch_weapon(1 if p.has_shotgun and nearest<9 and int(p.mag[1])+int(p.reserve[1])>0 else 0)
		aim_at(enemy.global_position+Vector3(0,1.35 if enemy.kind!="elite" else 2.0,0))
		Input.action_press("aim")
		p.fire()
		if p.mag[p.selected]==0:p.reload()
		var away=(p.position-enemy.position).normalized();away.y=0
		if nearest<6 and game.world.walkable(p.position+away*2):movement(away)
		else:movement(Vector3.ZERO)
		return
	Input.action_release("aim")
	if p.mag[p.selected]<3:p.reload()
	var id=game.target_id();var target=game.target_position()
	if game.stage==6:
		id="arena";target=Vector3(55,0,-80);var distance=1000.0
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.alive and e.eid.begins_with("wave_") and e.position.distance_to(p.position)<distance:target=e.position;distance=e.position.distance_to(p.position);id=e.eid
	# Collect nearby supplies through the same interaction ray as the player.
	for sid in game.world.items:
		if sid.begins_with("supply_") and is_instance_valid(game.world.items[sid]):
			var distance=p.position.distance_to(game.world.items[sid].position)
			if distance<5.5 or ((int(p.reserve[0])<25 or (p.has_shotgun and int(p.reserve[1])<12)) and distance<14):id=sid;target=game.world.items[sid].position;break
	if game.world.items.has(id) and p.camera.global_position.distance_to(target)<3.05:
		aim_at(target);p.update_interaction()
		if p.prompt_id==id:game.interact(id);path_clock=0;movement(Vector3.ZERO);return
	if id!=target_key or path_clock<=0:
		target_key=id;path=game.world.route(p.position,target)
		if not path.is_empty():path.remove_at(0)
		path_clock=1.0
	while not path.is_empty() and Vector2(p.position.x,p.position.z).distance_to(Vector2(path[0].x,path[0].z))<0.55:path.remove_at(0)
	if not path.is_empty():
		var dir=path[0]-p.position;dir.y=0;aim_at(p.camera.global_position+dir);movement(dir)
	else:
		var dir=target-p.position;dir.y=0
		if dir.length()>1.8:aim_at(target);movement(dir)
		else:movement(Vector3.ZERO)

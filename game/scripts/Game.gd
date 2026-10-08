extends Node3D

const Art=preload("res://scripts/Art.gd")
const Services=preload("res://scripts/Services.gd")
const World=preload("res://scripts/World.gd")
const Player=preload("res://scripts/Player.gd")
const UI=preload("res://scripts/UI.gd")
var world
var player
var ui
var env:WorldEnvironment
var music:AudioStreamPlayer
var hum:AudioStreamPlayer
var stage:=0
var difficulty:="Normal"
var collected:Array=[]
var dead:Array=[]
var playing:=false
var radio_text:=""
var radio_timer:=0.0
var toast_text:=""
var toast_timer:=0.0
var hit_timer:=0.0
var elapsed:=0.0
var wave:=0
var wave_timer:=0.0
var purge_elapsed:=0.0
var exit_timer:=-1.0
var last_log:="Find record tablets for the story behind the failure."
var qa_mode:=""
const RECORDS=[
	"01 / Dispatch: They called it a power fault. The last shift never checked out.",
	"02 / Engineering: Feeder A is beyond the west tunnel. Feeder B is in the east substation. Reset both before the generator.",
	"03 / Security: The access card is offline until auxiliary power returns. The laboratory lock is independent.",
	"04 / Research: They follow sound. Some wait for you to stop. Keep a wall between you and a stalker.",
	"05 / Containment: Purge cycles attract specimens. Clear three waves before the reactor door releases.",
	"06 / Last entry: Isolate all three regulators. Put the containment creature down. Do not look back."
]

func _ready() -> void:
	get_tree().auto_accept_quit=false
	Services.setup()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--qa-"):qa_mode=a
	if not qa_mode.is_empty():
		Services.settings.fullscreen=false;Services.settings.resolution=0;Services.settings.fps_cap=0;Services.settings.vsync=false;Services.apply_settings()
	ui=UI.new();add_child(ui);ui.setup(self)
	env=WorldEnvironment.new();var e:=Environment.new();e.background_mode=Environment.BG_COLOR;e.background_color=Color(0.028,0.047,0.056);e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color(0.39,0.51,0.60);e.ambient_light_energy=0.65;e.tonemap_mode=Environment.TONE_MAPPER_FILMIC;e.fog_enabled=true;e.fog_light_color=Color(0.045,0.066,0.078);e.fog_density=0.008;e.fog_sky_affect=0;env.environment=e;add_child(env)
	music=AudioStreamPlayer.new();music.bus="Music";music.stream=Services.stream("music");music.volume_db=-4;add_child(music);music.finished.connect(music.play);music.play()
	hum=AudioStreamPlayer.new();hum.bus="Effects";hum.stream=Services.stream("hum");hum.volume_db=-17;add_child(hum);hum.finished.connect(hum.play);hum.play()
	build_world(Vector3(0,0.1,9))
	ui.main_menu()
	print("BLACKOUT_READY 1.0.0 | ",OS.get_name()," | ",Engine.get_version_info().string)
	if not qa_mode.is_empty():call_deferred("start_qa")

func build_world(pos:Vector3) -> void:
	if is_instance_valid(world):remove_child(world);world.free()
	if is_instance_valid(player):remove_child(player);player.free()
	world=World.new();add_child(world);world.build(self)
	player=Player.new();add_child(player);player.setup(self);player.position=pos;player.camera.current=true
	apply_quality()

func apply_quality() -> void:
	var q=int(Services.settings.quality)
	get_viewport().msaa_3d=[Viewport.MSAA_DISABLED,Viewport.MSAA_2X,Viewport.MSAA_4X][q]
	if is_instance_valid(player):player.flashlight.shadow_enabled=q>0
	if is_instance_valid(env):env.environment.ambient_light_energy=0.65*float(Services.settings.gamma)

func start_campaign(continue_saved:bool) -> void:
	var data=Services.valid_save() if continue_saved else null
	if continue_saved and data==null:toast("Checkpoint unreadable. Start a new campaign.");ui.main_menu();return
	get_tree().paused=false;playing=false;wave=0;wave_timer=0;purge_elapsed=0;exit_timer=-1
	if data!=null:
		stage=int(data.stage);collected=data.collected.duplicate();dead=data.dead.duplicate();difficulty=str(data.difficulty);elapsed=float(data.get("elapsed",0))
		build_world(Vector3(float(data.position[0]),float(data.position[1]),float(data.position[2])))
		if not world.walkable(player.position):
			var c=world.nearest_cell(player.position);player.position=Vector3(c.x*2+1,0.05,c.y*2+1)
		player.restore(data.inventory);player.rotation.y=float(data.get("yaw",0));player.pitch=float(data.get("pitch",0))
	else:
		stage=0;collected=[];dead=[];elapsed=0;last_log="Find record tablets for the story behind the failure."
		build_world(Vector3(0,0.05,9))
		if difficulty=="Easy":player.medkits=4;player.reserve=[84,36]
	world.sync_gates(true);playing=true;ui.play_hud();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;player.input_delay=0.25
	if not continue_saved:checkpoint();radio("Dispatch: The distress beacon is inside. Get your pistol and light from the security desk.",11)
	else:radio("Checkpoint restored. "+objective(),7)
	print("CAMPAIGN_START stage=",stage," difficulty=",difficulty)

func checkpoint() -> bool:
	if not is_instance_valid(player) or stage>=9:return false
	# Every checkpoint guarantees a fair recovery budget without infinite combat pickups.
	if stage>0:
		player.health=maxf(player.health,75 if difficulty=="Normal" else 100)
		player.medkits=maxi(player.medkits,1)
		player.reserve[0]=maxi(int(player.reserve[0]),48)
		if player.has_shotgun:player.reserve[1]=maxi(int(player.reserve[1]),24)
	var data={"version":1,"stage":stage,"collected":collected.duplicate(),"dead":dead.duplicate(),"difficulty":difficulty,"position":[player.position.x,player.position.y,player.position.z],"yaw":player.rotation.y,"pitch":player.pitch,"inventory":player.inventory(),"elapsed":elapsed}
	var success=Services.write_json(Services.SAVE,data)
	toast("CHECKPOINT SAVED  /  recovery supplies secured" if success else "Save failed: check available disk space.")
	print("CHECKPOINT ",stage," ",success)
	return success

func change_stage(next:int,message:String) -> void:
	stage=next;world.sync_gates();radio(message,10)
	if next!=6 and next<9:checkpoint()
	print("MISSION_STAGE ",stage," ",objective())

func interact(id:String) -> void:
	if not playing or not world.items.has(id) or not is_instance_valid(world.items[id]):return
	if player.camera.global_position.distance_to(world.items[id].global_position)>3.9:return
	if id.begins_with("supply_"):
		if id in collected:return
		collected.append(id);world.collect(id)
		player.reserve[0]=mini(240,int(player.reserve[0])+(48 if difficulty=="Easy" else 36));player.reserve[1]=mini(90,int(player.reserve[1])+(18 if difficulty=="Easy" else 12));player.medkits=mini(9,player.medkits+(2 if difficulty=="Easy" else 1))
		toast("SUPPLIES  /  pistol ammo + shells + medkit");Services.sound(self,"pickup");return
	if id.begins_with("log_"):
		if not id in collected:collected.append(id)
		last_log=RECORDS[int(id.trim_prefix("log_"))];radio(last_log,16);world.collect(id);Services.sound(self,"terminal");return
	match id:
		"kit":
			if stage!=0:return
			collected.append(id);world.collect(id);player.has_pistol=true;player.flashlight.visible=true;player.sync_guns();Services.sound(self,"pickup")
			change_stage(1,"Dispatch: Reset feeder A beyond the west service tunnel and feeder B in the east substation, then start generator 04.")
		"feeder_a","feeder_b":
			if stage<1:toast("Collect your equipment first.");return
			if id in collected:toast("Feeder already online.");return
			collected.append(id);Services.sound(self,"terminal");toast("FEEDER ONLINE  /  "+str(feeder_count())+" OF 2")
			radio("Engineering: Feeder reset. "+("Generator 04 is ready to start." if feeder_count()==2 else "One feeder remains."),6)
		"generator":
			if stage!=1:toast("Auxiliary power is online." if stage>1 else "Collect your equipment first.");return
			if feeder_count()<2:toast("Reset BOTH feeders before starting generator 04.");return
			collected.append(id);Services.sound(self,"door",world.items[id].global_position,-1)
			change_stage(2,"Dispatch: Auxiliary power is stable. The security office is back online. Retrieve the laboratory keycard.")
		"keycard":
			if stage<2:toast("Card cradle offline. Restore auxiliary power.");return
			if stage!=2:return
			collected.append(id);world.collect(id);Services.sound(self,"pickup")
			change_stage(3,"Security access acquired. Use the terminal at the north laboratory gate.")
		"lab":
			if stage<3:toast("Laboratory authorization requires a security keycard.");return
			if stage==3:collected.append(id);change_stage(4,"Dispatch: Laboratory open. There is a pump shotgun on the southwest workbench. You will need it.")
		"shotgun":
			if stage!=4:return
			collected.append(id);world.collect(id);player.has_shotgun=true;player.switch_weapon(1);Services.sound(self,"pickup")
			change_stage(5,"Dispatch: Reach containment through the east transfer corridor. Start the purge at its control pedestal.")
		"lockdown":
			if stage<5:toast("Retrieve the shotgun before starting containment.");return
			if stage!=5:return
			# Clear hostiles behind the seal from mandatory wave accounting; they remain optional.
			wave=0;wave_timer=3;purge_elapsed=0;collected.append(id);checkpoint()
			change_stage(6,"Containment purge initiated. Transfer doors sealed. Survive three specimen waves; the reactor gate releases after the purge.")
			Services.sound(self,"alarm",null,-4)
		"regulator_a","regulator_b","regulator_c":
			if stage<7:toast("Containment must be purged first.");return
			if id in collected:toast("Regulator isolated.");return
			collected.append(id);Services.sound(self,"terminal");toast("REGULATOR ISOLATED  /  "+str(regulator_count())+" OF 3");check_reactor()
		"lift":
			if stage!=8:toast("The evacuation route opens after the reactor is stable.");return
			playing=true;stage=9;exit_timer=7;radio("Surface control: We have your signal. Lift inbound. Hold on.",7);Services.sound(self,"door",null,0)

func feeder_count() -> int:return int("feeder_a" in collected)+int("feeder_b" in collected)
func regulator_count() -> int:return int("regulator_a" in collected)+int("regulator_b" in collected)+int("regulator_c" in collected)
func log_count() -> int:
	var n:=0
	for id in collected:
		if str(id).begins_with("log_"):n+=1
	return n

func enemy_died(enemy) -> void:
	if not enemy.eid in dead:dead.append(enemy.eid)
	if enemy.eid=="elite":check_reactor()

func check_reactor() -> void:
	if stage==7 and regulator_count()==3 and "elite" in dead:
		change_stage(8,"Breach terminated. Evacuation gate unlocked on the east wall. Reach lift 13. This place is coming apart.")
		Services.sound(self,"alarm",null,-8)
	elif stage==7 and regulator_count()==3:radio("All regulators isolated. Stop the containment creature to secure the breach.",7)

func objective() -> String:
	match stage:
		0:return "01  /  Collect your pistol and flashlight"
		1:return "02  /  Restore auxiliary power  •  Feeders "+str(feeder_count())+"/2"
		2:return "03  /  Retrieve the security keycard"
		3:return "04  /  Unlock the laboratory"
		4:return "05  /  Acquire the pump shotgun"
		5:return "06  /  Start the containment purge"
		6:return "07  /  Survive containment lockdown"
		7:return "08  /  Stop the breach  •  Regulators "+str(regulator_count())+"/3"
		8:return "09  /  Escape through evacuation lift 13"
		_:return "10  /  Evacuating to the surface"

func objective_detail() -> String:
	return ["WASD to move, mouse to look. Pick up the equipment case on the security desk. Shift sprints; Ctrl crouches; Space jumps.","Reset feeder A in the west switchgear, beyond electrical stores and the service tunnel. Reset feeder B in substation 02, east of the north maintenance spine. Then start the generator in the northwest room.","Return along the maintenance spine. The security office is on its east side. The card is on the desk.","Continue north along the yellow floor stripe. Use the pedestal before the laboratory blast door.","Search the laboratory's southwest workbench. Use 1 and 2 to change weapons. R reloads; Q uses a medkit.","Leave the lab through the east corridor. Clear the holding room, stock up, then use the pedestal in the northeast corner.","Three waves are attracted by the purge. Watch for an attack wind-up, move aside, and fire during recovery. Collect green supply cases.","Isolate the three corner regulators and defeat the elite. Its raised arms telegraph a strike. Keep distance from its charge; circle the central core.","Follow the east gate into the escape corridor. Call the lift in the final room. The campaign ends once extraction completes.","Stay alive while the evacuation lift arrives."][clampi(stage,0,9)]

func target_id() -> String:
	match stage:
		0:return "kit"
		1:
			if not "feeder_a" in collected:return "feeder_a"
			if not "feeder_b" in collected:return "feeder_b"
			return "generator"
		2:return "keycard"
		3:return "lab"
		4:return "shotgun"
		5,6:return "lockdown"
		7:
			for id in ["regulator_a","regulator_b","regulator_c"]:
				if not id in collected:return id
			return "elite"
		_:return "lift"

func target_position() -> Vector3:
	var id=target_id()
	if world.items.has(id) and is_instance_valid(world.items[id]):return world.items[id].global_position
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.eid==id and e.alive:return e.global_position
	return Vector3(111,1.5,-158)

func mission_checklist() -> String:
	var lines=["Equipment secured","Auxiliary power online","Security keycard acquired","Laboratory unlocked","Shotgun acquired","Containment purged","Breach stopped","Evacuation"]
	var milestones=[1,2,3,4,5,7,8,9];var result:=""
	for i in range(lines.size()):result+=("[OK]  " if stage>=milestones[i] else "[  ]  ")+lines[i]+"\n"
	return result

func radio(words:String,seconds:=8.0) -> void:radio_text=words;radio_timer=seconds
func toast(words:String) -> void:toast_text=words;toast_timer=4

func noise(pos:Vector3,radius:float) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):e.hear(pos,radius)

func impact(pos:Vector3,normal:Vector3,organic:bool) -> void:
	var m=Art.ellipsoid(world,pos+normal*0.012,Vector3(0.10,0.10,0.10),Art.material("hit_organic" if organic else "hit_metal",Color(0.58,0.20,0.08) if organic else Color(1,0.69,0.23),0,0.5))
	var t=create_tween();t.tween_property(m,"scale",Vector3.ONE*0.01,0.17);t.tween_callback(m.queue_free)

func warning_ring(pos:Vector3,radius:float) -> void:
	var s:=TorusMesh.new();s.inner_radius=radius-0.07;s.outer_radius=radius;s.rings=32;s.ring_segments=6
	var m=Art.mesh(world,s,pos+Vector3(0,0.07,0),Art.material("attack_ring",Color(1,0.22,0.08),0,0.5),Vector3(1,0.03,1))
	var t=create_tween();t.tween_interval(1.2);t.tween_callback(m.queue_free)

func pause() -> void:
	if not playing:return
	get_tree().paused=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;ui.pause_menu()

func resume() -> void:
	if not playing:return
	ui.play_hud();get_tree().paused=false;player.focused=true;player.input_delay=0.25;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	Input.action_release("fire")

func die() -> void:
	playing=false;Services.sound(self,"death");get_tree().paused=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;ui.death_screen();print("PLAYER_DEATH stage=",stage)

func restart_checkpoint() -> void:start_campaign(true)

func return_to_menu() -> void:
	playing=false;get_tree().paused=false;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;ui.main_menu()

func _notification(what:int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:quit_game()
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(player):
		player.focused=false
		if playing and is_instance_valid(ui) and ui.menu_name=="":pause()

func _process(delta:float) -> void:
	if not playing:return
	elapsed+=delta;radio_timer=maxf(0,radio_timer-delta);toast_timer=maxf(0,toast_timer-delta);hit_timer=maxf(0,hit_timer-delta)
	if stage==6:
		purge_elapsed+=delta;wave_timer-=delta
		var remaining:=0
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.alive and e.eid.begins_with("wave_"):remaining+=1
		if remaining==0 and wave_timer<=0:
			if wave<3:
				wave+=1;wave_timer=9
				for i in range(4):
					var p=[Vector3(48,0,-66),Vector3(63,0,-95),Vector3(48,0,-93),Vector3(64,0,-73)][i]
					world.spawn_enemy("wave_"+str(wave)+"_"+str(i),"ambusher" if (i+wave)%3==0 else "stalker",p)
				radio("Purge cycle "+str(wave)+" of 3. Specimens detected.",6);Services.sound(self,"alarm",null,-11)
			elif purge_elapsed>=65:
				change_stage(7,"Purge complete. Reactor access released. Isolate the three regulators and stop the containment elite.")
	if exit_timer>=0:
		exit_timer-=delta
		if exit_timer<=0:playing=false;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;ui.ending();print("CAMPAIGN_END elapsed=",elapsed)

func start_qa() -> void:
	var path="res://scripts/QA.gd"
	if ResourceLoader.exists(path):
		var q=load(path).new();add_child(q);q.setup(self,qa_mode)

func _exit_tree() -> void:
	for audio in get_children():
		if audio is AudioStreamPlayer or audio is AudioStreamPlayer3D:
			audio.stop()
			audio.stream=null
	Art.mats.clear()
	Services.streams.clear()

func quit_game(code:=0) -> void:
	playing=false
	get_tree().paused=false
	for a in get_tree().get_nodes_in_group("audio_sources")+[music,hum]:
		if is_instance_valid(a):a.stop();a.stream=null
	Art.mats.clear();Services.streams.clear()
	await get_tree().process_frame
	OS.delay_msec(80)
	get_tree().quit(code)

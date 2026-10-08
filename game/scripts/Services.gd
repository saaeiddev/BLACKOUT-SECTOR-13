extends RefCounted
const SAVE:="user://checkpoint.json"
const PREFS:="user://settings.json"
const DEFAULTS={"sensitivity":1.0,"invert_y":false,"fov":82.0,"head_bob":true,"camera_shake":true,"subtitles":true,"gamma":1.05,"master":0.8,"music":0.40,"effects":0.85,"quality":1,"fullscreen":false,"resolution":0,"vsync":true,"fps_cap":120,"bindings":{}}
const KEYS={"forward":KEY_W,"back":KEY_S,"left":KEY_A,"right":KEY_D,"sprint":KEY_SHIFT,"crouch":KEY_CTRL,"jump":KEY_SPACE,"reload":KEY_R,"flashlight":KEY_F,"interact":KEY_E,"pistol":KEY_1,"shotgun":KEY_2,"heal":KEY_Q,"journal":KEY_TAB}
static var settings:Dictionary=DEFAULTS.duplicate(true)
static var streams:Dictionary={}
static func setup() -> void:
	for name in ["Music","Effects"]:
		if AudioServer.get_bus_index(name)<0:AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,name)
	var saved=read_json(PREFS)
	if saved is Dictionary:
		for k in DEFAULTS:
			if saved.has(k) and (typeof(saved[k])==typeof(DEFAULTS[k]) or (saved[k] is float and DEFAULTS[k] is int)):settings[k]=saved[k]
	settings.sensitivity=clampf(float(settings.sensitivity),0.2,3);settings.fov=clampf(float(settings.fov),65,110);settings.gamma=clampf(float(settings.gamma),0.6,1.8)
	settings.quality=clampi(int(settings.quality),0,2);settings.resolution=clampi(int(settings.resolution),0,2)
	for k in ["master","music","effects"]:settings[k]=clampf(float(settings[k]),0,1)
	install_bindings();apply_settings()
static func install_bindings() -> void:
	for action in KEYS.keys()+["fire","aim","pause"]:
		if not InputMap.has_action(action):InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var e:InputEvent;var binding=settings.bindings.get(action,{})
		if action=="pause":binding={"key":KEY_ESCAPE}
		if binding is Dictionary and binding.has("mouse"):e=InputEventMouseButton.new();e.button_index=clampi(int(binding.mouse),1,9)
		elif binding is Dictionary and binding.has("key"):e=InputEventKey.new();e.physical_keycode=int(binding.key)
		elif action in ["fire","aim"]:e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT if action=="fire" else MOUSE_BUTTON_RIGHT
		else:e=InputEventKey.new();e.physical_keycode=KEYS[action]
		InputMap.action_add_event(action,e)
static func key_label(action:String) -> String:
	var events=InputMap.action_get_events(action)
	if events.is_empty():return "?"
	if events[0] is InputEventMouseButton:return "Mouse "+str(events[0].button_index)
	return OS.get_keycode_string(events[0].physical_keycode)
static func rebind(action:String,event:InputEvent) -> void:
	var binding:Dictionary={"mouse":event.button_index} if event is InputEventMouseButton else {"key":event.physical_keycode}
	var e=InputMap.action_get_events(action)[0];var old:Dictionary={"mouse":e.button_index} if e is InputEventMouseButton else {"key":e.physical_keycode}
	for other in KEYS.keys()+["fire","aim"]:
		if other!=action and InputMap.event_is_action(event,other):settings.bindings[other]=old
	settings.bindings[action]=binding;install_bindings();write_json(PREFS,settings)
static func apply_settings() -> void:
	for pair in [["Master","master"],["Music","music"],["Effects","effects"]]:AudioServer.set_bus_volume_db(AudioServer.get_bus_index(pair[0]),linear_to_db(maxf(float(settings[pair[1]]),0.0001)))
	Engine.max_fps=clampi(int(settings.fps_cap),30,240) if int(settings.fps_cap)>0 else 0
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings.vsync else DisplayServer.VSYNC_DISABLED)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		if not settings.fullscreen:DisplayServer.window_set_size([Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)][int(settings.resolution)])
static func read_json(path:String):
	if not FileAccess.file_exists(path):return null
	var f=FileAccess.open(path,FileAccess.READ)
	if f==null:return null
	var parser:=JSON.new()
	if parser.parse(f.get_as_text())!=OK:return null
	return parser.data
static func write_json(path:String,data:Dictionary) -> bool:
	var f=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if f==null:return false
	f.store_string(JSON.stringify(data,"\t"));f.flush();f.close()
	if FileAccess.file_exists(path):DirAccess.copy_absolute(path,path+".previous");DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(path+".tmp",path)==OK
static func valid_save():
	var d=read_json(SAVE)
	if not d is Dictionary:return null
	if not d.has_all(["version","stage","collected","dead","position","inventory","difficulty"]):return null
	if d.version!=1 or not (d.stage is float or d.stage is int) or int(d.stage)<0 or int(d.stage)>8:return null
	if not d.position is Array or d.position.size()!=3:return null
	for n in d.position:
		if not (n is float or n is int) or not is_finite(float(n)) or absf(float(n))>1000:return null
	if not d.collected is Array or not d.dead is Array or not d.inventory is Dictionary:return null
	if not d.inventory.has_all(["health","medkits","mag","reserve","has_pistol","has_shotgun"]):return null
	if not d.inventory.mag is Array or not d.inventory.reserve is Array:return null
	if d.inventory.mag.size()!=2 or d.inventory.reserve.size()!=2:return null
	if not d.inventory.has_pistol is bool or not d.inventory.has_shotgun is bool:return null
	if d.difficulty not in ["Normal","Easy"]:return null
	if int(d.stage)>=1 and not d.inventory.has_pistol:return null
	if int(d.stage)>=5 and not d.inventory.has_shotgun:return null
	for id in d.collected+d.dead:
		if not id is String or id.length()>80:return null
	for key in ["yaw","pitch","elapsed"]:
		if d.has(key) and (not (d[key] is float or d[key] is int) or not is_finite(float(d[key]))):return null
	for n in d.inventory.mag+d.inventory.reserve+[d.inventory.health,d.inventory.medkits]:
		if not (n is float or n is int) or not is_finite(float(n)) or float(n)<0 or float(n)>9999:return null
	return d
static func stream(name:String) -> AudioStream:
	if not streams.has(name):streams[name]=load("res://assets/audio/"+name+".wav")
	return streams[name]
static func sound(parent:Node,name:String,pos=null,db:=-4.0,pitch:=1.0):
	var p:Node
	if pos==null:p=AudioStreamPlayer.new()
	else:p=AudioStreamPlayer3D.new();p.max_distance=32;p.unit_size=5
	p.stream=stream(name);p.bus="Effects";p.volume_db=db;p.pitch_scale=pitch;parent.add_child(p)
	p.add_to_group("audio_sources")
	if pos!=null:p.global_position=pos
	p.finished.connect(p.queue_free);p.play();return p

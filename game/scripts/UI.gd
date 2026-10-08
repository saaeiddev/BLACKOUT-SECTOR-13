extends CanvasLayer

const Audio=preload("res://scripts/Services.gd")
var game
var root:Control
var hud:Control
var menu:Control
var health_label:Label
var ammo_label:Label
var objective_label:Label
var region_label:Label
var prompt_label:Label
var radio_label:Label
var toast_label:Label
var hint_label:Label
var boss_label:Label
var rebinding:=""
var rebind_button:Button
var settings_return:="main"
var menu_name:=""
var accent:=Color(0.95,0.56,0.24)

class Reticle extends Control:
	var game
	func _process(_d):queue_redraw()
	func _draw():
		if not is_instance_valid(game.player) or not game.playing:return
		var p=game.player;var center=size/2
		var color=Color(0.86,0.94,0.93,0.85)
		if not p.prompt_id.is_empty():color=Color(0.35,1,0.75)
		var gap=4 if p.aiming else 9
		for v in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:draw_line(center+v*gap,center+v*(gap+5),color,1.2,true)
		if game.hit_timer>0:
			for v in [Vector2(1,1),Vector2(-1,1),Vector2(1,-1),Vector2(-1,-1)]:draw_line(center+v*6,center+v*10,Color(1,0.57,0.29),2,true)
		if p.hurt_timer>0:
			draw_rect(Rect2(Vector2.ZERO,size),Color(0.62,0.05,0.02,p.hurt_timer*0.16),true)
		# Corner frame and restrained status rails.
		for pair in [[Vector2(28,28),Vector2(60,28)],[Vector2(28,28),Vector2(28,48)],[Vector2(size.x-28,28),Vector2(size.x-60,28)]]:draw_line(pair[0],pair[1],Color(0.5,0.73,0.74,0.6),1)
		draw_rect(Rect2(32,size.y-41,190,4),Color(0.1,0.14,0.16))
		draw_rect(Rect2(32,size.y-41,190*p.health/100,4),Color(0.93,0.40,0.25) if p.health<30 else Color(0.5,0.84,0.73))
		draw_rect(Rect2(32,size.y-29,190*p.stamina/100,2),Color(0.67,0.72,0.75,0.6))

class FacilityMap extends Control:
	var game
	func _draw():
		if not is_instance_valid(game.world):return
		var scale_v=1.75;var offset=Vector2(295,384)
		for r in game.world.layout:
			var rect=Rect2(r.position*scale_v+offset,r.size*scale_v)
			draw_rect(rect,Color(0.07,0.15,0.18),true);draw_rect(rect,Color(0.20,0.39,0.42),false,1)
		for id in game.world.doors:
			var d=game.world.doors[id];var r:Rect2=d.rect
			draw_rect(Rect2(r.position*scale_v+offset,r.size*scale_v),Color(0.2,0.8,0.53) if d.open else Color(0.94,0.37,0.23),true)
		var p=game.player.position
		var loc=Vector2(p.x,p.z)*scale_v+offset
		draw_circle(loc,4,Color(0.9,0.97,0.94))
		draw_line(loc,loc+Vector2(-sin(game.player.rotation.y),-cos(game.player.rotation.y))*13,Color.WHITE,2)
		var t=game.target_position();var target=Vector2(t.x,t.z)*scale_v+offset
		draw_circle(target,7,Color(1,0.55,0.18),false,2)

func setup(g) -> void:
	game=g;process_mode=Node.PROCESS_MODE_ALWAYS
	root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(root)
	var theme:=Theme.new();theme.default_font_size=18
	for type in ["Button","OptionButton"]:
		for state in ["normal","hover","pressed","focus","disabled"]:
			var style:=StyleBoxFlat.new();style.bg_color=Color(0.10,0.17,0.20,0.94) if state=="normal" else Color(0.19,0.29,0.31)
			if state=="disabled":style.bg_color=Color(0.06,0.08,0.10,0.6)
			style.border_width_left=3;style.border_color=accent if state!="disabled" else Color(0.24,0.27,0.27)
			style.content_margin_left=18;style.content_margin_right=18;style.content_margin_top=10;style.content_margin_bottom=10
			theme.set_stylebox(state,type,style)
	root.theme=theme
	hud=Control.new();root.add_child(hud);hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var reticle:=Reticle.new();reticle.game=game;hud.add_child(reticle);reticle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);reticle.mouse_filter=Control.MOUSE_FILTER_IGNORE
	region_label=label(hud,"",Vector2(40,40),Vector2(550,30),14,Color(0.56,0.75,0.77))
	objective_label=label(hud,"",Vector2(40,72),Vector2(790,70),21)
	hint_label=label(hud,"",Vector2(40,136),Vector2(950,35),14,Color(0.67,0.75,0.76))
	health_label=label(hud,"",Vector2(32,630),Vector2(450,43),25)
	ammo_label=label(hud,"",Vector2(935,614),Vector2(310,65),24);ammo_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	prompt_label=label(hud,"",Vector2(310,465),Vector2(660,70),21,Color(0.66,1,0.83));prompt_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	radio_label=label(hud,"",Vector2(270,551),Vector2(740,62),18);radio_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	toast_label=label(hud,"",Vector2(760,40),Vector2(475,55),16,accent);toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	boss_label=label(hud,"",Vector2(840,127),Vector2(395,40),19,accent);boss_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	hud.visible=false

func label(parent:Node,words:String,pos:Vector2,size_v:Vector2,font_size:=18,color:=Color(0.87,0.92,0.90)) -> Label:
	var l:=Label.new();l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.text=words;l.add_theme_font_size_override("font_size",font_size);l.add_theme_color_override("font_color",color);l.add_theme_color_override("font_shadow_color",Color(0,0,0,0.8));l.add_theme_constant_override("shadow_offset_x",1);l.add_theme_constant_override("shadow_offset_y",2);l.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(l);l.position=pos;l.size=size_v;return l

func clear_menu() -> void:
	if is_instance_valid(menu):menu.queue_free()
	menu=Control.new();root.add_child(menu);menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg:=ColorRect.new();bg.color=Color(0.012,0.025,0.035,0.80);menu.add_child(bg);bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func button(parent:Node,words:String,pos:Vector2,size_v:Vector2,callback:Callable) -> Button:
	var b:=Button.new();b.text=words;b.position=pos;b.size=size_v;b.alignment=HORIZONTAL_ALIGNMENT_LEFT;parent.add_child(b);b.pressed.connect(callback);return b

func main_menu() -> void:
	menu_name="main";clear_menu();hud.visible=false
	label(menu,"FACILITY 13  /  EMERGENCY CHANNEL  /  03:17",Vector2(70,67),Vector2(700,30),14,accent)
	label(menu,"BLACKOUT",Vector2(65,109),Vector2(920,85),82)
	label(menu,"S E C T O R   1 3",Vector2(73,205),Vector2(650,45),28,accent)
	label(menu,"The signal is still transmitting.\nSomeone has to turn it off.",Vector2(75,269),Vector2(640,70),21)
	button(menu,"NEW GAME",Vector2(75,370),Vector2(345,45),choose_difficulty)
	var cont=button(menu,"CONTINUE",Vector2(75,423),Vector2(345,45),func():game.start_campaign(true))
	cont.disabled=Audio.valid_save()==null
	button(menu,"SETTINGS",Vector2(75,476),Vector2(345,45),func():settings_menu("main"))
	button(menu,"CREDITS",Vector2(75,529),Vector2(345,45),credits)
	button(menu,"QUIT",Vector2(75,582),Vector2(345,45),func():game.quit_game())
	label(menu,"Created by Amir Saeid Dehghan",Vector2(75,668),Vector2(700,25),15)
	label(menu,"NATIVE / OFFLINE\nCAMPAIGN 01\n\n01  RESPOND\n02  RESTORE\n03  CONTAIN\n04  ESCAPE",Vector2(941,399),Vector2(260,230),18,Color(0.45,0.64,0.66))
	label(menu,"1.0.0   •   Windows x64",Vector2(980,670),Vector2(240,25),13,Color(0.5,0.6,0.63))
	if FileAccess.file_exists(Audio.SAVE) and Audio.valid_save()==null:label(menu,"Checkpoint unreadable. New Game is available.",Vector2(454,422),Vector2(420,60),16,accent)

func choose_difficulty() -> void:
	menu_name="new";clear_menu()
	label(menu,"ENTER SECTOR 13",Vector2(260,120),Vector2(850,70),42)
	label(menu,"You are the maintenance specialist dispatched after the last distress call.\nReach the security desk. Find your equipment. Restore the facility.",Vector2(260,212),Vector2(770,95),22)
	button(menu,"NORMAL  /  Intended tension and combat",Vector2(260,338),Vector2(755,60),func():confirm_new("Normal"))
	button(menu,"EASY  /  Less damage, more supplies",Vector2(260,416),Vector2(755,60),func():confirm_new("Easy"))
	button(menu,"BACK",Vector2(260,530),Vector2(240,48),main_menu)

func confirm_new(difficulty:String) -> void:
	if Audio.valid_save()==null:game.difficulty=difficulty;game.start_campaign(false);return
	menu_name="overwrite";clear_menu()
	label(menu,"REPLACE EXISTING CHECKPOINT?",Vector2(240,225),Vector2(850,70),36)
	label(menu,"Starting a new campaign replaces your saved campaign progress.",Vector2(240,310),Vector2(850,60),22)
	button(menu,"START NEW CAMPAIGN",Vector2(240,410),Vector2(390,52),func():game.difficulty=difficulty;game.start_campaign(false))
	button(menu,"CANCEL",Vector2(660,410),Vector2(250,52),choose_difficulty)

func play_hud() -> void:
	if is_instance_valid(menu):menu.queue_free()
	menu_name="";hud.visible=true

func pause_menu() -> void:
	menu_name="pause";clear_menu();hud.visible=false
	label(menu,"TRANSMISSION PAUSED",Vector2(75,90),Vector2(900,75),46)
	label(menu,"Progress saves at mission checkpoints.\nCurrent objective: "+game.objective(),Vector2(78,194),Vector2(1000,90),22)
	button(menu,"RESUME",Vector2(78,320),Vector2(400,48),game.resume)
	button(menu,"RESTART CHECKPOINT",Vector2(78,378),Vector2(400,48),game.restart_checkpoint)
	button(menu,"SETTINGS",Vector2(78,436),Vector2(400,48),func():settings_menu("pause"))
	button(menu,"JOURNAL & FACILITY MAP",Vector2(78,494),Vector2(400,48),journal)
	button(menu,"MAIN MENU",Vector2(78,552),Vector2(400,48),game.return_to_menu)
	button(menu,"QUIT",Vector2(78,610),Vector2(400,48),func():game.quit_game())

func death_screen() -> void:
	menu_name="death";clear_menu();hud.visible=false
	label(menu,"SIGNAL LOST",Vector2(330,207),Vector2(800,90),64,accent)
	label(menu,"Your last checkpoint is ready.\nKeep moving during telegraphed attacks. Use cover and listen.",Vector2(330,312),Vector2(650,90),21)
	button(menu,"RESTART CHECKPOINT",Vector2(330,445),Vector2(530,55),game.restart_checkpoint)
	button(menu,"MAIN MENU",Vector2(330,514),Vector2(530,50),game.return_to_menu)

func ending() -> void:
	menu_name="ending";clear_menu();hud.visible=false
	label(menu,"06:42  /  SURFACE LEVEL",Vector2(170,105),Vector2(900,30),17,accent)
	label(menu,"DAWN, AT LAST.",Vector2(165,172),Vector2(1050,90),62)
	label(menu,"The breach is sealed. The facility is silent.\nYou made it out of Sector 13.\n\nThe transmission finally stops.",Vector2(173,292),Vector2(860,160),25)
	label(menu,"CAMPAIGN COMPLETE  •  "+str(game.dead.size())+" hostiles stopped  •  "+str(game.log_count())+" / 6 field records",Vector2(173,477),Vector2(1000,40),18,accent)
	label(menu,"Created by Amir Saeid Dehghan",Vector2(173,535),Vector2(900,45),23)
	button(menu,"CREDITS",Vector2(173,612),Vector2(270,48),credits)
	button(menu,"MAIN MENU",Vector2(463,612),Vector2(300,48),game.return_to_menu)
	button(menu,"QUIT",Vector2(783,612),Vector2(230,48),func():game.quit_game())

func credits() -> void:
	menu_name="credits";clear_menu()
	label(menu,"BLACKOUT: SECTOR 13",Vector2(165,95),Vector2(1000,80),46)
	label(menu,"Created by Amir Saeid Dehghan\n\nOriginal environment, creature rigs, weapons and procedural textures.\nOriginal synthesized ambience, music and sound effects.\nAI-assisted development and technical production.\n\nEngine: Godot 4.5.1 (MIT). Installer: NSIS 3.09.\nFull engine and third-party license notices accompany the game.\n\nNo recorded voice acting: narrative is delivered as subtitled radio text.",Vector2(170,205),Vector2(980,350),21)
	button(menu,"BACK TO MAIN MENU",Vector2(170,613),Vector2(420,52),game.return_to_menu)

func journal() -> void:
	menu_name="journal";clear_menu();hud.visible=false
	label(menu,"FIELD JOURNAL",Vector2(55,48),Vector2(620,70),36)
	label(menu,game.objective(),Vector2(58,129),Vector2(550,70),22)
	label(menu,game.objective_detail(),Vector2(58,214),Vector2(550,138),17)
	label(menu,"MISSION STATUS\n"+game.mission_checklist(),Vector2(58,365),Vector2(550,202),16)
	label(menu,"FIELD RECORDS: "+str(game.log_count())+" / 6\n"+game.last_log,Vector2(58,605),Vector2(560,82),14,Color(0.64,0.76,0.76))
	var map:=FacilityMap.new();map.game=game;menu.add_child(map);map.position=Vector2(638,58);map.size=Vector2(560,550)
	label(menu,"FACILITY PLAN  /  WHITE: YOU  /  ORANGE: OBJECTIVE\nRed gates are locked. Green gates are open.",Vector2(657,579),Vector2(570,55),14,accent)
	button(menu,"RESUME",Vector2(925,641),Vector2(290,45),game.resume)

func settings_menu(origin:String) -> void:
	settings_return=origin;menu_name="settings";clear_menu();hud.visible=false
	label(menu,"SYSTEM SETTINGS",Vector2(100,37),Vector2(1000,62),36)
	var tabs:=TabContainer.new();menu.add_child(tabs);tabs.position=Vector2(100,115);tabs.size=Vector2(1080,490)
	var columns:Dictionary={}
	for name in ["Gameplay","Display","Audio","Controls"]:
		var scroll:=ScrollContainer.new();scroll.name=name;tabs.add_child(scroll)
		var v:=VBoxContainer.new();v.size_flags_horizontal=Control.SIZE_EXPAND_FILL;v.add_theme_constant_override("separation",12);scroll.add_child(v);columns[name]=v
	slider(columns.Gameplay,"Mouse sensitivity","sensitivity",0.2,3,0.05)
	slider(columns.Gameplay,"Field of view","fov",65,110,1)
	slider(columns.Gameplay,"Brightness / gamma","gamma",0.6,1.8,0.05)
	checkbox(columns.Gameplay,"Invert mouse Y","invert_y")
	checkbox(columns.Gameplay,"Head bob","head_bob")
	checkbox(columns.Gameplay,"Camera shake","camera_shake")
	checkbox(columns.Gameplay,"Radio subtitles","subtitles")
	var note:=Label.new();note.text="Motion blur: OFF (never applied).";columns.Gameplay.add_child(note)
	options(columns.Display,"Quality","quality",["Low","Medium","High"],[0,1,2])
	options(columns.Display,"Window resolution","resolution",["1280 × 720","1600 × 900","1920 × 1080"],[0,1,2])
	checkbox(columns.Display,"Fullscreen","fullscreen")
	checkbox(columns.Display,"VSync","vsync")
	options(columns.Display,"Frame cap","fps_cap",["30","60","120","144","Unlimited"],[30,60,120,144,0])
	for pair in [["Master","master"],["Music","music"],["Effects","effects"]]:slider(columns.Audio,pair[0],pair[1],0,1,0.05)
	for action in Audio.KEYS.keys()+["fire","aim"]:
		var row:=HBoxContainer.new();columns.Controls.add_child(row)
		var l:=Label.new();l.text=action.capitalize();l.custom_minimum_size=Vector2(340,42);row.add_child(l)
		var b:=Button.new();b.text=Audio.key_label(action);b.custom_minimum_size=Vector2(540,42);row.add_child(b)
		b.pressed.connect(func():rebinding=action;rebind_button=b;b.text="Press a key or mouse button — Esc cancels")
	var reset:=Button.new();reset.text="Restore default bindings";columns.Controls.add_child(reset);reset.pressed.connect(func():Audio.settings.bindings={};Audio.install_bindings();settings_menu(settings_return))
	label(menu,"Settings are stored for your Windows user. Changes apply when you press Save.",Vector2(100,619),Vector2(1000,30),15,Color(0.6,0.74,0.74))
	button(menu,"SAVE & BACK",Vector2(895,662),Vector2(285,43),func():Audio.write_json(Audio.PREFS,Audio.settings);Audio.apply_settings();game.apply_quality();pause_menu() if settings_return=="pause" else main_menu())

func row_for(parent:Node,title:String) -> HBoxContainer:
	var row:=HBoxContainer.new();parent.add_child(row)
	var l:=Label.new();l.text=title;l.custom_minimum_size=Vector2(340,42);row.add_child(l);return row

func slider(parent:Node,title:String,key:String,min_v:float,max_v:float,step:float) -> void:
	var row=row_for(parent,title);var s:=HSlider.new();s.min_value=min_v;s.max_value=max_v;s.step=step;s.value=float(Audio.settings[key]);s.custom_minimum_size=Vector2(460,42);row.add_child(s)
	var value:=Label.new();value.text=str(snappedf(s.value,0.01));value.custom_minimum_size=Vector2(80,40);row.add_child(value)
	s.value_changed.connect(func(v):Audio.settings[key]=v;value.text=str(snappedf(v,0.01)))

func checkbox(parent:Node,title:String,key:String) -> void:
	var b:=CheckButton.new();b.text=title;b.button_pressed=Audio.settings[key];b.custom_minimum_size.y=42;parent.add_child(b);b.toggled.connect(func(v):Audio.settings[key]=v)

func options(parent:Node,title:String,key:String,labels:Array,values:Array) -> void:
	var row=row_for(parent,title);var b:=OptionButton.new();row.add_child(b);b.custom_minimum_size=Vector2(540,42)
	for name in labels:b.add_item(name)
	b.select(maxi(0,values.find(Audio.settings[key])));b.item_selected.connect(func(i):Audio.settings[key]=values[i])

func _input(event:InputEvent) -> void:
	if not rebinding.is_empty():
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
			rebind_button.text=Audio.key_label(rebinding);rebinding="";get_viewport().set_input_as_handled();return
		if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed):
			Audio.rebind(rebinding,event);rebinding="";settings_menu(settings_return);get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if menu_name=="settings":Audio.write_json(Audio.PREFS,Audio.settings);Audio.apply_settings();game.apply_quality();pause_menu() if settings_return=="pause" else main_menu()
		elif menu_name in ["pause","journal"]:game.resume()
		elif game.playing:game.pause()
		elif menu_name in ["credits","new","overwrite"]:game.return_to_menu()
	if event.is_action_pressed("journal") and game.playing:
		get_viewport().set_input_as_handled()
		if menu_name=="journal":game.resume()
		elif menu_name=="":game.pause();journal()

func _process(_delta:float) -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.player) or not hud.visible:return
	var p=game.player
	region_label.text=game.world.region_at(p.position)+"    /    "+game.difficulty.to_upper()
	objective_label.text=game.objective()
	var dist=p.position.distance_to(game.target_position())
	hint_label.text="OBJECTIVE  "+str(int(dist))+" m   •   "+Audio.key_label("journal")+" journal / map   •   "+Audio.key_label("flashlight")+" light   •   ESC pause"
	health_label.text="%03d  VITALS      %d  MEDKITS" % [ceili(p.health),p.medkits]
	ammo_label.text=("PISTOL" if p.selected==0 else "PUMP SHOTGUN")+"\n%02d / %03d" % [p.mag[p.selected],p.reserve[p.selected]] if p.has_pistol else "UNARMED\nFIND YOUR EQUIPMENT"
	if p.reload_timer>0:ammo_label.text="RELOADING\n"+ammo_label.text
	prompt_label.text=("["+Audio.key_label("interact")+"]  "+p.prompt_text) if not p.prompt_id.is_empty() else ""
	radio_label.text=("RADIO  /  "+game.radio_text) if game.radio_timer>0 and Audio.settings.subtitles else ""
	toast_label.text=game.toast_text if game.toast_timer>0 else ""
	boss_label.text=""
	if game.stage==6:boss_label.text="PURGE  /  WAVE "+str(game.wave)+" OF 3"
	if game.stage==7:
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.kind=="elite" and e.alive and e.position.distance_to(p.position)<35:boss_label.text="CONTAINMENT ELITE  /  "+str(ceili(e.health))+" HP"

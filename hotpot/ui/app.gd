extends Node
var saves=preload("res://systems/save_store.gd").new()
var settings=preload("res://systems/settings_store.gd").new()
var game: Node2D
var overlay: Control
var content: VBoxContainer
var screen_name="title"
var selected_slot=0
var title_message=""
var pending_exit=false
var pending_new_slot=0
var ui_theme: Theme

func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit=false
	settings.load_settings();settings.apply()
	ui_theme=Theme.new();ui_theme.default_font=preload("res://assets/font.otf");ui_theme.default_font_size=18
	var style=StyleBoxFlat.new();style.bg_color=Color("354a57")
	style.content_margin_left=18;style.content_margin_right=18;style.content_margin_top=12;style.content_margin_bottom=12
	style.set_corner_radius_all(8)
	ui_theme.set_stylebox("normal","Button",style)
	var hover=style.duplicate();hover.bg_color=Color("4a706f")
	ui_theme.set_stylebox("hover","Button",hover);ui_theme.set_stylebox("pressed","Button",hover)
	var disabled=style.duplicate();disabled.bg_color=Color("29343f")
	ui_theme.set_stylebox("disabled","Button",disabled)
	var layer=CanvasLayer.new();layer.layer=20;add_child(layer)
	overlay=Control.new();overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.theme=ui_theme;layer.add_child(overlay)
	var bg=ColorRect.new();bg.color=Color(0.065,0.10,0.14,0.97);bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.add_child(bg)
	var accent=ColorRect.new();accent.color=Color("d1ae73");accent.position=Vector2(70,80);accent.size=Vector2(6,630);overlay.add_child(accent)
	var scroll=ScrollContainer.new();scroll.position=Vector2(105,60);scroll.size=Vector2(1070,680);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;overlay.add_child(scroll)
	content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",18);scroll.add_child(content)
	show_title()

func text(value: String, size: int=18) -> Label:
	var label=Label.new();label.text=value;label.add_theme_font_size_override("font_size",size);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	content.add_child(label);return label

func button(value: String, action: Callable, parent: Node=null, enabled: bool=true) -> Button:
	var b=Button.new();b.text=value;b.disabled=not enabled;b.pressed.connect(action)
	(parent if parent!=null else content).add_child(b)
	return b

func begin_screen(name: String, heading: String, caption: String=""):
	screen_name=name;overlay.show()
	for node in content.get_children(): content.remove_child(node);node.queue_free()
	text(heading,36)
	if not caption.is_empty(): text(caption,17).modulate=Color("b4c9ca")

func show_title():
	get_tree().paused=false
	begin_screen("title","星灯回转锅","白天筹备，夜晚营业。经营属于你的异世界小店。")
	if not title_message.is_empty(): text(title_message).modulate=Color("e5c58e")
	for slot in range(1,4):
		var info=saves.info(slot)
		var row=HBoxContainer.new();row.add_theme_constant_override("separation",12);content.add_child(row)
		var label=Label.new();label.custom_minimum_size=Vector2(570,0);label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		if info.ok:
			label.text="存档 %d  /  第%d天 · %s · %d金%s"%[slot,int(info.data.day),info.data.get("phase","准备"),int(info.data.money),"  [可恢复备份]" if info.recovered else ""]
		elif info.exists: label.text="存档 %d  /  %s"%[slot,info.error]
		else: label.text="存档 %d  /  空位"%slot
		label.add_theme_font_size_override("font_size",18);row.add_child(label)
		button("继续",func(): start_game(slot,false),row,info.ok)
		button("新游戏",func(): request_new(slot),row)
	var legacy=saves.read(saves.LEGACY)
	if legacy.ok:
		button("导入旧版进度到空位",import_old)
	text("每个存档位独立经营。开门前、打烊后自动保存；营业中退出会回到开门前。",16)
	var row=HBoxContainer.new();row.add_theme_constant_override("separation",12);content.add_child(row)
	button("设置",show_settings,row)
	button("退出游戏",func(): get_tree().quit(),row)

func request_new(slot: int):
	if not saves.info(slot).exists: start_game(slot,true);return
	pending_new_slot=slot
	begin_screen("new_confirm","开始新的经营？","存档%d已有进度。新游戏将替换此存档位；另外两个存档位不受影响。"%slot)
	button("返回，保留原进度",show_title)
	button("确认新游戏",func(): start_game(pending_new_slot,true))

func start_game(slot: int, fresh: bool):
	var path=saves.slot_path(slot)
	if path.is_empty(): return
	var info=saves.info(slot)
	if not fresh and not info.ok:
		title_message="无法继续："+info.error;show_title();return
	if is_instance_valid(game): remove_child(game);game.queue_free();game=null
	game=preload("res://main.tscn").instantiate()
	game.save_path=path;game.auto_load=false;game.process_mode=Node.PROCESS_MODE_PAUSABLE
	add_child(game)
	if not fresh:
		game.apply_save(info.data)
		if info.recovered: game.notify("主存档异常，已恢复上次有效备份。下次保存会保留损坏文件。")
	else:
		if not game.save_game():
			title_message="新游戏未保存："+game.save_error;remove_child(game);game.queue_free();game=null;show_title();return
	selected_slot=slot
	game.pause_requested.connect(pause_game)
	resume_game()

func import_old():
	for slot in range(1,4):
		if not saves.info(slot).exists:
			var result=saves.import_legacy(slot)
			title_message="旧版进度已导入存档%d，原文件保留。"%slot if result.ok else result.error
			show_title();return
	title_message="三个存档位都有进度；请先选择一个存档继续，避免覆盖。";show_title()

func pause_game():
	if not is_instance_valid(game): return
	get_tree().paused=true
	begin_screen("pause","暂停营业","存档%d · 第%d天 · %s"%[selected_slot,game.day,game.phase])
	button("继续游戏",resume_game)
	button("保存进度",save_current,null,game.phase!="营业")
	if game.phase=="营业": text("本晚进度暂不保存。返回主菜单或退出后，从开门前重新营业。",16)
	button("设置",show_settings)
	button("返回主菜单",func(): request_leave(false))
	button("退出游戏",func(): request_leave(true))

func resume_game():
	screen_name="game";overlay.hide();get_tree().paused=false

func save_current():
	if not is_instance_valid(game): return
	var ok=game.save_game()
	pause_game()
	text("已保存进度。" if ok else "保存失败："+game.save_error).modulate=Color("e5c58e")

func request_leave(exit_app: bool):
	pending_exit=exit_app
	if not is_instance_valid(game): get_tree().quit();return
	get_tree().paused=true
	begin_screen("leave_confirm","退出游戏？" if exit_app else "返回主菜单？","营业中会放弃本晚进度，保留开门前存档。" if game.phase=="营业" else "将先保存当前进度。")
	button("继续经营",resume_game)
	button("确认退出" if exit_app else "确认返回",finish_leave)

func finish_leave():
	if not is_instance_valid(game): return
	if game.phase!="营业" and not game.save_game():
		begin_screen("leave_error","保存失败",game.save_error+"。游戏仍保留在内存中。")
		button("返回游戏",resume_game);button("重新尝试保存并退出",finish_leave);return
	get_tree().paused=false
	remove_child(game);game.queue_free();game=null
	if pending_exit: get_tree().quit()
	else: title_message="";show_title()

func show_settings():
	if is_instance_valid(game): get_tree().paused=true
	begin_screen("settings","设置","显示和音量设置独立保存，不影响经营进度。")
	var fullscreen=CheckButton.new();fullscreen.text="全屏显示（F11）";fullscreen.button_pressed=settings.fullscreen
	fullscreen.toggled.connect(func(on): settings.fullscreen=on;settings.apply();persist_settings())
	content.add_child(fullscreen)
	var focus=CheckButton.new();focus.text="切换到其他窗口时自动暂停";focus.button_pressed=settings.auto_pause
	focus.toggled.connect(func(on): settings.auto_pause=on;persist_settings());content.add_child(focus)
	text("总音量（当前版本尚无音乐音效）",18)
	var volume=HSlider.new();volume.min_value=0;volume.max_value=100;volume.step=1;volume.value=round(settings.master_volume*100);volume.custom_minimum_size=Vector2(0,35)
	var readout=Label.new();readout.text="%d%%"%volume.value
	volume.value_changed.connect(func(value): settings.master_volume=value/100.0;settings.apply();readout.text="%d%%"%value)
	volume.drag_ended.connect(func(_changed):persist_settings())
	content.add_child(volume);content.add_child(readout)
	button("返回",leave_settings)

func leave_settings():
	persist_settings()
	if is_instance_valid(game): pause_game()
	else: show_title()

func persist_settings():
	if not settings.save_settings(): text("设置保存失败，请检查用户目录权限。")

func _input(event):
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode==KEY_F11:
		settings.fullscreen=not settings.fullscreen;settings.apply();persist_settings()
		if screen_name=="settings": show_settings()
		get_viewport().set_input_as_handled();return
	if event.keycode==KEY_P and is_instance_valid(game):
		if screen_name=="game": pause_game()
		elif screen_name=="pause": resume_game()
		get_viewport().set_input_as_handled();return
	if event.keycode!=KEY_ESCAPE: return
	if screen_name=="game":
		if game.panel.visible or game.build_mode or game.furniture_mode: return
		pause_game()
	elif screen_name=="pause": resume_game()
	elif screen_name=="settings":
		persist_settings()
		if is_instance_valid(game): pause_game()
		else: show_title()
	elif screen_name=="new_confirm": show_title()
	elif is_instance_valid(game): pause_game()
	get_viewport().set_input_as_handled()

func _notification(what):
	if what==NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(overlay):
		persist_settings()
		if is_instance_valid(game): request_leave(true)
		else: get_tree().quit()
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(game) and settings.auto_pause and screen_name=="game": pause_game()

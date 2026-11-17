extends SceneTree
var app
func _initialize(): call_deferred("run")
func find_button(node: Node, name: String) -> Button:
	if node is Button and node.text==name: return node
	for child in node.get_children():
		var result=find_button(child,name)
		if result!=null: return result
	return null
func click_button(name: String):
	await process_frame;await process_frame
	var b=find_button(app.content,name)
	assert(b!=null)
	var pos=b.get_global_rect().get_center()
	var e=InputEventMouseButton.new();e.position=pos;e.global_position=pos;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true
	root.push_input(e);await process_frame
	e=InputEventMouseButton.new();e.position=pos;e.global_position=pos;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=false
	root.push_input(e);await process_frame
func press(key: int):
	var e=InputEventKey.new();e.pressed=true;e.keycode=key;root.push_input(e)
	await process_frame
	e=InputEventKey.new();e.pressed=false;e.keycode=key;root.push_input(e)
	await process_frame
func screenshot(name: String):
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/workspace/jiligulu/builds/"+name+".png")
func run():
	app=load("res://app.tscn").instantiate();root.add_child(app);app.settings.auto_pause=false
	await screenshot("v03-title")
	await click_button("新游戏")
	if app.screen_name=="new_confirm": await click_button("确认新游戏")
	assert(app.game!=null and app.screen_name=="game")
	await press(KEY_P);assert(paused and app.screen_name=="pause")
	await screenshot("v03-pause")
	await click_button("设置");assert(app.screen_name=="settings")
	await screenshot("v03-settings")
	await click_button("返回");assert(app.screen_name=="pause")
	await click_button("继续游戏");assert(not paused)
	app.game.show_open()
	await screenshot("v03-management")
	app.game.panel.hide();app.game.ready_food=[20,20,20,20,20,20,4];app.game.employee=true
	assert(app.game.start_business())
	app.game.set_process(false)
	for i in range(1600):
		if app.game.phase!="营业": break
		app.game.tick_business(0.1)
	assert(app.game.phase=="结算")
	await screenshot("v03-report")
	app.game.set_process(true)
	await press(KEY_P);await click_button("返回主菜单")
	assert(app.screen_name=="leave_confirm")
	await click_button("确认返回")
	assert(app.game==null and app.screen_name=="title")
	await screenshot("v03-saves")
	await click_button("继续")
	assert(app.game!=null and app.game.phase=="结算")
	print("PASS: native mouse/keyboard flow through new game, pause, settings, settlement, title and continue")
	quit()

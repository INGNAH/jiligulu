extends SceneTree
func _initialize(): call_deferred("run")
func click(p: Vector2):
	var motion=InputEventMouseMotion.new();motion.position=p;motion.global_position=p;root.push_input(motion)
	await process_frame
	var e=InputEventMouseButton.new();e.position=p;e.global_position=p;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;root.push_input(e)
	await process_frame
	e=InputEventMouseButton.new();e.position=p;e.global_position=p;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=false;root.push_input(e)
	await process_frame
func run():
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	game.phase="准备";game.layout.reset();game.sync_seats()
	game.view_focus=game.layout.center(Vector2i(4,7))
	game.toggle_build()
	await process_frame
	await process_frame
	await process_frame
	await click(game.tool_buttons["move"].get_global_rect().get_center())
	if game.build_tool!="move": quit(1);return
	await click((game.layout.center(Vector2i(3,7))-game.view_focus)*game.view_zoom+game.VIEW_CENTER)
	if game.moving_table!=2: print("MOVE PICK FAILED",game.get_global_mouse_position());quit(1);return
	await click((game.layout.center(Vector2i(4,7))-game.view_focus)*game.view_zoom+game.VIEW_CENTER)
	assert(game.moving_table==-1 and game.layout.tables[2].x==4)
	game.toggle_build()
	await click(game.slot_buttons[1].get_global_rect().get_center())
	assert(game.selected==1)
	print("PASS: real mouse events select build tool, move table and select food")
	quit()

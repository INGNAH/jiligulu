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
	await click((game.layout.center(Vector2i(3,7))-game.view_focus)*game.view_zoom+game.VIEW_CENTER)
	await process_frame
	assert(game.furniture_bubble.visible)
	await click(game.furniture_bubble.get_child(1).get_global_rect().get_center())
	assert(game.relocating)
	await click((game.layout.center(Vector2i(4,7))-game.view_focus)*game.view_zoom+game.VIEW_CENTER)
	assert(not game.relocating and game.layout.tables[2].x==4)
	game.toggle_build()
	await click(game.slot_buttons[1].get_global_rect().get_center())
	assert(game.selected==1)
	print("PASS: real mouse events select build tool, move table and select food")
	quit()

extends SceneTree
func _initialize(): call_deferred("run")
func shot(name: String):
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/workspace/jiligulu/builds/"+name+".png")
func key(code: int):
	var e=InputEventKey.new();e.pressed=true;e.keycode=code
	Input.parse_input_event(e)
	await process_frame
	e=InputEventKey.new();e.pressed=false;e.keycode=code
	Input.parse_input_event(e)
	await process_frame
func run():
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	game.phase="准备";game.layout.reset();game.sync_seats()
	await shot("core-room")
	await key(KEY_B)
	assert(game.build_mode)
	await shot("core-layout")
	await key(KEY_R)
	assert(game.build_rot==1)
	game.build_tool="move"
	game.edit_cell(Vector2i(3,7));assert(game.moving_table==2)
	game.build_rot=0;game.edit_cell(Vector2i(4,7));assert(game.moving_table==-1)
	game.undo_layout();assert(game.layout.tables[2].x==3)
	await key(KEY_B);assert(not game.build_mode)
	game.ready_food=[30,30,10,10,10,10,2];game.employee=true
	assert(game.start_business())
	for i in range(6): game.spawn_guest()
	for r in range(2):
		for i in range(6): game.add_plate(r,i,i*3)
	for i in range(100): game.tick_business(0.1)
	await shot("core-business")
	game.show_open()
	await shot("core-management")
	game.show_kitchen()
	await shot("core-kitchen")
	game.end_day()
	await shot("core-settlement")
	print("PASS: native render, B/R input, move/undo, business and settlement panels")
	quit()

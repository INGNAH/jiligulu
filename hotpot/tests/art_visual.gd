extends SceneTree
var Sprite=preload("res://art/sprite_spec.gd")
var Pack=preload("res://art/art_pack.gd")
var Renderer=preload("res://rendering/art_renderer.gd")
func texture(color: Color) -> Texture2D:
	var im=Image.create(16,16,false,Image.FORMAT_RGBA8);im.fill(color)
	return ImageTexture.create_from_image(im)
func _initialize(): call_deferred("run")
func run():
	var r=Renderer.new();var p=Pack.new();var s=Sprite.new()
	s.frames.assign([texture(Color.RED),texture(Color.GREEN)]);s.anchor=Vector2(8,8);s.fps=2;s.display_scale=Vector2(4,4)
	p.sprites={"fixture":s};r.configure(p)
	var canvas=Node2D.new();canvas.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(canvas)
	canvas.draw.connect(func(): r.draw(canvas,["fixture"],Vector2(100,100),0.6))
	canvas.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var shot=root.get_texture().get_image()
	var pixel=shot.get_pixel(100,100)
	assert(pixel.g>0.9 and pixel.r<0.1)
	assert(shot.get_pixel(65,100).g<0.9)
	print("PASS: actual viewport draws correct animation frame at configured anchored bounds")
	canvas.queue_free();await process_frame
	var game=load("res://main.tscn").instantiate()
	p.sprites={"character/player/idle":s,"furniture/table/0":s,"portrait/lumi/neutral":s}
	game.art_pack=p
	root.add_child(game);game.phase="准备";game.show_open()
	await process_frame
	await RenderingServer.frame_post_draw
	assert(game.art.valid.size()==3)
	root.get_texture().get_image().save_png("/workspace/jiligulu/builds/art-integration-test.png")
	print("PASS: game draws assigned test textures and portrait alongside existing placeholders")
	quit()

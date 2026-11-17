extends SceneTree
var failures=0
var Sprite=preload("res://art/sprite_spec.gd")
var Pack=preload("res://art/art_pack.gd")
var Renderer=preload("res://rendering/art_renderer.gd")
func check(ok: bool,message: String):
	if ok: print("PASS: ",message)
	else: failures+=1;push_error(message)
func texture(color: Color,size: int=16) -> Texture2D:
	var image=Image.create(size,size,false,Image.FORMAT_RGBA8);image.fill(color)
	return ImageTexture.create_from_image(image)
func _initialize(): call_deferred("run")
func run():
	var sprite=Sprite.new();sprite.frames.assign([texture(Color.RED),texture(Color.GREEN)])
	sprite.anchor=Vector2(8,16);sprite.display_scale=Vector2(2,2);sprite.offset=Vector2(3,-4);sprite.fps=4
	check(sprite.problem().is_empty(),"valid equally sized frames accepted")
	check(sprite.destination(Vector2(100,200),sprite.frames[0])==Rect2(87,164,32,32),"source anchor, offset and scale preserve world foot position")
	check(sprite.frame_index(0.3)==1 and sprite.frame_index(0.5)==0,"animated frames advance and loop at configured FPS")
	sprite.loop=false
	check(sprite.frame_index(20)==1,"non-looping animation holds last frame")
	sprite.frames.append(texture(Color.BLUE,32))
	check(not sprite.problem().is_empty(),"inconsistent frame canvas rejected")
	sprite.frames.pop_back()
	var pack=Pack.new();pack.sprites={"character/player/idle":sprite,"portrait/lumi/neutral":sprite,"broken":Sprite.new()}
	var renderer=Renderer.new();renderer.configure(pack)
	check(renderer.errors.size()==1 and not renderer.valid.has("broken"),"invalid slot excluded while other art remains available")
	check(renderer.resolve(["missing"])==null,"missing art keeps placeholder path")
	check(renderer.resolve(["character/player/walk","character/player/idle"])==sprite,"missing walk falls back to idle")
	renderer.actor_time("a","idle",1);renderer.actor_time("a","walk",0.1)
	check(is_equal_approx(renderer.actor_seconds("a"),0.1),"animation restarts on actor-state transition")
	renderer.actor_time("a","walk",0.2)
	check(is_equal_approx(renderer.actor_seconds("a"),0.3),"same state keeps independent actor clock")
	sprite.pixel_art=false
	var portrait=renderer.portrait(["portrait/lumi/neutral"],Vector2(200,300))
	check(portrait.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR and portrait.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED,"portrait uses smooth sampling with preserved aspect ratio")
	portrait.free()
	pack.sprites.erase("broken")
	check(ResourceSaver.save(pack,"user://test_art.tres")==OK,"art pack serializes as exportable Godot resources")
	var loaded=load("user://test_art.tres")
	check(loaded.validate().is_empty() and loaded.sprites.size()==2,"saved resource pack reloads with texture frames")
	var game=load("res://main.tscn").instantiate();root.add_child(game);game.set_process(false)
	var snapshot=game.layout.snapshot()
	game.art.configure(loaded)
	check(game.layout.snapshot()==snapshot,"visual asset replacement never modifies physical layout")
	game.held=1;game.player_motion=true
	check(game.player_animation()=="carry_walk","carrying while moving selects carry animation")
	check(game.actor_keys("player","carry_walk")==["character/player/carry_walk","character/player/walk","character/player/idle"],"partial art delivery uses explicit fallback chain")
	check(game.art.resolve(["furniture/table/1"])==null,"missing rotated view never rotates a 2.5D texture automatically")
	game.layout.belts.clear();game.layout.belts[Vector2i.ZERO]=0;game.layout.belts[Vector2i.RIGHT]=0;game.layout.belts[Vector2i.UP]=0
	check(game.belt_art_key(Vector2i.ZERO)=="belt/ne","conveyor corner slot matches actual neighboring directions")
	game.layout.restore(snapshot);game.show_open()
	check(game.panel_box.get_child(1) is TextureRect,"employee management panel embeds configured portrait")
	game.queue_free()
	print("RESULT: ",failures," failures")
	quit(1 if failures else 0)

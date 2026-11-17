extends RefCounted
var pack: Resource
var valid: Dictionary = {}
var errors=PackedStringArray()
var actor_states: Dictionary = {}

func configure(resource: Resource):
	pack=resource;valid.clear();actor_states.clear();errors.clear()
	if pack==null: return
	errors=pack.validate()
	for key in pack.sprites:
		var spec=pack.sprites[key]
		if spec is Resource and spec.has_method("problem") and spec.problem().is_empty(): valid[key]=spec

func resolve(keys: Array):
	for key in keys:
		if valid.has(key): return valid[key]
	return null

func draw(canvas: CanvasItem, keys: Array, position: Vector2, seconds: float=0.0) -> bool:
	var spec=resolve(keys)
	if spec==null: return false
	var texture=spec.texture_at(seconds)
	if texture==null: return false
	canvas.draw_texture_rect(texture,spec.destination(position,texture),false)
	return true

func actor_time(id: String, state: String, dt: float) -> float:
	if not actor_states.has(id) or actor_states[id].state!=state:
		actor_states[id]={"state":state,"time":0.0}
	actor_states[id].time+=dt
	return actor_states[id].time

func actor_seconds(id: String) -> float:
	return actor_states.get(id,{"time":0.0}).time

func portrait(keys: Array, size: Vector2) -> Control:
	var spec=resolve(keys)
	if spec==null: return null
	var view=TextureRect.new()
	view.texture=spec.texture_at(0)
	view.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST if spec.pixel_art else CanvasItem.TEXTURE_FILTER_LINEAR
	view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.custom_minimum_size=size
	view.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return view

extends Resource
## One image or a sequence of equally sized PNG frames.
## Anchor is in source-image pixels, measured from its top-left corner.
@export var frames: Array[Texture2D] = []
@export var anchor: Vector2 = Vector2.ZERO
@export var display_scale: Vector2 = Vector2.ONE
@export var offset: Vector2 = Vector2.ZERO
@export_range(0.0,60.0,0.1) var fps: float = 8.0
@export var loop: bool = true
@export var pixel_art: bool = true

func problem() -> String:
	if frames.is_empty(): return "No frames assigned"
	if display_scale.x<=0 or display_scale.y<=0: return "Display scale must be positive"
	var size=Vector2.ZERO
	for frame in frames:
		if frame==null: return "Null texture in frame sequence"
		if size==Vector2.ZERO: size=frame.get_size()
		elif frame.get_size()!=size: return "Frames must have identical canvas sizes"
	return ""

func frame_index(seconds: float) -> int:
	if frames.is_empty(): return -1
	var index=maxi(0,int(floor(seconds*fps)))
	return index%frames.size() if loop else mini(index,frames.size()-1)

func texture_at(seconds: float) -> Texture2D:
	var index=frame_index(seconds)
	return null if index<0 else frames[index]

func destination(position: Vector2, texture: Texture2D) -> Rect2:
	return Rect2(position+offset-anchor*display_scale,texture.get_size()*display_scale)

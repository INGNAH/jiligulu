extends Resource
## Explicit slots; an unfilled slot keeps the procedural placeholder.
@export var sprites: Dictionary = {}

func validate() -> PackedStringArray:
	var errors=PackedStringArray()
	for key in sprites:
		var spec=sprites[key]
		if not spec is Resource or not spec.has_method("problem"):
			errors.append(str(key)+": Expected sprite_spec resource")
		else:
			var problem=spec.problem()
			if not problem.is_empty(): errors.append(str(key)+": "+problem)
	return errors

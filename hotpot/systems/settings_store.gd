extends RefCounted
const PATH="user://settings.cfg"
var fullscreen=false
var master_volume=0.8
var auto_pause=true

func load_settings():
	var config=ConfigFile.new()
	if config.load(PATH)!=OK: return
	var value=config.get_value("display","fullscreen",false)
	fullscreen=value if value is bool else false
	value=config.get_value("audio","master_volume",0.8)
	master_volume=clampf(float(value),0,1) if (value is float or value is int) and is_finite(float(value)) else 0.8
	value=config.get_value("game","auto_pause",true)
	auto_pause=value if value is bool else true

func save_settings() -> bool:
	var config=ConfigFile.new()
	config.set_value("display","fullscreen",fullscreen)
	config.set_value("audio","master_volume",master_volume)
	config.set_value("game","auto_pause",auto_pause)
	return config.save(PATH)==OK

func apply():
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(master_volume,0.0001)))
	AudioServer.set_bus_mute(0,master_volume==0)
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

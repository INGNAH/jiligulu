extends SceneTree

var failures=[]
func check(ok:bool,message:String):
	if not ok: failures.append(message)

func _initialize(): call_deferred("run")
func run():
	var game=load("res://main.tscn").instantiate()
	game.auto_load=false
	root.add_child(game)
	game.set_process(false)
	for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
		check(game.player_can_stand(game.player+direction*12),"spawn must allow movement")
	var layout=game.layout
	for f in layout.stations+layout.facilities:
		for tile in layout.footprint(f):
			check(not layout.walkable(tile,true) and not layout.walkable(tile),"fixture footprint blocked")
	layout.stations.pop_back()
	check(layout.compile(),"one station serves all zones")
	for t in layout.tables: check(layout.station_for_table(t)==0,"all tables share the station")
	game.ready_food=[16,30,16,12,12,12,12]
	check(game.start_business(),"service opens")
	var mains=0
	var sides=0
	var visitors=[0,0,0]
	var seen={}
	for step in range(3100):
		if game.phase!="营业": break
		for g in game.guests:
			if g!=null: seen[g.ticket]=g
		game.tick_business(0.05)
	for g in seen.values():
		mains+=g.get("mains_eaten",0)
		sides+=g.get("sides_eaten",0)
		for kind in g.visited: visitors[kind]+=1
	check(game.phase=="结算" and game.served==game.guest_target,"whole evening settled")
	check(mains>game.served and mains>sides and sides>0,"repeat main orders outweigh side trips")
	for count in visitors: check(count>0,"guests used each self-service facility")
	print("Shared dining: guests=",game.served," mains=",mains," sides=",sides," sauce/drinks/ice=",visitors)
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)

extends SceneTree
var failures=0
func check(ok: bool,s: String):
	if ok: print("PASS: ",s)
	else: failures+=1;push_error(s)
func _initialize(): call_deferred("run")
func run():
	var l=load("res://layout.gd").new()
	check(l.compile() and l.tables.size()==6 and l.stations.size()==2,"starter has six independent tables, two ingredient stations and reachable chairs")
	var kitchen=Vector2i(1,8)
	check(not l.walkable(kitchen) and l.walkable(kitchen,true),"staff-only kitchen permissions")
	check(not l.path(Vector2i(0,11),kitchen,true).is_empty(),"kitchen worker can reach service window")
	check(l.partitions.values().has("window"),"starter kitchen has a serving window")
	l.expanded=true
	check(l.floor_at(Vector2i(23,10)),"east wing available after expansion")
	l.expanded=false
	var before=l.snapshot()
	check(not l.place_table(Vector2i(2,2),0,0),"overlapping tables rejected without changing layout")
	check(not l.place_table(Vector2i(-1,0),0,0),"out of bounds furniture rejected")
	check(not l.place_table(Vector2i(14,10),1,2),"side-facing dining seats rejected")
	check(l.place_table(Vector2i(14,10),2,2),"front-facing seats can be placed freely")
	check(l.compile() and l.station_for_table(l.tables.back())>=0,"a new zone uses the shared stations")
	l.restore(before)
	check(l.place_table(Vector2i(4,7),0,0,2) and l.compile(),"move table transaction retains seat access and station access")
	l.restore(before)
	var legacy=before.duplicate(true)
	legacy.feeders=legacy.stations
	legacy.erase("stations")
	l.restore(legacy)
	check(l.compile() and l.snapshot()==before,"previous layouts restore stations and use the current save schema")
	check(l.upgrade_snapshot(legacy)==before,"saved layouts use current station names")
	l.restore(before);l.stations.clear()
	check(l.compile(),"table service can open without optional side stations")
	l.restore(before);l.shape=2
	check(not l.compile() and not l.floor_at(Vector2i(15,1)),"L-shaped floor cutout invalidates furniture in missing floor")
	l.restore(before);l.shape=1
	check(not l.compile() and not l.floor_at(Vector2i(3,1)),"long room shape changes usable floor")
	l.restore(before)
	for x in range(l.WIDTH): l.partitions[Vector2i(x,10)]="wall"
	check(l.path(Vector2i(20,11),Vector2i(2,1)).is_empty() and not l.compile(),"blocked aisle is detected by actual pathfinding")
	l.restore(before)
	var json=JSON.parse_string(JSON.stringify(l.snapshot()))
	l.restore(json)
	check(l.compile() and l.snapshot()==before,"layout round trip restores integer coordinates, zones and furniture")
	var game=load("res://main.tscn").instantiate();root.add_child(game);game.set_process(false)
	game.phase="准备";game.ready_food=[20,20,20,20,20,20,6];game.employee=true;game.staff_zone=-1
	game.income=0;game.tips=0;game.spending=0;game.served=0;game.satisfaction=0;game.plates.clear()
	game.layout.reset()
	check(game.start_business(),"restaurant starts with validated layout")
	game.player=game.layout.center(game.KITCHEN_STATION);game.selected=1
	check(game.player_can_stand(game.player) and not game.layout.walkable(game.KITCHEN_STATION),"manager can enter kitchen while guests cannot")
	game.interact()
	check(game.held==-1 and game.ready_food[1]==20,"manager opens order menu without taking stock")
	game.panel.hide()
	game.employee=false
	game.tick_staff(1.0)
	check(game.plates.is_empty() and not game.staff_carry.is_empty(),"basic attendant collects sides at the kitchen before delivery")
	game.employee=true
	var initial_staff=game.staff_pos
	var walked=false
	var first=game.guests[0]
	for i in range(350):
		game.tick_business(0.1)
		walked=walked or game.staff_pos!=initial_staff
		if first.has("main_dish") and walked and game.zone_stats[1].arrivals>0: break
	check(game.service_team.size()==2 and first.has("main_dish") and game.order_trips>0,"attendant records first diner's actual main order within 35 seconds")
	check(walked,"employee physically walks between kitchen and station")
	check(game.zone_stats[0].arrivals>0 and game.zone_stats[1].arrivals>0,"arrivals are distributed across independent zones")
	# Full plates cannot silently disappear when a station is full.
	var cap=game.layout.STATION_CAPACITY
	while game.station_plate_count(0)<cap: game.add_plate(0,0)
	check(not game.add_plate(0,0),"station plate capacity prevents overfilling")
	# Compare identical meals with and without hunger penalty at settlement.
	var guest_index=0
	if game.guests[guest_index]==null: game.guests[guest_index]={"full":80,"capacity":80,"liked":true,"eaten":3,"score":80,"hungry":0.0}
	game.guests[guest_index].full=80;game.guests[guest_index].capacity=80;game.guests[guest_index].liked=true;game.guests[guest_index].eaten=3;game.guests[guest_index].score=80;game.guests[guest_index].hungry=0.0
	var baseline=game.satisfaction;game.checkout(guest_index);var fast=game.satisfaction-baseline
	game.guests[guest_index]={"full":80,"capacity":80,"liked":true,"eaten":3,"score":80,"hungry":30.0}
	baseline=game.satisfaction;game.checkout(guest_index)
	check(game.satisfaction-baseline<fast,"long food waits reduce rating even if guest eventually eats")
	# Restart state after synthetic checkout checks.
	game.end_day();game.next_day()
	for d in range(3):
		game.ready_food=[20,20,20,20,20,20,4]
		var cash=game.money
		game.income=0;game.spending=0
		check(game.start_business(),"consecutive day %d starts"%(d+1))
		for i in range(1600):
			if game.phase!="营业": break
			game.tick_business(0.1)
		check(game.phase=="结算" and game.served==game.guest_target and game.money==cash+game.income-game.spending,"consecutive day %d settles all guests and reconciles ledger"%(d+1))
		check(game.plates.is_empty() and game.staff_carry.is_empty() and game.staff_path.is_empty(),"all food and staff state returned at closing")
		var snapshot=game.layout.snapshot();var saved_day=game.day
		game.load_game()
		check(game.layout.snapshot()==snapshot and game.day==saved_day and game.phase=="结算","settlement reload preserves layout and day")
		game.next_day()
	# Compatibility with original demo saves.
	var f=FileAccess.open(game.SAVE_PATH,FileAccess.WRITE)
	f.store_string(JSON.stringify({"version":1,"money":177,"day":4,"raw":[1,0,0,0,0,0],"ready":[0,2,0,0,0,0,0]}));f.close()
	game.load_game()
	check(game.money==177 and game.day==4 and game.layout.compile(),"v1 saves migrate to valid default layout")
	game.queue_free()
	print("RESULT: ",failures," failures")
	quit(1 if failures else 0)

extends SceneTree
var failures=0
func check(ok:bool,message:String):
	if not ok:
		failures+=1
		push_error(message)
func _initialize(): call_deferred("run")

func run():
	var g=load("res://main.tscn").instantiate()
	g.auto_load=false
	root.add_child(g)
	g.set_process(false)
	g.ready_food=[0,40,0,0,0,0,0]
	check(g.start_business(),"open")
	var station=g.layout.station_for_table(g.layout.tables[g.seat_tables[0]])
	var diner=g.guests[0]
	diner.service="served"
	diner.served_at=0
	diner.visited=[0,1,2]
	g.guest_target=1
	for step in range(450): g.tick_business(0.05)
	check(diner.get("refill_wait",0.0)>8 and diner.position==g.layout.center(g.layout.station_cell(station)),"guest waits at empty station")
	g.ready_food[4]=2
	var carried=false
	for step in range(600):
		g.tick_business(0.05)
		carried=carried or not g.staff_carry.is_empty()
		if diner.has("carry_food"): break
	check(carried and diner.get("carry_food",-1)==4,"attendant delivers stock and waiting guest takes it")
	var tray=g.plates[0]
	var guest={"ticket":1,"pickup_station":station,"wish":4,"last_meal":8}
	check(g.portion_label(6)=="满" and tray.portions==5 and g.portion_label(tray.portions)=="大量","full and many")
	g.take_side_at_station(guest)
	check(tray.portions==3 and g.portion_label(tray.portions)=="少量","few")
	g.take_side_at_station(guest)
	g.take_side_at_station(guest)
	check(tray.portions==0 and g.portion_label(tray.portions)=="空" and tray in g.plates,"empty tray remains visible")
	var compare=diner.duplicate(true)
	g.checkout(0)
	var delayed=g.satisfaction
	compare.refill_wait=0
	g.guests[0]=compare
	g.checkout(0)
	check(g.satisfaction-delayed>delayed and str(g.reviews).contains("等了"),"shortage affects actual checkout and review")
	print("Tray and restock failures: ",failures)
	quit(1 if failures else 0)

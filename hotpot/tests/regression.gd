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
	var l=game.layout
	game.show_open()
	var slider=game.panel_box.find_children("*","HSlider",true,false)[0]
	for price in [18,21,24,27,30]:
		slider.value=price
		var count=18-int(price/3)
		check(game.expected_guests()==count and game.preparation_plan().recommended==3*count,"price %d"%price)
		check(game.save_game() and game.load_game() and game.menu_price==price,"price persistence")
	var plan=game.preparation_plan()
	check(plan.targets[1]>plan.targets[0] and plan.targets[2]>plan.targets[4],"main course weights")
	game.panel.hide()
	game.toggle_build()
	game.picked=game.pick_at(l.kitchen_cell())
	game.stow_picked()
	check(l.kitchen_stored and not l.compile(),"stowed kitchen blocks opening")
	check(game.save_game() and game.load_game() and l.kitchen_stored,"stowed kitchen survives reload")
	check(l.move_kitchen(l.kitchen_cell(),2) and l.compile(),"replace kitchen")
	var old=l.snapshot()
	old.erase("kitchen_stored")
	l.restore(old)
	check(not l.kitchen_stored,"old layout has kitchen")
	var flower=Vector2i(9,4)
	l.place_facility(flower,4)
	for c in l.neighbors(flower): l.paint_partition(c,"wall")
	check(l.compile(),"enclosed decoration allows opening")
	l.reset()
	game.ready_food=[20,20,20,20,20,20,20]
	check(game.start_business(),"open for routing")
	var guest=game.guests[0]
	check(guest.position!=game.seats[0] and not guest.trip.is_empty(),"guest enters through door")
	var stations=l.stations_for_table(l.tables[game.seat_tables[0]])
	var near=stations[0]
	var far=stations[1]
	game.add_plate(near,0)
	game.plates[0].portions=0
	game.add_plate(far,0)
	guest.position=game.seats[0]
	guest.trip.clear()
	guest.service="served"
	guest.visited=[0,1,2]
	guest.last_meal=8
	game.tick_business(0.05)
	check(guest.get("pickup_station",-1)==far,"redirect to stocked counter")
	for frame in range(400):
		game.tick_business(0.05)
		if guest.has("carry_food"): break
	check(guest.position==l.center(l.station_cell(far)) and game.plates[1].portions==5,"takes food at farther station")
	game.guest_target=40
	while game.guests.has(null): game.spawn_guest()
	for n in 3: game.spawn_guest()
	game.guest_target=game.spawned
	for frame in 250: game.tick_business(0.01)
	check(game.waiting.size()==3 and game.waiting[0].position==l.center(l.queue_tile(0)),"queue gathers at marked places")
	var first=game.waiting[0].ticket
	game.checkout(0)
	game.seat_next()
	check(game.guests[0].ticket==first and not game.guests[0].trip.is_empty(),"oldest ticket walks to released seat")
	var diner=game.guests[0]
	diner.trip.clear()
	diner.position=game.seats[0]
	diner.service="out"
	diner.tried_side=true
	game.tick_business(0.05)
	check(game.guests[0]==null,"sold-out mains end meal after a side attempt")
	for failure in failures: push_error(failure)
	print("Regression failures: ",failures.size())
	quit(0 if failures.is_empty() else 1)

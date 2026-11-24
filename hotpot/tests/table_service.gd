extends SceneTree

func _initialize():
	call_deferred("run")

func run():
	var game=load("res://main.tscn").instantiate()
	game.auto_load=false
	root.add_child(game)
	game.set_process(false)
	game.ready_food=[100,100,100,100,100,100,100]
	if not game.start_business():
		quit(1)
		return
	game.guest_target=1
	var guest=game.guests[0]
	var chair=game.layout.cell(game.seats[0])
	var spot=game.layout.service_spots[chair]
	var stages=[]
	var errors=[]
	for step in range(1600):
		var state=guest.get("service","waiting")
		var full=guest.full
		var walking_out=guest.has("pickup_station")
		var carrying=guest.has("carry_food")
		var eating=guest.has("eating_time")
		var stock=0
		var station=int(guest.get("pickup_station",-1))
		for plate in game.plates:
			if plate.station==station: stock+=plate.portions
		var trips=game.staff_trips
		game.tick_business(0.05)
		var current=guest.get("service","waiting")
		for worker in game.service_team:
			if game.layout.service_obstacles.has(game.layout.cell(worker.pos)):
				errors.append("staff crossed a chair or fixture")
			if (state=="ordering" and current!="ordering" and worker.role=="点单") or (state=="preparing" and current=="served" and worker.role!="点单"):
				if worker.pos!=game.layout.center(spot) or spot not in game.layout.neighbors(chair):
					errors.append("staff served away from the table")
				stages.append(worker.role)
		if guest.has("pickup_station") and not walking_out:
			if guest.has("carry_food") or guest.full!=full: errors.append("collected before arrival")
		if walking_out and guest.has("carry_food"):
			if guest.position!=game.layout.center(game.layout.station_cell(station)) or guest.full!=full:
				errors.append("incorrect station pickup")
			if trips==game.staff_trips:
				for plate in game.plates:
					if plate.station==station: stock-=plate.portions
				if stock!=guest.side_portions: errors.append("incorrect portion deduction")
			stages.append("pickup")
		if carrying and guest.has("eating_time"):
			if guest.position!=game.seats[0] or guest.full!=full: errors.append("incorrect pot transfer")
			stages.append("pot")
		if eating and not guest.has("eating_time"):
			if guest.full<=full: errors.append("meal did not fill diner")
			stages.append("eaten")
			break
	if stages.size()!=5 or stages.slice(2)!=["pickup","pot","eaten"]: errors.append("missing service stages")
	for message in errors: push_error(message)
	print("Table service: ",stages," / ",errors.size()," failures")
	quit(0 if errors.is_empty() else 1)

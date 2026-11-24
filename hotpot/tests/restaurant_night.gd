extends SceneTree

var failures=0

func check(ok:bool,message:String):
	if not ok:
		failures+=1
		push_error(message)

func _initialize(): call_deferred("run")

func night(moved:bool,limited:bool)->Dictionary:
	var g=load("res://main.tscn").instantiate()
	g.auto_load=false
	root.add_child(g)
	g.set_process(false)
	var l=g.layout
	if moved:
		g.toggle_build()
		g.build_tool="kitchen"
		g.build_rot=0
		g.edit_cell(Vector2i(16,6))
		check(l.kitchen_cell()==Vector2i(16,6),"catalog moves kitchen")
		g.undo_layout()
		check(l.kitchen_cell()==Vector2i(1,9),"undo restores kitchen")
		g.build_tool="kitchen"
		g.edit_cell(Vector2i(16,6))
		l.erase(Vector2i(1,7))
		l.paint_partition(Vector2i(16,5),"staff")
		l.paint_partition(Vector2i(16,4),"window")
		check(l.compile() and l.pickup==Vector2i(16,5),"delivery pickup follows relocated window")
		g.toggle_build()
		g.load_game()
		check(l.kitchen_cell()==Vector2i(16,6) and l.pickup==Vector2i(16,5),"layout survives save and reload")
		g.player=l.center(l.kitchen_cell())
		check(g.at_kitchen() and not l.walkable(l.kitchen_cell()) and not l.walkable(Vector2i(17,6),true),"interaction, guest restriction and counter collision move together")
	g.ready_food=[100,100,100,100,100,100,100]
	if limited: g.regular_menu=[false,false,true,false,true,false,false]
	check(g.start_business(),"open")
	var delivered=false
	for tick in range(3100):
		if g.phase!="营业": break
		for worker in g.service_team:
			if worker.stage=="deliver": delivered=true
		g.tick_business(0.05)
	check(delivered and g.phase=="结算" and g.served==10,"whole service completes")
	check(g.bulletin.contains("霜牛") and g.bulletin.contains("明日预计"),"reviews and next day projection")
	if limited: check(g.food_served[1]==0 and g.food_served[6]==0,"unlisted beef cannot be served")
	var stats=g.zone_stats[1]
	var result={"wait":stats.first_wait/stats.visits,"served":g.served,"rating":g.satisfaction/g.served,"reputation":g.reputation}
	g.queue_free()
	return result

func run():
	var original=night(false,false)
	var moved=night(true,false)
	var limited=night(false,true)
	check(abs(original.wait-moved.wait)>1,"moving kitchen changes real service times")
	print("Default / moved / limited: ",original," ",moved," ",limited)
	print("Restaurant night failures: ",failures)
	quit(1 if failures else 0)

extends SceneTree
var failures=0
func check(ok: bool, message: String):
	if ok: print("PASS: ",message)
	else: failures+=1;push_error(message)
func _initialize(): call_deferred("run")
func run():
	var game=load("res://main.tscn").instantiate();game.auto_load=false;root.add_child(game);game.set_process(false)
	game.save_path="user://ledger.json"
	check(game.business_history.is_empty(),"new game has no invented history")
	game.ready_food=[30,30,30,30,30,30,6];game.employee=true
	check(game.start_business(),"service starts with ledger enabled")
	for i in range(1600):
		if game.phase!="营业": break
		game.tick_business(0.1)
	check(game.business_history.size()==1,"closing records one day")
	var entry=game.business_history[0].duplicate(true)
	check(entry.income==game.income and entry.spending==game.spending and entry.served==game.served,"ledger matches settled accounts including wage")
	check(entry.dishes==game.food_served and entry.zones==game.zone_stats,"ledger preserves dish and zone detail")
	game.end_day()
	check(game.business_history.size()==1,"duplicate close never duplicates history")
	check(game.save_store.read(game.save_path).ok,"new history validates and saves")
	game.next_day()
	check(game.business_history[0]==entry and game.food_served!=entry.dishes,"next day resets live stats without mutating history")
	game.business_history=[];game.load_game()
	check(game.business_history.size()==1 and game.day==2,"history survives load across days")
	var ledger=load("res://systems/ledger.gd")
	var history=[]
	for day in range(1,36):
		var row=entry.duplicate(true);row.day=day
		history=ledger.record(history,row)
	check(history.size()==30 and history[0].day==6 and history[-1].day==35,"history keeps latest thirty days")
	var updated=entry.duplicate(true);updated.day=35;updated.income=999
	history=ledger.record(history,updated)
	check(history.size()==30 and history[-1].income==999,"same day replaces rather than duplicates")
	var a=entry.duplicate(true);a.served=1;a.score_total=100
	var b=entry.duplicate(true);b.served=9;b.score_total=0
	check(ledger.totals([a,b]).rating==10,"multi-day rating is weighted by customer count")
	check(ledger.totals(history).days==7,"overview uses latest seven records")
	var data=game.snapshot();data.history=[entry];data.history[0].dishes[0]=-1
	check(not game.save_store.validate(data).is_empty(),"negative historical sales are rejected")
	data=game.snapshot();data.history[0].zones[0].hungry="bad"
	check(not game.save_store.validate(data).is_empty(),"corrupt nested history is rejected")
	game.apply_save({"version":3,"money":150,"day":8})
	check(game.business_history.is_empty(),"old saves load with empty history")
	game.show_history();check(game.panel.visible,"empty-history screen opens")
	game.business_history=[entry];game.show_history();game.show_history_day(entry)
	check(game.panel.visible,"history detail screen opens")
	game.queue_free();await process_frame
	print("Ledger failures: ",failures);quit(1 if failures else 0)

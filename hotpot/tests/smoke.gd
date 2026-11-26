extends SceneTree
var failures = 0
func check(ok: bool, message: String):
	if not ok:
		failures += 1
		push_error(message)
	else: print("PASS: ", message)
func _initialize():
	call_deferred("run")
func run():
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.money=150;game.day=1;game.raw=[0,0,0,0,0,0];game.ready_food=[0,0,0,0,0,0,0]
	game.phase="准备";game.employee=false;game.decor=false;game.mastery=0;game.affection=0
	game.income=0;game.spending=0;game.tips=0;game.served=0;game.satisfaction=0
	check(game.buy(1) and game.money==132 and game.raw[1]==3,"purchase deducts exact cost and adds stock")
	check(game.prepare(1) and game.raw[1]==2 and game.ready_food[1]==2,"plating consumes one ingredient and makes two dishes")
	check(not game.prepare(0),"cannot plate missing ingredients")
	game.raw[4]=3;game.raw[1]=3
	game.finish_cook(true)
	check(game.mastery==1 and game.ready_food[6]==2 and game.raw[1]==2 and game.raw[4]==2,"cooking consumes both ingredients and grants mastery")
	game.finish_cook(false)
	check(game.mastery==1 and game.ready_food[1]==4,"failed timing gives fallback meat without mastery")
	game.ready_food=[12,12,0,0,0,0,2]
	check(game.hire() and game.money==102,"employee recruitment charged once")
	check(not game.hire(),"no duplicate recruitment")
	check(game.start_business(),"open restaurant with sufficient stock")
	game.player=game.layout.center(game.KITCHEN_STATION);game.interact()
	check(game.held==-1 and game.ready_food[0]==12,"manager opens custom orders without taking ordinary stock")
	game.panel.hide()
	check(game.guests[0].order==-1,"no special request on arrival")
	game.guests[0].order=0;game.cook_order(0,game.guests[0].ticket);game.cook_cursor.value=55;game.finish_service_heat(game.heat_generation);game.tick_business(2.5);game.guests[0].trip.clear()
	var cash=game.money
	check(game.serve_guest(0) and game.money==cash+8 and game.held==-1,"preference delivery awards exact tip and consumes plate")
	game.held=0
	check(not game.serve_guest(0) and game.held==0,"repeated preference cannot farm tips")
	game.ready_food[0]+=1;game.held=-1
	game.spawn_guest();game.spawn_guest()
	var hero_index=-1
	for i in range(game.guests.size()):
		if game.guests[i]!=null and game.guests[i].special: hero_index=i
	game.held=3
	check(not game.serve_guest(hero_index) and game.held==3,"hero rejects spicy food without consuming it")
	game.held=-1;game.guests[hero_index].order=0;game.cook_order(hero_index,game.guests[hero_index].ticket);game.cook_cursor.value=55;game.finish_service_heat(game.heat_generation);game.tick_business(2.5);game.guests[hero_index].trip.clear();cash=game.money
	check(game.serve_guest(hero_index) and game.money==cash+20 and game.affection==1,"hero accepts mild meat and grants affection and bonus")
	for i in range(1600):
		if game.phase != "营业": break
		game.tick_business(0.1)
	check(game.phase=="结算" and game.served==10,"full business day settles all ten guests")
	check(game.plates.is_empty() and game.spending==56,"closing clears serving stations and charges eight-coin wage")
	check(game.money==150+game.income-game.spending,"day ledger reconciles cash, income and all expenses")
	var saved_money=game.money
	game.save_game();game.money=0;game.load_game()
	check(game.money==saved_money and game.phase=="结算","save and reload preserve settlement and cash")
	game.next_day()
	check(game.day==2 and game.phase=="准备" and game.income==0 and game.spending==0,"next day resets daily ledger")
	print("RESULT: ",failures," failures")
	game.queue_free()
	quit(1 if failures else 0)

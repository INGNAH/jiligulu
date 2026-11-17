extends SceneTree
var failures=0
func check(ok: bool, message: String):
	if ok: print("PASS: ",message)
	else: failures+=1;push_error(message)
func _initialize(): call_deferred("run")
func run():
	var game=load("res://main.tscn").instantiate()
	game.auto_load=false;root.add_child(game)
	var p=game.preparation_plan()
	check(p.recommended==30 and p.missing==30,"default demand is thirty plates")
	game.money=0
	var before=game.raw.duplicate()
	check(not game.buy_recommended() and game.raw==before and game.spending==0,"insufficient funds never partially purchase")
	game.money=1000
	var cost=p.cost
	check(game.buy_recommended() and game.money==1000-cost and game.spending==cost,"purchase debits exact quoted cost")
	check(game.preparation_plan().cost==0,"existing raw stock prevents duplicate purchasing")
	var cash=game.money
	game.buy_recommended()
	check(game.money==cash,"repeated purchase is free when supplies suffice")
	var raw_before=0
	for n in game.raw: raw_before+=n
	var made=game.prepare_recommended()
	var raw_after=0
	for n in game.raw: raw_after+=n
	check(made==30 and (raw_before-raw_after)*2==made,"planned preparation conserves ingredients and stops at target")
	check(game.prepare_recommended()==0,"repeated preparation consumes nothing")
	game.raw=[5,0,0,0,0,0];game.ready_food=[0,0,0,0,0,0,0]
	check(game.prepare_target(0,3)==4 and game.raw[0]==3,"odd target rounds to whole two-plate batches")
	check(game.prepare_target(0,2)==0 and game.raw[0]==3,"lower target never destroys existing stock")
	check(game.prepare_target(0,100)==6 and game.raw[0]==0,"limited stock cannot become negative")
	game.ready_food=[0,0,0,0,0,0,36]
	check(game.preparation_plan().cost==0 and game.preparation_plan().missing==0,"special dishes count toward total demand")
	game.menu_price=18
	check(game.preparation_plan().recommended==36,"budget pricing increases recommended demand")
	game.menu_price=30
	check(game.preparation_plan().recommended==24,"premium pricing reduces recommended demand")
	game.phase="营业";game.raw=[3,3,3,3,3,3]
	before=game.raw.duplicate();cash=game.money
	check(not game.buy_recommended() and game.prepare_recommended()==0 and not game.buy(0) and not game.prepare(0) and game.raw==before and game.money==cash,"live service blocks procurement and preparation mutations")
	game.phase="准备"
	game.show_preparation()
	check(game.panel.visible and game.panel_box.get_child_count()>10,"plan panel builds its inventory and actions")
	game.queue_free()
	await process_frame
	print("Preparation failures: ",failures)
	quit(1 if failures else 0)

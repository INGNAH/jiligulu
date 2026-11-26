extends SceneTree
var errors=[]
func check(ok:bool,message:String):
	if not ok: errors.append(message)
func _initialize(): call_deferred("run")

func total(a:Array)->int:
	return a.reduce(func(x,y):return x+int(y),0)

func ui_button(g,prefix:String):
	for child in g.panel_box.get_children():
		if child is Button and child.text.begins_with(prefix): return child
	return null

func click(g,prefix:String)->bool:
	var control=ui_button(g,prefix)
	check(control!=null,"missing control: "+prefix)
	if control==null: return false
	control.pressed.emit()
	return true

func service_night(g):
	g.raw=[4,4,4,4,4,4]
	g.ready_food=[30,30,30,30,30,30,30]
	check(g.start_business(),"open for service")
	g.player=g.layout.center(g.KITCHEN_STATION)
	var dish=g.Dishes.by_id(g.menu.mains[0])
	var slot=int(dish.core[0])
	for heat in [55,0,-1]:
		var raw_before=g.raw.duplicate()
		var plates_before=g.ready_food.duplicate()
		g.interact()
		if not click(g,"现场补做 · "+dish.name): return
		if heat<0:
			click(g,"取消本锅")
		else:
			g._process(0.04 if heat==55 else 0.45)
			var action=ui_button(g,"现在出锅")
			if not click(g,"现在出锅"): return
			action.pressed.emit()
			raw_before[slot]-=1
			plates_before[slot]+=2 if heat==55 else 1
		check(g.raw==raw_before and g.ready_food==plates_before,"live yield or cancellation: %d"%heat)
	var guest=g.guests[0]
	guest.order=0
	guest.trip.clear()
	guest.service="ordered"
	guest.main_order=slot
	g.interact()
	click(g,"亲自送主菜")
	check(not g.accept_order(0,guest.ticket),"main tray blocks special")
	g.release_order()
	g.interact()
	click(g,"端自取盘")
	check(not g.accept_order(0,guest.ticket),"side tray blocks special")
	g.release_order()
	var before=g.ready_food.duplicate()
	g.show_diner(0)
	click(g,"接单")
	g.interact()
	click(g,g.Recipes.TOOLS[0]+" · ")
	click(g,"制作 · ")
	click(g,"加料 火椒")
	click(g,"加料开火")
	click(g,"取消本锅")
	check(g.ready_food==before and g.order_seat<0,"cancel returns formula exactly once")
	g.show_diner(0)
	click(g,"接单")
	g.interact()
	click(g,g.Recipes.TOOLS[0]+" · ")
	click(g,"制作 · ")
	click(g,"加料 火椒")
	click(g,"加料开火")
	g.cook_cursor.value=55
	click(g,"现在出锅")
	g.tick_business(2.6)
	check(g.held>=0 and "辣味" in g.cooked_tags,"plated with actual topping")
	g.player=g.seats[0]
	guest.ticket+=100
	check(not g.serve_guest(0),"same seat with different ticket rejects delivery")
	guest.ticket-=100
	g.interact()
	check(guest.bonus and g.held<0,"customer receives meal through table interaction")
	for tick in 3200:
		if g.phase!="营业": break
		g.tick_business(0.05)
	check(g.phase=="结算" and g.served==g.guest_target,"whole night settles")
	g.next_day()
	g.ready_food=[20,20,20,20,20,20,20]
	check(g.start_business(),"open for cancellation checks")
	g.player=g.layout.center(g.KITCHEN_STATION)
	g.guests[0].order=0
	var available=g.ready_food.duplicate()
	g.show_diner(0)
	click(g,"接单")
	g.checkout(0)
	check(g.ready_food==available and g.order_seat<0,"departure returns only reserved ingredients")
	g.interact()
	click(g,"端自取盘")
	g.end_day()
	g.end_day()
	check(g.ready_food==available and g.held<0,"closing returns carried tray once")

func run():
	var g=load("res://main.tscn").instantiate()
	g.auto_load=false
	root.add_child(g)
	g.set_process(false)
	g.phase="准备"
	g.raw=[5,5,5,5,5,5]
	g.ready_food=[0,0,0,0,0,0,0]
	g.mastery_by_dish={}

	# Heat windows: basic plating is wider than the signature stew.
	check(g.heat_quality(0,30)==1 and g.heat_quality(0,80)==1 and g.heat_quality(0,25)==0 and g.heat_quality(0,85)==0,"normal window 30-80")
	check(g.heat_quality(g.STEW_SLOT,35)==0 and g.heat_quality(g.STEW_SLOT,55)==1 and g.heat_quality(g.STEW_SLOT,75)==0,"stew window 40-70")

	# Success: 1 raw -> 3 plates, +1 mastery for that slot only.
	check(g.finish_cook_dish(0,1) and g.raw[0]==4 and g.ready_food[0]==3,"success yields three plates")
	check(g.mastery_by_dish.get(0,0)==1 and g.mastery_by_dish.get(1,0)==0,"mastery is per dish")
	# Miss: 1 raw -> 1 plate, no mastery.
	check(g.finish_cook_dish(0,0) and g.raw[0]==3 and g.ready_food[0]==4 and g.mastery_by_dish.get(0,0)==1,"miss yields one plate")

	# Conservation: every raw consumed becomes a known number of plates.
	var raw_before=total(g.raw)
	var ready_before=total(g.ready_food)
	g.finish_cook_dish(2,1)
	g.finish_cook_dish(3,0)
	check(raw_before-total(g.raw)==2 and total(g.ready_food)-ready_before==g.COOK_YIELD_SUCCESS+g.COOK_YIELD_FAIL,"raw and plates conserved by yield rule")

	# Missing stock or invalid slot changes nothing.
	g.raw[5]=0
	var snap=[g.raw.duplicate(),g.ready_food.duplicate()]
	check(not g.finish_cook_dish(5,1) and not g.finish_cook_dish(9,1) and g.raw==snap[0] and g.ready_food==snap[1],"no stock no change")

	# Quick plating after three successes skips the minigame and costs one raw.
	g.raw[4]=10
	for n in 3: g.finish_cook_dish(4,1)
	var raw4=g.raw[4]
	var ready4=g.ready_food[4]
	g.cook_dish(4)
	check(not g.cooking and g.raw[4]==raw4-1 and g.ready_food[4]==ready4+g.COOK_YIELD_SUCCESS,"quick plating after mastery")
	# Unmastered dish opens the heat bar instead.
	g.raw[3]=2
	g.cook_dish(3)
	check(g.cooking and g.cook_slot==3,"unmastered dish opens heat bar")
	g.cooking=false
	g.panel.hide()

	# Stew keeps its original rules through the shared entry.
	g.raw[1]=3;g.raw[4]=3
	var stew_before=g.mastery
	check(g.finish_cook_dish(g.STEW_SLOT,1) and g.ready_food[6]>=2 and g.mastery==stew_before+1 and g.mastery_by_dish[g.STEW_SLOT]==g.mastery,"stew success via shared entry")

	# Live service blocks cooking.
	g.phase="营业"
	check(not g.can_cook(0),"no cooking during service")
	g.phase="准备"

	# Save round trip and legacy migration.
	var expect=g.mastery_by_dish.duplicate()
	var data=g.snapshot()
	check(g.save_store.validate(data)=="","snapshot validates")
	check(g.save_game() and g.load_game() and g.mastery_by_dish==expect,"mastery round trip")
	var legacy=g.snapshot()
	legacy.erase("mastery_by_dish")
	legacy.mastery=2
	g.apply_save(legacy)
	check(g.mastery==2 and g.mastery_by_dish.size()==1,"legacy mastery migrates to stew")
	var bad=g.snapshot()
	bad.mastery_by_dish={"9":1}
	check(g.save_store.validate(bad)!="","reject unknown slot")

	service_night(g)
	for e in errors: push_error(e)
	print("Cooking failures: ",errors.size())
	quit(0 if errors.is_empty() else 1)

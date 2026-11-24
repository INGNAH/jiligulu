extends SceneTree
var failures=0
func check(ok:bool,reason:String):
	if not ok:
		failures+=1
		push_error(reason)
func _initialize(): call_deferred("run")
func run():
	var g=load("res://main.tscn").instantiate()
	g.auto_load=false
	root.add_child(g)
	g.set_process(false)
	g.raw=[3,3,3,3,3,3]
	g.research_inputs=[2,3,4]
	g.research()
	check(g.formulas[2]==[4] and g.raw==[3,3,2,2,2,3],"shrimp recipe records tofu and spends real ingredients")
	check(g.Recipes.tags(2,g.formulas[2]).has("清淡"),"extra ingredient contributes a reusable tag")
	g.research_inputs=[5,3]
	g.research()
	check(g.formulas[1]==null and g.raw[5]==2 and g.raw[3]==1,"conflicting radish research fails and consumes its inputs")
	check(g.Recipes.match_inputs([4]).has("error"),"missing core cannot invent a recipe")
	g.research_inputs=[5,0]
	g.research()
	g.offerings=[false,true,false]
	g.save_game()
	g.formulas=[[],null,null]
	g.load_game()
	check(g.formulas[1]==[0] and not g.offerings[0],"custom recipe and tonight's menu survive reload")
	g.ready_food=[30,30,30,30,30,30,30]
	g.start_business()
	var guest=g.guests[0]
	guest.order=1
	guest.craving="甜酸"
	var stock=g.ready_food.duplicate()
	g.accept_order(0,guest.ticket)
	check(g.ready_food[5]==stock[5]-1 and g.ready_food[0]==stock[0]-1,"full researched formula reserved")
	g.player=g.layout.center(g.KITCHEN_STATION)
	g.show_dish(0,guest.ticket)
	g.cook_order(0,guest.ticket)
	g.player=g.seats[0]
	g.tick_business(2.6)
	check(g.held<0 and not g.serve_guest(0),"finished meal stays at stove")
	g.player=g.layout.center(g.KITCHEN_STATION)
	g.tick_business(0.05)
	check(g.held==5 and g.cooked_tags.has("甜酸"),"original formula already fulfils craving")
	g.release_order()
	var available=g.ready_food.duplicate()
	for food in g.staff_carry: available[food]+=1
	check(available==stock,"cancel restores all reserved recipe ingredients")
	print("Recipe research failures: ",failures)
	quit(1 if failures else 0)

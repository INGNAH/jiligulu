extends SceneTree
const P=preload("res://systems/patrons.gd")
var errors=[]
func check(ok:bool,message:String):
	if not ok: errors.append(message)
func _initialize(): call_deferred("run")
func run():
	var rng=RandomNumberGenerator.new()
	rng.seed=3
	var p={"preference":"辣味","dislikes":[],"regular":null,"special_want":2,"wish":3}
	check(P.choose(p,[6,7,9],rng)==9,"prefers spicy")
	p.dislikes=["辣味"]
	check(P.choose(p,[6,9],rng)==6 and P.choose(p,[9],rng)==9,"avoids disliked dishes until only choice")
	p.dislikes=[]
	var g=load("res://main.tscn").instantiate()
	g.auto_load=false
	root.add_child(g)
	g.set_process(false)
	g.ready_food=[20,20,20,20,20,20,20]
	g.formulas[2]=[]
	g.dishes_unlocked.append(2)
	g.menu.specials=[0,2]
	g.start_business()
	var guest=g.guests[0]
	guest.profile=p
	check(g.preferred_special(guest)==2,"stocked special first")
	g.ready_food[3]=0
	check(g.preferred_special(guest)!=2,"missing one core rules out special")
	for food in [3,0]:
		var diner=guest.duplicate(true)
		diner.profile=p
		diner.pot_food=food
		diner.side_portions=1
		g.finish_side(diner)
		check(diner.liked==(food==3),"liked follows actual food")
		g.guests[0]=diner
		var missed=g.missed_taste
		g.checkout(0)
		check(g.missed_taste-missed==int(food!=3),"settlement taste count")
	for error in errors: push_error(error)
	quit(0 if errors.is_empty() else 1)

extends SceneTree
const D=preload("res://systems/dishes.gd")
var errors=[]
func check(ok:bool,message:String):
	if not ok: errors.append(message)
func _initialize(): call_deferred("run")
func run():
	var g=load("res://main.tscn").instantiate()
	g.auto_load=false
	root.add_child(g)
	g.set_process(false)
	for group in D.CAPS:
		var ids=D.ids(group.trim_suffix("s"))
		check(ids.size()==(4 if group=="sides" else 6),"catalog "+group)
		var selected={group:[]}
		for i in ids.size():
			check(D.toggle(selected,ids,ids[i])==(i<D.CAPS[group]),"capacity "+group)
	var old=g.snapshot()
	old.version=4
	old.erase("menu")
	old.erase("dishes_unlocked")
	old.regular_menu=[true,false,true,true,true,true,true]
	old.formulas=[[],null,[4]]
	old.offerings=[false,true,true]
	old.ready=[3,4,5,6,7,8,9]
	g.apply_save(old)
	check(g.menu=={"mains":[7,8],"sides":[12,13,14],"specials":[2]},"legacy selections")
	check(2 in g.dishes_unlocked and 1 not in g.dishes_unlocked,"legacy research")
	var current=g.snapshot()
	check(current.version==5 and g.save_store.validate(current)=="","valid v5")
	check(g.save_game() and g.load_game(),"disk round trip")
	check(g.menu==current.menu and g.dishes_unlocked==current.dishes_unlocked,"round trip selections")
	check(g.ready_food==old.ready and g.raw==old.raw and g.money==old.money,"migration conserves stock and money")
	current.menu.specials.append(8)
	check(g.save_store.validate(current)!="","reject wrong kind")
	for error in errors: push_error(error)
	quit(0 if errors.is_empty() else 1)

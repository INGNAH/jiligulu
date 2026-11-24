extends SceneTree

func _initialize():
	call_deferred("run")

func press_button(game,prefix:String)->bool:
	for child in game.panel_box.get_children():
		if child is Button and child.text.begins_with(prefix):
			child.pressed.emit()
			return true
	return false

func run():
	var game=load("res://main.tscn").instantiate()
	game.auto_load=false
	root.add_child(game)
	game.set_process(false)
	game.offerings=[true,false,false]
	game.ready_food=[100,100,100,100,100,100,100]
	if not game.start_business():
		quit(1)
		return
	game.guest_target=2
	var chosen=-1
	var other=-1
	for tick in range(2400):
		game.tick_business(0.05)
		var open=[]
		for i in range(game.guests.size()):
			var g=game.guests[i]
			if g!=null and g.order==0: open.append(i)
		if open.size()==2 and game.guests[open[0]].trip.is_empty():
			chosen=open[0]
			other=open[1]
			break
	if chosen<0 or game.seat_tables[chosen]==game.seat_tables[other]:
		push_error("Two different tables never simultaneously requested the menu special")
		quit(1)
		return
	var diner=game.guests[chosen]
	var ignored=game.guests[other]
	var base=game.BASE[diner.order]
	var stock=game.ready_food[base]
	var click=InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=true
	click.position=(game.order_bubble(chosen).get_center()-game.view_focus)*game.view_zoom+game.VIEW_CENTER
	game._unhandled_input(click)
	var ok=press_button(game,"接单") and game.order_seat==chosen and game.ready_food[base]==stock-1
	game.refresh()
	ok=game.service_bar.visible and game.service_titles[0].text==game.seat_label(chosen) and ok
	game.player=game.layout.center(Vector2i(1,6))
	game.refresh()
	var portions=0
	for plate in game.plates:
		if game.layout.stations[plate.station].zone==0: portions+=plate.portions
	ok=game.service_titles[0].text.contains("出餐窗") and game.service_details[0].text.contains("余 %d 份"%portions) and ok
	game.player=game.layout.center(game.KITCHEN_STATION)
	game.refresh()
	ok=game.service_details[0].text.contains("已留") and game.service_details[1].text=="今晚未上菜单" and ok
	game.interact()
	ok=press_button(game,"取消接单") and game.ready_food[base]==stock and ok
	game.panel.hide()
	game.show_diner(chosen)
	ok=press_button(game,"接单") and ok
	click.position=(game.utensil_rect(0).get_center()-game.view_focus)*game.view_zoom+game.VIEW_CENTER
	game._unhandled_input(click)
	ok=press_button(game,"加料 火椒") and press_button(game,"加料开火") and game.kitchen_time>0 and game.ready_food[base]==stock-1 and ok
	game.refresh()
	ok=game.service_titles[1].text=="后厨制作中" and ok
	for tick in range(51): game.tick_business(0.05)
	game.refresh()
	ok=game.service_titles[1].text.contains("手持") and game.service_details[2].text==game.seat_label(chosen) and ok
	ok=not game.serve_guest(other) and game.held==base and ok
	game.player=game.layout.center(game.layout.service_spots[game.layout.cell(game.seats[chosen])])
	game.interact()
	ok=diner.bonus and game.tips==11 and game.order_seat==-1 and ok
	for tick in range(3100):
		if game.phase!="营业": break
		game.tick_business(0.05)
	game.refresh()
	ok=not game.service_bar.visible and game.slot_buttons[0].get_parent().visible and ok
	ok=game.served==2 and not ignored.bonus and game.income==2*game.menu_price+11 and ok
	print("Two tables, one optional order, kitchen, delivery and settlement: ",ok)
	quit(0 if ok else 1)

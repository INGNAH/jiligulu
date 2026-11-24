extends SceneTree
var failures=0
func check(ok: bool, message: String):
	if ok: print("PASS: ",message)
	else: failures+=1;push_error(message)
func _initialize(): call_deferred("run")
func run():
	var store=load("res://systems/save_store.gd").new()
	var data={"version":1,"money":150,"day":1,"raw":[0,0,0,0,0,0],"ready":[0,0,0,0,0,0,0]}
	check(store.write(store.slot_path(1),data).ok,"first slot saves and creates parent directory")
	data.money=99
	check(store.write(store.slot_path(1),data).ok and store.read_file(store.slot_path(1)+".bak").data.money==150,"second save backs up previous valid state")
	store.write_text(store.slot_path(1),"{broken")
	var recovered=store.read(store.slot_path(1))
	check(recovered.ok and recovered.recovered and recovered.data.money==150,"corrupt primary restores last valid backup")
	data.money=123
	check(store.write(store.slot_path(1),data).ok and FileAccess.file_exists(store.slot_path(1)+".corrupt"),"saving after recovery preserves corrupt original for diagnosis")
	check(store.read_file(store.slot_path(1)+".bak").data.money==150,"recovery never replaces good backup with corrupt bytes")
	var bad=data.duplicate(true);bad.raw=[1,2]
	check(not store.write(store.slot_path(1),bad).ok and store.read(store.slot_path(1)).data.money==123,"invalid inventory rejected without overwriting valid progress")
	bad=data.duplicate(true);bad.version=999
	check(not store.validate(bad).is_empty(),"unknown future schema rejected")
	bad=data.duplicate(true);bad.phase="营业"
	check(not store.validate(bad).is_empty(),"partial live-business snapshots rejected")
	bad=data.duplicate(true);bad.layout={"shape":0,"tables":[{"x":0}],"stations":[]}
	check(not store.validate(bad).is_empty(),"malformed furniture rejected before layout restore")
	bad=data.duplicate(true);bad.money="money"
	check(not store.validate(bad).is_empty(),"wrong numeric types rejected")
	check(not store.write("",data).ok,"invalid path reports save failure")
	store.write_text("user://blocked","not a folder")
	check(not store.write("user://blocked/slot.json",data).ok,"unwritable destination does not report false save success")
	store.write(store.LEGACY,data)
	check(store.import_legacy(2).ok and store.read(store.LEGACY).data.money==123,"legacy import copies progress and preserves source")
	check(not store.import_legacy(2).ok,"legacy import cannot overwrite occupied slot")
	data.money=250;store.write(store.slot_path(3),data)
	check(store.info(1).data.money==123 and store.info(3).data.money==250,"save slots remain independent")
	var config=load("res://systems/settings_store.gd").new()
	config.master_volume=0.25;config.auto_pause=false;config.fullscreen=false
	check(config.save_settings(),"settings file saved independently")
	var next_config=load("res://systems/settings_store.gd").new();next_config.load_settings()
	check(next_config.master_volume==0.25 and not next_config.auto_pause,"settings restore stored values")
	var app=load("res://app.tscn").instantiate();root.add_child(app)
	app.settings.auto_pause=false
	check(app.screen_name=="title" and app.game==null,"boot reaches title without starting or changing a save")
	app.request_new(1)
	check(app.screen_name=="new_confirm" and store.info(1).data.money==123,"new game in occupied slot requires in-game confirmation")
	app.show_title();app.start_game(1,false)
	check(app.game.money==123 and app.selected_slot==1 and app.screen_name=="game","continue loads selected slot")
	app.game.ready_food=[20,20,20,20,20,20,2]
	check(app.game.start_business(),"opening creates a recoverable preparation checkpoint")
	var checkpoint=store.info(1).data
	check(checkpoint.phase=="准备" and checkpoint.ready[0]==20,"pre-opening checkpoint includes prepared dishes")
	app.game.panel.hide();app.pause_game()
	var elapsed=app.game.elapsed
	await create_timer(0.1,true).timeout
	check(is_equal_approx(app.game.elapsed,elapsed) and paused,"paused application stops restaurant simulation")
	app.resume_game()
	await create_timer(0.1,true).timeout
	check(app.game.elapsed>elapsed,"resume restarts simulation")
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not paused,"focus-loss pause can be disabled")
	app.settings.auto_pause=true;app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(paused and app.screen_name=="pause","focus-loss pause works when enabled")
	app.request_leave(false)
	check(app.screen_name=="leave_confirm" and is_instance_valid(app.game),"leaving a live night requires confirmation")
	app.finish_leave()
	check(app.game==null and app.screen_name=="title" and not paused,"confirmed leave unloads session and returns to title")
	app.start_game(1,false)
	check(app.game.phase=="准备" and app.game.ready_food[0]==20,"continue after abort restores complete pre-opening state")
	app.game.money=111;app.request_leave(false);app.finish_leave()
	check(store.info(1).data.money==111,"leaving preparation saves current progress")
	app.start_game(3,false)
	check(app.game.money==250,"switching slots does not carry previous game cash")
	app.game.save_path="user://blocked/slot.json";app.request_leave(false);app.finish_leave()
	check(is_instance_valid(app.game) and app.screen_name=="leave_error" and paused,"save failure keeps live session available instead of silently quitting")
	app.game.save_path=store.slot_path(3);app.resume_game()
	app.game.phase="准备";app.game.raw=[2,1,0,3,0,1];app.game.ready_food=[0,0,0,0,0,0,0]
	check(app.game.prepare_all()==14 and app.game.raw==[0,0,0,0,0,0] and app.game.ready_food==[4,2,0,6,0,2,0],"batch preparation conserves ingredients and produces exact plates")
	app.game.menu_price=18
	check(app.game.expected_guests()==12,"budget price increases expected customers")
	app.game.menu_price=30
	check(app.game.expected_guests()==8,"premium price lowers expected customers")
	app.game.staff_exp=0;var slow=app.game.staff_speed();app.game.staff_exp=30
	check(app.game.staff_level()==2 and app.game.staff_speed()>slow,"employee level two increases travel efficiency")
	app.game.staff_exp=60
	check(app.game.staff_level()==3 and app.game.staff_capacity()==4,"employee level three increases carrying capacity")
	# Test an actual premium evening with stock conservation and meal-price reconciliation.
	app.game.employee=true;app.game.ready_food=[20,20,20,20,20,20,3];app.game.food_served=[0,0,0,0,0,0,0]
	app.game.income=0;app.game.spending=0;app.game.served=0;app.game.satisfaction=0
	var cash=app.game.money
	check(app.game.start_business() and app.game.guest_target==8,"premium pricing applies to next business session")
	app.game.set_process(false)
	var initial=123
	for i in range(1600):
		if app.game.phase!="营业": break
		app.game.tick_business(0.1)
	var remaining=app.game.ready_food.reduce(func(a,b):return a+b,0)
	var eaten=app.game.food_served.reduce(func(a,b):return a+b,0)
	check(app.game.served==8 and app.game.phase=="结算","premium session completes all eight guests")
	check(eaten+remaining==initial,"sales report and remaining stock conserve all food")
	check(app.game.money==cash+app.game.income-app.game.spending and app.game.income==app.game.served*app.game.menu_price+app.game.tips,"uniform buffet fees reconcile with wage and cash")
	var settled=app.game.money;app.game.end_day()
	check(app.game.money==settled,"repeated closing cannot charge wages or pay meals twice")
	app.game.save_game();app.game.menu_price=18;app.game.staff_exp=0;app.game.load_game()
	check(app.game.menu_price==30 and app.game.staff_exp==60 and app.game.food_served.reduce(func(a,b):return a+b,0)==eaten,"price, employee progression and dish report persist")
	app.queue_free();paused=false
	print("RESULT: ",failures," failures")
	quit(1 if failures else 0)

extends SceneTree
const Staff=preload("res://systems/staff.gd")

var errors=[]
func check(ok:bool,message:String):
	if not ok: errors.append(message)

func _initialize(): call_deferred("run")

func sum_ints(arr:Array)->int:
	return arr.reduce(func(a,b):return a+int(b),0)

func measure_first_main_wait(root_node:Node,order_hired:bool,deliver_hired:bool)->float:
	var g=load("res://main.tscn").instantiate()
	g.auto_load=false
	root_node.add_child(g)
	g.set_process(false)
	g.ready_food=[20,20,20,20,20,20,20]
	g.staff.order.hired=order_hired
	g.staff.deliver.hired=deliver_hired
	g.start_business()
	g.guest_target=1
	var diner=g.guests[0]
	diner.position=g.seats[0]
	diner.trip.clear()
	for step in range(800):
		g.tick_business(0.05)
		if diner.has("served_at"): break
	var waited=float(diner.get("served_at",999.0))
	g.queue_free()
	return waited

func run_evening_for_roles(root_node:Node,roles_to_hire:Array)->Dictionary:
	var g=load("res://main.tscn").instantiate()
	g.auto_load=false
	root_node.add_child(g)
	g.set_process(false)
	g.money=300
	g.spending=0
	g.income=0
	g.ready_food=[24,30,24,18,18,18,12]
	var initial_stock=sum_ints(g.ready_food)
	for role in roles_to_hire:
		check(g.hire(role),"hire "+role)
	var after_hire_money=g.money
	var hire_spent=g.spending
	check(hire_spent==roles_to_hire.size()*Staff.HIRE_COST and after_hire_money==300-hire_spent,"hire cost conserved")
	check(g.start_business(),"open evening")
	for step in range(3100):
		if g.phase!="营业": break
		g.tick_business(0.05)
	var settled_money=g.money
	var wage_spent=g.spending-hire_spent
	g.end_day()
	var out={
		"phase":g.phase,
		"served":g.served,
		"target":g.guest_target,
		"wage":wage_spent,
		"money_ok":g.money==300+g.income-g.spending and g.money==settled_money,
		"stock_conserved":sum_ints(g.food_served)+sum_ints(g.ready_food)==initial_stock,
		"staff":Staff.serialize(g.staff),
	}
	g.queue_free()
	return out

func run():
	# 1. Without an order-taker or deliverer, main-course wait increases by at least the configured threshold; hiring restores responsiveness.
	var wait_both_hired=measure_first_main_wait(root,true,true)
	var wait_no_order=measure_first_main_wait(root,false,true)
	var wait_no_deliver=measure_first_main_wait(root,true,false)
	check(wait_no_order-wait_both_hired>=Staff.UNHIRED_ORDER_DELAY,"missing order staff measurably delays first main")
	check(wait_no_deliver-wait_both_hired>=Staff.UNHIRED_DELIVER_DELAY,"missing delivery staff measurably delays first main")

	# 2. Independent recruitment, progression, speed/capacity scaling, zone priority, and Lv.3 dual-dish delivery.
	var g=load("res://main.tscn").instantiate()
	g.auto_load=false
	root.add_child(g)
	g.set_process(false)
	g.money=200
	check(g.hire("order") and not g.hire("order") and g.money==200-Staff.HIRE_COST,"order role hired once")
	check(not g.staff.deliver.hired and not g.staff.refill.hired,"other roles remain unhired")
	check(Staff.dispatch_delay(g.staff,"order")==0.0 and Staff.dispatch_delay(g.staff,"deliver")==Staff.UNHIRED_DELIVER_DELAY,"hiring clears only that role delay")

	var order_lv1_speed=g.staff_speed("order")
	g.staff.order.exp=30
	check(g.staff_level("order")==2 and g.staff_speed("order")>order_lv1_speed and g.staff_level("deliver")==1 and g.staff_level("refill")==1,"independent level two speed boost")
	g.staff.order.exp=60
	check(g.staff_level("order")==3 and g.staff_capacity("order")==2 and g.staff_capacity("deliver")==1,"level three increases order capacity independently")

	g.staff.deliver.hired=true
	var deliver_lv1_speed=g.staff_speed("deliver")
	g.staff.deliver.exp=60
	check(g.staff_level("deliver")==3 and g.staff_speed("deliver")>deliver_lv1_speed and g.staff_capacity("deliver")==2,"deliver level three boosts speed and carry capacity")

	# Zone assignment prioritizes waiting diners in the assigned zone.
	g.ready_food=[20,20,20,20,20,20,20]
	g.staff.order.zone=1
	check(g.start_business(),"open for zone and batch checks")
	g.spawn_guest()
	var zone0_seat=-1
	var zone1_seat=-1
	for s in range(g.guests.size()):
		if g.guests[s]==null: continue
		g.guests[s].position=g.seats[s]
		g.guests[s].trip.clear()
		g.guests[s].wait=5.0
		var z=g.layout.tables[g.seat_tables[s]].zone
		if z==0 and zone0_seat<0: zone0_seat=s
		if z==1 and zone1_seat<0: zone1_seat=s
	check(zone0_seat>=0 and zone1_seat>=0 and g.choose_table_service_seat("order")==zone1_seat,"assigned zone prioritized")

	# Player manual actions cover missing roles while conserving stock.
	var stock_before=sum_ints(g.ready_food)+sum_ints(g.food_served)
	check(g.take_main_order(zone0_seat) and g.guests[zone0_seat].get("service","")=="ordered","player manually takes main order")
	g.player=g.layout.center(g.KITCHEN_STATION)
	check(g.pickup_main_order(zone0_seat) and g.held>=0,"player picks up ordered main at kitchen")
	g.player=g.seats[zone0_seat]
	check(g.deliver_main_order(zone0_seat) and g.held==-1 and g.guests[zone0_seat].get("service","")=="served","player delivers main to table")
	check(sum_ints(g.ready_food)+sum_ints(g.food_served)==stock_before,"manual main delivery conserves stock")

	g.player=g.layout.center(g.KITCHEN_STATION)
	var side_food=g.SIDE_FOODS[0]
	var side_stock_before=g.ready_food[side_food]
	check(g.pickup_side_tray(side_food) and g.held==side_food,"player picks up side tray")
	check(g.refill_station_manual(0) and g.held==-1 and g.ready_food[side_food]==side_stock_before-1 and g.station_plate_count(0)==1,"player manually refills side station")

	# Lv.3 deliverer batches two ordered mains in one kitchen pickup.
	g.take_main_order(zone1_seat)
	g.guests[zone0_seat].service="waiting"
	g.take_main_order(zone0_seat)
	var deliver_worker=g.service_team[1]
	deliver_worker.pos=g.layout.center(g.layout.pickup)
	deliver_worker.path=[]
	deliver_worker.stage="kitchen"
	deliver_worker.seat=zone1_seat
	deliver_worker.ticket=g.guests[zone1_seat].ticket
	g.guests[zone1_seat].service="preparing"
	g.tick_table_service(deliver_worker,0.05)
	check(deliver_worker.stage=="deliver" and deliver_worker.extra.size()==1,"level three deliverer carries second main in one run")
	g.end_day()

	# 3. Legacy save migration, v5 round-trip, and schema validation.
	var legacy=g.snapshot()
	legacy.erase("staff")
	legacy.employee=true
	legacy.staff_exp=45
	legacy.staff_zone=2
	g.apply_save(legacy)
	check(g.staff.refill=={"hired":true,"exp":45,"zone":2} and not g.staff.order.hired and not g.staff.deliver.hired,"legacy employee fields migrate to staff.refill")

	g.staff.order={"hired":true,"exp":32,"zone":1}
	g.staff.deliver={"hired":false,"exp":0,"zone":-1}
	g.staff.refill={"hired":true,"exp":60,"zone":0}
	var expected_staff=Staff.serialize(g.staff)
	check(g.save_store.validate(g.snapshot())=="","staff snapshot validates")
	check(g.save_game() and g.load_game() and g.staff==expected_staff,"all three roles persist across save and load")

	var invalid=g.snapshot()
	invalid.staff.order.exp=99
	check(g.save_store.validate(invalid)!="","reject out-of-range staff exp")
	invalid=g.snapshot()
	invalid.staff.deliver.zone=5
	check(g.save_store.validate(invalid)!="","reject invalid staff zone")
	invalid=g.snapshot()
	invalid.staff.erase("refill")
	check(g.save_store.validate(invalid)!="","reject incomplete staff table")
	g.queue_free()

	# 4. Wage settlement scales with hired role count (0, 2, 3) and conserves cash and food.
	var night0=run_evening_for_roles(root,[])
	var night2=run_evening_for_roles(root,["order","deliver"])
	var night3=run_evening_for_roles(root,["order","deliver","refill"])
	check(night0.phase=="结算" and night0.wage==0 and night0.money_ok and night0.stock_conserved,"zero hired roles pay zero wage and conserve stock")
	check(night2.phase=="结算" and night2.wage==2*Staff.DAILY_WAGE and night2.money_ok and night2.stock_conserved,"two hired roles pay two wages and conserve stock")
	check(night2.staff.order.exp>0 and night2.staff.deliver.exp>0 and night2.staff.refill.exp==0,"only hired roles gain evening exp")
	check(night3.phase=="结算" and night3.wage==3*Staff.DAILY_WAGE and night3.money_ok and night3.stock_conserved,"three hired roles pay three wages and conserve stock")

	await process_frame
	for e in errors: push_error(e)
	print("Staff failures: ",errors.size())
	quit(0 if errors.is_empty() else 1)

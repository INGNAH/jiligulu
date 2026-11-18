extends Node2D

const ING = ["灯笼菇", "霜角牛肉", "跳跳虾", "火椒", "云绵豆腐", "水晶萝卜"]
const COST = [3, 6, 5, 2, 3, 2]
const COLORS = [Color("e5ba70"), Color("e58087"), Color("f4a679"), Color("e35d50"), Color("fff0cd"), Color("a5d9cf")]
const SAVE_PATH = "user://starpot.json"
signal pause_requested
@export var save_path: String = SAVE_PATH
@export var auto_load: bool = true
var save_store=preload("res://systems/save_store.gd").new()
var save_error=""
const FILL=[26,42,25,14,46,18,52]
const TASTE=["鲜香","肉类","海鲜","辣味","清淡","甜酸"]
const SPECIALS=["香煎霜牛","酸甜萝卜","椒香跳跳虾"]
const BASE=[1,5,2]
const FACILITY=["蘸料","饮料","冰淇淋","等候长椅"]
var facility_kind=0
var offerings=[true,true,true]
var kitchen_time=0.0
var cooked=-1
var reputation=70
var event_booked=false
var bulletin="今天是开业第一天。"
var waiting=[]
var lost=0
var missed_taste=0
var menu_price=24
var guest_target=10
var staff_exp=0
var staff_trips=0
var business_history=[]
var food_served=[0,0,0,0,0,0,0]
var last_save_ok=true
@export var art_pack: Resource = preload("res://art/default_pack.tres")
var art = preload("res://rendering/art_renderer.gd").new()
var player_motion = false
var staff_motion = false
var art_clock = 0.0
var layout = preload("res://layout.gd").new()
var build_mode = false
var build_tool = "table"
var build_rot = 0
var build_zone = 0
var moving_table = -1
var layout_plans = [null, null, null]
var layout_history: Array = []
var tool_buttons: Dictionary = {}
var build_bar: HBoxContainer
var build_info: Label
var action_label: Label
var slot_buttons: Array = []
var staff_pos = Vector2(360,650)
var staff_path: Array = []
var staff_carry: Array = []
var staff_route = -1
var staff_feeder = 0
var staff_state = "备餐区"
var staff_zone = -1
var staff_animation = 0.0
var last_brush = Vector2i(-100,-100)
var zone_stats: Array = []
var font = preload("res://assets/font.otf")
var money = 150
var day = 1
var raw = [0,0,0,0,0,0]
var ready_food = [0,0,0,0,0,0,0]
var mastery = 0
var affection = 0
var employee = false
var decor = false
var decor_pos = Vector2(1080, 600)
var phase = "准备"
var selected = 0
var held = -1
var player = Vector2(630,600)
var plates: Array = []
var guests: Array = []
var elapsed = 0.0
var spawn_clock = 0.0
var staff_clock = 0.0
var spawned = 0
var income = 0
var spending = 0
var tips = 0
var served = 0
var satisfaction = 0
var special_done = false
var ui: Control
var top: Label
var hint: Label
var status: Label
var panel: PanelContainer
var panel_box: VBoxContainer
var toast_text = "欢迎来到星灯回转锅。先逛市场，再去料理台！"
var toast_time = 8.0
var cooking = false
var cook_time = 0.0
var cook_cursor: ProgressBar
var summary = ""
var furniture_mode = false
var seats: Array = []
var seat_tables: Array = []

func _ready():
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	art.configure(art_pack)
	for problem in art.errors: push_warning("Art: "+problem)
	var theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = 17
	var card = StyleBoxFlat.new()
	card.bg_color = Color("303b49")
	card.corner_radius_top_left = 16
	card.corner_radius_top_right = 16
	card.corner_radius_bottom_left = 16
	card.corner_radius_bottom_right = 16
	card.content_margin_left = 16
	card.content_margin_right = 16
	card.content_margin_top = 16
	card.content_margin_bottom = 16
	theme.set_stylebox("panel", "PanelContainer", card)
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color("46596a")
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	theme.set_stylebox("normal", "Button", normal)
	var hover = normal.duplicate()
	hover.bg_color = Color("637e8b")
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", hover)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = theme
	add_child(ui)
	top = label_at(Vector2(30,18),24)
	hint = label_at(Vector2(30,720),17)
	status = label_at(Vector2(30,768),15)
	var help = label_at(Vector2(30,65),15)
	help.text = "WASD 移动 · E 交互 · 1—7 选菜 · Q 放回 · B 布局 · P 暂停 · Esc 关闭"
	var menu = Button.new()
	menu.text = "店长手册 / 存档"
	menu.position = Vector2(1060,18)
	menu.pressed.connect(show_menu)
	ui.add_child(menu)
	panel = PanelContainer.new()
	panel.position = Vector2(825,100)
	panel.custom_minimum_size = Vector2(410,560)
	panel_box = VBoxContainer.new()
	panel_box.add_theme_constant_override("separation",10)
	var scroll=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(400,528)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	panel_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(panel_box)
	panel.add_child(scroll)
	ui.add_child(panel)
	panel.hide()
	var build_button = Button.new()
	build_button.text = "店铺布局 [B]"
	build_button.position = Vector2(1060,60)
	build_button.pressed.connect(toggle_build)
	ui.add_child(build_button)
	build_bar = HBoxContainer.new()
	build_bar.position = Vector2(30,108)
	build_bar.add_theme_constant_override("separation",6)
	ui.add_child(build_bar)
	for tool in [["table","放桌椅"],["move","移动"],["belt","铺餐带"],["feeder","补餐点"],["zone","改分区"],["erase","拆除"]]:
		var b = Button.new()
		b.text = tool[1]
		b.pressed.connect(func(): build_tool=tool[0]; moving_table=-1)
		build_bar.add_child(b)
		tool_buttons[tool[0]]=b
	for item in [["设施",choose_facility],["分区",func(): build_zone=(build_zone+1)%3],["旋转 R",func(): build_rot=(build_rot+1)%4],["撤销",undo_layout],["房型",cycle_shape],["方案",show_layout_plans],["还原布局",reset_layout],["完成",toggle_build]]:
		var b=Button.new(); b.text=item[0]; b.pressed.connect(item[1]); build_bar.add_child(b)
	build_info=label_at(Vector2(30,169),16)
	action_label=label_at(Vector2(30,743),16)
	var slots=HBoxContainer.new()
	slots.position=Vector2(30,685)
	slots.add_theme_constant_override("separation",6)
	ui.add_child(slots)
	for i in range(7):
		var b=Button.new()
		b.add_theme_font_size_override("font_size",14)
		b.custom_minimum_size=Vector2(163,30)
		b.focus_mode=Control.FOCUS_NONE
		b.pressed.connect(func(): selected=i)
		slots.add_child(b); slot_buttons.append(b)
	sync_seats()
	if auto_load and (FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path+".bak")): load_game()
	refresh()

func label_at(pos: Vector2, size: int) -> Label:
	var l = Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size",size)
	ui.add_child(l)
	return l

func dish_name(i: int) -> String:
	return "清炖霜牛" if i == 6 else ING[i]

func notify(s: String):
	toast_text = s
	toast_time = 6

func refresh():
	top.text = "星灯回转锅 / 第 %d 天 · %s   金币 %d   收入 %d" % [day,phase,money,income]
	status.text = toast_text if toast_time > 0 else "布局提示：餐带同色闭环；桌椅邻接同区餐带；补餐点紧邻同区餐带。"
	var guide = "营业 %d 秒 · 已结账 %d/%d" % [maxi(0,150-int(elapsed)),served,guest_target] if phase=="营业" else "准备期 · 左上采购，左下备菜，左侧铃铛开门"
	hint.text="手持：%s   |   %s"%["空盘托" if held<0 else SPECIALS[cooked] if cooked>=0 else dish_name(held),guide]
	action_label.text=nearby_action()
	if phase=="营业": action_label.text+="　叫号区 %d人等候"%waiting.size()
	for i in range(slot_buttons.size()):
		slot_buttons[i].text="%s%d %s ×%d"%["▶" if selected==i else "",i+1,dish_name(i),ready_food[i]]
		slot_buttons[i].modulate=Color("ffe2a2") if selected==i else Color.WHITE
	for tool in tool_buttons:
		tool_buttons[tool].modulate=Color("ffe2a2") if tool==build_tool else Color.WHITE
	build_bar.visible=build_mode
	build_info.visible=build_mode
	if build_mode:
		build_info.text="%s · %s区 · 旋转%d° | 左键操作，餐带可拖画 / 右键取消或拆除"%[{"facility":FACILITY[facility_kind],"table":"放桌椅","move":"点击桌子，再点新位置","belt":"铺闭环餐带","feeder":"放补餐点","zone":"给桌子或餐带改区","erase":"拆除"}[build_tool],layout.zone_name(build_zone),build_rot*90]
		action_label.text="B / 完成：退出布局；放置免费。房型切换保留家具，请修复红色提示后营业。"

func nearby_action() -> String:
	if build_mode: return ""
	if player.distance_to(Vector2(160,220))<120: return "[E] 打开采购" if phase!="营业" else "商户已收摊"
	if player.distance_to(Vector2(190,580))<135: return "[C] 现做加单 / [E] 拿 %s（剩 %d）"%[dish_name(selected),ready_food[selected]] if phase=="营业" else "[E] 打开料理台"
	if player.distance_to(Vector2(160,365))<80: return "[E] 开店 / 招聘 / 岗位安排"
	if phase=="营业":
		for i in range(seats.size()):
			if guests[i]!=null and player.distance_to(seats[i])<65 and held>=0: return "[E] 给这位客人送 %s"%dish_name(held)
		for r in range(layout.routes.size()):
			for f in layout.routes[r].feeders:
				if player.distance_to(layout.center(f.cell))<65: return "[E] 从补餐点放上 %s区餐带"%layout.zone_name(layout.routes[r].zone)
	return "靠近设施查看操作；先选菜，料理台拿菜，再到补餐点或客人旁按 E。"

func sync_seats():
	seats.clear(); seat_tables.clear(); guests.clear()
	for i in range(layout.tables.size()):
		for c in layout.chairs(layout.tables[i]):
			seats.append(layout.center(c));seat_tables.append(i);guests.append(null)

func remember_layout():
	layout_history.append(layout.snapshot())
	if layout_history.size()>40: layout_history.pop_front()

func undo_layout():
	if layout_history.is_empty(): return
	layout.restore(layout_history.pop_back());moving_table=-1;sync_seats()

func toggle_build():
	if phase!="准备": notify("准备期才能调整布局，先完成当晚营业。");return
	panel.hide(); cooking=false;build_mode=not build_mode;moving_table=-1
	layout.compile();sync_seats()
	if not build_mode:
		if not player_can_stand(player): player=layout.center(Vector2i(0,11))
		save_game()
		if not layout.errors.is_empty(): notify(layout.errors[0])

func cycle_shape():
	remember_layout();layout.shape=(layout.shape+1)%3;layout.compile()
	notify("房型：%s。已有桌椅保留，请移动超出地板的家具。"%["方形","长条","L形"][layout.shape])

func show_layout_plans():
	if phase!="准备": return
	clear_panel("布局方案")
	for slot in range(layout_plans.size()):
		var plan=layout_plans[slot]
		var title="方案 %d"%(slot+1)
		if plan==null:
			button(title+" · 保存当前布局",store_layout_plan.bind(slot))
		else:
			line("%s · %s · %d桌 / %d格餐带"%[title,["方形","长条","L形"][int(plan.shape)],plan.tables.size(),plan.belts.size()])
			button("使用"+title,apply_layout_plan.bind(slot))
			button("更新"+title,confirm_plan_update.bind(slot))
	close_button()

func confirm_plan_update(slot: int):
	clear_panel("更新方案 %d？"%(slot+1))
	line("将用当前店铺布局替换这份方案。")
	button("确认替换",store_layout_plan.bind(slot))
	button("返回方案",show_layout_plans)

func store_layout_plan(slot: int):
	if phase!="准备" or slot<0 or slot>=layout_plans.size(): return
	var previous=layout_plans[slot]
	layout_plans[slot]=layout.snapshot()
	if not save_game():
		layout_plans[slot]=previous
	show_layout_plans()

func apply_layout_plan(slot: int):
	if phase!="准备" or slot<0 or slot>=layout_plans.size() or layout_plans[slot]==null: return
	remember_layout()
	layout.restore(layout_plans[slot])
	sync_seats()
	moving_table=-1
	panel.hide()
	notify("已使用方案 %d。可撤销，完成布局后保存。"%(slot+1))

func reset_layout():
	clear_panel("还原店铺布局？")
	line("将替换当前桌椅、餐带和补餐点，恢复方形双区布局。资金与食材保留。可以用撤销恢复。")
	button("确认还原",func(): remember_layout();layout.reset();sync_seats();panel.hide())
	close_button()

func edit_cell(c: Vector2i):
	if not layout.floor_at(c) and build_tool!="erase" and build_tool!="move": return
	if build_tool=="move" and moving_table<0:
		moving_table=layout.table_at(c)
		if moving_table>=0: build_rot=layout.tables[moving_table].rot;build_zone=layout.tables[moving_table].zone
		return
	remember_layout()
	var success=true
	match build_tool:
		"facility": success=layout.place_facility(c,facility_kind)
		"table": success=layout.place_table(c,build_rot,build_zone)
		"move":
			if moving_table>=0:
				success=layout.place_table(c,build_rot,build_zone,moving_table)
				if success: moving_table=-1
		"belt": success=layout.place_belt(c,build_zone)
		"feeder": success=layout.place_feeder(c,build_zone)
		"erase": layout.erase(c)
		"zone":
			var i=layout.table_at(c)
			if i>=0: layout.tables[i].zone=build_zone
			elif layout.belts.has(c): layout.belts[c]=build_zone
			else:
				for f in layout.feeders:
					if c==Vector2i(f.x,f.y): f.zone=build_zone
	if not success:
		layout_history.pop_back();notify("不能放在这里：需要完整地板，桌椅和设备不能重叠。")
	layout.compile();sync_seats()

func player_can_stand(p: Vector2) -> bool:
	if not Rect2(65,185,1145,475).has_point(p): return false
	for offset in [Vector2(-10,-8),Vector2(10,-8),Vector2(-10,8),Vector2(10,8)]:
		var q=p+offset
		if q.x>=layout.ORIGIN.x and not layout.walkable(layout.cell(q)): return false
	return true

func _process(dt):
	var before_player=player
	var before_staff=staff_pos
	toast_time -= dt
	if not panel.visible and not furniture_mode and not build_mode and kitchen_time<=0:
		var v = Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
		var next = player + v.normalized()*230*dt
		next.x = clampf(next.x,80,1190)
		next.y = clampf(next.y,195,650)
		if player_can_stand(Vector2(next.x,player.y)): player.x=next.x
		if player_can_stand(Vector2(player.x,next.y)): player.y=next.y
	if build_mode and not panel.visible and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and build_tool in ["belt","erase","zone"]:
		var c=layout.cell(get_global_mouse_position())
		if c!=last_brush: last_brush=c;edit_cell(c)
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): last_brush=Vector2i(-100,-100)
	if cooking and is_instance_valid(cook_cursor):
		cook_time += dt
		cook_cursor.value = (sin(cook_time*3.0)+1)*50
	if phase == "营业" and not panel.visible: tick_business(dt)
	player_motion=player.distance_to(before_player)>0.01
	staff_motion=staff_pos.distance_to(before_staff)>0.01
	art_clock+=dt
	art.actor_time("player",player_animation(),dt)
	art.actor_time("lumi",staff_animation_name(),dt)
	refresh()
	queue_redraw()

func _unhandled_key_input(e):
	if not e is InputEventKey or not e.pressed or e.echo: return
	if e.keycode==KEY_B: toggle_build();return
	if build_mode:
		if e.keycode==KEY_ESCAPE:
			if panel.visible: panel.hide()
			elif moving_table>=0: moving_table=-1
			else: toggle_build()
		elif e.keycode==KEY_R: build_rot=(build_rot+1)%4
		elif e.keycode>=KEY_1 and e.keycode<=KEY_3: build_zone=e.keycode-KEY_1
		return
	if e.keycode == KEY_ESCAPE:
		cooking = false
		panel.hide()
		furniture_mode = false
	elif e.keycode >= KEY_1 and e.keycode <= KEY_7: selected = e.keycode-KEY_1
	elif kitchen_time>0: return
	elif e.keycode==KEY_C and phase=="营业" and not panel.visible and player.distance_to(Vector2(190,580))<135: kitchen_orders()
	elif e.keycode == KEY_Q and held >= 0:
		cooked=-1
		ready_food[held] += 1
		held = -1
	elif e.keycode == KEY_F and phase != "营业" and decor:
		panel.hide()
		furniture_mode = not furniture_mode
		notify("点击地板摆放星灯盆栽；F / Esc 退出。")
	elif e.keycode == KEY_E and not panel.visible: interact()

func _unhandled_input(e):
	if phase=="营业" and not panel.visible and e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT and e.pressed:
		for i in range(guests.size()-1,-1,-1):
			var g=guests[i]
			if g!=null and e.position.distance_to(g.position+Vector2(0,-19))<26:
				clear_panel("莱恩" if g.special else "客人 %d"%(g.ticket+1))
				line("喜好："+TASTE[g.wish]+" · "+ING[g.wish])
				line("饱腹 %d / %d"%[g.full,g.capacity])
				if g.order>=0: line("加单："+SPECIALS[g.order]+("（已送达）" if g.bonus else ""))
				close_button();return
	if build_mode and not panel.visible and e is InputEventMouseButton and e.pressed:
		var c=layout.cell(e.position)
		if e.button_index==MOUSE_BUTTON_LEFT:
			last_brush=c;edit_cell(c)
		elif e.button_index==MOUSE_BUTTON_RIGHT:
			if moving_table>=0: moving_table=-1
			else:
				remember_layout();layout.erase(c);layout.compile();sync_seats()
		return
	if furniture_mode and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var p = e.position
		if Rect2(90,170,1080,470).has_point(p) and not Rect2(320,230,650,330).has_point(p):
			decor_pos = p
			furniture_mode = false
			save_game()

func interact():
	if player.distance_to(Vector2(160,220)) < 120:
		if phase == "营业": notify("商户收摊了，明天再采购。")
		else: show_market()
		return
	if player.distance_to(Vector2(190,580)) < 135:
		if phase == "营业": take_food()
		else: show_kitchen()
		return
	if player.distance_to(Vector2(160,365)) < 80:
		if phase == "结算": show_summary()
		elif phase != "营业": show_open()
		return
	if phase == "营业":
		if held >= 0:
			if cooked>=0:
				for i in range(guests.size()):
					var g=guests[i]
					if g!=null and g.order==cooked and not g.bonus and g.trip.is_empty() and player.distance_to(seats[i])<65:
						serve_guest(i);return
				notify("请到点了这道菜的客人桌旁，等客人回座后送餐。");return
			for r in range(layout.routes.size()):
				for f in layout.routes[r].feeders:
					if player.distance_to(layout.center(f.cell))<65:
						if add_plate(r,held,f.index): held=-1
						else: notify("这条餐带已满，等客人取餐。")
						return
		notify("料理台取菜 → 同区补餐点放菜；也可直接给客人送喜欢的菜。")

func clear_panel(title: String):
	cooking = false
	for c in panel_box.get_children():
		panel_box.remove_child(c)
		c.queue_free()
	var l = Label.new()
	l.text = title
	l.add_theme_font_size_override("font_size",24)
	panel_box.add_child(l)
	if title=="星灯营业铃":
		var portrait=art.portrait(["portrait/lumi/neutral"],Vector2(360,140))
		if portrait!=null: panel_box.add_child(portrait)
	panel.show()

func line(s: String):
	var l = Label.new()
	l.text = s
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 390
	panel_box.add_child(l)

func button(s: String, f: Callable):
	var b = Button.new()
	b.text = s
	b.pressed.connect(f)
	panel_box.add_child(b)

func close_button(): button("返回餐厅  [Esc]",func(): panel.hide(); cooking=false)

func buy(i: int) -> bool:
	if phase!="准备" or i<0 or i>=6: return false
	var cost = COST[i]*3
	if money < cost: notify("金币不足，试试便宜的食材。") ; return false
	money -= cost
	spending += cost
	raw[i] += 3
	return true

func preparation_plan() -> Dictionary:
	return preload("res://systems/preparation.gd").plan(raw,ready_food,COST,expected_guests())

func buy_recommended() -> bool:
	if phase!="准备": return false
	var plan=preparation_plan()
	if money<plan.cost:
		notify("采购清单需要%d金，资金不足；尚未购买。"%plan.cost)
		return false
	money-=plan.cost;spending+=plan.cost
	for i in range(6): raw[i]+=plan.purchases[i]
	notify("已按清单采购，花费%d金。原料还需装盘。"%plan.cost)
	return true

func prepare_target(i: int, target: int) -> int:
	if phase!="准备" or i<0 or i>=6 or target<0: return 0
	var units=mini(int(raw[i]),int(ceil(maxi(0,target-int(ready_food[i]))/2.0)))
	raw[i]-=units;ready_food[i]+=units*2
	return units*2

func prepare_recommended() -> int:
	if phase!="准备": return 0
	var plan=preparation_plan()
	var made=0
	for i in range(6): made+=prepare_target(i,plan.targets[i])
	notify("按计划装盘%d份，剩余原料保留。"%made)
	return made

func show_preparation():
	clear_panel("营业准备 · 库存与采购计划")
	var plan=preparation_plan()
	line("预计%d客 × 3盘 = 建议%d盘。已备%d盘，缺%d盘。"%[expected_guests(),plan.recommended,plan.total,plan.missing])
	line("清单优先使用现有库存，均衡补齐六种基础菜；以3份原料一组采购。建议数量不保证客人口味或送餐效率。")
	for i in range(6):
		line("%s：原料%d / 成品%d / 目标%d盘 / 需买%d份"%[ING[i],raw[i],ready_food[i],plan.targets[i],plan.purchases[i]])
	line("预计采购%d金；持有%d金。%s"%[plan.cost,money,"露米今晚另需8金工资。" if employee else "目前由你亲自补餐。"])
	button("按清单采购 · %d金"%plan.cost,func(): buy_recommended();show_preparation())
	button("按计划装盘 · 保留多余原料",func(): prepare_recommended();show_preparation())
	button("查看开店检查",show_open)
	close_button()

func show_market():
	clear_panel("月桥集市 · 三家商户")
	line("每份原料装成 2 盘。采购以 3 份一组。")
	button("查看库存与建议采购清单",show_preparation)
	for i in range(6):
		var merchant = ["森林菜婆", "霜角牧场", "潮汐鱼贩", "森林菜婆", "霜角牧场", "潮汐鱼贩"][i]
		button("%s · %s ×3 / %d 金  [存 %d]" % [merchant,ING[i],COST[i]*3,raw[i]],func(): buy(i); show_market())
	close_button()

func show_kitchen():
	clear_panel("料理台 · 备菜与火候")
	button("按预计客流制定备菜计划",show_preparation)
	for i in range(6):
		button("装盘 %s（饱腹%d） 原料%d / 待上%d" % [ING[i],FILL[i],raw[i],ready_food[i]],func(): prepare(i); show_kitchen())
	button("全部基础食材批量装盘",func(): prepare_all();show_kitchen())
	button("清炖霜牛：牛肉 + 豆腐  [熟练 %d/3]" % mastery,show_cook)
	line("清炖霜牛标签：肉类 · 清淡。勇者喜欢它。\n装盘、烹饪在开店前完成；营业时 E 取选中菜。")
	close_button()

func prepare_all() -> int:
	if phase!="准备": notify("营业前才能批量备菜。");return 0
	var amount=0
	for i in range(raw.size()):
		amount+=int(raw[i])*2
		ready_food[i]+=int(raw[i])*2;raw[i]=0
	notify("已装盘%d份。需要炖菜时，请先留好牛肉和豆腐。"%amount)
	return amount

func prepare(i: int) -> bool:
	if phase!="准备" or i<0 or i>=6: return false
	if raw[i] <= 0: notify("缺少原料，去集市采购。") ; return false
	raw[i] -= 1
	ready_food[i] += 2
	return true

func show_cook():
	if raw[1] < 1 or raw[4] < 1: notify("需要 1 份牛肉和 1 份豆腐。") ; return
	if mastery >= 3:
		finish_cook(true)
		show_kitchen()
		return
	clear_panel("小锅慢炖 · 火候小游戏")
	line("在火候条 40—70 时点击出锅。\n成功：2 盘清炖霜牛，熟练度 +1。\n失误：原料仍变成 2 盘牛肉，不会白白丢失。")
	cook_cursor = ProgressBar.new()
	cook_cursor.custom_minimum_size = Vector2(380,40)
	panel_box.add_child(cook_cursor)
	cook_time = 0
	cooking = true
	button("现在出锅！",func(): finish_cook(cook_cursor.value >= 40 and cook_cursor.value <= 70); show_kitchen())
	close_button()

func finish_cook(success: bool):
	if raw[1] < 1 or raw[4] < 1: return
	raw[1] -= 1
	raw[4] -= 1
	ready_food[6 if success else 1] += 2
	if success: mastery += 1
	notify("炖菜完成！熟练三次后解锁快捷制作。" if success else "火候偏了，改成普通牛肉盘。")
	cooking = false

func choose_facility():
	clear_panel("自取与等候设施")
	for j in range(FACILITY.size()):
		button(FACILITY[j],func(): facility_kind=j;build_tool="facility";panel.hide())
	close_button()

func show_news():
	clear_panel("街区快报")
	line(bulletin)
	line("店铺口碑 %d / 100　今晚预计 %d 位来客"%[reputation,expected_guests()])
	if phase=="准备":
		if event_booked: line("今晚活动：人气 coser 到店")
		else: button("邀请 coser · 40 金 / 增加 5 位来客",book_event)
	close_button()

func book_event():
	if phase!="准备" or event_booked: return
	if money<40: notify("活动费用需要40金。");return
	money-=40;spending+=40;event_booked=true
	show_news()

func configure_menu():
	clear_panel("今晚的特别菜单")
	for j in range(SPECIALS.size()):
		button(("%s · "%("供应" if offerings[j] else "下架"))+SPECIALS[j],func(): offerings[j]=not offerings[j];configure_menu())
	line("现做一份消耗一盘对应备菜。客人进餐后才会加单。")
	close_button()

func show_open():
	clear_panel("星灯营业铃")
	line("每位入座客人支付同一餐费。饱腹离席，完成加单另收小费。")
	button("街区快报与活动",show_news)
	button("选择特别菜单",configure_menu)
	button("餐费 %d 金 / 预计 %d 客（点击调整）"%[menu_price,expected_guests()],cycle_price)
	line("基础客流随餐费变化，昨日口碑和今日活动会影响到店人数。")
	layout.compile()
	line("布局：%d 张桌 / %d 座 / %d 条餐带。"%[layout.tables.size(),seats.size(),layout.routes.size()])
	if not layout.errors.is_empty(): line("必须修复："+str(layout.errors[0]))
	var plan=preparation_plan()
	line("库存检查：已备%d / 建议%d盘。%s"%[plan.total,plan.recommended,"不足12盘，不能开门。" if plan.total<12 else "可开门；仍有缺餐风险。" if plan.missing>0 else "数量充足，注意及时补餐。"])
	if employee and money<8: line("资金提醒：当前不足8金工资，需依靠今晚收入支付。")
	if not employee: line("人手提醒：尚未招聘，需要亲自往返补餐。")
	button("库存预警与备菜计划",show_preparation)
	line("先选菜 → 料理台 E 拿菜 → 彩色补餐点 E 上餐。长餐带需要更久才能送达。")
	button("敲铃 · 开始营业",func(): start_business())
	if not employee: button("招聘露米 · 符文补餐员 30 金",func(): hire(); show_open())
	else:
		line("露米 Lv.%d · 经验%d/60 · 今晚工资8金。\n每趟运%d盘，步速%d；完成补餐与营业积累经验。"%[staff_level(),staff_exp,staff_capacity(),staff_speed()])
		button("岗位：%s（点击切换）"%("自动巡区" if staff_zone<0 else layout.zone_name(staff_zone)+"区"),cycle_staff_zone)
	if not decor: button("购买星灯盆栽 15 金 · 评价 +5",func(): if money >= 15: money-=15; spending+=15; decor=true; show_open())
	close_button()

func expected_guests() -> int:
	return maxi(3,(12 if menu_price==18 else 8 if menu_price==30 else 10)+roundi((reputation-70)/6.0)+(5 if event_booked else 0))

func cycle_price():
	if phase!="准备": return
	menu_price={18:24,24:30,30:18}.get(menu_price,24)
	show_open()

func staff_level() -> int: return 1+mini(2,int(staff_exp/30))
func staff_capacity() -> int: return 3+(1 if staff_level()>=3 else 0)
func staff_speed() -> float: return 145.0+(staff_level()-1)*15.0

func cycle_staff_zone():
	staff_zone+=1
	if staff_zone>2: staff_zone=-1
	show_open()

func hire() -> bool:
	if employee or money < 30: return false
	money -= 30
	spending += 30
	employee = true
	return true

func start_business() -> bool:
	if phase!="准备": return false
	if not layout.compile(): notify("无法开门："+str(layout.errors[0]));return false
	sync_seats()
	zone_stats=[]
	for z in range(3): zone_stats.append({"visits":0,"hungry":0.0,"score":0,"meals":0,"arrivals":0})
	staff_pos=layout.center(Vector2i(0,11));staff_path.clear();staff_carry.clear();staff_route=-1;staff_state="备餐区"
	var total = 0
	for n in ready_food: total += n
	if total < 12:
		notify("至少准备 12 盘食物再营业，建议按预计客人数准备每人3盘。")
		return false
	if not save_game(): return false
	guest_target=expected_guests()
	staff_trips=0
	phase = "营业"
	elapsed = 0
	spawned = 0
	waiting.clear();lost=0;missed_taste=0;cooked=-1
	spawn_clock = 0
	staff_clock = 0
	panel.hide()
	spawn_guest()
	notify("开门啦！先到料理台取菜，给餐带补货。勇者将第三个到来。")
	return true

func kitchen_orders():
	clear_panel("后厨 · 现做加单")
	for j in range(SPECIALS.size()):
		var count=0
		for g in guests:
			if g!=null and g.order==j and not g.bonus: count+=1
		if count>0: button("%s ×%d · 使用一盘%s"%[SPECIALS[j],count,ING[BASE[j]]],cook_order.bind(j))
	close_button()

func cook_order(j:int):
	if phase!="营业" or held>=0: notify("先腾出双手。");return
	if ready_food[BASE[j]]<=0: notify("对应备菜已用完。");return
	ready_food[BASE[j]]-=1;held=BASE[j];cooked=j;kitchen_time=2.5;panel.hide()
	notify("正在制作"+SPECIALS[j]+"…")

func take_food():
	if held >= 0: notify("手里已有菜，Q 放回备餐区。") ; return
	if ready_food[selected] <= 0: notify("这道菜已经没有了，按 1—7 换菜。") ; return
	ready_food[selected] -= 1
	held = selected

func spawn_guest():
	if spawned>=guest_target: return
	var ticket=spawned
	spawned+=1
	waiting.append({"ticket":ticket,"patience":18+(ticket%4)*5+maxi(0,reputation-60)/4.0})
	seat_next()

func seat_next():
	if waiting.is_empty(): return
	var chosen=-1
	var lowest=10000
	for i in range(seats.size()):
		if guests[i]!=null: continue
		var z=layout.tables[seat_tables[i]].zone
		if zone_stats[z].arrivals<lowest:
			lowest=zone_stats[z].arrivals;chosen=i
	if chosen<0: return
	var z=layout.tables[seat_tables[chosen]].zone
	zone_stats[z].arrivals+=1
	var ticket=int(waiting.pop_front().ticket)
	var wish=1 if ticket==2 else ticket%6
	guests[chosen]={"ticket":ticket,"position":seats[chosen],"trip":[],"visited":[],"full":0,"capacity":68+(ticket%4)*12,"order":-1,"order_at":0.0,"liked":false,"wish":wish,"special":ticket==2,"eaten":0,"wait":0.0,"bonus":false,"score":80-maxi(0,menu_price-24),"last_meal":0.0,"hungry":0.0}

func plate_pos(t: float, r: int=0) -> Vector2:
	if r<0 or r>=layout.routes.size(): return Vector2.ZERO
	var cells=layout.routes[r].cells
	var d=fposmod(t,float(cells.size()))
	var i=int(d)
	return layout.center(cells[i]).lerp(layout.center(cells[(i+1)%cells.size()]),d-i)

func route_plate_count(r: int) -> int:
	var count=0
	for p in plates:
		if p.route==r: count+=1
	return count

func add_plate(r: int, food: int, index: int) -> bool:
	if r<0 or r>=layout.routes.size() or route_plate_count(r)>=layout.routes[r].capacity: return false
	plates.append({"food":food,"t":float(index),"route":r})
	return true

func tick_business(dt: float):
	elapsed += dt
	if kitchen_time>0:
		kitchen_time=maxf(0,kitchen_time-dt)
		if kitchen_time==0: notify("出锅了，送到点单客人桌边。")
	spawn_clock += dt
	if spawn_clock >= (5.0 if event_booked else 8.0)+float(spawned%3):
		spawn_clock = 0
		spawn_guest()
	seat_next()
	var benches=0
	for f in layout.facilities:
		if f.kind==3: benches+=1
	for j in range(waiting.size()-1,-1,-1):
		waiting[j].patience-=dt*(0.55 if j<benches*2 else 1.0)
		if waiting[j].patience<=0: waiting.remove_at(j);lost+=1
	for p in plates: p.t=fposmod(p.t+dt*1.8,float(layout.routes[p.route].cells.size()))
	for i in range(seats.size()):
		var g = guests[i]
		if g == null: continue
		g.wait+=dt
		if not g.trip.is_empty():
			g.position=g.position.move_toward(g.trip[0],dt*110)
			if g.position==g.trip[0]: g.trip.pop_front()
			if g.trip.is_empty() and g.visited.back()==2: g.full+=10
			continue
		var kind=0 if g.eaten==0 else 2 if g.full>=g.capacity*0.7 else 1
		if kind not in g.visited and (g.ticket+kind)%3!=1:
			g.visited.append(kind)
			var best=[]
			for f in layout.facilities:
				if f.kind!=kind: continue
				var route=layout.path(layout.cell(seats[i]),Vector2i(f.x,f.y))
				if not route.is_empty() and (best.is_empty() or route.size()<best.size()): best=route
			if best.size()>1:
				for cell in best: g.trip.append(layout.center(cell))
				best.reverse()
				for cell in best: g.trip.append(layout.center(cell))
				continue
		g.last_meal+=dt
		var table=layout.tables[seat_tables[i]]
		var r=layout.route_for_table(table)
		if g.full<g.capacity and g.last_meal>10: g.hungry+=dt
		if r>=0 and g.full<g.capacity and g.last_meal>=5:
			var target=layout.center(layout.routes[r].cells[layout.pickup_index(table,r)])
			for j in range(plates.size()-1,-1,-1):
				if plates[j].food!=g.wish and g.last_meal<7: continue
				if plates[j].route==r and plate_pos(plates[j].t,r).distance_to(target)<20:
					var food=int(plates[j].food)
					g.full+=FILL[food];g.liked=g.liked or food==g.wish
					if g.eaten==0 and (g.special or g.ticket%4!=3):
						for offset in range(3):
							var recipe=(BASE.find(g.wish)+3+offset)%3 if g.wish in BASE else (g.ticket+offset)%3
							if offerings[recipe]: g.order=recipe;g.order_at=g.wait;break
					food_served[food]+=1;g.eaten+=1;g.last_meal=0;plates.remove_at(j);break
		if (g.full>=g.capacity and (g.order<0 or g.bonus or g.wait-g.order_at>12)) or g.wait>65: checkout(i)
	if employee: tick_staff(dt)
	if elapsed>=150 or served>=guest_target: end_day()

func staff_choose_food() -> int:
	for i in range(seats.size()):
		var g=guests[i]
		if g!=null and not g.bonus and layout.route_for_table(layout.tables[seat_tables[i]])==staff_route:
			var wish=1 if g.special else int(g.wish)
			if ready_food[wish]>0: return wish
	for j in range(6):
		var k=(j+int(staff_animation))%6
		if ready_food[k]>0: return k
	return -1

func tick_staff(dt: float):
	staff_animation+=dt
	if not staff_path.is_empty():
		var target=layout.center(staff_path[0])
		staff_pos=staff_pos.move_toward(target,dt*staff_speed())
		if staff_pos.distance_to(target)<1: staff_path.pop_front()
		return
	staff_clock+=dt
	if staff_clock<0.6: return
	staff_clock=0
	if staff_state=="去补餐":
		var r=layout.routes[staff_route]
		var delivered=0
		while not staff_carry.is_empty():
			var food=staff_carry.pop_front()
			if not add_plate(staff_route,food,r.feeders[staff_feeder].index): ready_food[food]+=1
			else: delivered+=1
		if delivered>0: staff_trips+=1
		staff_state="回厨房"
		staff_path=layout.path(layout.cell(staff_pos),Vector2i(0,11));return
	if staff_state=="回厨房": staff_state="备餐区"
	var best=-INF
	var chosen=-1
	for r in range(layout.routes.size()):
		if staff_zone>=0 and layout.routes[r].zone!=staff_zone: continue
		if route_plate_count(r)>=layout.routes[r].capacity: continue
		var need=0.0
		for i in range(seats.size()):
			if guests[i]!=null and guests[i].eaten<3 and layout.route_for_table(layout.tables[seat_tables[i]])==r: need+=3-guests[i].eaten+guests[i].last_meal/5.0
		var score=need*3-route_plate_count(r)
		if score>best: best=score;chosen=r
	if chosen<0: return
	staff_route=chosen
	var shortest: Array=[]
	for i in range(layout.routes[chosen].feeders.size()):
		var route=layout.path(Vector2i(0,11),layout.routes[chosen].feeders[i].cell)
		if not route.is_empty() and (shortest.is_empty() or route.size()<shortest.size()): shortest=route;staff_feeder=i
	if shortest.is_empty(): return
	for j in range(staff_capacity()):
		var food=staff_choose_food()
		if food<0: break
		ready_food[food]-=1;staff_carry.append(food)
	if staff_carry.is_empty(): return
	staff_path=shortest;staff_state="去补餐"

func serve_guest(i: int) -> bool:
	var g = guests[i]
	if g == null or held < 0 or kitchen_time>0: return false
	var match_food = cooked>=0 and cooked==g.order and g.trip.is_empty()
	if g.bonus or not match_food:
		notify("已满足点单。" if g.bonus else "不是想要的菜，食物仍留在手里。")
		return false
	g.bonus = true
	g.full+=FILL[held];g.liked=true;cooked=-1
	food_served[held]+=1
	g.eaten += 1
	g.last_meal = 0
	g.score = 100
	var reward = 18 if g.special else 6
	money += reward
	income += reward
	tips += reward
	if g.special:
		affection += 1
		special_done = true
	held = -1
	notify("莱恩：清淡的肉正合适！好感 +1，奖励 +18。" if g.special else "正是我想吃的！满意度提升，小费 +6。")
	return true

func checkout(i: int):
	var g = guests[i]
	if g == null: return
	var fee = menu_price
	money += fee
	income += fee
	served += 1
	if not g.liked: missed_taste+=1
	var score=clampi(int(g.score)+(10 if g.liked else -18)-(20 if g.full<g.capacity else 0)-int(g.hungry/3)+(5 if decor else 0),0,100)
	satisfaction+=score
	var z=layout.tables[seat_tables[i]].zone
	zone_stats[z].visits+=1;zone_stats[z].score+=score;zone_stats[z].hungry+=g.hungry;zone_stats[z].meals+=g.eaten
	guests[i] = null

func end_day():
	if phase!="营业": return
	for i in range(seats.size()):
		if guests[i] != null: checkout(i)
	if employee:
		money -= 8
		spending += 8
		staff_exp=mini(60,staff_exp+staff_trips+2)
	for p in plates: ready_food[p.food] += 1
	plates.clear()
	for food in staff_carry: ready_food[food]+=1
	staff_carry.clear();staff_path.clear();staff_state="休息"
	if held >= 0:
		ready_food[held] += 1
		held = -1
	lost+=waiting.size();waiting.clear()
	var rating=int(float(satisfaction)/maxi(1,served))
	var narrow_menu=served>=3 and food_served.count(0)>=5
	reputation=clampi(roundi((reputation+rating)*0.5)-mini(8,lost)-(5 if narrow_menu else 0),0,100)
	bulletin="第%d夜餐后快报 · %d位入座，%d位未等到座位。客评%d分。%s"%[day,served,lost,rating,"有%d位客人没吃到偏好的菜。"%missed_taste if missed_taste else "客人们都尝到了喜欢的菜。"]
	var variety=0
	for count in food_served:
		if count>0: variety+=1
	bulletin+="\n餐后留言："+("想吃的菜等了好久，下次希望能多几种。" if missed_taste>served/2 else "今天吃到了喜欢的菜，下次还想来。")
	bulletin+="\n售出%d种菜 · 收入%d金 / 支出%d金 · 加单小费%d金。"%[variety,income,spending,tips]
	if narrow_menu: bulletin+="\n不少客人希望餐带上多一些选择。"
	event_booked=false;cooked=-1;kitchen_time=0
	phase = "结算"
	summary = "接待 %d 位客人\n营业收入 %d（含小费 %d）\n采购 / 招聘 / 装修 / 工资 %d\n当日净收益 %d\n平均评价 %d / 100\n勇者好感 %d · %s\n剩余食材和餐盘保留到明天。" % [served,income,tips,spending,income-spending,int(float(satisfaction)/maxi(1,served)),affection,"点单完成" if special_done else "期待下次点单"]
	for z in range(3):
		var stat=zone_stats[z]
		if stat.visits>0: summary+="\n%s区：%d客 / 评价%d / 缺餐等待%.0f秒"%[layout.zone_name(z),stat.visits,int(float(stat.score)/stat.visits),stat.hungry]
	summary+="\n餐费%d金 · 吃掉%d盘"%[menu_price,food_served.reduce(func(a,b):return a+b,0)]
	if employee: summary+="\n露米完成%d趟补餐 · 经验%d · Lv.%d"%[staff_trips,staff_exp,staff_level()]
	business_history=preload("res://systems/ledger.gd").record(business_history,{
		"day":day,"income":income,"spending":spending,"tips":tips,"served":served,
		"score_total":satisfaction,"plates":food_served.reduce(func(a,b):return a+b,0),
		"price":menu_price,"tables":layout.tables.size(),"routes":layout.routes.size(),
		"dishes":food_served.duplicate(),"zones":zone_stats.duplicate(true)})
	save_game()
	show_summary()

func show_summary():
	clear_panel("打烊啦 · 第 %d 天" % day)
	line(summary)
	var dishes=[]
	for i in range(food_served.size()):
		if food_served[i]>0: dishes.append("%s %d盘"%[dish_name(i),food_served[i]])
	if not dishes.is_empty(): line("菜品销量："+" / ".join(dishes))
	if not last_save_ok: line("存档未成功："+save_error)
	button("街区快报",show_news)
	button("查看历日经营记录",show_history)
	button("收拾好，迎接下一天",next_day)

func show_history():
	clear_panel("经营记录 · 最近30个营业日")
	if business_history.is_empty():
		line("尚无营业记录。完成一次营业后自动记账；旧版本未记录的日期不会补造数据。")
	else:
		var totals=preload("res://systems/ledger.gd").totals(business_history)
		line("最近%d次营业：收入%d / 支出%d / 净收益%d金。
接待%d客，吃掉%d盘，客均评价%d。"%[totals.days,totals.income,totals.spending,totals.profit,totals.served,totals.plates,totals.rating])
		line("支出按实际付款日计入，含采购、招聘、装修和工资；并非已售食材的成本。")
		if business_history.size()>1:
			var current=business_history[-1];var previous=business_history[-2]
			line("最近两次对比：收入%+d / 净收益%+d / 客流%+d。"%[current.income-previous.income,(current.income-current.spending)-(previous.income-previous.spending),current.served-previous.served])
		for i in range(business_history.size()-1,-1,-1):
			var entry=business_history[i]
			button("第%d天 · 收%d / 支%d / 净%d · %d客"%[entry.day,entry.income,entry.spending,entry.income-entry.spending,entry.served],func(): show_history_day(entry))
	if phase=="结算": button("返回本日结算",show_summary)
	close_button()

func show_history_day(entry: Dictionary):
	clear_panel("第%d天 · 营业明细"%entry.day)
	line("餐费%d金 · %d桌 / %d条餐带
接待%d客 · 吃掉%d盘
收入%d（含小费%d） / 支出%d
净收益%d金 · 平均评价%d"%[entry.price,entry.tables,entry.routes,entry.served,entry.plates,entry.income,entry.tips,entry.spending,entry.income-entry.spending,int(float(entry.score_total)/maxi(1,entry.served))])
	for i in range(7):
		if entry.dishes[i]>0: line("%s：%d盘"%[dish_name(i),entry.dishes[i]])
	for z in range(3):
		var stat=entry.zones[z]
		if stat.visits>0: line("%s区：%d客 / 评价%d / 缺餐等待%.0f秒"%[layout.zone_name(z),stat.visits,int(float(stat.score)/stat.visits),stat.hungry])
	button("返回经营记录",show_history)
	close_button()

func next_day():
	if phase!="结算": return
	day += 1
	phase = "准备"
	income = 0
	spending = 0
	tips = 0
	served = 0
	satisfaction = 0
	special_done = false
	food_served=[0,0,0,0,0,0,0]
	panel.hide()
	if money < 18 and raw.reduce(func(a,b):return a+b,0) == 0 and ready_food.reduce(func(a,b):return a+b,0) < 12:
		money += 36
		notify("商会送来 36 金周转补助，继续试试新搭配吧。")
	save_game()

func snapshot() -> Dictionary:
	return {"reputation":reputation,"bulletin":bulletin,"event_booked":event_booked,"offerings":offerings.duplicate(),"version":4,"layout_plans":layout_plans.duplicate(true),"history":business_history.duplicate(true),"layout":layout.snapshot(),"staff_zone":staff_zone,"money":money,"day":day,"raw":raw.duplicate(),"ready":ready_food.duplicate(),"mastery":mastery,"affection":affection,"employee":employee,"decor":decor,"decor_x":decor_pos.x,"decor_y":decor_pos.y,"phase":phase,"summary":summary,"income":income,"spending":spending,"tips":tips,"served":served,"satisfaction":satisfaction,"menu_price":menu_price,"staff_exp":staff_exp,"food_served":food_served.duplicate(),"special_done":special_done,"saved_at":Time.get_datetime_string_from_system()}

func save_game() -> bool:
	if phase=="营业":
		save_error="营业中请先暂停；退出会回到开门前的存档。";notify(save_error);return false
	var result=save_store.write(save_path,snapshot())
	last_save_ok=result.ok
	save_error="" if result.ok else result.error
	if not result.ok: notify("保存失败："+save_error)
	return result.ok

func load_game() -> bool:
	var result=save_store.read(save_path)
	if not result.ok:
		save_error=result.error;notify("无法读取存档："+save_error);return false
	apply_save(result.data)
	if result.recovered: notify("主存档无法读取，已恢复最近一次有效备份。")
	return true

func apply_save(data: Dictionary):
	reputation=int(data.get("reputation",70));bulletin=data.get("bulletin","今天是新的营业日。");event_booked=data.get("event_booked",false);offerings=data.get("offerings",[true,true,true]).duplicate();cooked=-1
	layout_plans=data.get("layout_plans",[null,null,null]).duplicate(true)
	business_history=data.get("history",[]).duplicate(true)
	if data.has("layout"): layout.restore(data.layout)
	else: layout.reset()
	staff_zone=clampi(int(data.get("staff_zone",-1)),-1,2)
	sync_seats()
	money=int(data.get("money",150));day=int(data.get("day",1))
	raw=data.get("raw",[0,0,0,0,0,0]).duplicate();ready_food=data.get("ready",[0,0,0,0,0,0,0]).duplicate()
	mastery=int(data.get("mastery",0));affection=int(data.get("affection",0))
	employee=data.get("employee",false);decor=data.get("decor",false)
	decor_pos=Vector2(data.get("decor_x",1080),data.get("decor_y",600))
	phase=data.get("phase","准备");summary=data.get("summary","")
	income=int(data.get("income",0));spending=int(data.get("spending",0));tips=int(data.get("tips",0));served=int(data.get("served",0));satisfaction=int(data.get("satisfaction",0))
	menu_price=int(data.get("menu_price",24));staff_exp=int(data.get("staff_exp",0))
	food_served=data.get("food_served",[0,0,0,0,0,0,0]).duplicate();special_done=data.get("special_done",false)
	guest_target=expected_guests()
	plates.clear();staff_carry.clear();staff_path.clear();held=-1;build_mode=false;moving_table=-1;layout_history.clear()
	if phase=="结算": show_summary()

func show_menu():
	if build_mode: toggle_build()
	clear_panel("店长手册 · 查看时暂停营业")
	line("① 左上集市采购 → 左下料理台装盘。\n② 右侧铃铛开店，可招聘露米往返补餐。\n③ 按 1—7 选菜，料理台 E 拿菜。\n④ 走近彩色补餐点 E 上餐，客人自动取餐。\n⑤ 看加单气泡，到料理台按 C 现做，回桌旁 E 送餐。\n⑥ 打烊看账本，再迎接下一天。\n\n清炖霜牛成功三次解锁快捷制作。\n准备期按 B 布局，左键放置，R 旋转，右键拆除。\n餐带同区闭环；桌子与补餐点紧邻同区餐带。\n露米可自动巡区，或指定负责某一区。\n准备期可手动保存，打烊自动保存。")
	if phase=="结算": button("查看打烊账本 / 下一天",show_summary)
	button("街区快报",show_news)
	button("查看历日经营记录",show_history)
	button("保存进度",func():
		if save_game(): notify("进度已保存。"))
	if not pause_requested.get_connections().is_empty(): button("暂停 / 设置 / 返回主菜单",func(): pause_requested.emit())
	close_button()

func text_at(p: Vector2,s: String,size: int=18,col: Color=Color("f9ecd8")):
	draw_string(font,p,s,HORIZONTAL_ALIGNMENT_LEFT,-1,size,col)

func person(p: Vector2,col: Color,kind: int=0):
	ellipse(p+Vector2(0,13),Vector2(23,9),Color(0,0,0,0.17))
	draw_circle(p,18,col)
	draw_circle(p+Vector2(0,-23),15,Color("f8d9b2"))
	draw_arc(p+Vector2(0,-26),15,PI,TAU,20,col,8)
	draw_circle(p+Vector2(-5,-23),1.7,Color("3b3039"))
	draw_circle(p+Vector2(5,-23),1.7,Color("3b3039"))
	if kind == 1:
		draw_colored_polygon(PackedVector2Array([p+Vector2(-16,-30),p+Vector2(-22,-48),p+Vector2(-6,-35)]),col)
		draw_colored_polygon(PackedVector2Array([p+Vector2(16,-30),p+Vector2(22,-48),p+Vector2(6,-35)]),col)

func ellipse(center: Vector2,r: Vector2,color: Color):
	var points = PackedVector2Array()
	for i in range(48): points.append(center+Vector2(cos(i*TAU/48)*r.x,sin(i*TAU/48)*r.y))
	draw_colored_polygon(points,color)

func _draw():
	draw_rect(Rect2(0,0,1280,800),Color("222c37"))
	draw_rect(Rect2(30,110,1220,575),Color("5a4241"))
	draw_rect(Rect2(48,130,1184,540),Color("bb916b"))
	for y in range(140,670,44):
		draw_line(Vector2(48,y),Vector2(1232,y),Color("a57b5c"),2)
		for x in range(60+(y%3)*50,1230,130): draw_line(Vector2(x,y),Vector2(x,mini(y+42,670)),Color("ad8360"),1)
	draw_rect(Rect2(48,110,1184,80),Color("847466"))
	draw_rect(Rect2(48,170,1184,20),Color("5b4845"))
	for x in range(48,1232,148):
		draw_rect(Rect2(x,110,10,80),Color("624d47"))
	for x in [450,750,1050]:
		draw_rect(Rect2(x,119,95,43),Color("3e626d"))
		draw_line(Vector2(x+47,119),Vector2(x+47,162),Color("c6ad84"),4)
		draw_line(Vector2(x,140),Vector2(x+95,140),Color("c6ad84"),3)
	for x in [290,990]:
		draw_line(Vector2(x,110),Vector2(x,175),Color("44364b"),4)
		draw_circle(Vector2(x,175),20,Color("ffd88a"))
		draw_circle(Vector2(x,175),30,Color(1,0.8,0.4,0.10))
	if not art.draw(self,["furniture/market"],Vector2(170,255),art_clock): block(Rect2(80,200,180,55),25,Color("6c7f65"))
	text_at(Vector2(95,203),"月桥集市",22)
	text_at(Vector2(95,232),"采购  ·  E",16)
	for i in range(6): draw_circle(Vector2(95+i*28,258),10,COLORS[i])
	if not art.draw(self,["furniture/kitchen"],Vector2(190,630),art_clock): block(Rect2(80,570,220,60),25,Color("6f5360"))
	text_at(Vector2(95,578),"料理台 / 备餐区",20)
	text_at(Vector2(95,607),"备菜 · 取菜  E",16)
	draw_circle(Vector2(160,365),40,Color("dcaa57"))
	text_at(Vector2(128,370),"开店铃",20,Color("523e3a"))
	text_at(Vector2(80,420),"招聘 / 装修 / 开门",16,Color("493638"))
	draw_layout()
	if decor:
		draw_circle(decor_pos,16,Color("bf785b"))
		for d in [Vector2(-10,-15),Vector2(8,-20),Vector2(0,-30)]: draw_circle(decor_pos+d,12,Color("93b885"))

func bubble_style() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color("fff1d9")
	s.corner_radius_top_left=10;s.corner_radius_top_right=10;s.corner_radius_bottom_left=10;s.corner_radius_bottom_right=10
	return s

func draw_layout():
	for y in range(layout.HEIGHT):
		for x in range(layout.WIDTH):
			var c=Vector2i(x,y);var p=layout.center(c)
			if not layout.floor_at(c): draw_rect(Rect2(p-Vector2.ONE*20,Vector2.ONE*40),Color("283541"))
			else: art.draw(self,["environment/floor"],p,art_clock)
			if layout.floor_at(c) and build_mode: draw_rect(Rect2(p-Vector2.ONE*20,Vector2.ONE*40),Color(1,1,1,0.18),false,1)
	for f in layout.facilities:
		var pos=layout.center(Vector2i(f.x,f.y))
		block(Rect2(pos-Vector2(17,9),Vector2(34,18)),12,Color("77acac"))
		text_at(pos+Vector2(-18,-12),FACILITY[int(f.kind)],13)
	for q in range(mini(5,waiting.size())):
		person(layout.center(Vector2i(20-q,11)),COLORS[int(waiting[q].ticket)%6],0)
	text_at(layout.center(Vector2i(18,11)),"叫号区 %d"%waiting.size(),14)
	var objects=[]
	for c in layout.belts: objects.append({"y":layout.center(c).y,"kind":"belt","data":c})
	for t in layout.tables: objects.append({"y":layout.center(layout.body(t)[-1]).y+17,"kind":"table","data":t})
	for t in layout.tables:
		for c in layout.chairs(t): objects.append({"y":layout.center(c).y-5,"kind":"chair","data":c,"rot":t.rot})
	for f in layout.feeders: objects.append({"y":layout.center(Vector2i(f.x,f.y)).y,"kind":"feeder","data":f})
	for i in range(seats.size()):
		if guests[i]!=null: objects.append({"y":guests[i].position.y,"kind":"guest","data":i})
	objects.append({"y":player.y,"kind":"player","data":0})
	if employee: objects.append({"y":staff_pos.y,"kind":"staff","data":0})
	for plate in plates:
		objects.append({"y":layout.center(layout.cell(plate_pos(plate.t,plate.route))).y+0.5,"kind":"plate","data":plate})
	objects.sort_custom(func(a,b): return a.y<b.y)
	for obj in objects: draw_depth_object(obj)
	# Bubbles stay above scenery, independently of body occlusion.
	for i in range(seats.size()):
		if guests[i]==null: continue
		var g=guests[i];var pos=g.position
		if g.order<0 or not g.trip.is_empty(): continue
		var bubble=pos+Vector2(-54,-72 if i%2==0 else -103)
		draw_style_box(bubble_style(),Rect2(bubble,Vector2(109,26)))
		text_at(bubble+Vector2(4,18),"谢谢！" if g.bonus else SPECIALS[g.order],12,Color("51444b"))
	if build_mode:
		var c=layout.cell(get_global_mouse_position())
		if build_tool=="table" or (build_tool=="move" and moving_table>=0):
			var t={"x":c.x,"y":c.y,"rot":build_rot,"zone":build_zone}
			var col=Color(0.4,1,0.7,0.5) if layout.table_valid(t,moving_table) else Color(1,0.3,0.3,0.6)
			for q in layout.body(t)+layout.chairs(t): draw_rect(Rect2(layout.center(q)-Vector2.ONE*19,Vector2.ONE*38),col)
		elif layout.floor_at(c): draw_rect(Rect2(layout.center(c)-Vector2.ONE*19,Vector2.ONE*38),Color(1,1,1,0.35))
		if not layout.errors.is_empty(): text_at(Vector2(350,182),str(layout.errors[0]),14,Color("ffe3bd"))
	else:
		for r in range(layout.routes.size()):
			var route=layout.routes[r]
			var p=layout.center(route.cells[0])+Vector2(-10,-47)
			text_at(p,"%s区 %d/%d盘 · 一圈%.0f秒"%[layout.zone_name(route.zone),route_plate_count(r),route.capacity,route.cells.size()/1.8],13,Color("fff0d4"))

func block(rect: Rect2,height: float,color: Color):
	draw_rect(Rect2(rect.position+Vector2(7,9),rect.size),Color(0.12,0.08,0.13,0.22))
	draw_rect(Rect2(rect.position+Vector2(0,-height),rect.size+Vector2(0,height)),color.darkened(0.38))
	draw_rect(Rect2(rect.position+Vector2(0,-height),rect.size),color)
	draw_line(rect.position+Vector2(0,-height),rect.position+Vector2(rect.size.x,-height),color.lightened(0.25),2)
	draw_line(rect.position+Vector2(0,rect.size.y-height),rect.position+Vector2(rect.size.x,rect.size.y-height),color.darkened(0.17),2)

func draw_depth_object(obj: Dictionary):
	if draw_art_object(obj): return
	match obj.kind:
		"belt":
			var c=obj.data;var pos=layout.center(c);var col=layout.ZONE_COLORS[layout.belts[c]]
			block(Rect2(pos-Vector2.ONE*20,Vector2.ONE*40),22,Color("557373"))
			draw_line(pos+Vector2(-18,-39),pos+Vector2(18,-39),col,3)
			for r in range(layout.routes.size()):
				var cells=layout.routes[r].cells;var idx=cells.find(c)
				if idx<0: continue
				var d=Vector2(cells[(idx+1)%cells.size()]-c);var q=pos-Vector2(0,22)
				draw_polyline(PackedVector2Array([q-d*4+d.orthogonal()*4,q+d*3,q-d*4-d.orthogonal()*4]),Color("a8d8c8"),1.5)

		"plate":
			var plate=obj.data
			var q=plate_pos(plate.t,plate.route)-Vector2(0,24)
			ellipse(q+Vector2(2,3),Vector2(13,7),Color(0,0,0,0.2));ellipse(q,Vector2(13,7),Color("fff0da"))
			draw_circle(q-Vector2(0,2),6,Color("c78558") if plate.food==6 else COLORS[plate.food])
		"table":
			var t=obj.data;var cells=layout.body(t);var a=layout.center(cells[0]);var b=layout.center(cells[1])
			var rect=Rect2(a-Vector2.ONE*17,b-a+Vector2.ONE*34)
			for x in [rect.position.x+4,rect.end.x-9]:
				for y in [rect.position.y+5,rect.end.y-6]: draw_rect(Rect2(x,y-19,6,24),Color("674a43"))
			block(Rect2(rect.position-Vector2(0,22),rect.size),7,Color("d3a578"))
			draw_line(rect.position+Vector2(0,-28),rect.position+Vector2(rect.size.x,-28),layout.ZONE_COLORS[t.zone],3)
			for c in cells:
				var q=layout.center(c)-Vector2(0,29)
				if not art.draw(self,["prop/hotpot"],q,art_clock):
					ellipse(q+Vector2(0,3),Vector2(12,8),Color("69565a"));ellipse(q,Vector2(12,7),Color("bd8551"));ellipse(q-Vector2(0,2),Vector2(9,5),Color("f4c172"))
				for k in range(2):
					var v=fmod(Time.get_ticks_msec()/850.0+k*0.5,1.0)
					draw_arc(q+Vector2(sin(v*5+k)*3,-6-v*20),4,0,PI,8,Color(1,0.94,0.8,(1-v)*0.45),1.5)
		"chair":
			var q=layout.center(obj.data)
			for x in [-10,7]: draw_rect(Rect2(q+Vector2(x,-5),Vector2(4,16)),Color("665052"))
			block(Rect2(q-Vector2(13,7),Vector2(26,18)),10,Color("97696a"))
		"feeder":
			var f=obj.data;var q=layout.center(Vector2i(f.x,f.y))
			block(Rect2(q-Vector2.ONE*16,Vector2.ONE*32),25,layout.ZONE_COLORS[f.zone])
			text_at(q+Vector2(-11,-19),"补",19,Color("293a41"))
		"guest":
			var i=obj.data;var g=guests[i]
			if not art.draw(self,["character/hero/sit","character/hero/idle"] if g.special else ["character/guest_%d/sit"%(g.wish%3),"character/guest_%d/idle"%(g.wish%3)],g.position,art_clock):
				person(g.position,Color("6b92b5") if g.special else COLORS[g.wish],i%2)
		"staff":
			if not art.draw(self,actor_keys("lumi",staff_animation_name()),staff_pos,art.actor_seconds("lumi")):
				person(staff_pos,Color("b5a1d5"),1)
			text_at(staff_pos+Vector2(-18,-55),"露米",13)
		"player":
			if not art.draw(self,actor_keys("player",player_animation()),player,art.actor_seconds("player")):
				person(player,Color("70b9b1"))
			if held>=0:
				ellipse(player+Vector2(23,-3),Vector2(14,8),Color("fff0da"));draw_circle(player+Vector2(23,-6),7,Color("c78558") if held==6 else COLORS[held])

func player_animation() -> String:
	if held>=0: return "carry_walk" if player_motion else "carry_idle"
	return "walk" if player_motion else "idle"

func staff_animation_name() -> String:
	if not staff_carry.is_empty(): return "carry_walk" if staff_motion else "carry_idle"
	return "walk" if staff_motion else "idle"

func actor_keys(id: String, state: String) -> Array:
	var keys=["character/"+id+"/"+state]
	if state.begins_with("carry_"): keys.append("character/"+id+"/"+state.trim_prefix("carry_"))
	keys.append("character/"+id+"/idle")
	return keys

func belt_art_key(c: Vector2i) -> String:
	var dirs=""
	for pair in [["n",Vector2i.UP],["e",Vector2i.RIGHT],["s",Vector2i.DOWN],["w",Vector2i.LEFT]]:
		if layout.belts.has(c+pair[1]): dirs+=pair[0]
	return "belt/"+dirs

func draw_art_object(obj: Dictionary) -> bool:
	match obj.kind:
		"table":
			var t=obj.data
			var cells=layout.body(t)
			var center=(layout.center(cells[0])+layout.center(cells[1]))/2.0
			if not art.draw(self,["furniture/table/"+str(t.rot)],center,art_clock): return false
			# World anchor stays at the footprint center; pots remain separate movable assets.
			for c in cells:
				var pos=layout.center(c)-Vector2(0,29)
				if not art.draw(self,["prop/hotpot"],pos,art_clock):
					ellipse(pos,Vector2(12,8),Color("bd8551"));ellipse(pos-Vector2(0,2),Vector2(9,5),Color("f4c172"))
			return true
		"chair": return art.draw(self,["furniture/chair/"+str(obj.rot)],layout.center(obj.data),art_clock)
		"belt": return art.draw(self,[belt_art_key(obj.data)],layout.center(obj.data),art_clock)
		"feeder":
			var f=obj.data;var pos=layout.center(Vector2i(f.x,f.y))
			if not art.draw(self,["furniture/feeder"],pos,art_clock): return false
			text_at(pos+Vector2(-8,-20),"补",16,layout.ZONE_COLORS[f.zone]);return true
		"plate":
			var p=obj.data;var pos=plate_pos(p.t,p.route)-Vector2(0,24)
			var empty_drawn=art.draw(self,["prop/plate"],pos,art_clock)
			var food_key="food/"+str(p.food)
			if not empty_drawn and art.resolve([food_key])==null: return false
			if not empty_drawn: ellipse(pos,Vector2(13,7),Color("fff0da"))
			if not art.draw(self,[food_key],pos-Vector2(0,2),art_clock): draw_circle(pos-Vector2(0,2),6,Color("c78558") if p.food==6 else COLORS[p.food])
			return true
	return false

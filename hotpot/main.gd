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
const Recipes=preload("res://systems/recipes.gd")
const Dishes=preload("res://systems/dishes.gd")
const Patrons=preload("res://systems/patrons.gd")
var patron_rng=RandomNumberGenerator.new()
var SPECIALS=Dishes.special_column("name")
var BASE=Dishes.special_column("core").map(func(core):return core[0])
var menu={"mains":[7,8,6,9],"sides":[12,13,14],"specials":[0]}
var dishes_unlocked=Dishes.mains()+Dishes.sides()+[0]
const FACILITY=["蘸料","饮料","冰淇淋","等候长椅","星灯盆栽"]
var facility_kind=0
# Legacy callers use stock-slot flags. Slot 6 is the prepared beef alternative.
var regular_menu:Array:
	get:
		var flags=[false,false,false,false,false,false,false]
		for id in menu.mains+menu.sides: flags[Dishes.by_id(id).core[0]]=true
		flags[6]=7 in menu.mains
		return flags
	set(flags):
		menu.mains=[]
		menu.sides=[]
		for id in [7,8]+Dishes.sides():
			var dish=Dishes.by_id(id)
			var group=dish.kind+"s"
			if flags[dish.core[0]] or (id==7 and flags[6]):
				if menu[group].size()<Dishes.CAPS[group]: menu[group].append(id)
var reviews=[]
var table_results={}
var formulas=[[],null,null,null,null,null]
var offerings:Array:
	get: return Dishes.specials().map(func(id):return id in menu.specials)
	set(flags):
		menu.specials=[]
		for id in range(mini(flags.size(),Dishes.specials().size())):
			if flags[id] and id in dishes_unlocked and menu.specials.size()<Dishes.CAPS.specials: menu.specials.append(id)
var research_inputs=[]
var toppings=[]
var reserved=[]
var cooked_tags=[]
var kitchen_time=0.0
var cooked=-1
var order_seat=-1
const ORDER_HOLD_SECONDS=24.0
var reputation=70
var event_booked=false
var bulletin="今天是开业第一天。"
var waiting=[]
var departing=[]
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
var build_tool = "select"
var build_rot = 0
var build_zone = 0
var moving_table = -1
var layout_plans = [null, null, null]
var layout_history: Array = []
var build_bar: HBoxContainer
var build_info: Label
var action_label: Label
var slot_buttons: Array = []
var service_bar=HBoxContainer.new()
var service_titles:Array[Label]=[]
var service_details:Array[Label]=[]
var service_icons:Array[TextureRect]=[]
var help:Label
var service_team=[]
var staff_pos = Vector2(360,650)
var staff_path: Array = []
var staff_carry: Array = []
var staff_station = -1
var SIDE_FOODS:Array:
	get: return menu.sides.map(func(id):return Dishes.by_id(id).core[0])
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
# Per stock-slot cooking mastery (0-5 basic ingredients, 6 = stewed frost beef).
var mastery_by_dish: Dictionary = {}
# Legacy single mastery maps to the stew slot.
var mastery: int:
	get: return int(mastery_by_dish.get(STEW_SLOT,0))
	set(value): mastery_by_dish[STEW_SLOT]=int(value)
const STEW_SLOT=6
const QUICK_MASTERY=3
# Timing windows on the 0-100 heat bar. Basic plating is forgiving, the stew is tight.
const WINDOW_NORMAL=Vector2i(30,80)
const WINDOW_SIGNATURE=Vector2i(40,70)
# Skilled plating yields 3 plates per raw portion, a miss yields 1. Plain plating always yields 2.
const COOK_YIELD_SUCCESS=3
const COOK_YIELD_FAIL=1
var cook_slot=-1
var affection = 0
var employee = false
var decor = false
var decor_pos = Vector2(1080, 600)
var phase = "准备"
var selected = 0
var held = -1
const ENTRANCE_AISLE=Vector2(285,365)
var player = ENTRANCE_AISLE
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
var toast_text = "欢迎来到星灯火锅店。先逛市场，再去料理台！"
var toast_time = 8.0
var cooking = false
var cook_time = 0.0
var cook_cursor: ProgressBar
var summary = ""
var furniture_mode = false
var seats: Array = []
var seat_tables: Array = []

const CORNER="res://art/corner/"
const ROOM=preload(CORNER+"room.png")
const BOARDS=preload(CORNER+"floor.png")
const MANAGER=preload(CORNER+"manager.png")
const WAITER=preload(CORNER+"waiter.png")
const DINER=preload(CORNER+"diner.png")
const TABLE=preload(CORNER+"table.png")
const CHAIR=preload(CORNER+"chair.png")
const SERVICE={
	"hotpot":preload("res://art/corner/service/hotpot.png"),
	"plate":preload("res://art/corner/service/plate.png"),
	"station":preload("res://art/corner/service/feeder.png"),
	"market":preload("res://art/corner/service/market.png"),
	"kitchen":preload("res://art/corner/service/kitchen.png"),
	"bell":preload("res://art/corner/service/bell.png"),
	"sauce":preload("res://art/corner/service/sauce.png"),
	"drink":preload("res://art/corner/service/drink.png"),
	"ice":preload("res://art/corner/service/ice.png"),
	"food0":preload("res://art/corner/service/food0.png"),
	"food1":preload("res://art/corner/service/food1.png"),
	"food2":preload("res://art/corner/service/food2.png"),
	"food3":preload("res://art/corner/service/food3.png"),
	"food4":preload("res://art/corner/service/food4.png"),
	"food5":preload("res://art/corner/service/food5.png"),
	"food6":preload("res://art/corner/service/food6.png"),
	"bench":preload("res://art/corner/service/bench.png"),
	"flowers":preload("res://art/corner/service/flowers.png"),
}
const VIEW_CENTER=Vector2(510,510)
var view_focus=Vector2(390,250)
var view_zoom=2.5
var facing_left=false
var staff_left=false
var furniture_bubble=HBoxContainer.new()
var picked={}
var relocating=false
var catalog=HBoxContainer.new()

func view_ground(screen:Vector2)->Vector2:
	return (screen-VIEW_CENTER)/view_zoom+view_focus

func update_view(dt:float):
	var target=player
	if build_mode:
		var pan=movement_input()
		if pan==Vector2.ZERO:
			var mouse=get_viewport().get_mouse_position()
			if mouse.x<35: pan.x=-1
			if mouse.x>1245: pan.x=1
			if mouse.y<35: pan.y=-1
			if mouse.y>785: pan.y=1
		target=view_focus+pan.normalized()*dt*420
	var zoom_target=1.65 if build_mode else 2.5
	view_zoom=lerpf(view_zoom,zoom_target,1-exp(-dt*12)) if not build_mode else zoom_target
	target=target.clamp(Vector2(74,198),Vector2(1170+(120 if layout.expanded else 0),650))
	view_focus=target if build_mode else view_focus.lerp(target,1-exp(-dt*12))
	furniture_bubble.visible=build_mode and not panel.visible and not picked.is_empty() and not relocating
	if furniture_bubble.visible:
		var f=picked.item
		var anchor=layout.center(Vector2i(f.x,f.y))
		furniture_bubble.position=(VIEW_CENTER+(anchor-view_focus-Vector2(0,52))*view_zoom).clamp(Vector2.ZERO,Vector2(1090,615))
	queue_redraw()


func _ready():
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	art.configure(art_pack)
	for problem in art.errors: push_warning("Art: "+problem)
	var theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = 17
	var card = StyleBoxFlat.new()
	card.bg_color = Color("49374e")
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
	normal.bg_color = Color("655271")
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	theme.set_stylebox("normal", "Button", normal)
	var hover = normal.duplicate()
	hover.bg_color = Color("887194")
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", hover)
	normal.bg_color=Color("ffe8d9e8")
	hover.bg_color=Color("ffdfaa")
	theme.set_color("font_color","Button",Color("573b58"))
	theme.set_color("font_hover_color","Button",Color("573b58"))
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = theme
	add_child(ui)
	top = label_at(Vector2(30,18),24)
	hint = label_at(Vector2(24,94),17)
	status = label_at(Vector2(24,154),15)
	help = label_at(Vector2(30,65),15)
	help.text = "WASD 移动 · E 交互 · 1—7 选菜 · Q 放回 · B 布局 · P 暂停 · Esc 关闭"
	var menu = Button.new()
	menu.text = "店长手册 / 存档"
	menu.position = Vector2(1060,18)
	menu.pressed.connect(show_menu)
	ui.add_child(menu)
	var bag=Button.new()
	bag.text="背包 [I]"
	bag.position=Vector2(940,18)
	bag.pressed.connect(show_bag)
	ui.add_child(bag)
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
	build_bar.position=Vector2(35,665)
	ui.add_child(build_bar)
	for category in ["地面","墙面","装饰家具","营业家具"]:
		layout_button(build_bar,category,show_category.bind(category))
	for item in [["分区",func(): build_zone=(build_zone+1)%3],["撤销",undo_layout],["扩建任务",show_expansion],["方案",show_layout_plans],["还原布局",reset_layout],["完成",toggle_build]]:
		layout_button(build_bar,item[0],item[1])
	catalog.position=Vector2(35,724)
	ui.add_child(catalog)
	show_category("营业家具")
	ui.add_child(furniture_bubble)
	layout_button(furniture_bubble,"旋转 ↻",rotate_picked)
	layout_button(furniture_bubble,"移动",func(): relocating=true)
	layout_button(furniture_bubble,"收起",stow_picked)
	furniture_bubble.hide()
	build_info=label_at(Vector2(30,169),16)
	action_label=label_at(Vector2(24,124),16)
	var slots=HBoxContainer.new()
	slots.position=Vector2(294,692)
	slots.add_theme_constant_override("separation",8)
	ui.add_child(slots)
	for i in range(7):
		var b=Button.new()
		b.add_theme_font_size_override("font_size",17)
		b.custom_minimum_size=Vector2(92,90)
		b.icon=SERVICE["food"+str(i)]
		b.expand_icon=true
		b.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment=VERTICAL_ALIGNMENT_TOP
		b.add_theme_constant_override("icon_max_width",50)
		b.add_theme_stylebox_override("normal",hud_chip())
		b.add_theme_stylebox_override("hover",hud_chip(true))
		b.add_theme_stylebox_override("pressed",hud_chip(true))
		b.add_theme_stylebox_override("hover_pressed",hud_chip(true))
		b.toggle_mode=true
		var shortcut=Label.new()
		shortcut.text=str(i+1)
		shortcut.position=Vector2(7,4)
		shortcut.add_theme_font_size_override("font_size",14)
		shortcut.add_theme_color_override("font_color",Color("795570"))
		shortcut.mouse_filter=Control.MOUSE_FILTER_IGNORE
		b.add_child(shortcut)
		for state in ["font_hover_color","font_pressed_color","font_hover_pressed_color"]:
			b.add_theme_color_override(state,Color("543957"))
		b.add_theme_color_override("font_color",Color("543957"))
		b.tooltip_text=dish_name(i)
		b.focus_mode=Control.FOCUS_NONE
		b.pressed.connect(func(): selected=i)
		slots.add_child(b); slot_buttons.append(b)
	setup_service_bar()
	sync_seats()
	view_focus=player
	if auto_load and (FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path+".bak")): load_game()
	refresh()

func setup_service_bar():
	service_bar.position=Vector2(208,696)
	service_bar.add_theme_constant_override("separation",8)
	service_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.add_child(service_bar)
	for i in range(3):
		var card=PanelContainer.new()
		card.custom_minimum_size=Vector2(282,84)
		card.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var style=hud_chip()
		style.content_margin_left=14
		style.content_margin_right=10
		card.add_theme_stylebox_override("panel",style)
		service_bar.add_child(card)
		var row=HBoxContainer.new()
		row.mouse_filter=Control.MOUSE_FILTER_IGNORE
		card.add_child(row)
		var icon=TextureRect.new()
		icon.custom_minimum_size=Vector2(42,42)
		icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		service_icons.append(icon)
		var lines=VBoxContainer.new()
		lines.alignment=BoxContainer.ALIGNMENT_CENTER
		lines.mouse_filter=Control.MOUSE_FILTER_IGNORE
		row.add_child(lines)
		var title=Label.new()
		title.add_theme_font_size_override("font_size",19)
		title.add_theme_color_override("font_color",Color("513953"))
		lines.add_child(title)
		service_titles.append(title)
		var detail=Label.new()
		detail.add_theme_font_size_override("font_size",16)
		detail.add_theme_color_override("font_color",Color("65465a"))
		lines.add_child(detail)
		service_details.append(detail)

func service_card(index:int,title:String,detail:String,food:int=-1):
	service_titles[index].text=title
	service_details[index].text=detail
	service_icons[index].visible=food>=0
	service_icons[index].texture=SERVICE["food"+str(food)] if food>=0 else null

func by_service_window()->bool:
	for tile in layout.neighbors(layout.cell(player)):
		if layout.partitions.get(tile)=="window": return true
	return false

func refresh_service_bar():
	if by_service_window() and not at_kitchen():
		var portions=[0,0,0]
		var outstanding=[0,0,0]
		var stations=[0,0,0]
		for station in layout.stations: stations[station.zone]+=1
		for plate in plates: portions[layout.stations[plate.station].zone]+=plate.portions
		for i in range(guests.size()):
			var g=guests[i]
			if g!=null and g.get("service","waiting") in ["ordered","preparing"]:
				outstanding[layout.tables[seat_tables[i]].zone]+=1
		for z in range(3):
			var supply="本区台余 %d 份"%portions[z] if stations[z]>0 else "可跨区自取"
			service_card(z,layout.zone_name(z)+"区 · 出餐窗",supply+"  /  待送 %d 单"%outstanding[z])
		return
	if at_kitchen() and cooked<0:
		for slot in 3:
			if slot>=menu.specials.size():
				service_card(slot,"空菜位","今晚未上菜单")
				continue
			var j=menu.specials[slot]
			var food=int(BASE[j])
			var detail="%s · 余 %d 盘"%[ING[food],ready_food[food]]
			if order_seat>=0 and guests[order_seat].order==j: detail="原方食材 · 已留齐"
			elif not offerings[j] or formulas[j]==null: detail="今晚未上菜单"
			elif formulas[j]!=null:
				for ingredient in formula(j):
					if ready_food[ingredient]==0: detail=ING[ingredient]+" · 缺 1 盘";break
			service_card(slot,SPECIALS[j],detail,food)
		return
	if order_seat<0:
		var count=0
		for g in guests:
			if g!=null and g.order>=0 and not g.bonus: count+=1
		service_card(0,"待接加单  %d"%count,"点击客人或加单气泡" if count else "客人想加菜时会冒气泡")
		service_card(1,"手持","空盘托" if held<0 else dish_name(held),held)
		service_card(2,"营业剩余 %d 秒"%maxi(0,150-ceili(elapsed)),"已结账 %d / %d 位"%[served,guest_target])
		return
	var guest=guests[order_seat]
	var dish=SPECIALS[guest.order]
	service_card(0,seat_label(order_seat),dish,BASE[guest.order])
	if kitchen_time>0:
		service_card(1,"后厨制作中","%.1f 秒后出锅"%kitchen_time)
		service_card(2,"送餐位置",seat_label(order_seat))
	elif cooked>=0 and held<0:
		service_card(1,"已出锅","回料理台取菜")
		service_card(2,"送餐位置",seat_label(order_seat))
	elif cooked>=0:
		service_card(1,"手持 · "+dish,"已出锅",held)
		service_card(2,"送餐位置",seat_label(order_seat) if guest.trip.is_empty() else "客人自取中，等候回座")
	else:
		service_card(1,"已预留备菜",Recipes.TOOLS[guest.order]+" · 原方已留齐")
		service_card(2,"前往后厨","靠近料理台，点击"+Recipes.TOOLS[guest.order])

func layout_button(parent:Control,title:String,action:Callable):
	var b=Button.new()
	b.text=title
	b.custom_minimum_size=Vector2(84,40)
	b.add_theme_stylebox_override("normal",hud_chip())
	b.add_theme_stylebox_override("hover",hud_chip(true))
	b.pressed.connect(action)
	parent.add_child(b)

func show_category(category:String):
	for b in catalog.get_children(): catalog.remove_child(b);b.queue_free()
	var groups={"地面":[["员工地板","staff"],["走道","aisle"],["拆除","erase"]],"墙面":[["隔墙","wall"],["出餐窗","window"]],"装饰家具":[["星灯盆栽","facility",4]],"营业家具":[["桌椅","table"],["料理台","kitchen"],["食材台","station"],["蘸料台","facility",0],["饮料台","facility",1],["冰淇淋台","facility",2],["长椅","facility",3],["改分区","zone"]]}
	for item in groups[category]:
		layout_button(catalog,item[0],func(): build_tool=item[1];build_rot=(build_rot & 2) if build_tool=="table" else build_rot;facility_kind=item[2] if item.size()>2 else 0;picked={};relocating=false)

func pick_at(c:Vector2i)->Dictionary:
	var idx=layout.table_at(c)
	if idx>=0: return {"type":"table","item":layout.tables[idx]}
	for group in ["facilities","stations","kitchens"]:
		if group=="kitchens" and layout.kitchen_stored: continue
		for f in layout.get(group):
			if c in layout.footprint(f): return {"type":group,"item":f}
	return {}

func stow_picked():
	if picked.is_empty(): return
	remember_layout()
	if picked.type=="kitchens": layout.kitchen_stored=true
	else:
		var items=layout.tables if picked.type=="table" else layout.get(picked.type)
		items.erase(picked.item)
	picked={}
	relocating=false
	layout.compile()
	sync_seats()
	notify("已收起，可从装修目录重新摆放。")

func rotate_picked():
	if picked.is_empty(): return
	var f=picked.item
	change_picked(Vector2i(f.x,f.y),(int(f.get("rot",0))+(2 if picked.type=="table" else 1))%4)

func change_picked(c:Vector2i,rot:int):
	var f=picked.item
	var group=layout.tables if picked.type=="table" else layout.get(picked.type)
	var idx=group.find(f)
	if idx<0: picked={};return
	remember_layout()
	var valid=false
	if picked.type=="kitchens":
		valid=layout.move_kitchen(c,rot)
	elif picked.type=="table":
		valid=layout.place_table(c,rot,f.zone,idx)
	else:
		group.remove_at(idx)
		var candidate=f.duplicate()
		candidate.merge({"x":c.x,"y":c.y,"rot":rot},true)
		valid=layout.place_fixture(group,candidate)
		if valid: group.pop_back()
		group.insert(idx,candidate if valid else f)
	if valid:
		picked.item=group[idx];relocating=false;layout.compile();sync_seats()
	else:
		layout_history.pop_back();notify("这里空间不足。")

func hud_chip(active:bool=false)->StyleBoxFlat:
	var box=StyleBoxFlat.new()
	box.bg_color=Color("ffebc9f2") if active else Color("ffefe1cc")
	box.set_corner_radius_all(12)
	box.set_border_width_all(3 if active else 2)
	box.border_color=Color("e9ab64") if active else Color("fff5e8ec")
	box.shadow_color=Color("65415e77")
	box.shadow_size=2
	box.shadow_offset=Vector2(0,3)
	return box

func label_at(pos: Vector2, size: int) -> Label:
	var l = Label.new()
	l.position = pos
	l.add_theme_constant_override("outline_size",4)
	l.add_theme_color_override("font_outline_color",Color("614660"))
	l.add_theme_font_size_override("font_size",size)
	ui.add_child(l)
	return l

func dish_name(i: int) -> String:
	return "清炖霜牛" if i == 6 else ING[i]

func notify(s: String):
	toast_text = s
	toast_time = 6

func refresh():
	top.text = "星灯火锅店 / 第 %d 天 · %s   金币 %d   收入 %d" % [day,phase,money,income]
	status.text = toast_text if toast_time > 0 else ""
	var guide = "营业 %d 秒 · 已结账 %d/%d" % [maxi(0,150-int(elapsed)),served,guest_target] if phase=="营业" else "准备期 · 左上采购，左下备菜，左侧铃铛开门"
	hint.text="手持：%s   |   %s"%["空盘托" if held<0 else SPECIALS[cooked] if cooked>=0 else dish_name(held),guide]
	if phase=="营业": hint.text="营业剩余 %d 秒 · 已结账 %d/%d"%[maxi(0,150-ceili(elapsed)),served,guest_target]
	if order_seat>=0:
		var meal=SPECIALS[guests[order_seat].order]
		var step="送到桌边" if held>=0 else "回料理台取菜" if cooked>=0 else "前往后厨"
		if kitchen_time>0: step="烹饪中 %.1f 秒"%kitchen_time
		hint.text="%s · %s　%s"%[seat_label(order_seat),meal,step]
	action_label.text=nearby_action()
	if phase=="营业": action_label.text+="　叫号区 %d人等候"%waiting.size()
	for i in range(slot_buttons.size()):
		slot_buttons[i].text=("原 %d · 盘 %d"%[raw[i],ready_food[i]]) if i<raw.size() else "备菜 %d"%ready_food[i]
		slot_buttons[i].set_pressed_no_signal(selected==i)
	
	service_bar.visible=phase=="营业" and not build_mode
	if service_bar.visible: refresh_service_bar()
	slot_buttons[0].get_parent().visible=not build_mode and phase!="营业"
	help.text="WASD 移动 · E 交互 · 点击客人查看加单 · P 暂停" if phase=="营业" else "WASD 移动 · E 交互 · 1—7 选菜 · Q 放回 · B 布局 · P 暂停 · Esc 关闭"
	catalog.visible=build_mode
	build_bar.visible=build_mode
	build_info.visible=build_mode
	if build_mode:
		build_info.text="%s · %s区 · 旋转%d° | WASD 平移，墙面可拖画 / 右键取消或拆除"%[{"staff":"后厨地板：店长和员工可通行","select":"点击家具调整位置","window":"出餐窗：后厨交接窗口","wall":"拖画隔墙，留空作门口","aisle":"拖铺走道","facility":FACILITY[facility_kind],"table":"放桌椅","move":"点击桌子，再点新位置","kitchen":"搬动料理台，R 旋转","station":"放共用食材台","zone":"给桌子或食材台改区","erase":"拆除"}[build_tool],layout.zone_name(build_zone),build_rot*90]
		action_label.text="B / 完成：退出布局；放置免费。房型切换保留家具，请修复红色提示后营业。"

var KITCHEN_STATION:Vector2i:
	get: return layout.kitchen_cell()

func at_kitchen()->bool:
	var cell=layout.cell(player)
	return not layout.kitchen_stored and layout.floor_at(cell) and player.distance_to(layout.center(KITCHEN_STATION))<55 and layout.path(cell,KITCHEN_STATION,true).size() in [1,2]

func nearby_action() -> String:
	if build_mode: return ""
	if player.distance_to(Vector2(100,205))<34: return "[E] 查看后门路牌"
	if player.distance_to(Vector2(160,220))<120: return "[E] 打开采购" if phase!="营业" else "商户已收摊"
	if at_kitchen(): return "[E / C] 查看定制单" if phase=="营业" else "[E] 打开料理台"
	if player.distance_to(Vector2(160,365))<80: return "[E] 开店 / 招聘 / 岗位安排"
	if phase=="营业":
		if order_seat>=0 and held>=0 and kitchen_time<=0 and player.distance_to(seats[order_seat])<65:
			return "[E] 送到"+seat_label(order_seat) if guests[order_seat].trip.is_empty() else "客人正在自取，稍候回座"
	return "普通菜自动出餐；客人点了定制菜时，到后厨按 E 查看。"

func sync_seats():
	if not picked.is_empty():
		var group=layout.tables if picked.type=="table" else layout.get(picked.type)
		if not group.has(picked.item): picked={};relocating=false
	seats.clear(); seat_tables.clear(); guests.clear()
	for i in range(layout.tables.size()):
		for c in layout.chairs(layout.tables[i]):
			seats.append(layout.center(c));seat_tables.append(i);guests.append(null)

func remember_layout():
	layout_history.append(layout.snapshot())
	if layout_history.size()>40: layout_history.pop_front()

func undo_layout():
	if layout_history.is_empty(): return
	picked={};relocating=false;restore_interior(layout_history.pop_back());moving_table=-1;sync_seats()

func toggle_build():
	if phase!="准备": notify("准备期才能调整布局，先完成当晚营业。");return
	picked={};relocating=false;build_tool="select";panel.hide(); cooking=false;build_mode=not build_mode;moving_table=-1
	layout.compile();sync_seats()
	if not build_mode:
		if not player_can_stand(player): player=ENTRANCE_AISLE
		save_game()
		if not layout.errors.is_empty(): notify(layout.errors[0])

func show_expansion():
	clear_panel("店铺扩建")
	if layout.expanded: line("东侧三列已开放装修。")
	elif day<4: line("完成三个营业日后，可向东扩建三列。")
	else: button("领取扩建 · 向东三列",func(): layout.expanded=true;layout.compile();save_game();panel.hide())
	close_button()

func restore_interior(plan:Dictionary):
	var expanded=layout.expanded
	layout.restore(plan)
	layout.expanded=expanded
	layout.compile()

func show_layout_plans():
	if phase!="准备": return
	clear_panel("布局方案")
	for slot in range(layout_plans.size()):
		var plan=layout_plans[slot]
		var title="方案 %d"%(slot+1)
		if plan==null:
			button(title+" · 保存当前布局",store_layout_plan.bind(slot))
		else:
			line("%s · %s · %d桌 / %d个食材台"%[title,["方形","长条","L形"][int(plan.shape)],plan.tables.size(),plan.stations.size()])
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
	restore_interior(layout_plans[slot])
	sync_seats()
	moving_table=-1
	panel.hide()
	notify("已使用方案 %d。可撤销，完成布局后保存。"%(slot+1))

func reset_layout():
	clear_panel("还原店铺布局？")
	line("将替换当前桌椅和食材台，恢复方形双区布局。资金与食材保留。可以用撤销恢复。")
	button("确认还原",func(): remember_layout();layout.reset();sync_seats();panel.hide())
	close_button()

func edit_cell(c: Vector2i):
	if relocating and not picked.is_empty():
		change_picked(c,int(picked.item.get("rot",0)));return
	if build_tool=="select":
		picked=pick_at(c);return
	if not layout.floor_at(c) and build_tool!="erase" and build_tool!="move": return
	if build_tool=="move" and moving_table<0:
		moving_table=layout.table_at(c)
		if moving_table>=0: build_rot=layout.tables[moving_table].rot;build_zone=layout.tables[moving_table].zone
		return
	remember_layout()
	var success=true
	match build_tool:
		"staff","window","wall","aisle": success=layout.paint_partition(c,build_tool)
		"facility": success=layout.place_facility(c,facility_kind,build_rot)
		"table": success=layout.place_table(c,build_rot,build_zone)
		"move":
			if moving_table>=0:
				success=layout.place_table(c,build_rot,build_zone,moving_table)
				if success: moving_table=-1
		"kitchen": success=layout.move_kitchen(c,build_rot)
		"station": success=layout.place_station(c,build_zone,build_rot)
		"erase": layout.erase(c)
		"zone":
			var i=layout.table_at(c)
			if i>=0: layout.tables[i].zone=build_zone
			else:
				for f in layout.stations:
					if c in layout.footprint(f): f.zone=build_zone
	if success and build_tool in ["facility","table","station","kitchen"]:
		build_tool="select";picked=pick_at(c)
	if not success:
		layout_history.pop_back();notify("不能放在这里：需要完整地板，桌椅和设备不能重叠。")
	layout.compile();sync_seats()

func player_can_stand(p: Vector2) -> bool:
	if not Rect2(65,185,1145+(120 if layout.expanded else 0),485).has_point(p): return false
	for offset in [Vector2(-10,-8),Vector2(10,-8),Vector2(-10,8),Vector2(10,8)]:
		var q=p+offset
		if Rect2(124,238,92,20).has_point(q) or Rect2(148,368,24,12).has_point(q): return false
		var tile=layout.cell(q)
		if q.x>=layout.ORIGIN.x and (not layout.walkable(tile,true) or layout.table_at(tile)>=0): return false
	return true

func movement_input()->Vector2:
	return Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))

func _process(dt):
	var before_player=player
	var before_staff=staff_pos
	toast_time -= dt
	if not panel.visible and not furniture_mode and not build_mode:
		var v=movement_input()
		var next = player + v.normalized()*230*dt
		next.x = clampf(next.x,80,1190+(120 if layout.expanded else 0))
		next.y = clampf(next.y,195,650)
		if player_can_stand(Vector2(next.x,player.y)): player.x=next.x
		if player_can_stand(Vector2(player.x,next.y)): player.y=next.y
	if build_mode and get_viewport().gui_get_hovered_control()==null and not panel.visible and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and build_tool in ["erase","zone","wall","aisle","staff"]:
		var c=layout.cell(view_ground(get_viewport().get_mouse_position()))
		if c!=last_brush: last_brush=c;edit_cell(c)
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): last_brush=Vector2i(-100,-100)
	if cooking and is_instance_valid(cook_cursor):
		cook_time += dt
		cook_cursor.value = (sin(cook_time*3.0)+1)*50
	if phase == "营业" and not panel.visible: tick_business(dt)
	if player.x!=before_player.x: facing_left=player.x<before_player.x
	if staff_pos.x!=before_staff.x: staff_left=staff_pos.x<before_staff.x
	player_motion=player.distance_to(before_player)>0.01
	staff_motion=staff_pos.distance_to(before_staff)>0.01
	art_clock+=dt
	art.actor_time("player",player_animation(),dt)
	art.actor_time("lumi",staff_animation_name(),dt)
	refresh()
	update_view(dt)

func _unhandled_key_input(e):
	if not e is InputEventKey or not e.pressed or e.echo: return
	if e.keycode==KEY_I:
		show_bag();return
	if e.keycode==KEY_B: toggle_build();return
	if build_mode:
		if e.keycode==KEY_ESCAPE:
			if panel.visible: panel.hide()
			elif moving_table>=0: moving_table=-1
			elif not picked.is_empty(): picked={};relocating=false
			else: toggle_build()
		elif e.keycode==KEY_R:
			if not picked.is_empty(): rotate_picked()
			else: build_rot=(build_rot+(2 if build_tool in ["table","move"] else 1))%4
		elif e.keycode>=KEY_1 and e.keycode<=KEY_3: build_zone=e.keycode-KEY_1
		return
	if e.keycode == KEY_ESCAPE:
		cooking = false
		panel.hide()
		furniture_mode = false
	elif e.keycode >= KEY_1 and e.keycode <= KEY_7: selected = e.keycode-KEY_1
	elif kitchen_time>0: return
	elif e.keycode==KEY_C and phase=="营业" and not panel.visible and at_kitchen(): kitchen_orders()
	elif e.keycode == KEY_Q and held >= 0:
		release_order()
	elif e.keycode == KEY_F and phase != "营业" and decor:
		panel.hide()
		furniture_mode = not furniture_mode
		notify("点击地板摆放星灯盆栽；F / Esc 退出。")
	elif e.keycode == KEY_E and not panel.visible: interact()

func _unhandled_input(e):
	if phase=="营业" and not panel.visible and e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT and e.pressed:
		var point=view_ground(e.position)
		for station in range(layout.stations.size()):
			var f=layout.stations[station]
			if station_rect(f).has_point(point) or layout.cell(point) in layout.footprint(f):
				clear_panel("%d号食材台 · 全店共用"%(station+1))
				for tray in plates:
					if tray.station==station: line("%s · %s（%d / 6）"%[ING[tray.food],portion_label(tray.portions),tray.portions])
				if station_plate_count(station)==0: line("空台 · 等待员工补餐")
				close_button()
				return
		if at_kitchen() and cooked<0:
			for j in range(Recipes.TOOLS.size()):
				if utensil_rect(j).has_point(point):
					if order_seat>=0 and guests[order_seat].order==j: show_dish(order_seat,guests[order_seat].ticket)
					else: kitchen_orders(j)
					return
		for i in range(guests.size()-1,-1,-1):
			var g=guests[i]
			if g!=null and g.order>=0 and g.trip.is_empty() and order_bubble(i).has_point(point):
				show_diner(i)
				return
		for i in range(guests.size()-1,-1,-1):
			var g=guests[i]
			if g!=null and Rect2(diner_position(i)-Vector2(25,60),Vector2(50,62)).has_point(point):
				show_diner(i)
				return
	if build_mode and not panel.visible and e is InputEventMouseButton and e.pressed:
		var c=layout.cell(view_ground(e.position))
		if e.button_index==MOUSE_BUTTON_LEFT:
			last_brush=c
			if not relocating and build_tool not in ["erase","zone","move","aisle","staff"] and not pick_at(c).is_empty(): build_tool="select"
			edit_cell(c)
		elif e.button_index==MOUSE_BUTTON_RIGHT:
			if relocating: relocating=false
			elif moving_table>=0: moving_table=-1
			else:
				picked={}
				remember_layout();layout.erase(c);layout.compile();sync_seats()
		return
	if furniture_mode and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var p = view_ground(e.position)
		if Rect2(90,170,1080,470).has_point(p) and not Rect2(320,230,650,330).has_point(p):
			decor_pos = p
			furniture_mode = false
			save_game()

func interact():
	if player.distance_to(Vector2(100,205))<34:
		clear_panel("后门 · 郊外小径")
		line("农场、牧场、工坊和鱼塘将在后续开放。")
		close_button();return
	if player.distance_to(Vector2(160,220)) < 120:
		if phase == "营业": notify("商户收摊了，明天再采购。")
		else: show_market()
		return
	if at_kitchen():
		if phase == "营业": kitchen_orders()
		else: show_kitchen()
		return
	if player.distance_to(Vector2(160,365)) < 80:
		if phase == "结算": show_summary()
		elif phase != "营业": show_open()
		return
	if phase == "营业":
		if order_seat>=0 and cooked>=0:
			if player.distance_to(seats[order_seat])<65 and guests[order_seat].trip.is_empty():
				serve_guest(order_seat)
			else: notify("请到"+seat_label(order_seat)+"旁，等客人回座后送餐。")
			return
		notify("点击有气泡的客人可以接单，也可以在后厨选单。")

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
	line("预计采购%d金；持有%d金。%s"%[plan.cost,money,"露米今晚另需8金工资。" if employee else "当班补餐员每趟从厨房带两盘到食材台。"])
	button("按清单采购 · %d金"%plan.cost,func(): buy_recommended();show_preparation())
	button("按计划装盘 · 保留多余原料",func(): prepare_recommended();show_preparation())
	button("查看开店检查",show_open)
	close_button()

func show_bag():
	clear_panel("背包 · 食材库存")
	for group in ["原料","备菜"]:
		line(group)
		var grid=GridContainer.new()
		grid.columns=4
		panel_box.add_child(grid)
		var counts=raw if group=="原料" else ready_food
		for i in range(counts.size()):
			var item=Button.new()
			item.custom_minimum_size=Vector2(88,72)
			item.icon=SERVICE["food"+str(i)]
			item.expand_icon=true
			item.vertical_icon_alignment=VERTICAL_ALIGNMENT_TOP
			item.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
			item.text="×%d"%counts[i]
			item.add_theme_stylebox_override("normal",hud_chip())
			item.tooltip_text="%s · %s ×%d\n%s"%[dish_name(i),group,counts[i],"用于研发；1份可装2盘" if group=="原料" else "可供餐或按配方取用 · 饱腹 %d"%FILL[i]]
			grid.add_child(item)
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
	button("菜谱研发 · 投入原料试做",show_research)
	button("按预计客流制定备菜计划",show_preparation)
	for i in range(6):
		button("装盘 %s（饱腹%d） 原料%d / 待上%d" % [ING[i],FILL[i],raw[i],ready_food[i]],func(): prepare(i); show_kitchen())
		var skilled=mastery_by_dish.get(i,0)>=QUICK_MASTERY
		button("%s %s · 1份出%d盘  [熟练 %d/%d]" % ["快速精装" if skilled else "火候精装",ING[i],COOK_YIELD_SUCCESS,mini(int(mastery_by_dish.get(i,0)),QUICK_MASTERY),QUICK_MASTERY],cook_dish.bind(i))
	button("全部基础食材批量装盘",func(): prepare_all();show_kitchen())
	button("清炖霜牛：牛肉 + 豆腐  [熟练 %d/3]" % mastery,show_cook)
	line("普通装盘稳定出2盘；火候精装命中出%d盘、失手只出%d盘，熟练3次后可快速精装。\n清炖霜牛标签：肉类 · 清淡。勇者喜欢它。"%[COOK_YIELD_SUCCESS,COOK_YIELD_FAIL])
	close_button()

func change_input(items:Array,food:int):
	if food in items: items.erase(food)
	else: items.append(food)

func show_research():
	if phase!="准备": return
	clear_panel("菜谱研发")
	line("每种原料投入一份，试做时消耗。核心齐全的原方中，优先匹配核心种类最多的一道。")
	for j in range(SPECIALS.size()):
		line("%s · %s · 核心 %s"%[SPECIALS[j],Recipes.TOOLS[j],ingredient_names(Recipes.CORES[j])])
	for food in range(raw.size()):
		button("%s %s · 库存 %d"%["已选" if food in research_inputs else "选择",ING[food],raw[food]],func(): change_input(research_inputs,food);show_research())
	button("试做并记录配方",research)
	line("成功后更新这道菜的配方。到营业铃的今晚菜单上架。")
	close_button()

func ingredient_names(foods:Array)->String:
	var names=[]
	for food in foods: names.append(ING[food])
	return "、".join(names)

func research():
	if phase!="准备" or research_inputs.is_empty(): return
	for food in research_inputs:
		if raw[food]<1: notify(ING[food]+"不足。");return
	for food in research_inputs: raw[food]-=1
	var result=Recipes.match_inputs(research_inputs)
	research_inputs.clear()
	clear_panel("试做结果")
	if result.has("error"): line(result.error)
	else:
		var j=int(result.recipe)
		formulas[j]=result.extras
		if j not in dishes_unlocked: dishes_unlocked.append(j)
		line(SPECIALS[j]+" · "+"、".join(Recipes.tags(j,result.extras)))
		line("已记入菜谱。每份需 "+ingredient_names(formula(j)))
	save_game()
	button("继续研发",show_research)
	button("调整今晚菜单",configure_menu)
	close_button()

func formula(j:int)->Array:
	return Recipes.CORES[j]+formulas[j]

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
	cook_dish(STEW_SLOT)

func cook_window(slot:int)->Vector2i:
	return WINDOW_SIGNATURE if slot==STEW_SLOT else WINDOW_NORMAL

func cook_inputs(slot:int)->Array:
	return [1,4] if slot==STEW_SLOT else [slot]

func can_cook(slot:int)->bool:
	if phase!="准备" or slot<0 or slot>STEW_SLOT: return false
	return cook_inputs(slot).all(func(food):return raw[food]>=1)

# Opens the heat-bar minigame for one stock slot, or finishes instantly once mastered.
func cook_dish(slot:int):
	if not can_cook(slot):
		notify("需要 1 份牛肉和 1 份豆腐。" if slot==STEW_SLOT else "缺少%s原料，或营业中不能备菜。"%ING[clampi(slot,0,5)])
		return
	if int(mastery_by_dish.get(slot,0))>=QUICK_MASTERY:
		finish_cook_dish(slot,1)
		show_kitchen()
		return
	var window=cook_window(slot)
	cook_slot=slot
	clear_panel(("小锅慢炖" if slot==STEW_SLOT else "火候精装 · "+ING[slot])+" · 火候小游戏")
	if slot==STEW_SLOT: line("在火候条 %d—%d 时点击出锅。\n成功：2 盘清炖霜牛，熟练度 +1。\n失误：原料仍变成 2 盘牛肉，不会白白丢失。"%[window.x,window.y])
	else: line("在火候条 %d—%d 时点击出锅。\n成功：1 份原料出 %d 盘，熟练度 +1。\n失误：只出 %d 盘。"%[window.x,window.y,COOK_YIELD_SUCCESS,COOK_YIELD_FAIL])
	cook_cursor = ProgressBar.new()
	cook_cursor.custom_minimum_size = Vector2(380,40)
	panel_box.add_child(cook_cursor)
	cook_time = 0
	cooking = true
	button("现在出锅！",func(): finish_cook_dish(slot,heat_quality(slot,cook_cursor.value)); show_kitchen())
	close_button()

func heat_quality(slot:int,heat:float)->int:
	var window=cook_window(slot)
	return 1 if heat>=window.x and heat<=window.y else 0

# quality: 1 success, 0 miss. Returns false when nothing was cooked.
func finish_cook_dish(slot:int,quality:int)->bool:
	if slot==STEW_SLOT:
		if raw[1] < 1 or raw[4] < 1: return false
		finish_cook(quality==1)
		return true
	if slot<0 or slot>=6 or raw[slot]<1: return false
	raw[slot]-=1
	ready_food[slot]+=COOK_YIELD_SUCCESS if quality==1 else COOK_YIELD_FAIL
	if quality==1: mastery_by_dish[slot]=int(mastery_by_dish.get(slot,0))+1
	notify("%s精装完成，出%d盘。"%[ING[slot],COOK_YIELD_SUCCESS] if quality==1 else "火候偏了，%s只装出%d盘。"%[ING[slot],COOK_YIELD_FAIL])
	cooking=false
	cook_slot=-1
	return true

func finish_cook(success: bool):
	if raw[1] < 1 or raw[4] < 1: return
	raw[1] -= 1
	raw[4] -= 1
	ready_food[6 if success else 1] += 2
	if success: mastery += 1
	notify("炖菜完成！熟练三次后解锁快捷制作。" if success else "火候偏了，改成普通牛肉盘。")
	cooking = false
	cook_slot = -1

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
	clear_panel("今晚菜单")
	for group in Dishes.CAPS:
		var title={"mains":"主菜","sides":"自取","specials":"特别菜"}[group]
		line("%s　%d / %d"%[title,menu[group].size(),Dishes.CAPS[group]])
		for dish in Dishes.DISHES:
			if dish.kind+"s"!=group: continue
			if dish.id not in dishes_unlocked:
				line(dish.name+" · 待研发")
			else:
				button(("供应 · " if dish.id in menu[group] else "下架 · ")+dish.name,change_menu.bind(dish.id))
	close_button()

func change_menu(id:int):
	if not Dishes.toggle(menu,dishes_unlocked,id): notify("本类菜单已满，请先下架一道菜。")
	configure_menu()

func show_open():
	clear_panel("星灯营业铃")
	line("每位入座客人支付同一餐费。饱腹离席，完成加单另收小费。")
	button("街区快报与活动",show_news)
	button("调整今晚菜单",configure_menu)
	var price=HSlider.new()
	price.min_value=18
	price.max_value=30
	price.step=3
	price.value=menu_price
	panel_box.add_child(price)
	var forecast=Label.new()
	panel_box.add_child(forecast)
	var update_price=func(value):
		menu_price=int(value)
		forecast.text="每客 %d 金　·　预计 %d 位客人"%[menu_price,expected_guests()]
	price.value_changed.connect(update_price)
	update_price.call(price.value)
	line("基础客流随餐费变化，昨日口碑和今日活动会影响到店人数。")
	layout.compile()
	line("布局：%d 张桌 / %d 座 / %d 个食材台。"%[layout.tables.size(),seats.size(),layout.stations.size()])
	if not layout.errors.is_empty(): line("必须修复："+str(layout.errors[0]))
	var plan=preparation_plan()
	line("库存检查：已备%d / 建议%d盘。%s"%[plan.total,plan.recommended,"不足12盘，不能开门。" if plan.total<12 else "可开门；仍有缺餐风险。" if plan.missing>0 else "数量充足，注意及时补餐。"])
	if employee and money<8: line("资金提醒：当前不足8金工资，需依靠今晚收入支付。")
	if not employee: line("主菜由送餐员送桌，自取台由当班员工补餐。招聘露米可提高每趟运量。")
	button("库存预警与备菜计划",show_preparation)
	line("肉类点单送桌，蔬菜到食材台自取，店长在后厨现做定制菜。")
	button("敲铃 · 开始营业",func(): start_business())
	if not employee: button("招聘露米 · 符文补餐员 30 金",func(): hire(); show_open())
	else:
		line("露米 Lv.%d · 经验%d/60 · 今晚工资8金。\n每趟运%d盘，步速%d；完成补餐与营业积累经验。"%[staff_level(),staff_exp,staff_capacity(),staff_speed()])
		button("岗位：%s（点击切换）"%("自动巡区" if staff_zone<0 else layout.zone_name(staff_zone)+"区"),cycle_staff_zone)
	if not decor: button("购买星灯盆栽 15 金 · 评价 +5",func(): if money >= 15: money-=15; spending+=15; decor=true; show_open())
	close_button()

func expected_guests() -> int:
	return maxi(3,(18-roundi(menu_price/3.0))+roundi((reputation-70)/6.0)+(5 if event_booked else 0))

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
	reviews.clear()
	table_results.clear()
	zone_stats=[]
	for z in range(3): zone_stats.append({"visits":0,"hungry":0.0,"score":0,"meals":0,"arrivals":0,"first_wait":0.0,"side_walk":0.0})
	service_team.clear()
	for role in ["点单","送餐"]:
		service_team.append({"role":role,"pos":layout.center(KITCHEN_STATION),"path":[],"stage":"idle","seat":-1,"ticket":-1,"food":-1})
	staff_pos=layout.center(layout.kitchen_cell());staff_path.clear();staff_carry.clear();staff_station=-1;staff_state="备餐区"
	var total = 0
	for i in range(ready_food.size()):
		if regular_menu[i]: total+=ready_food[i]
	if total < 12:
		notify("普通菜单上架菜品至少备齐 12 盘再营业，建议按预计客人数准备每人3盘。")
		return false
	if not save_game(): return false
	patron_rng.seed=day+2
	guest_target=expected_guests()
	staff_trips=0
	phase = "营业"
	elapsed = 0
	spawned = 0
	waiting.clear();departing.clear();lost=0;missed_taste=0;cooked=-1
	spawn_clock = 0
	staff_clock = 0
	panel.hide()
	spawn_guest()
	notify("开门啦！普通菜开始自动供应，留意客人的定制单。勇者将第三个到来。")
	return true

func seat_label(i:int)->String:
	return "%s区 %d桌%s席"%[layout.zone_name(layout.tables[seat_tables[i]].zone),seat_tables[i]+1,"左" if i%2==0 else "右"]

func order_bubble(i:int)->Rect2:
	return Rect2(diner_position(i)+Vector2(-54,-72 if i%2==0 else -103),Vector2(113,40))

func show_diner(i:int):
	var g=guests[i]
	clear_panel(("%s · "%seat_label(i))+("莱恩" if g.special else "客人 %d"%(g.ticket+1)))
	line("忌口："+"、".join(g.profile.dislikes))
	line("喜好："+TASTE[g.wish]+" · "+ING[g.wish])
	if g.special: line("期待：尝到招牌霜牛")
	elif g.ticket%4==0: line("期待：赶路前快点吃饱")
	if g.has("main_dish"): line("常规点单："+Dishes.by_id(g.main_dish).name)
	if g.liked: line("吃到了喜欢的"+g.profile.preference+"口味")
	line("首菜等候 %.0f 秒"%g.get("served_at",g.wait))
	line("饱腹 %d / %d"%[g.full,g.capacity])
	if g.order>=0:
		line("加单："+SPECIALS[g.order]+("（已送达）" if g.bonus else ""))
		line("这次想吃："+g.get("craving","随意"))
		if not g.bonus and order_seat<0:
			button("接单 · "+ingredient_names(formula(g.order)),accept_order.bind(i,g.ticket))
		elif order_seat==i: line("店长已接单")
	close_button()

func accept_order(i:int,ticket:int)->bool:
	var g=guests[i]
	if phase!="营业" or g==null or g.ticket!=ticket or g.order<0 or g.bonus or order_seat>=0: return false
	if formulas[g.order]==null: return false
	for food in formula(g.order):
		if ready_food[food]<=0: notify("缺少备菜："+ING[food]);return false
	reserved=formula(g.order)
	for food in reserved: ready_food[food]-=1
	order_seat=i
	g.accepted_at=g.wait
	panel.hide()
	notify("已接"+seat_label(i)+"的"+SPECIALS[g.order]+"，到后厨制作。")
	return true

func release_order():
	for food in reserved: ready_food[food]+=1
	if reserved.is_empty() and held>=0: ready_food[held]+=1
	reserved.clear()
	toppings.clear()
	cooked_tags.clear()
	held=-1
	cooked=-1
	kitchen_time=0
	order_seat=-1

func utensil_rect(j:int)->Rect2:
	var pos=layout.fixture_center(layout.kitchens[0])+Vector2(-63+(j%3)*43,-61-int(j/3)*20)
	return Rect2(pos,Vector2(42,19))

func kitchen_orders(tool:int=-1):
	clear_panel("后厨 · 现做加单")
	var count=0
	if tool<0:
		for j in range(SPECIALS.size()):
			button(Recipes.TOOLS[j]+" · "+SPECIALS[j],kitchen_orders.bind(j))
	for i in range(guests.size()):
		var g=guests[i]
		if g==null or g.order<0 or g.bonus or (order_seat>=0 and order_seat!=i): continue
		if g.order!=tool: continue
		count+=1
		if cooked<0:
			var stock="原方已留齐" if order_seat==i else ingredient_names(formula(g.order))
			button("制作 · %s · %s（%s）"%[seat_label(i),SPECIALS[g.order],stock],show_dish.bind(i,g.ticket))
		else: line(seat_label(i)+" · "+SPECIALS[g.order]+(" 烹饪中" if kitchen_time>0 else " 待送餐"))
	if count==0 and tool>=0: line("这件厨具目前没有待做订单。")
	if order_seat>=0:
		button("放回备菜并取消接单" if held>=0 else "取消接单",func(): release_order(); kitchen_orders())
	close_button()

func show_dish(i:int,ticket:int):
	if not at_kitchen() or cooked>=0: return
	if order_seat<0 and not accept_order(i,ticket): return
	if order_seat!=i or guests[i].ticket!=ticket: return
	var g=guests[i]
	var j=int(g.order)
	var tags=Recipes.tags(j,formulas[j]+toppings)
	clear_panel(Recipes.TOOLS[j]+" · "+SPECIALS[j])
	line(seat_label(i)+" · 原方 "+ingredient_names(formula(j)))
	line("本锅标签："+"、".join(tags))
	line("平时喜欢："+TASTE[g.wish]+("（已满足）" if TASTE[g.wish] in tags else "（未满足）"))
	var craving=g.get("craving","随意")
	line("今天想吃："+craving+("（已满足）" if craving in tags else "（未满足）"))
	button("按原方开火" if toppings.is_empty() else "加料开火",cook_order.bind(i,ticket))
	for food in range(ING.size()):
		if ready_food[food]<=0 or TASTE[food] in Recipes.FORBIDDEN[j]: continue
		button("%s %s · %s（余%d）"%["移除" if food in toppings else "加料",ING[food],TASTE[food],ready_food[food]],func(): change_input(toppings,food);show_dish(i,ticket))
	close_button()

func cook_order(i:int,ticket:int):
	if not at_kitchen() or cooked>=0 or held>=0: return
	var g=guests[i]
	if g==null or g.ticket!=ticket or g.order<0 or g.bonus: return
	if order_seat<0 and not accept_order(i,ticket): return
	if order_seat!=i: return
	for food in toppings:
		if ready_food[food]<=0: notify(ING[food]+"已用完。");return
	for food in toppings:
		ready_food[food]-=1
		reserved.append(food)
	cooked_tags=Recipes.tags(g.order,formulas[g.order]+toppings)
	toppings.clear()
	cooked=g.order
	kitchen_time=2.5
	panel.hide()
	notify("正在制作"+SPECIALS[cooked]+"…")

func spawn_guest():
	if spawned>=guest_target: return
	var ticket=spawned
	spawned+=1
	if waiting.size()>=layout.QUEUE_SIZE:
		lost+=1
		return
	waiting.append({"position":layout.center(layout.DOOR)+Vector2(0,20),"ticket":ticket,"patience":18+(ticket%4)*5+maxi(0,reputation-60)/4.0})
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
	var entry=waiting.pop_front()
	var route=layout.guest_path(layout.cell(seats[chosen]),layout.cell(entry.position) if entry.position.y<=layout.center(layout.DOOR).y else layout.DOOR)
	route.reverse()
	var ticket=int(entry.ticket)
	var profile=Patrons.profile(ticket,patron_rng)
	var wish=profile.wish
	guests[chosen]={"profile":profile,"ticket":ticket,"position":entry.position,"trip":route.map(layout.center),"visited":[],"full":0,"capacity":68+(ticket%4)*12,"order":-1,"order_at":0.0,"liked":false,"wish":wish,"special":ticket==2,"eaten":0,"wait":0.0,"bonus":false,"score":80-maxi(0,menu_price-24),"last_meal":0.0,"hungry":0.0}

func station_plate_count(station:int)->int:
	var count=0
	for tray in plates:
		if tray.station==station and tray.portions>0: count+=1
	return count

func portion_label(portions:int)->String:
	if portions==6: return "满"
	if portions>=4: return "大量"
	if portions>0: return "少量"
	return "空"

func add_plate(station:int,food:int)->bool:
	if station<0 or station>=layout.stations.size() or station_plate_count(station)>=layout.STATION_CAPACITY: return false
	for tray in plates:
		if tray.station==station and tray.portions==0:
			tray.food=food
			tray.portions=6
			return true
	plates.append({"station":station,"food":food,"portions":6})
	return true

func tick_business(dt: float):
	elapsed+=dt
	if kitchen_time>0:
		kitchen_time=maxf(0,kitchen_time-dt)
		if kitchen_time==0: notify("出锅了，到料理台取菜。")
	if cooked>=0 and kitchen_time==0 and held<0 and at_kitchen(): held=BASE[cooked]
	spawn_clock += dt
	if spawn_clock >= (5.0 if event_booked else 8.0)+float(spawned%3):
		spawn_clock = 0
		spawn_guest()
	seat_next()
	var benches=0
	for f in layout.facilities:
		if f.kind==3: benches+=1
	for j in range(waiting.size()-1,-1,-1):
		var target=layout.center(layout.queue_tile(j))
		var pos=waiting[j].position
		if pos.y!=target.y: target=Vector2(pos.x,target.y)
		waiting[j].position=pos.move_toward(target,dt*115)
		waiting[j].patience-=dt*(0.55 if j<benches*2 else 1.0)
		if waiting[j].patience<=0:
			departing.append({"position":waiting[j].position,"trip":[layout.center(layout.DOOR),layout.center(layout.DOOR)+Vector2(0,24)]})
			waiting.remove_at(j);lost+=1
	for actor in departing.duplicate():
		actor.position=actor.position.move_toward(actor.trip[0],dt*120)
		if actor.position==actor.trip[0]: actor.trip.pop_front()
		if actor.trip.is_empty(): departing.erase(actor)
	for i in range(seats.size()):
		var g = guests[i]
		if g == null: continue
		g.wait+=dt
		if not g.trip.is_empty() and not g.get("waiting_refill",false) and g.get("facility_pause",0.0)<=0: g.walk_seconds=g.get("walk_seconds",0.0)+dt
		if g.order<0 and (g.eaten>0 or (g.has("served_at") and g.wait-g.served_at>=3)) and (g.special or g.ticket%4!=3):
			var recipe=preferred_special(g)
			if recipe>=0:
				g.craving=g.profile.preference
				g.order=recipe
				g.order_at=g.wait
		if not g.trip.is_empty():
			if g.get("facility_pause",0.0)>0:
				g.facility_pause-=dt
				continue
			if g.trip[0].x!=g.position.x: g.left=g.trip[0].x<g.position.x
			g.position=g.position.move_toward(g.trip[0],dt*110)
			if g.position==g.trip[0]: g.trip.pop_front()
			if g.trip.is_empty():
				if g.has("pickup_station"):
					# Another diner can empty the tray while this guest is on the way.
					if station_plate_count(g.pickup_station)==0 and g.get("refill_wait",0.0)<22 and g.wait-g.get("served_at",0.0)<65:
						g.waiting_refill=true
						g.refill_wait=g.get("refill_wait",0.0)+dt
						g.trip=[g.position]
						continue
					g.waiting_refill=false
					g.tried_side=true
					take_side_at_station(g)
					g.erase("pickup_station")
					g.trip=g.return_trip
					g.erase("return_trip")
				elif g.has("carry_food"):
					g.pot_food=g.carry_food
					g.erase("carry_food")
					g.eating_time=1.0
				elif g.has("facility_return"):
					g.facility_pause=1.1
					g.trip=g.facility_return
					g.erase("facility_return")
				elif g.get("facility_visit",-1)==2: g.full+=10
				if g.trip.is_empty(): g.erase("facility_visit")
			continue
		if g.has("eating_time"):
			g.eating_time-=dt
			if g.eating_time<=0: finish_side(g)
			continue
		if order_seat==i and g.wait-g.accepted_at<ORDER_HOLD_SECONDS: continue
		var kind=next_facility(g)
		if g.get("service","waiting")=="served" and kind>=0:
			var best=[]
			for index in layout.facilities.size():
				if layout.facilities[index].kind!=kind: continue
				var route=layout.guest_path(layout.cell(seats[i]),layout.facility_access[index])
				if not route.is_empty() and (best.is_empty() or route.size()<best.size()): best=route
			if not best.is_empty():
				g.visited.append(kind)
				g.facility_visit=kind
				for cell in best: g.trip.append(layout.center(cell))
				g.facility_return=g.trip.duplicate()
				g.facility_return.reverse()
				continue
		g.last_meal+=dt
		var table=layout.tables[seat_tables[i]]
		var r=layout.station_for_table(table)
		for station in layout.stations_for_table(table):
			if station_plate_count(station)>0:
				r=station
				break
		if g.get("service","waiting") not in ["served","out"]:
			if g.wait-g.get("reordered_at",0.0)>65: checkout(i)
			continue
		if g.full<g.capacity and g.last_meal>10: g.hungry+=dt
		if g.wait-g.get("served_at",0.0)>65 or g.full>=g.capacity:
			checkout(i)
			continue
		var side_count=int(g.get("sides_eaten",0))
		var wants_side=not g.get("tried_side",false) and side_count==0 and (g.ticket%3==0 or g.wish in SIDE_FOODS)
		if g.get("service","waiting")=="served" and g.last_meal>=4 and (not wants_side or r<0 or not SIDE_FOODS.any(func(food):return regular_menu[food])):
			g.service="waiting"
			g.reordered_at=g.wait
			continue
		if g.get("service","waiting")=="out" and (g.get("tried_side",false) or r<0):
			g.shortage=true
			checkout(i)
			continue
		var seeks_side=(wants_side or g.get("service","waiting")=="out") and g.last_meal>=5
		if r>=0 and seeks_side and (side_plate(g,r)>=0 or (g.last_meal>=7 and SIDE_FOODS.any(func(food): return regular_menu[food]))):
			var walk=layout.guest_path(layout.cell(seats[i]),layout.station_cell(r))
			if not walk.is_empty():
				for tile in walk: g.trip.append(layout.center(tile))
				g.return_trip=g.trip.duplicate()
				g.return_trip.reverse()
				g.pickup_station=r
	for worker in service_team: tick_table_service(worker,dt)
	tick_staff(dt)
	if elapsed>=150 or (served>=guest_target and departing.is_empty()): end_day()

func next_facility(g:Dictionary)->int:
	for kind in range(3):
		if kind in g.visited: continue
		if kind==0 and g.ticket%4==1: continue
		if kind==1 and (g.ticket%4==2 or g.wait-g.get("served_at",g.wait)<3): continue
		if kind==2 and (g.ticket%3==1 or g.full<g.capacity*0.7): continue
		if layout.facilities.any(func(f):return f.kind==kind): return kind
	return -1

func side_plate(g:Dictionary,station:int)->int:
	for j in range(plates.size()):
		var plate=plates[j]
		if plate.station==station and plate.portions>0 and (plate.food==g.wish or g.last_meal>=7):
			return j
	return -1

func take_side_at_station(g:Dictionary):
	var index=side_plate(g,g.pickup_station)
	if index<0: return
	var plate=plates[index]
	g.carry_food=plate.food
	g.side_portions=mini(plate.portions,1+int(g.ticket)%3)
	if plate.portions==6: food_served[plate.food]+=1
	plate.portions-=g.side_portions

func finish_side(g:Dictionary):
	var food=int(g.pot_food)
	var taken=int(g.side_portions)
	g.full+=maxi(1,roundi(FILL[food]*taken/6.0))
	g.sides_eaten=g.get("sides_eaten",0)+1
	g.liked=g.liked or Patrons.likes(g.profile,[TASTE[food]])
	g.eaten+=1
	g.last_meal=0
	g.erase("side_portions")
	g.erase("eating_time")

func preferred_special(g:Dictionary)->int:
	var available=menu.specials.filter(func(id):return formulas[id]!=null and formula(id).all(func(food):return ready_food[food]>0))
	if g.profile.special_want in available: return g.profile.special_want
	return Patrons.choose(g.profile,available,patron_rng)

func tick_table_service(w:Dictionary,dt:float):
	if not w.path.is_empty():
		var target=layout.center(w.path[0])
		if w.pos.x!=target.x: w.left=target.x<w.pos.x
		w.pos=w.pos.move_toward(target,200*dt)
		if w.pos==target: w.path.pop_front()
		return
	if w.stage!="idle":
		var g=guests[w.seat]
		if g==null or g.ticket!=w.ticket:
			if w.food>=0: ready_food[w.food]+=1
		elif w.stage=="order":
			g.main_order=-1
			var available=menu.mains.filter(func(id):return ready_food[Dishes.by_id(id).core[0]]>0 or (id==7 and ready_food[6]>0))
			var id=Patrons.choose(g.profile,available,patron_rng)
			if id>=0:
				g.main_dish=id
				g.main_order=Dishes.by_id(id).core[0]
				if id==7 and ready_food[1]==0: g.main_order=6
			if g.order<0 and g.profile.special_want in menu.specials and preferred_special(g)==g.profile.special_want:
				g.order=g.profile.special_want
				g.order_at=g.wait
				g.craving=g.profile.preference
			g.service="ordered" if g.main_order>=0 else "out"
		elif w.stage=="kitchen":
			var food=int(g.main_order)
			if ready_food[food]<=0: food=-1
			if food>=0:
				ready_food[food]-=1;w.food=food;w.stage="deliver"
				w.path=layout.path(layout.pickup,layout.service_spots[layout.cell(seats[w.seat])],true,layout.service_obstacles)
				return
			g.service="out"
		elif w.stage=="deliver":
			g.main_food=w.food
			if not g.has("served_at"): g.served_at=g.wait
			g.mains_eaten=g.get("mains_eaten",0)+1
			g.last_meal=0
			g.service="served";g.pot_food=w.food;g.full+=FILL[w.food]
			g.liked=g.liked or Patrons.likes(g.profile,Dishes.by_id(g.main_dish).tags);food_served[w.food]+=1
		w.stage="idle";w.food=-1
	var taking=w.role=="点单"
	var seat=-1
	var longest=-1.0
	for i in guests.size():
		var g=guests[i]
		if g==null or not g.trip.is_empty(): continue
		if g.get("service","waiting")!=("waiting" if taking else "ordered"): continue
		var waiting_time=g.wait-g.get("reordered_at",0.0)
		if waiting_time>longest:
			seat=i
			longest=waiting_time
	if seat<0: return
	var guest=guests[seat]
	var target=layout.service_spots[layout.cell(seats[seat])] if taking else layout.pickup
	var path=layout.path(layout.cell(w.pos),target,true,layout.service_obstacles)
	if path.is_empty(): return
	w.path=path;w.seat=seat;w.ticket=guest.ticket
	w.stage="order" if taking else "kitchen"
	guest.service="ordering" if taking else "preparing"


func choose_supply_food(station:int)->int:
	var best=-INF
	var chosen=-1
	for food in SIDE_FOODS:
		if not regular_menu[food] or ready_food[food]<=0: continue
		var portions=staff_carry.count(food)*6
		for tray in plates:
			if tray.station==station and tray.food==food: portions+=tray.portions
		if portions>3: continue
		var score=12-portions
		for i in range(guests.size()):
			var diner=guests[i]
			if diner!=null and diner.wish==food and diner.full<diner.capacity and layout.station_for_table(layout.tables[seat_tables[i]])==station:
				score+=2
		if score>best: best=score;chosen=food
	return chosen

func tick_staff(dt: float):
	staff_animation+=dt
	if not staff_path.is_empty():
		var target=layout.center(staff_path[0])
		staff_pos=staff_pos.move_toward(target,dt*(staff_speed() if employee else 130.0))
		if staff_pos.distance_to(target)<1: staff_path.pop_front()
		return
	staff_clock+=dt
	if staff_clock<0.6: return
	staff_clock=0
	if staff_state=="去补餐":
		var delivered=0
		while not staff_carry.is_empty():
			var food=staff_carry.pop_front()
			if not add_plate(staff_station,food): ready_food[food]+=1
			else: delivered+=1
		if delivered>0: staff_trips+=1
		staff_state="回厨房"
		staff_path=layout.path(layout.cell(staff_pos),layout.kitchen_cell(),true,layout.service_obstacles);return
	if staff_state=="回厨房": staff_state="备餐区"
	var best=-INF
	var chosen=-1
	for station in range(layout.stations.size()):
		var count=station_plate_count(station)
		if count>=layout.STATION_CAPACITY or choose_supply_food(station)<0: continue
		var score=20.0 if count==0 else -float(count)
		if employee and layout.stations[station].zone==staff_zone: score+=4
		for i in range(guests.size()):
			var diner=guests[i]
			if diner!=null and diner.full<diner.capacity and layout.station_for_table(layout.tables[seat_tables[i]])==station:
				score+=1
				if diner.get("waiting_refill",false): score+=6+diner.refill_wait
		if score>best: best=score;chosen=station
	if chosen<0: return
	staff_station=chosen
	var shortest=layout.path(layout.kitchen_cell(),layout.station_cell(chosen),true,layout.service_obstacles)
	if shortest.is_empty(): return
	for j in range(mini(layout.STATION_CAPACITY-station_plate_count(chosen),staff_capacity() if employee else 2)):
		var food=choose_supply_food(chosen)
		if food<0: break
		ready_food[food]-=1;staff_carry.append(food)
	if staff_carry.is_empty(): return
	staff_path=shortest;staff_state="去补餐"

func serve_guest(i: int) -> bool:
	var g = guests[i]
	if g == null or held < 0 or kitchen_time>0: return false
	var match_food = i==order_seat and cooked>=0 and cooked==g.order and g.trip.is_empty()
	if g.bonus or not match_food:
		notify("已满足点单。" if g.bonus else "不是想要的菜，食物仍留在手里。")
		return false
	var liked=Patrons.likes(g.profile,cooked_tags)
	var craved=g.get("craving","") in cooked_tags
	order_seat=-1
	g.bonus = true
	g.full+=int(Dishes.by_id(cooked).fill);g.liked=g.liked or liked;cooked=-1
	for ingredient in reserved: food_served[ingredient]+=1
	reserved.clear()
	cooked_tags.clear()
	g.eaten += 1
	g.last_meal = 0
	g.score = 90+(5 if liked else 0)+(5 if craved else 0)
	var reward = (18 if g.special else 6)+(2 if liked else 0)+(3 if craved else 0)
	money += reward
	income += reward
	tips += reward
	if g.special:
		affection += 1
		special_done = true
	held = -1
	notify("%s · 小费 +%d"%["正是今天想吃的味道！" if craved else "是我喜欢的味道！" if liked else "谢谢，上菜了。",reward])
	return true

func checkout(i: int):
	var g = guests[i]
	if g == null: return
	if order_seat==i: release_order()
	var fee = menu_price
	money += fee
	income += fee
	served += 1
	if not g.liked: missed_taste+=1
	var score=clampi(int(g.score)+(10 if g.liked else -18)-(20 if g.full<g.capacity else 0)-int(g.hungry/3)+(5 if decor else 0),0,100)
	var first_wait=float(g.get("served_at",g.get("wait",0.0)))
	var visitor=int(g.get("ticket",-1))
	if visitor>=0:
		score-=mini(16,int(first_wait/4))
		var actual=dish_name(g.main_food) if g.has("main_food") else "未送达"
		var remark="想吃%s，主菜%s。"%[ING[g.get("wish",0)],actual]
		if visitor%4==0:
			score+=6 if g.full>=g.capacity and g.wait<55 else -4
			remark="赶路想吃饱，%s，坐了%d秒。"%["吃饱了" if g.full>=g.capacity else "还差几口",int(g.wait)]
		elif g.get("special",false) and g.profile.preference=="肉类":
			var beef=g.get("main_food",-1) in [1,6] or (g.bonus and g.order==0)
			score+=8 if beef else -12
			remark="冲霜牛来的，"+("吃到了牛肉。" if beef else "没尝到牛肉。主菜："+actual+"。")
		if g.has("profile"): remark+=" "+("吃到了喜欢的" if g.liked else "没尝到想吃的")+g.profile.preference+"口味。"
		if g.get("shortage",false): remark+=" 想点的主菜售罄了。"
		if g.get("refill_wait",0.0)>8.0:
			score-=mini(18,ceili((g.refill_wait-8.0)/2.0))
			remark+=" 自取台缺菜，累计等了%d秒。"%roundi(g.refill_wait)
		if reviews.size()<3 or (g.get("special",false) and not reviews.any(func(review):return review.contains("冲霜牛来的"))): reviews.append(seat_label(i)+" · "+remark)
	score=clampi(score,0,100)
	satisfaction+=score
	var z=layout.tables[seat_tables[i]].zone
	var table_index=seat_tables[i]
	var result=table_results.get(table_index,{"visits":0,"wait":0.0,"score":0})
	result.visits+=1
	result.wait+=first_wait
	result.score+=score
	table_results[table_index]=result
	zone_stats[z].refill_wait=zone_stats[z].get("refill_wait",0.0)+g.get("refill_wait",0.0)
	zone_stats[z].first_wait+=first_wait
	zone_stats[z].side_walk+=g.get("walk_seconds",0.0)
	zone_stats[z].visits+=1;zone_stats[z].score+=score;zone_stats[z].hungry+=g.hungry;zone_stats[z].meals+=g.eaten
	if g.has("position"):
		var route=layout.guest_path(layout.cell(g.position),layout.DOOR).map(layout.center)
		route.append(layout.center(layout.DOOR)+Vector2(0,24))
		departing.append({"position":g.position,"trip":route})
	guests[i] = null

func end_day():
	for w in service_team:
		if w.food>=0: ready_food[w.food]+=1
	service_team.clear()
	if phase!="营业": return
	for i in range(seats.size()):
		if guests[i] != null: checkout(i)
	if employee:
		money -= 8
		spending += 8
		staff_exp=mini(60,staff_exp+staff_trips+2)
	for p in plates:
		if p.portions==6: ready_food[p.food]+=1
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
	bulletin+="\n自取台开盘计入供应；打烊只回收完整餐盘。"
	if narrow_menu: bulletin+="\n不少客人希望食材台多一些选择。"
	for z in range(zone_stats.size()):
		if zone_stats[z].get("refill_wait",0.0)>8:
			bulletin+="\n%s区 · 客人等补餐累计 %d 秒。"%[layout.zone_name(z),roundi(zone_stats[z].refill_wait)]
	event_booked=false;cooked=-1;kitchen_time=0
	bulletin+="\n"+"\n".join(reviews)+"\n明日预计 %d 位来客（当前餐费）。"%expected_guests()
	phase = "结算"
	summary = "接待 %d 位客人\n营业收入 %d（含小费 %d）\n采购 / 招聘 / 装修 / 工资 %d\n当日净收益 %d\n平均评价 %d / 100\n勇者好感 %d · %s\n剩余食材和餐盘保留到明天。" % [served,income,tips,spending,income-spending,int(float(satisfaction)/maxi(1,served)),affection,"点单完成" if special_done else "期待下次点单"]
	for z in range(3):
		var stat=zone_stats[z]
		if stat.visits>0: summary+="\n%s区：%d客 / 评价%d / 缺餐等待%.0f秒"%[layout.zone_name(z),stat.visits,int(float(stat.score)/stat.visits),stat.hungry]
	for z in range(3):
		var stat=zone_stats[z]
		if stat.visits>0: summary+="\n%s区 · 首菜平均 %.1f 秒 / 自取往返 %.1f 秒"%[layout.zone_name(z),stat.first_wait/stat.visits,stat.side_walk/stat.visits]
	summary+="\n餐费%d金 · 供应%d盘"%[menu_price,food_served.reduce(func(a,b):return a+b,0)]
	if employee: summary+="\n露米完成%d趟补餐 · 经验%d · Lv.%d"%[staff_trips,staff_exp,staff_level()]
	business_history=preload("res://systems/ledger.gd").record(business_history,{
		"day":day,"income":income,"spending":spending,"tips":tips,"served":served,
		"score_total":satisfaction,"plates":food_served.reduce(func(a,b):return a+b,0),
		"price":menu_price,"tables":layout.tables.size(),"station_count":layout.stations.size(),
		"table_results":table_results.duplicate(true),"dishes":food_served.duplicate(),"zones":zone_stats.duplicate(true)})
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
接待%d客，供应%d盘，客均评价%d。"%[totals.days,totals.income,totals.spending,totals.profit,totals.served,totals.plates,totals.rating])
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
	line("餐费%d金 · %d桌 / %d个食材台
接待%d客 · 供应%d盘
收入%d（含小费%d） / 支出%d
净收益%d金 · 平均评价%d"%[entry.price,entry.tables,entry.station_count,entry.served,entry.plates,entry.income,entry.tips,entry.spending,entry.income-entry.spending,int(float(entry.score_total)/maxi(1,entry.served))])
	for i in range(7):
		if entry.dishes[i]>0: line("%s：%d盘"%[dish_name(i),entry.dishes[i]])
	for z in range(3):
		var stat=entry.zones[z]
		if stat.visits>0:
			line("%s区：%d客 / 评价%d / 缺餐等待%.0f秒"%[layout.zone_name(z),stat.visits,int(float(stat.score)/stat.visits),stat.hungry])
			if stat.has("first_wait"): line("首菜平均 %.1f 秒 · 自取往返平均 %.1f 秒"%[stat.first_wait/stat.visits,stat.side_walk/stat.visits])
	for key in entry.get("table_results",{}):
		var row=entry.table_results[key]
		line("%d桌 · 首菜 %.1f 秒 · 客评 %d 分"%[int(key)+1,row.wait/row.visits,roundi(float(row.score)/row.visits)])
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

func mastery_save() -> Dictionary:
	# JSON object keys are strings; slots are restored to ints on load.
	var out={}
	for slot in mastery_by_dish: out[str(slot)]=int(mastery_by_dish[slot])
	return out

func load_mastery(data: Dictionary):
	mastery_by_dish={}
	var saved=data.get("mastery_by_dish",{})
	if saved is Dictionary:
		for key in saved: mastery_by_dish[int(key)]=int(saved[key])
	# Saves before v5 only stored the stew mastery.
	if not mastery_by_dish.has(STEW_SLOT): mastery_by_dish[STEW_SLOT]=int(data.get("mastery",0))

func snapshot() -> Dictionary:
	return {"reputation":reputation,"bulletin":bulletin,"event_booked":event_booked,"formulas":formulas.duplicate(true),"regular_menu":regular_menu.duplicate(),"offerings":offerings.duplicate(),"version":5,"menu":menu.duplicate(true),"dishes_unlocked":dishes_unlocked.duplicate(),"layout_plans":layout_plans.duplicate(true),"history":business_history.duplicate(true),"layout":layout.snapshot(),"staff_zone":staff_zone,"money":money,"day":day,"raw":raw.duplicate(),"ready":ready_food.duplicate(),"mastery":mastery,"mastery_by_dish":mastery_save(),"affection":affection,"employee":employee,"decor":decor,"decor_x":decor_pos.x,"decor_y":decor_pos.y,"phase":phase,"summary":summary,"income":income,"spending":spending,"tips":tips,"served":served,"satisfaction":satisfaction,"menu_price":menu_price,"staff_exp":staff_exp,"food_served":food_served.duplicate(),"special_done":special_done,"saved_at":Time.get_datetime_string_from_system()}

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
	formulas=data.get("formulas",[[],[],[]]).duplicate(true)
	for j in range(formulas.size()):
		if formulas[j]!=null: formulas[j]=formulas[j].map(func(food): return int(food))
	formulas.resize(Dishes.specials().size())
	dishes_unlocked=Dishes.mains()+Dishes.sides()+Dishes.specials().filter(func(id):return formulas[id]!=null)
	research_inputs.clear();toppings.clear();reserved.clear();cooked_tags.clear()
	regular_menu=data.get("regular_menu",[true,true,true,true,true,true,true]).duplicate()
	reputation=int(data.get("reputation",70));bulletin=data.get("bulletin","今天是新的营业日。");event_booked=data.get("event_booked",false);offerings=data.get("offerings",[true,true,true]).duplicate();cooked=-1
	if data.has("menu"):
		for group in Dishes.CAPS: menu[group]=data.menu[group].map(func(id):return int(id))
	if data.has("dishes_unlocked"): dishes_unlocked=data.dishes_unlocked.map(func(id):return int(id))
	layout_plans=data.get("layout_plans",[null,null,null]).duplicate(true)
	for slot in range(layout_plans.size()):
		if layout_plans[slot]!=null: layout_plans[slot]=layout.upgrade_snapshot(layout_plans[slot])
	business_history=data.get("history",[]).duplicate(true)
	for entry in business_history:
		if not entry.has("station_count"): entry.station_count=entry.get("routes",0)
		entry.erase("routes")
	if data.has("layout"): layout.restore(data.layout)
	else: layout.reset()
	if not player_can_stand(player): player=ENTRANCE_AISLE
	staff_zone=clampi(int(data.get("staff_zone",-1)),-1,2)
	sync_seats()
	money=int(data.get("money",150));day=int(data.get("day",1))
	raw=data.get("raw",[0,0,0,0,0,0]).map(func(n):return int(n))
	ready_food=data.get("ready",[0,0,0,0,0,0,0]).map(func(n):return int(n))
	load_mastery(data);affection=int(data.get("affection",0))
	employee=data.get("employee",false);decor=data.get("decor",false)
	decor_pos=Vector2(data.get("decor_x",1080),data.get("decor_y",600))
	phase=data.get("phase","准备");summary=data.get("summary","")
	income=int(data.get("income",0));spending=int(data.get("spending",0));tips=int(data.get("tips",0));served=int(data.get("served",0));satisfaction=int(data.get("satisfaction",0))
	menu_price=clampi(roundi(float(data.get("menu_price",24))/3.0)*3,18,30);staff_exp=int(data.get("staff_exp",0))
	food_served=data.get("food_served",[0,0,0,0,0,0,0]).duplicate();special_done=data.get("special_done",false)
	guest_target=expected_guests()
	order_seat=-1;kitchen_time=0;plates.clear();staff_carry.clear();staff_path.clear();held=-1;build_mode=false;moving_table=-1;layout_history.clear()
	if phase=="结算": show_summary()

func show_menu():
	if build_mode: toggle_build()
	clear_panel("店长手册 · 查看时暂停营业")
	line("① 左上集市采购 → 左下料理台装盘。\n② 右侧铃铛开店，可招聘露米往返补餐。\n③ 普通菜由出餐口和员工供应。\n④ 客人到食材台取餐。\n⑤ 看加单气泡，到料理台按 C 现做，回桌旁 E 送餐。\n⑥ 打烊看账本，再迎接下一天。\n\n清炖霜牛成功三次解锁快捷制作。\n准备期按 B 布局，左键放置，R 旋转，右键拆除。\n食材台全店共用，台旁留出取餐通道。\n露米可自动巡区，或优先照看指定区域。\n准备期可手动保存，打烊自动保存。")
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
	draw_set_transform(VIEW_CENTER-view_focus*view_zoom,0,Vector2.ONE*view_zoom)
	var seam=216.0
	for x in range(-2,6):
		for y in range(8):
			draw_texture(BOARDS,Vector2(x*300,seam+y*BOARDS.get_height()))
		
	for x in range(-2,8): draw_texture_rect(ROOM,Rect2(x*210+74,seam-94,210,157.5),false)
	draw_layout()
	var right_edge=layout.ORIGIN.x+layout.room_width()*layout.CELL
	for exterior in [Rect2(-2500,-2000,5000,2122),Rect2(-2500,122,2565,548),Rect2(right_edge,122,2200,548),Rect2(-2500,670,5000,2000)]:
		draw_rect(exterior,Color("17131c"))

	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	
	

func bubble_style() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color("fff1d9")
	s.corner_radius_top_left=10;s.corner_radius_top_right=10;s.corner_radius_bottom_left=10;s.corner_radius_bottom_right=10
	return s

func draw_layout():
	for y in range(layout.HEIGHT):
		for x in range(layout.room_width()):
			var c=Vector2i(x,y);var p=layout.center(c)
			if y>0 and not layout.floor_at(c): draw_rect(Rect2(p-Vector2.ONE*20,Vector2.ONE*40),Color("283541"))
			
			if layout.floor_at(c) and build_mode: draw_rect(Rect2(p-Vector2.ONE*20,Vector2.ONE*40),Color(1,1,1,0.18),false,1)
	draw_rect(Rect2(82,155,32,51),Color("624453"))
	draw_rect(Rect2(85,158,26,45),Color("b78869"))
	draw_circle(Vector2(105,185),2,Color("ffdb94"))
	text_at(Vector2(85,153),"后门",10,Color("fff2cc"))
	var objects=[]
	for c in layout.partitions:
		if not layout.floor_at(c): continue
		var point=layout.center(c)
		if layout.partitions[c] in ["wall","window"]:
			objects.append({"y":point.y+18,"kind":layout.partitions[c],"data":point})
		elif layout.partitions[c]=="staff":
			draw_rect(Rect2(point-Vector2.ONE*20,Vector2.ONE*40),Color("749da0"))
			draw_rect(Rect2(point-Vector2.ONE*19,Vector2.ONE*38),Color("aac5bb"))
		else:
			draw_rect(Rect2(point-Vector2.ONE*20,Vector2.ONE*40),Color("d9b69f"))
			draw_rect(Rect2(point-Vector2.ONE*19,Vector2.ONE*38),Color("e8cdb5"))
	add_service(objects,"market",Vector2(170,260),108)
	if not layout.kitchen_stored: add_service(objects,"kitchen",fixture_foot(layout.kitchens[0]),fixture_width(layout.kitchens[0]))
	add_service(objects,"bell",Vector2(160,380),38)
	if decor: add_service(objects,"flowers",decor_pos,30)
	var facilities=["sauce","drink","ice","bench","flowers"]
	for f in layout.facilities:
		add_service(objects,facilities[int(f.kind)],fixture_foot(f),fixture_width(f))
	var door=layout.center(layout.DOOR)
	draw_rect(Rect2(door-Vector2(20,-10),Vector2(40,13)),Color("a7665f"))
	for side in [-21,18]: draw_rect(Rect2(door+Vector2(side,-12),Vector2(4,36)),Color("91664f"))
	text_at(door+Vector2(-12,9),"正门",10)
	for q in layout.QUEUE_SIZE:
		var tile=layout.center(layout.queue_tile(q))
		draw_rect(Rect2(tile-Vector2(19,9),Vector2(38,18)),Color("987e85"))
		text_at(tile+Vector2(-7,4),"等位" if q==0 else str(q+1),9)
	for actor in waiting+departing if phase=="营业" else []:
		var pos=actor.position
		objects.append({"y":pos.y,"kind":"waiting","data":pos})
	for t in layout.tables: objects.append({"y":layout.center(layout.body(t)[-1]).y+17,"kind":"table","data":t})
	for t in layout.tables:
		for c in layout.chairs(t): objects.append({"y":stool_position(layout.center(c),t.rot).y-1,"kind":"chair","data":c,"rot":t.rot})
	for f in layout.stations: objects.append({"y":fixture_foot(f).y,"kind":"station","data":f})
	for i in range(seats.size()):
		if guests[i]!=null: objects.append({"y":diner_position(i).y,"kind":"guest","data":i})
	objects.append({"y":player.y,"kind":"player","data":0})
	if phase=="营业":
		for worker in service_team: objects.append({"y":worker.pos.y,"kind":"server","data":worker})
	if employee or phase=="营业": objects.append({"y":staff_pos.y,"kind":"staff","data":0})
	objects.sort_custom(func(a,b): return a.y<b.y)
	for obj in objects: draw_depth_object(obj)
	# Bubbles stay above scenery, independently of body occlusion.
	for i in range(seats.size()):
		if guests[i]==null: continue
		var g=guests[i];var pos=diner_position(i)
		if not g.trip.is_empty() and not g.get("waiting_refill",false):
			if g.has("facility_visit"): text_at(pos+Vector2(-18,-56),"取"+FACILITY[g.facility_visit],9,Color("fff0dc"))
			continue
		if g.get("waiting_refill",false):
			text_at(pos+Vector2(-24,-55),"等补餐 %d秒"%int(g.refill_wait),11,Color("fff0dc"))
		elif g.last_meal>=3 and g.full<g.capacity:
			var thought=pos+Vector2(13,-55)
			ellipse(thought+Vector2(-6,10),Vector2(3,2),Color("cfede0"))
			ellipse(thought,Vector2(13,9),Color("e3f7eb"))
			if g.last_meal<4: text_at(thought+Vector2(-6,3),"…",10,Color("60506a"))
			else: service_sprite("food"+str(g.wish),thought+Vector2(0,6),15)
		if g.order<0:
			if g.get("service","waiting") in ["ordered","preparing"] and g.wait>=10:
				text_at(pos+Vector2(-24,-55),"等主菜 %d秒"%int(g.wait),11,Color("fff0dc"))
			continue
		var bubble=order_bubble(i)
		draw_style_box(bubble_style(),bubble)
		text_at(bubble.position+Vector2(4,18),"谢谢！" if g.bonus else ("已接·" if order_seat==i else "")+SPECIALS[g.order],12,Color("51444b"))
		if not g.bonus: text_at(bubble.position+Vector2(4,33),"想吃："+g.get("craving","随意"),11,Color("755364"))
	if phase=="营业" and at_kitchen() and cooked<0:
		for j in range(Recipes.TOOLS.size()):
			var rect=utensil_rect(j)
			draw_style_box(bubble_style(),rect)
			text_at(rect.position+Vector2(4,14),Recipes.TOOLS[j],11,Color("51444b"))
	if build_mode:
		var c=layout.cell(view_ground(get_viewport().get_mouse_position()))
		if relocating and not picked.is_empty():
			var f=picked.item.duplicate()
			f.x=c.x
			f.y=c.y
			var table=picked.type=="table"
			var cells=layout.body(f)+layout.chairs(f) if table else layout.footprint(f)
			for tile in cells: draw_rect(Rect2(layout.center(tile)-Vector2.ONE*19,Vector2.ONE*38),Color(0.8,0.96,0.82,0.45))
			var tex=TABLE
			var foot=(layout.center(cells.front())+layout.center(cells.back()))/2+Vector2(0,14)
			var size=Vector2(86,56)
			if table:
				for chair in layout.chairs(f):
					var seat=stool_position(layout.center(chair),f.rot)
					ellipse(seat-Vector2(0,5),Vector2(13,6),Color(0.88,0.70,0.55,0.65))
			else:
				var key="kitchen" if picked.type=="kitchens" else "station"
				if picked.type=="facilities": key=["sauce","drink","ice","bench","flowers"][f.kind]
				tex=SERVICE[key]
				foot=fixture_foot(f)
				size=station_rect(f).size if picked.type=="stations" else tex.get_size()*fixture_width(f)/tex.get_width()
			draw_texture_rect(tex,Rect2(foot-Vector2(size.x/2,size.y),size),false,Color(1,1,1,0.6))
		elif build_tool=="table" or (build_tool=="move" and moving_table>=0):
			var t={"x":c.x,"y":c.y,"rot":build_rot,"zone":build_zone}
			var col=Color(0.4,1,0.7,0.5) if layout.table_valid(t,moving_table) else Color(1,0.3,0.3,0.6)
			for q in layout.body(t)+layout.chairs(t): draw_rect(Rect2(layout.center(q)-Vector2.ONE*19,Vector2.ONE*38),col)
		elif build_tool in ["station","facility","kitchen"] or (relocating and picked.type!="table"):
			var dims={"x":c.x,"y":c.y,"span":1 if build_tool=="facility" and facility_kind==4 else 2,"rot":build_rot}
			if relocating:
				dims=picked.item.duplicate();dims.x=c.x;dims.y=c.y
			for tile in layout.footprint(dims):
				draw_rect(Rect2(layout.center(tile)-Vector2.ONE*19,Vector2.ONE*38),Color(1,0.9,0.65,0.45))
		elif layout.floor_at(c): draw_rect(Rect2(layout.center(c)-Vector2.ONE*19,Vector2.ONE*38),Color(1,1,1,0.35))
		if not layout.errors.is_empty(): text_at(Vector2(350,182),str(layout.errors[0]),14,Color("ffe3bd"))
func block(rect: Rect2,height: float,color: Color):
	draw_rect(Rect2(rect.position+Vector2(7,9),rect.size),Color(0.12,0.08,0.13,0.22))
	draw_rect(Rect2(rect.position+Vector2(0,-height),rect.size+Vector2(0,height)),color.darkened(0.38))
	draw_rect(Rect2(rect.position+Vector2(0,-height),rect.size),color)
	draw_line(rect.position+Vector2(0,-height),rect.position+Vector2(rect.size.x,-height),color.lightened(0.25),2)
	draw_line(rect.position+Vector2(0,rect.size.y-height),rect.position+Vector2(rect.size.x,rect.size.y-height),color.darkened(0.17),2)

func draw_depth_object(obj: Dictionary):
	if draw_art_object(obj): return
	match obj.kind:
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
		"station":
			var f=obj.data;var q=layout.center(Vector2i(f.x,f.y))
			block(Rect2(q-Vector2.ONE*16,Vector2.ONE*32),25,layout.ZONE_COLORS[f.zone])
			text_at(q+Vector2(-11,-19),"补",19,Color("293a41"))
		"guest":
			var i=obj.data;var g=guests[i]
			if not g.trip.is_empty():
				sprite(DINER,g.position+Vector2(0,2),Vector2(48,53),g.get("left",false))
			else:
				var direction=layout.facing(layout.tables[seat_tables[i]])
				var tex=DINER
				if direction==Vector2i.UP: tex=preload("res://art/corner/diner_back.png")
				sprite(tex,diner_position(i)-Vector2(0,3),Vector2(40,51))
		"staff":
			sprite(WAITER,staff_pos,Vector2(34,57),staff_left)
			if not staff_carry.is_empty(): service_sprite("food"+str(staff_carry[0]),staff_pos+Vector2(11,-16),15)
			text_at(staff_pos+Vector2(-14,-58),"补餐",10,Color("fff0dc"))
		"player":
			ellipse(player+Vector2(-1,0),Vector2(15,3),Color("#5b426655"))
			ellipse(player-Vector2(0,1),Vector2(8,2),Color("#50355388"))
			sprite(MANAGER,player,Vector2(56,60),facing_left)
			if held>=0:
				draw_meal(player+Vector2(21,-21),held)

func player_animation() -> String:
	if held>=0: return "carry_walk" if player_motion else "carry_idle"
	return "walk" if player_motion else "idle"

func staff_animation_name() -> String:
	if not staff_carry.is_empty(): return "carry_walk" if staff_motion else "carry_idle"
	return "walk" if staff_motion else "idle"

func stool_position(seat:Vector2,rotation:int)->Vector2:
	# Keep the stool outside the table's footprint while sharing its centerline with the pot.
	return seat+Vector2(0,-18 if rotation==0 else 12)

func diner_position(i:int)->Vector2:
	var guest=guests[i]
	if not guest.trip.is_empty(): return guest.position
	return stool_position(seats[i],layout.tables[seat_tables[i]].rot)

func actor_keys(id: String, state: String) -> Array:
	var keys=["character/"+id+"/"+state]
	if state.begins_with("carry_"): keys.append("character/"+id+"/"+state.trim_prefix("carry_"))
	keys.append("character/"+id+"/idle")
	return keys

func sprite(tex:Texture2D,foot:Vector2,size:Vector2,flip:bool=false):
	draw_texture_rect(tex,Rect2(foot-Vector2(size.x/2,size.y),Vector2(-size.x if flip else size.x,size.y)),false)

func draw_art_object(obj: Dictionary) -> bool:
	match obj.kind:
		"server":
			var w=obj.data
			sprite(WAITER,w.pos,Vector2(34,57),w.get("left",false))
			if w.food>=0: draw_meal(w.pos+Vector2(13,-17),w.food)
			text_at(w.pos+Vector2(-12,-61),w.role,10,Color("fff0dc"))
			return true
		"window":
			var p:Vector2=obj.data
			draw_rect(Rect2(p+Vector2(-20,0),Vector2(40,19)),Color("b88b99"))
			for x in [-20,16]:
				draw_rect(Rect2(p+Vector2(x,-27),Vector2(4,28)),Color("855b68"))
			draw_rect(Rect2(p+Vector2(-20,-28),Vector2(40,5)),Color("dbaf88"))
			draw_rect(Rect2(p+Vector2(-20,-2),Vector2(40,5)),Color("f3c58f"))
			return true
		"wall":
			var p:Vector2=obj.data
			draw_rect(Rect2(p+Vector2(-20,-23),Vector2(40,43)),Color("92718a"))
			draw_rect(Rect2(p+Vector2(-20,-21),Vector2(40,34)),Color("cbaac3"))
			draw_rect(Rect2(p+Vector2(-20,-27),Vector2(40,5)),Color("79556c"))
			draw_rect(Rect2(p+Vector2(-20,-27),Vector2(40,2)),Color("e3b696"))
			draw_rect(Rect2(p+Vector2(-20,13),Vector2(40,6)),Color("946c68"))
			return true
		"table":
			var t=obj.data
			var cells=layout.body(t)
			var center=(layout.center(cells[0])+layout.center(cells[1]))/2.0
			var facing=Vector2(layout.facing(t))
			sprite(TABLE,center+Vector2(0,14),Vector2(86,56))
			var table_index=layout.tables.find(t)
			for side in range(2):
				var setting=layout.center(cells[side])-Vector2(0,20)
				draw_rect(Rect2(setting+Vector2(-13,-5),Vector2(23,9)),Color("66485e"))
				draw_rect(Rect2(setting+Vector2(-11,-4),Vector2(19,6)),Color("997587"))
				service_sprite("hotpot",setting,27)
				saucer(setting+(Vector2(13,3) if facing.x==0 else Vector2(0,10)),5)
				var diner=guests[table_index*2+side]
				if diner!=null and diner.has("pot_food"):
					service_sprite("food"+str(diner.pot_food),setting-Vector2(1,5),12)
			return true
		"chair":
			var stool=stool_position(layout.center(obj.data),obj.rot)
			draw_rect(Rect2(stool+Vector2(-9,-2),Vector2(4,10)),Color("835862"))
			draw_rect(Rect2(stool+Vector2(6,-2),Vector2(4,10)),Color("835862"))
			ellipse(stool-Vector2(0,4),Vector2(13,6),Color("956760"))
			ellipse(stool-Vector2(0,6),Vector2(13,5),Color("e5b17f"))
			return true
		"service":
			service_sprite(obj.data.name,obj.data.pos,obj.data.width)
			return true
		"waiting":
			sprite(DINER,obj.data,Vector2(47,52));return true
		"station":
			var f=obj.data
			draw_ingredient_station(f)
			return true
	return false

func station_rect(f:Dictionary)->Rect2:
	var width=fixture_width(f)
	var deep=int(f.get("span",1))>1 and int(f.get("rot",0))%2==1
	var size=Vector2(width,84 if deep else 48)
	return Rect2(fixture_foot(f)-Vector2(width*0.5,size.y),size)

func draw_ingredient_station(f:Dictionary):
	var rect=station_rect(f)
	var tex:Texture2D=SERVICE.station
	var front=20.0
	var top=rect.size.y-front
	# Resize the wooden work surface independently of the cabinet front.
	draw_texture_rect_region(tex,Rect2(rect.position,Vector2(rect.size.x,top)),Rect2(0,0,tex.get_width(),16))
	draw_texture_rect_region(tex,Rect2(rect.position+Vector2(0,top),Vector2(rect.size.x,front)),Rect2(0,16,tex.get_width(),tex.get_height()-16))
	if phase!="营业": return
	var stock={}
	var station=layout.stations.find(f)
	for tray in plates:
		if tray.station==station and tray.portions>0: stock[tray.food]=stock.get(tray.food,0)+tray.portions
	var deep=rect.size.y>rect.size.x
	var foods=stock.keys()
	for slot in foods.size():
		var col=slot%2
		var row=int(slot/2)
		var x=rect.size.x*(0.28+0.44*col)
		var y=top*(0.47+0.46*row)
		if deep:
			x=rect.size.x*(0.42+0.16*col)
			y=top*(0.30+0.21*slot)
		var width=23.0 if deep else 26.0
		if int(stock[foods[slot]])<=3: width*=0.86
		service_sprite("food"+str(foods[slot]),rect.position+Vector2(x,y),width)

func fixture_width(f:Dictionary)->float:
	if layout.footprint(f).size()==1: return layout.CELL
	return layout.CELL*(1.9 if int(f.get("rot",0))%2==0 else 1.0)

func fixture_foot(f:Dictionary)->Vector2:
	var cells=layout.footprint(f)
	return Vector2(layout.fixture_center(f).x,maxf(layout.center(cells.front()).y,layout.center(cells.back()).y)+layout.CELL*0.45)

func add_service(objects:Array,key:String,pos:Vector2,width:float):
	objects.append({"y":pos.y,"kind":"service","data":{"name":key,"pos":pos,"width":width}})

func service_sprite(key:String,foot:Vector2,width:float):
	var tex:Texture2D=SERVICE[key]
	sprite(tex,foot,Vector2(width,width*tex.get_height()/tex.get_width()))

func saucer(center:Vector2,width:float):
	ellipse(center+Vector2(0,1),Vector2(width,width*0.42),Color("76566f"))
	ellipse(center,Vector2(width-1,width*0.4),Color("ffebc9"))
	ellipse(center,Vector2(width*0.74,width*0.25),Color("d7abba"))
	ellipse(center+Vector2(0,1),Vector2(width*0.69,width*0.21),Color("fff1df"))

func draw_meal(pos:Vector2,food:int):
	saucer(pos,20)
	service_sprite("food"+str(food),pos+Vector2(0,4),30)

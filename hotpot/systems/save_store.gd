extends RefCounted
const LEGACY = "user://starpot.json"
const SLOT_COUNT = 3
const LIMIT = 2 * 1024 * 1024

func slot_path(slot: int) -> String:
	return "user://saves/slot_%d.json"%slot if slot>=1 and slot<=SLOT_COUNT else ""

func integer(value, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=low and value<=high

func array_counts(value, count: int) -> bool:
	if not value is Array or value.size()!=count: return false
	for n in value:
		if not integer(n,0,1000000): return false
	return true

func validate(data) -> String:
	if not data is Dictionary: return "存档格式无效"
	if not integer(data.get("version",0),1,5): return "存档版本不支持"
	if not integer(data.get("day",0),1,1000000) or not integer(data.get("money",null),-1000000000,1000000000): return "日期或资金数据无效"
	for pair in [["raw",6],["ready",7],["food_served",7]]:
		if data.has(pair[0]) and not array_counts(data[pair[0]],pair[1]): return "食材库存或统计无效"
	for key in ["mastery","affection","income","spending","tips","served","satisfaction","staff_exp"]:
		if data.has(key) and not integer(data[key],0,1000000000): return "经营数值无效："+key
	if data.has("mastery_by_dish"):
		var book=data.mastery_by_dish
		if not book is Dictionary or book.size()>7: return "熟练度记录无效"
		for key in book:
			if not str(key).is_valid_int() or not integer(int(str(key)),0,6) or not integer(book[key],0,1000000000): return "熟练度记录无效"
	for key in ["employee","decor","special_done"]:
		if data.has(key) and not data[key] is bool: return "状态数据无效："+key
	if data.get("phase","准备") not in ["准备","结算"]: return "此存档没有可恢复的阶段"
	if not data.get("summary","") is String: return "账本格式无效"
	if not integer(data.get("staff_zone",-1),-1,2): return "员工岗位无效"
	if data.has("staff"):
		var staff_problem=preload("res://systems/staff.gd").validate(data.staff)
		if not staff_problem.is_empty(): return staff_problem
	if not integer(data.get("menu_price",24),18,30): return "餐费设置无效"
	for key in ["decor_x","decor_y"]:
		if data.has(key) and (not (data[key] is int or data[key] is float) or not is_finite(float(data[key])) or abs(data[key])>10000): return "装饰坐标无效"
	var history=data.get("history",[])
	if not history is Array or history.size()>30: return "经营历史格式无效"
	var previous_day=0
	for entry in history:
		if not entry is Dictionary: return "经营历史条目无效"
		if not integer(entry.get("day"),previous_day+1,int(data.day)): return "经营历史日期无效"
		previous_day=int(entry.day)
		for key in ["income","spending","tips","served","score_total","plates","tables"]:
			if not integer(entry.get(key),0,1000000000): return "经营历史数值无效"
		if not integer(entry.get("station_count",entry.get("routes")),0,512): return "食材台数量无效"
		if entry.tips>entry.income or entry.score_total>entry.served*100: return "经营历史统计不一致"
		if not integer(entry.get("price"),18,30) or not array_counts(entry.get("dishes"),7): return "经营历史菜品无效"
		if entry.dishes.reduce(func(a,b):return a+b,0)!=entry.plates: return "经营历史销量不一致"
		if not entry.get("zones") is Array or entry.zones.size()!=3: return "经营历史分区无效"
		var results=entry.get("table_results",{})
		if not results is Dictionary or results.size()>512: return "餐桌统计无效"
		for key in results:
			var row=results[key]
			if not str(key).is_valid_int() or not row is Dictionary or not integer(row.get("visits"),1,1000000) or not integer(row.get("score"),0,100000000): return "餐桌统计无效"
			if not (row.get("wait") is int or row.get("wait") is float) or not is_finite(float(row.wait)) or row.wait<0: return "餐桌等待无效"
		for zone in entry.zones:
			if not zone is Dictionary: return "经营历史分区无效"
			for key in ["visits","score","meals","arrivals"]:
				if not integer(zone.get(key),0,1000000000): return "经营历史分区数值无效"
			for field in ["first_wait","side_walk"]:
				var duration=zone.get(field,0)
				if not (duration is int or duration is float) or not is_finite(float(duration)) or duration<0: return "分区动线统计无效"
			var hungry=zone.get("hungry")
			if not (hungry is int or hungry is float) or not is_finite(float(hungry)) or hungry<0 or hungry>1000000000: return "经营历史等待时间无效"
	if not integer(data.get("reputation",70),0,100) or not data.get("event_booked",false) is bool or not data.get("bulletin","") is String: return "口碑数据无效"
	if data.has("regular_menu"):
		var menu=data.regular_menu
		if not menu is Array or menu.size()!=7: return "普通菜单无效"
		for value in menu:
			if not value is bool: return "普通菜单无效"
	if data.has("formulas"):
		var book=data.formulas
		if not book is Array or book.size() not in [3,6]: return "菜谱记录无效"
		var recipes=preload("res://systems/recipes.gd")
		for j in range(book.size()):
			if book[j]==null: continue
			if not book[j] is Array or book[j].size()>6: return "配方无效"
			var seen=recipes.CORES[j].duplicate()
			for item in book[j]:
				if not integer(item,0,5) or int(item) in seen or recipes.TAGS[int(item)] in recipes.FORBIDDEN[j]: return "配方加料无效"
				seen.append(int(item))
	var offerings=data.get("offerings",[true,true,true])
	if not offerings is Array or offerings.size() not in [3,6]: return "菜单数据无效"
	for on_menu in offerings:
		if not on_menu is bool: return "菜单数据无效"
	var dishes=preload("res://systems/dishes.gd")
	var unlocked=data.get("dishes_unlocked",[])
	if not unlocked is Array: return "解锁列表无效"
	var seen_ids=[]
	for id in unlocked:
		if not integer(id,0,dishes.DISHES.size()-1) or int(id) in seen_ids: return "菜品编号无效"
		seen_ids.append(int(id))
		if dishes.is_special(int(id)):
			var book=data.get("formulas",[])
			if id>=book.size() or book[int(id)]==null: return "解锁菜谱缺少配方"
	if data.has("menu"):
		if not data.menu is Dictionary: return "菜单格式无效"
		for group in dishes.CAPS:
			var ids=data.menu.get(group)
			if not ids is Array or ids.size()>dishes.CAPS[group]: return "菜单容量无效"
			var seen=[]
			for id in ids:
				if not integer(id,0,dishes.DISHES.size()-1) or int(id) in seen: return "菜单编号无效"
				if int(id) not in seen_ids or dishes.by_id(int(id)).kind+"s"!=group: return "菜品分类或解锁状态无效"
				seen.append(int(id))
	var plans=data.get("layout_plans",[null,null,null])
	if not plans is Array or plans.size()!=3: return "布局方案无效"
	for plan in plans:
		if plan!=null and not validate_layout(plan).is_empty(): return "布局方案无效"
	if not data.has("layout"): return ""
	return validate_layout(data.layout)

func validate_layout(layout) -> String:
	if not layout is Dictionary or not integer(layout.get("shape",-1),0,2): return "房型数据无效"
	if not layout.get("kitchen_stored",false) is bool: return "料理台收起状态无效"
	var stations=layout.get("stations",layout.get("feeders"))
	if not layout.get("tables") is Array or layout.tables.size()>512: return "桌椅数据无效"
	if not stations is Array or stations.size()>512: return "食材台数据无效"
	var max_x=23 if layout.get("expanded",false) else 20
	if layout.has("kitchen"):
		var k=layout.kitchen
		if not k is Dictionary or not integer(k.get("x"),0,max_x) or not integer(k.get("y"),0,11) or not integer(k.get("rot"),0,3): return "料理台位置无效"
	var facilities=layout.get("facilities",[])
	if not facilities is Array or facilities.size()>252: return "自取设施无效"
	for f in facilities:
		if not f is Dictionary or not integer(f.get("kind"),0,4) or not integer(f.get("x"),0,max_x) or not integer(f.get("y"),0,11): return "自取设施无效"
	for t in layout.tables:
		if not t is Dictionary or not integer(t.get("x"),0,max_x) or not integer(t.get("y"),0,11) or not integer(t.get("rot"),0,3) or not integer(t.get("zone"),0,2): return "桌椅数据无效"
	for f in stations:
		if not f is Dictionary or not integer(f.get("x"),0,max_x) or not integer(f.get("y"),0,11) or not integer(f.get("zone"),0,2): return "食材台数据无效"
	return ""

func read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {"ok":false,"missing":true,"error":"没有存档"}
	var file=FileAccess.open(path,FileAccess.READ)
	if file==null: return {"ok":false,"error":"存档无法读取"}
	if file.get_length()>LIMIT: return {"ok":false,"error":"存档超出大小限制"}
	var parser=JSON.new()
	if parser.parse(file.get_as_text())!=OK: return {"ok":false,"error":"存档内容损坏"}
	var problem=validate(parser.data)
	if not problem.is_empty(): return {"ok":false,"error":problem}
	return {"ok":true,"data":parser.data,"recovered":false}

func read(path: String) -> Dictionary:
	var primary=read_file(path)
	if primary.ok: return primary
	var backup=read_file(path+".bak")
	if backup.ok:
		backup.recovered=true;backup.primary_error=primary.error
		return backup
	return primary

func write_text(path: String, text: String) -> bool:
	var file=FileAccess.open(path,FileAccess.WRITE)
	if file==null: return false
	file.store_string(text);file.flush()
	var ok=file.get_error()==OK
	file.close()
	return ok

func write(path: String, data: Dictionary) -> Dictionary:
	var problem=validate(data)
	if not problem.is_empty(): return {"ok":false,"error":problem}
	if path.is_empty(): return {"ok":false,"error":"存档位置无效"}
	var full=ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(full.get_base_dir())!=OK: return {"ok":false,"error":"无法创建存档目录"}
	var text=JSON.stringify(data)
	if text.length()>LIMIT: return {"ok":false,"error":"存档超出大小限制"}
	if not write_text(path+".tmp",text) or not read_file(path+".tmp").ok: return {"ok":false,"error":"写入新存档失败，旧存档未改动"}
	if FileAccess.file_exists(path):
		if read_file(path).ok:
			if not write_text(path+".bak.tmp",FileAccess.get_file_as_string(path)) or DirAccess.rename_absolute(full+".bak.tmp",full+".bak")!=OK:
				return {"ok":false,"error":"备份失败，旧存档未改动"}
		else:
			# Preserve corrupt bytes for diagnosis; never replace a good backup with them.
			if not write_text(path+".corrupt",FileAccess.get_file_as_string(path)): return {"ok":false,"error":"损坏存档归档失败"}
	if DirAccess.rename_absolute(full+".tmp",full)!=OK: return {"ok":false,"error":"无法替换存档，旧存档与备份保留"}
	return {"ok":true}

func info(slot: int) -> Dictionary:
	var path=slot_path(slot)
	var result=read(path)
	result.path=path;result.slot=slot
	result.exists=FileAccess.file_exists(path) or FileAccess.file_exists(path+".bak")
	return result

func import_legacy(slot: int) -> Dictionary:
	if info(slot).exists: return {"ok":false,"error":"只能导入到空存档位"}
	var source=read(LEGACY)
	if not source.ok: return source
	return write(slot_path(slot),source.data)

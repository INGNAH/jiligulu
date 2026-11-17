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
	if not integer(data.get("version",0),1,3): return "存档版本不支持"
	if not integer(data.get("day",0),1,1000000) or not integer(data.get("money",null),-1000000000,1000000000): return "日期或资金数据无效"
	for pair in [["raw",6],["ready",7],["food_served",7]]:
		if data.has(pair[0]) and not array_counts(data[pair[0]],pair[1]): return "食材库存或统计无效"
	for key in ["mastery","affection","income","spending","tips","served","satisfaction","staff_exp"]:
		if data.has(key) and not integer(data[key],0,1000000000): return "经营数值无效："+key
	for key in ["employee","decor","special_done"]:
		if data.has(key) and not data[key] is bool: return "状态数据无效："+key
	if data.get("phase","准备") not in ["准备","结算"]: return "此存档没有可恢复的阶段"
	if not data.get("summary","") is String: return "账本格式无效"
	if not integer(data.get("staff_zone",-1),-1,2): return "员工岗位无效"
	if not integer(data.get("menu_price",24),18,30): return "餐费设置无效"
	for key in ["decor_x","decor_y"]:
		if data.has(key) and (not (data[key] is int or data[key] is float) or not is_finite(float(data[key])) or abs(data[key])>10000): return "装饰坐标无效"
	if not data.has("layout"): return ""
	var layout=data.layout
	if not layout is Dictionary or not integer(layout.get("shape",-1),0,2): return "房型数据无效"
	for key in ["tables","feeders","belts"]:
		if not layout.get(key) is Array or layout[key].size()>512: return "布局数据无效"
	var occupied={}
	for t in layout.tables:
		if not t is Dictionary or not integer(t.get("x"),0,20) or not integer(t.get("y"),0,11) or not integer(t.get("rot"),0,3) or not integer(t.get("zone"),0,2): return "桌椅数据无效"
	for f in layout.feeders:
		if not f is Dictionary or not integer(f.get("x"),0,20) or not integer(f.get("y"),0,11) or not integer(f.get("zone"),0,2): return "补餐点数据无效"
	for b in layout.belts:
		if not b is Array or b.size()!=3 or not integer(b[0],0,20) or not integer(b[1],0,11) or not integer(b[2],0,2): return "餐带数据无效"
		var pos=Vector2i(b[0],b[1])
		if occupied.has(pos): return "餐带坐标重复"
		occupied[pos]=true
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

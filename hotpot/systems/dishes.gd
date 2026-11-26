extends RefCounted

const CAPS={"mains":4,"sides":3,"specials":3}
const DISHES=[
	{"id": 0, "name": "香煎霜牛", "kind": "special", "core": [1], "cost": 1, "fill": 42, "tags": ["肉类", "鲜香"], "tier": "signature", "forbidden": []},
	{"id": 1, "name": "清渍酸甜萝卜", "kind": "special", "core": [5], "cost": 1, "fill": 18, "tags": ["清淡", "甜酸"], "tier": "signature", "forbidden": ["辣味"]},
	{"id": 2, "name": "椒香跳跳虾", "kind": "special", "core": [2, 3], "cost": 2, "fill": 25, "tags": ["海鲜", "辣味"], "tier": "signature", "forbidden": []},
	{"id": 3, "name": "菌香豆腐煲", "kind": "special", "core": [0, 4], "cost": 2, "fill": 26, "tags": ["鲜香", "清淡"], "tier": "signature", "forbidden": []},
	{"id": 4, "name": "萝卜炖霜牛", "kind": "special", "core": [1, 5], "cost": 2, "fill": 42, "tags": ["肉类", "甜酸"], "tier": "signature", "forbidden": []},
	{"id": 5, "name": "鲜虾菌汤", "kind": "special", "core": [0, 2], "cost": 2, "fill": 26, "tags": ["鲜香", "海鲜"], "tier": "signature", "forbidden": []},
	{"id": 6, "name": "菌香灯笼菇", "kind": "main", "core": [0], "cost": 1, "fill": 26, "tags": ["鲜香"], "tier": "normal", "forbidden": []},
	{"id": 7, "name": "霜牛薄切", "kind": "main", "core": [1], "cost": 1, "fill": 42, "tags": ["肉类"], "tier": "normal", "forbidden": []},
	{"id": 8, "name": "鲜煮跳跳虾", "kind": "main", "core": [2], "cost": 1, "fill": 25, "tags": ["海鲜"], "tier": "normal", "forbidden": []},
	{"id": 9, "name": "炙烤火椒", "kind": "main", "core": [3], "cost": 1, "fill": 14, "tags": ["辣味"], "tier": "normal", "forbidden": []},
	{"id": 10, "name": "云绵豆腐锅", "kind": "main", "core": [4], "cost": 1, "fill": 46, "tags": ["清淡"], "tier": "normal", "forbidden": []},
	{"id": 11, "name": "蜜渍水晶萝卜", "kind": "main", "core": [5], "cost": 1, "fill": 18, "tags": ["甜酸"], "tier": "normal", "forbidden": []},
	{"id": 12, "name": "灯笼菇", "kind": "side", "core": [0], "cost": 1, "fill": 26, "tags": ["鲜香"], "tier": "normal", "forbidden": []},
	{"id": 13, "name": "火椒", "kind": "side", "core": [3], "cost": 1, "fill": 14, "tags": ["辣味"], "tier": "normal", "forbidden": []},
	{"id": 14, "name": "云绵豆腐", "kind": "side", "core": [4], "cost": 1, "fill": 46, "tags": ["清淡"], "tier": "normal", "forbidden": []},
	{"id": 15, "name": "水晶萝卜", "kind": "side", "core": [5], "cost": 1, "fill": 18, "tags": ["甜酸"], "tier": "normal", "forbidden": []},
]
static func by_id(id:int)->Dictionary:
	return DISHES[id] if id>=0 and id<DISHES.size() else {}

static func ids(kind:String)->Array:
	return DISHES.filter(func(d):return d.kind==kind).map(func(d):return d.id)

static func mains()->Array: return ids("main")
static func sides()->Array: return ids("side")
static func specials()->Array: return ids("special")
static func is_main(id:int)->bool: return by_id(id).get("kind")=="main"
static func is_side(id:int)->bool: return by_id(id).get("kind")=="side"
static func is_special(id:int)->bool: return by_id(id).get("kind")=="special"

static func toggle(menu:Dictionary,unlocked:Array,id:int)->bool:
	if id not in unlocked: return false
	var group=by_id(id).kind+"s"
	if id in menu[group]: menu[group].erase(id)
	elif menu[group].size()<CAPS[group]: menu[group].append(id)
	else: return false
	return true

static func special_column(field:String)->Array:
	return specials().map(func(id):return by_id(id)[field])

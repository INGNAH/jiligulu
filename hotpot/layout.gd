extends RefCounted
# Grid coordinates are serialized as integers; no scene nodes are stored in saves.
const ORIGIN = Vector2(340,190)
const CELL = 40
const WIDTH = 21
const HEIGHT = 12
const ZONE_COLORS = [Color("66b9b0"),Color("c695c8"),Color("dfb96a")]
var expanded=false
func room_width()->int: return WIDTH+(3 if expanded else 0)

var shape = 0
var tables: Array = []
var feeders: Array = []
var routes: Array = []
var errors: Array = []

func _init(): reset()
func center(c: Vector2i) -> Vector2: return ORIGIN + Vector2(c)*CELL + Vector2.ONE*CELL/2
func cell(p: Vector2) -> Vector2i: return Vector2i(floor((p.x-ORIGIN.x)/CELL),floor((p.y-ORIGIN.y)/CELL))
func floor_at(c: Vector2i) -> bool:
	if c.x<0 or c.x>=room_width() or c.y<0 or c.y>=HEIGHT: return false
	if shape==1 and c.y<4: return false
	if shape==2 and c.x>=13 and c.y<5: return false
	return true
func neighbors(c: Vector2i) -> Array:
	return [c+Vector2i.LEFT,c+Vector2i.RIGHT,c+Vector2i.UP,c+Vector2i.DOWN]
func body(t: Dictionary) -> Array:
	var c=Vector2i(t.x,t.y)
	return [c,c+(Vector2i.RIGHT if t.rot%2==0 else Vector2i.DOWN)]
func chairs(t: Dictionary) -> Array:
	var d=[Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP,Vector2i.RIGHT][t.rot]
	var result=[]
	for c in body(t): result.append(c+d)
	return result
var partitions={}
func paint_partition(c:Vector2i,kind:String)->bool:
	if not floor_at(c) or c in [Vector2i(0,11),Vector2i(20,11)]: return false
	if not partitions.has(c) and occupied(c): return false
	partitions[c]=kind
	return true

var facilities=[]
func footprint(f:Dictionary)->Array:
	var origin=Vector2i(f.x,f.y)
	if int(f.get("span",1))==1: return [origin]
	return [origin,origin+[Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP][int(f.get("rot",0))%4]]

func fixture_center(f:Dictionary)->Vector2:
	var cells=footprint(f)
	return (center(cells.front())+center(cells.back()))/2

func place_fixture(items:Array,f:Dictionary)->bool:
	for c in footprint(f):
		if not floor_at(c) or occupied(c): return false
	items.append(f)
	return true

func facility_at(c: Vector2i) -> int:
	for i in range(facilities.size()):
		if c in footprint(facilities[i]): return i
	return -1
func place_facility(c:Vector2i,kind:int,rot:int=0)->bool:
	return place_fixture(facilities,{"x":c.x,"y":c.y,"kind":kind,"rot":rot,"span":1 if kind==4 else 2})
func occupied(c: Vector2i, skip: int=-1) -> bool:
	if partitions.has(c) or facility_at(c)>=0: return true
	for i in range(tables.size()):
		if i!=skip and (c in body(tables[i]) or c in chairs(tables[i])): return true
	for f in feeders:
		if c in footprint(f): return true
	return false
func table_valid(t: Dictionary, skip: int=-1) -> bool:
	if t.rot not in [0,2]: return false
	for c in body(t)+chairs(t):
		if not floor_at(c) or occupied(c,skip): return false
	return true
func place_table(c: Vector2i, rot: int, zone: int, skip: int=-1) -> bool:
	var t={"x":c.x,"y":c.y,"rot":rot,"zone":zone}
	if not table_valid(t,skip): return false
	if skip>=0: tables[skip]=t
	else: tables.append(t)
	return true
func table_at(c: Vector2i) -> int:
	for i in range(tables.size()):
		if c in body(tables[i]) or c in chairs(tables[i]): return i
	return -1
func place_feeder(c:Vector2i,zone:int,rot:int=0)->bool:
	return place_fixture(feeders,{"x":c.x,"y":c.y,"zone":zone,"rot":rot,"span":2})
func erase(c: Vector2i):
	if partitions.erase(c): return
	var station=facility_at(c)
	if station>=0: facilities.remove_at(station); return
	var i=table_at(c)
	if i>=0: tables.remove_at(i); return
	for j in range(feeders.size()-1,-1,-1):
		if c in footprint(feeders[j]): feeders.remove_at(j)
func walkable(c:Vector2i,staff:bool=false)->bool:
	if not staff and partitions.get(c)=="staff": return false
	if not floor_at(c) or partitions.get(c) in ["wall","window"]: return false
	for items in [facilities,feeders]:
		for f in items:
			if int(f.get("span",1))>1 and c==footprint(f).back(): return false
	for t in tables:
		if c in body(t): return false
	return true
func path(a:Vector2i,b:Vector2i,staff:bool=false)->Array:
	if not walkable(a,staff) or not walkable(b,staff): return []
	var queue=[a]
	var previous={a:a}
	var index=0
	while index<queue.size():
		var c=queue[index]; index+=1
		if c==b:
			var result=[b]
			while result.back()!=a: result.append(previous[result.back()])
			result.reverse(); return result
		for n in neighbors(c):
			if walkable(n,staff) and not previous.has(n): previous[n]=c; queue.append(n)
	return []
func reset():
	partitions.clear()
	for y in range(8,12):
		for x in range(2): partitions[Vector2i(x,y)]="staff"
	for y in range(7,11): partitions[Vector2i(2,y)]="wall"
	partitions[Vector2i(1,7)]="window"
	partitions[Vector2i(0,7)]="wall"
	facilities.clear()
	shape=0; tables.clear(); feeders.clear()
	for a in [[2,2,2,0],[5,2,2,0],[3,7,0,0],[13,2,2,1],[16,2,2,1],[14,7,0,1]]:
		tables.append({"x":a[0],"y":a[1],"rot":a[2],"zone":a[3]})
	facilities=[{"x":7,"y":9,"kind":0},{"x":10,"y":7,"kind":1},{"x":17,"y":9,"kind":2}]
	feeders=[{"x":0,"y":5,"zone":0},{"x":11,"y":5,"zone":1}]
	for f in facilities: f.span=2;f.rot=0
	for f in feeders: f.span=2;f.rot=1
	compile()
func compile() -> bool:
	routes.clear(); errors.clear()
	for items in [facilities,feeders]:
		for f in items:
			for tile in footprint(f):
				if not floor_at(tile): errors.append("工作台占地超出房型。");break
	for f in facilities:
		if path(Vector2i(20,11),Vector2i(f.x,f.y)).is_empty(): errors.append("自取或等候设施没有可达通道")
	for f in feeders:
		var station=Vector2i(f.x,f.y)
		if path(Vector2i(20,11),station).is_empty(): errors.append("食材台需要顾客通道。")
		routes.append({"zone":f.zone,"cell":station,"feeders":[{"cell":station,"index":0}],"capacity":8})
	if tables.is_empty(): errors.append("至少放一张桌子。")
	for i in range(tables.size()):
		var t=tables[i]
		if not table_valid(t,i): errors.append("第%d张桌椅重叠或超出房型。"%(i+1))
		if route_for_table(t)<0: errors.append("第%d张桌所在分区需要食材台。"%(i+1))
		for c in chairs(t):
			if path(Vector2i(20,11),c).is_empty(): errors.append("第%d张桌的座位无法从入口走到。"%(i+1));break
	for f in feeders:
		var c=Vector2i(f.x,f.y)
		if not floor_at(c) or path(Vector2i(0,11),c,true).is_empty(): errors.append("补餐点超出房型，或厨房通道被堵住。")
	return errors.is_empty()
func zone_name(z: int) -> String: return ["青叶","紫月","金穗"][z]
func facing(t:Dictionary)->Vector2i:
	return [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT][int(t.rot)]

func route_for_table(t:Dictionary)->int:
	var closest=-1
	var distance=INF
	for i in routes.size():
		var d=center(routes[i].cell).distance_squared_to(center(body(t)[0]))
		if routes[i].zone==t.zone and d<distance: closest=i;distance=d
	return closest

func snapshot() -> Dictionary:
	var painted=[]
	for c in partitions: painted.append([c.x,c.y,partitions[c]])
	return {"expanded":expanded,"partitions":painted,"facilities":facilities.duplicate(true),"shape":shape,"tables":tables.duplicate(true),"belts":[],"feeders":feeders.duplicate(true)}
func restore(data: Dictionary):
	expanded=data.get("expanded",false)
	facilities=data.get("facilities",[]).duplicate(true)
	for f in facilities:
		for key in ["x","y","kind"]: f[key]=int(f[key])
	shape=clampi(int(data.get("shape",0)),0,2)
	tables=data.get("tables",[]).duplicate(true);feeders=data.get("feeders",[]).duplicate(true)
	for t in tables:
		for k in ["x","y","rot","zone"]: t[k]=int(t[k])
		t.rot=int(t.rot) & 2
	for f in feeders:
		for k in ["x","y","zone"]: f[k]=int(f[k])
	partitions.clear()
	for tile in data.get("partitions",[]): partitions[Vector2i(int(tile[0]),int(tile[1]))]=tile[2]
	for items in [facilities,feeders]:
		for f in items:
			for key in ["rot","span"]:
				if f.has(key): f[key]=int(f[key])
	compile()

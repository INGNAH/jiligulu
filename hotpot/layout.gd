extends RefCounted
# Grid coordinates are serialized as integers; no scene nodes are stored in saves.
const ORIGIN = Vector2(340,190)
const CELL = 40
const WIDTH = 21
const HEIGHT = 12
const ZONE_COLORS = [Color("66b9b0"),Color("c695c8"),Color("dfb96a")]
var shape = 0
var tables: Array = []
var belts: Dictionary = {}
var feeders: Array = []
var routes: Array = []
var errors: Array = []

func _init(): reset()
func center(c: Vector2i) -> Vector2: return ORIGIN + Vector2(c)*CELL + Vector2.ONE*CELL/2
func cell(p: Vector2) -> Vector2i: return Vector2i(floor((p.x-ORIGIN.x)/CELL),floor((p.y-ORIGIN.y)/CELL))
func floor_at(c: Vector2i) -> bool:
	if c.x<0 or c.x>=WIDTH or c.y<0 or c.y>=HEIGHT: return false
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
var facilities=[]
func facility_at(c: Vector2i) -> int:
	for i in range(facilities.size()):
		if c==Vector2i(facilities[i].x,facilities[i].y): return i
	return -1
func place_facility(c:Vector2i, kind:int) -> bool:
	if not floor_at(c) or occupied(c): return false
	facilities.append({"x":c.x,"y":c.y,"kind":kind})
	return true
func occupied(c: Vector2i, skip: int=-1) -> bool:
	if belts.has(c) or facility_at(c)>=0: return true
	for i in range(tables.size()):
		if i!=skip and (c in body(tables[i]) or c in chairs(tables[i])): return true
	for f in feeders:
		if c==Vector2i(f.x,f.y): return true
	return false
func table_valid(t: Dictionary, skip: int=-1) -> bool:
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
func place_belt(c: Vector2i, zone: int) -> bool:
	if not floor_at(c): return false
	if belts.has(c): belts[c]=zone; return true
	if occupied(c): return false
	belts[c]=zone
	return true
func place_feeder(c: Vector2i, zone: int) -> bool:
	if not floor_at(c) or occupied(c): return false
	feeders.append({"x":c.x,"y":c.y,"zone":zone})
	return true
func erase(c: Vector2i):
	var station=facility_at(c)
	if station>=0: facilities.remove_at(station); return
	var i=table_at(c)
	if i>=0: tables.remove_at(i); return
	belts.erase(c)
	for j in range(feeders.size()-1,-1,-1):
		if c==Vector2i(feeders[j].x,feeders[j].y): feeders.remove_at(j)
func walkable(c: Vector2i) -> bool:
	if not floor_at(c) or belts.has(c): return false
	for t in tables:
		if c in body(t): return false
	return true
func path(a: Vector2i,b: Vector2i) -> Array:
	if not walkable(a) or not walkable(b): return []
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
			if walkable(n) and not previous.has(n): previous[n]=c; queue.append(n)
	return []
func reset():
	facilities.clear()
	shape=0; tables.clear(); belts.clear(); feeders.clear()
	for bounds in [[1,3,7,6,0],[12,3,18,6,1]]:
		for x in range(bounds[0],bounds[2]+1):
			belts[Vector2i(x,bounds[1])]=bounds[4]; belts[Vector2i(x,bounds[3])]=bounds[4]
		for y in range(bounds[1]+1,bounds[3]):
			belts[Vector2i(bounds[0],y)]=bounds[4]; belts[Vector2i(bounds[2],y)]=bounds[4]
	for a in [[2,2,2,0],[5,2,2,0],[3,7,0,0],[13,2,2,1],[16,2,2,1],[14,7,0,1]]:
		tables.append({"x":a[0],"y":a[1],"rot":a[2],"zone":a[3]})
	facilities=[{"x":7,"y":9,"kind":0},{"x":10,"y":7,"kind":1},{"x":17,"y":9,"kind":2}]
	feeders=[{"x":0,"y":5,"zone":0},{"x":11,"y":5,"zone":1}]
	compile()
func compile() -> bool:
	routes.clear(); errors.clear()
	for f in facilities:
		if path(Vector2i(20,11),Vector2i(f.x,f.y)).is_empty(): errors.append("自取或等候设施没有可达通道")
	var unseen=belts.duplicate()
	while not unseen.is_empty():
		var start=unseen.keys()[0]
		var component=[]; var queue=[start]; unseen.erase(start)
		while not queue.is_empty():
			var c=queue.pop_front();component.append(c)
			for n in neighbors(c):
				if unseen.has(n): unseen.erase(n);queue.append(n)
		var valid=component.size()>=8
		var zone=int(belts[start])
		for c in component:
			var links=0
			for n in neighbors(c):
				if belts.has(n): links+=1
			if links!=2 or belts[c]!=zone or not floor_at(c): valid=false
		if not valid: errors.append("餐带需要同区、无分岔的闭合环路（至少8格）。");continue
		# Follow actual adjacency rather than relying on insertion order.
		var ordered=[start];var prev=Vector2i(-100,-100);var current=start
		while true:
			var next_cell=start
			for n in neighbors(current):
				if belts.has(n) and n!=prev: next_cell=n;break
			if next_cell==start: break
			ordered.append(next_cell);prev=current;current=next_cell
			if ordered.size()>component.size(): break
		var r={"cells":ordered,"zone":zone,"feeders":[],"capacity":maxi(4,int(ordered.size()/2))}
		for f in feeders:
			if f.zone!=zone: continue
			for n in neighbors(Vector2i(f.x,f.y)):
				if n in ordered:
					r.feeders.append({"cell":Vector2i(f.x,f.y),"index":ordered.find(n)})
					break
		if r.feeders.is_empty(): errors.append("%s区餐带缺少紧邻的同区补餐点。"%zone_name(zone))
		routes.append(r)
	if tables.is_empty(): errors.append("至少放一张桌子。")
	for i in range(tables.size()):
		var t=tables[i]
		if not table_valid(t,i): errors.append("第%d张桌椅重叠或超出房型。"%(i+1))
		if route_for_table(t)<0: errors.append("第%d张桌未紧邻同区餐带。"%(i+1))
		for c in chairs(t):
			if path(Vector2i(20,11),c).is_empty(): errors.append("第%d张桌的座位无法从入口走到。"%(i+1));break
	for f in feeders:
		var c=Vector2i(f.x,f.y)
		if not floor_at(c) or path(Vector2i(0,11),c).is_empty(): errors.append("补餐点超出房型，或厨房通道被堵住。")
	return errors.is_empty()
func zone_name(z: int) -> String: return ["青叶","紫月","金穗"][z]
func route_for_table(t: Dictionary) -> int:
	for i in range(routes.size()):
		if routes[i].zone!=t.zone: continue
		for c in body(t):
			for n in neighbors(c):
				if n in routes[i].cells: return i
	return -1
func pickup_index(t: Dictionary,r: int) -> int:
	for c in body(t):
		for n in neighbors(c):
			if n in routes[r].cells: return routes[r].cells.find(n)
	return -1
func snapshot() -> Dictionary:
	var tiles=[]
	for c in belts: tiles.append([c.x,c.y,belts[c]])
	return {"facilities":facilities.duplicate(true),"shape":shape,"tables":tables.duplicate(true),"belts":tiles,"feeders":feeders.duplicate(true)}
func restore(data: Dictionary):
	facilities=data.get("facilities",[]).duplicate(true)
	for f in facilities:
		for key in ["x","y","kind"]: f[key]=int(f[key])
	shape=clampi(int(data.get("shape",0)),0,2)
	tables=data.get("tables",[]).duplicate(true);feeders=data.get("feeders",[]).duplicate(true);belts.clear()
	for t in tables:
		for k in ["x","y","rot","zone"]: t[k]=int(t[k])
	for f in feeders:
		for k in ["x","y","zone"]: f[k]=int(f[k])
	for c in data.get("belts",[]): belts[Vector2i(int(c[0]),int(c[1]))]=int(c[2])
	compile()

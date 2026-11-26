extends RefCounted
# Grid coordinates are serialized as integers; no scene nodes are stored in saves.
const ORIGIN = Vector2(340,190)
const CELL = 40
const DOOR=Vector2i(20,11)
const QUEUE_SIZE=5
func queue_tile(index:int)->Vector2i:
	return DOOR+Vector2i.LEFT*(QUEUE_SIZE-index)

func entry_area(c:Vector2i)->bool:
	return c.y==DOOR.y and c.x>=DOOR.x-QUEUE_SIZE and c.x<=DOOR.x

const WIDTH = 21
const HEIGHT = 12
const ZONE_COLORS = [Color("66b9b0"),Color("c695c8"),Color("dfb96a")]
const DEFAULT_KITCHEN={"x":1,"y":9,"rot":2,"span":2}
var kitchen_stored=false
var kitchens=[]
var pickup=Vector2i(1,9)
func kitchen_cell()->Vector2i:
	return Vector2i(kitchens[0].x,kitchens[0].y)

func move_kitchen(c:Vector2i,rot:int)->bool:
	var next={"x":c.x,"y":c.y,"rot":rot,"span":2}
	var old=kitchens.pop_back()
	for tile in footprint(next):
		if not floor_at(tile) or partitions.get(tile) in ["wall","window"] or facility_at(tile)>=0 or table_at(tile)>=0 or entry_area(tile):
			kitchens.append(old)
			return false
		for f in stations:
			if tile in footprint(f):
				kitchens.append(old)
				return false
	kitchen_stored=false
	kitchens.append(next)
	return true

var service_spots = {}
var service_obstacles = {}
var expanded=false
func room_width()->int: return WIDTH+(3 if expanded else 0)

var shape = 0
var tables: Array = []
var stations: Array = []
const STATION_CAPACITY=8
var table_stations={}
var errors: Array = []

func _init(): reset()
func center(c: Vector2i) -> Vector2: return ORIGIN + Vector2(c)*CELL + Vector2.ONE*CELL/2
func cell(p: Vector2) -> Vector2i: return Vector2i(floor((p.x-ORIGIN.x)/CELL),floor((p.y-ORIGIN.y)/CELL))
func floor_at(c: Vector2i) -> bool:
	if c.x<0 or c.x>=room_width() or c.y<1 or c.y>=HEIGHT: return false
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
	if entry_area(c) and kind!="aisle": return false
	if not floor_at(c) or c in [Vector2i(0,11),Vector2i(20,11)]: return false
	if not kitchen_stored and c in footprint(kitchens[0]) and kind in ["wall","window"]: return false
	if kind in ["wall","window"] and (facility_at(c)>=0 or table_at(c)>=0 or stations.any(func(f):return c in footprint(f))): return false
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
	if entry_area(c): return true
	if (not kitchen_stored and not kitchens.is_empty() and c in footprint(kitchens[0])) or partitions.get(c) in ["wall","window"] or facility_at(c)>=0: return true
	for i in range(tables.size()):
		if i!=skip and (c in body(tables[i]) or c in chairs(tables[i])): return true
	for f in stations:
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
func place_station(c:Vector2i,zone:int,rot:int=0)->bool:
	return place_fixture(stations,{"x":c.x,"y":c.y,"zone":zone,"rot":rot,"span":2})
func erase(c: Vector2i):
	if partitions.erase(c): return
	var station=facility_at(c)
	if station>=0: facilities.remove_at(station); return
	var i=table_at(c)
	if i>=0: tables.remove_at(i); return
	for j in range(stations.size()-1,-1,-1):
		if c in footprint(stations[j]): stations.remove_at(j)
func walkable(c:Vector2i,staff:bool=false)->bool:
	if not kitchen_stored and (c==footprint(kitchens[0]).back() or (not staff and c==kitchen_cell())): return false
	if not staff and partitions.get(c)=="staff": return false
	if not floor_at(c) or partitions.get(c) in ["wall","window"]: return false
	for items in [facilities,stations]:
		for f in items:
			if c in footprint(f): return false
	for t in tables:
		if c in body(t): return false
	return true
func path(a:Vector2i,b:Vector2i,staff:bool=false,blocked:Dictionary={})->Array:
	if blocked.has(a) or blocked.has(b) or not walkable(a,staff) or not walkable(b,staff): return []
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
			if not previous.has(n) and not blocked.has(n) and walkable(n,staff): previous[n]=c; queue.append(n)
	return []
func reset():
	kitchen_stored=false
	kitchens=[DEFAULT_KITCHEN.duplicate()]
	partitions.clear()
	for y in range(8,12):
		for x in range(2): partitions[Vector2i(x,y)]="staff"
	for y in range(7,11): partitions[Vector2i(2,y)]="wall"
	partitions[Vector2i(1,7)]="window"
	partitions[Vector2i(0,7)]="wall"
	facilities.clear()
	shape=0; tables.clear(); stations.clear()
	for a in [[2,2,2,0],[5,2,2,0],[3,7,0,0],[13,2,2,1],[16,2,2,1],[14,7,0,1]]:
		tables.append({"x":a[0],"y":a[1],"rot":a[2],"zone":a[3]})
	facilities=[{"x":7,"y":9,"kind":0},{"x":10,"y":7,"kind":1},{"x":17,"y":9,"kind":2}]
	stations=[{"x":0,"y":5,"zone":0},{"x":11,"y":5,"zone":1}]
	for f in facilities: f.span=2;f.rot=0
	for f in stations: f.span=2;f.rot=1
	compile()
func compile() -> bool:
	errors.clear(); table_stations.clear()
	for x in range(QUEUE_SIZE+1):
		var tile=DOOR+Vector2i.LEFT*x
		if not walkable(tile) or table_at(tile)>=0:
			errors.append("正门和等位区需要留空，请移开家具或隔墙。");break
	if kitchen_stored: errors.append("开店前请在营业家具中放回料理台。")
	service_spots.clear()
	service_obstacles.clear()
	for table in tables:
		for chair in chairs(table): service_obstacles[chair]=true
	for fixture in facilities+stations:
		for tile in footprint(fixture): service_obstacles[tile]=true
	pickup=kitchen_cell()
	var shortest=[]
	for window in partitions:
		if partitions[window]!="window": continue
		for tile in neighbors(window):
			if partitions.get(tile)!="staff" and tile!=kitchen_cell(): continue
			var route=path(kitchen_cell(),tile,true,service_obstacles)
			if not route.is_empty() and (shortest.is_empty() or route.size()<shortest.size()): shortest=route
	if not shortest.is_empty(): pickup=shortest.back()
	elif partitions.values().has("window"): errors.append("出餐窗旁需要一格与料理台相通的员工地板。")
	for items in [facilities,stations]:
		for f in items:
			for tile in footprint(f):
				if not floor_at(tile): errors.append("工作台占地超出房型。");break
	station_access.clear()
	facility_access.clear()
	for f in facilities:
		var access=approach_cell(f,false)
		facility_access.append(access)
		if f.kind!=4 and access==NO_ACCESS: errors.append("%s号设施旁需要留出顾客通道。"%(facility_access.size()))
	for f in stations:
		var access=approach_cell(f,true)
		station_access.append(access)
		if access==NO_ACCESS: errors.append("%d号共用食材台旁需要留出顾客和员工都能走到的通道。"%station_access.size())
	if tables.is_empty(): errors.append("至少放一张桌子。")
	for i in range(tables.size()):
		var t=tables[i]
		if not table_valid(t,i): errors.append("第%d张桌椅重叠或超出房型。"%(i+1))
		var reachable=[]
		for station in range(stations.size()):
			var walk=guest_path(chairs(t)[0],station_cell(station))
			if not walk.is_empty(): reachable.append([station,walk.size()])
		reachable.sort_custom(func(a,b):return a[1]<b[1])
		table_stations[Vector2i(t.x,t.y)]=reachable.map(func(entry):return entry[0])
		for c in chairs(t):
			if guest_path(c,Vector2i(20,11)).is_empty(): errors.append("第%d张桌的座位无法从入口走到。"%(i+1));break
			var best=[]
			for tile in neighbors(c):
				var approach=path(pickup,tile,true,service_obstacles)
				if not approach.is_empty() and (best.is_empty() or approach.size()<best.size()): best=approach
			if best.is_empty(): errors.append("第%d张桌旁需要留出员工能走到的服务位。"%(i+1))
			else: service_spots[c]=best.back()
	return errors.is_empty()
func zone_name(z: int) -> String: return ["青叶","紫月","金穗"][z]
func facing(t:Dictionary)->Vector2i:
	return [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT][int(t.rot)]

const NO_ACCESS=Vector2i(-1,-1)
var station_access=[]
var facility_access=[]
func approach_cell(f:Dictionary,needs_staff:bool)->Vector2i:
	for tile in footprint(f):
		for neighbor in neighbors(tile):
			if service_obstacles.has(neighbor): continue
			if path(Vector2i(20,11),neighbor,false,service_obstacles).is_empty(): continue
			if needs_staff and path(kitchen_cell(),neighbor,true,service_obstacles).is_empty(): continue
			return neighbor
	return NO_ACCESS

func station_cell(index:int)->Vector2i:
	return station_access[index]

func station_for_table(t:Dictionary)->int:
	var available=stations_for_table(t)
	return -1 if available.is_empty() else available[0]

func stations_for_table(t:Dictionary)->Array:
	return table_stations.get(Vector2i(t.x,t.y),[])

func guest_path(chair:Vector2i,target:Vector2i)->Array:
	var blocked=service_obstacles.duplicate()
	blocked.erase(chair)
	return path(chair,target,false,blocked)

func snapshot() -> Dictionary:
	var painted=[]
	for c in partitions: painted.append([c.x,c.y,partitions[c]])
	return {"kitchen_stored":kitchen_stored,"kitchen":kitchens[0].duplicate(),"expanded":expanded,"partitions":painted,"facilities":facilities.duplicate(true),"shape":shape,"tables":tables.duplicate(true),"stations":stations.duplicate(true)}
static func upgrade_snapshot(data:Dictionary)->Dictionary:
	var result={}
	for key in ["kitchen_stored","kitchen","expanded","partitions","facilities","shape","tables"]:
		if data.has(key): result[key]=data[key]
	result.stations=data.get("stations",data.get("feeders",[]))
	return result.duplicate(true)

func restore(data: Dictionary):
	kitchen_stored=data.get("kitchen_stored",false)
	var fdata=data.get("kitchen",DEFAULT_KITCHEN)
	kitchens=[{"x":int(fdata.x),"y":int(fdata.y),"rot":int(fdata.rot),"span":2}]
	expanded=data.get("expanded",false)
	facilities=data.get("facilities",[]).duplicate(true)
	for f in facilities:
		for key in ["x","y","kind"]: f[key]=int(f[key])
	shape=clampi(int(data.get("shape",0)),0,2)
	tables=data.get("tables",[]).duplicate(true);stations=data.get("stations",data.get("feeders",[])).duplicate(true)
	for t in tables:
		for k in ["x","y","rot","zone"]: t[k]=int(t[k])
		t.rot=int(t.rot) & 2
	for f in stations:
		for k in ["x","y","zone"]: f[k]=int(f[k])
	partitions.clear()
	for tile in data.get("partitions",[]): partitions[Vector2i(int(tile[0]),int(tile[1]))]=tile[2]
	for items in [facilities,stations]:
		for f in items:
			for key in ["rot","span"]:
				if f.has(key): f[key]=int(f[key])
	compile()

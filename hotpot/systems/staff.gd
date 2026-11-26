extends RefCounted

const ROLES=["order","deliver","refill"]
const TITLES={"order":"点单员","deliver":"送餐员","refill":"补餐员"}
const NAMES={"order":"米娅","deliver":"阿木","refill":"露米"}
const HIRE_COST=30
const DAILY_WAGE=8
const MAX_EXP=60
const EXP_PER_LEVEL=30

# Unhired roles fall back to part-time kitchen help with measurable delay and lower speed/capacity.
const UNHIRED_ORDER_DELAY=0.5
const UNHIRED_DELIVER_DELAY=0.5
const UNHIRED_TABLE_SPEED=220.0
const UNHIRED_REFILL_SPEED=130.0
const UNHIRED_REFILL_CAPACITY=2
const ZONE_PRIORITY_BONUS=15.0

static func default_state()->Dictionary:
	var out={}
	for role in ROLES: out[role]={"hired":false,"exp":0,"zone":-1}
	return out

static func level(exp_points:int)->int:
	return 1+mini(2,int(maxi(0,exp_points)/EXP_PER_LEVEL))

static func speed(role:String,exp_points:int)->float:
	var lvl=level(exp_points)
	if role=="refill": return 145.0+float(lvl-1)*15.0
	return 300.0+float(lvl-1)*20.0

static func capacity(role:String,exp_points:int)->int:
	var lvl=level(exp_points)
	if role=="refill": return 3+(1 if lvl>=3 else 0)
	return 1+(1 if lvl>=3 else 0)

static func active_speed(staff:Dictionary,role:String)->float:
	var entry=staff.get(role,{})
	if entry.get("hired",false): return speed(role,int(entry.get("exp",0)))
	return UNHIRED_REFILL_SPEED if role=="refill" else UNHIRED_TABLE_SPEED

static func active_capacity(staff:Dictionary,role:String)->int:
	var entry=staff.get(role,{})
	if entry.get("hired",false): return capacity(role,int(entry.get("exp",0)))
	return UNHIRED_REFILL_CAPACITY if role=="refill" else 1

static func dispatch_delay(staff:Dictionary,role:String)->float:
	if staff.get(role,{}).get("hired",false): return 0.0
	if role=="order": return UNHIRED_ORDER_DELAY
	if role=="deliver": return UNHIRED_DELIVER_DELAY
	return 0.0

static func hired_count(staff:Dictionary)->int:
	var count=0
	for role in ROLES:
		if staff.get(role,{}).get("hired",false): count+=1
	return count

static func daily_wages(staff:Dictionary)->int:
	return hired_count(staff)*DAILY_WAGE

static func gain_exp(staff:Dictionary,role:String,trips:int):
	if not staff.has(role) or not staff[role].get("hired",false): return
	staff[role].exp=mini(MAX_EXP,int(staff[role].get("exp",0))+maxi(0,trips)+2)

static func serialize(staff:Dictionary)->Dictionary:
	var out={}
	for role in ROLES:
		var row=staff.get(role,{})
		out[role]={
			"hired":bool(row.get("hired",false)),
			"exp":clampi(int(row.get("exp",0)),0,MAX_EXP),
			"zone":clampi(int(row.get("zone",-1)),-1,2),
		}
	return out

static func migrate(data:Dictionary)->Dictionary:
	var state=default_state()
	if data.has("staff") and data.staff is Dictionary:
		for role in ROLES:
			if data.staff.has(role) and data.staff[role] is Dictionary:
				var row=data.staff[role]
				state[role]={
					"hired":bool(row.get("hired",false)),
					"exp":clampi(int(row.get("exp",0)),0,MAX_EXP),
					"zone":clampi(int(row.get("zone",-1)),-1,2),
				}
	else:
		state.refill={
			"hired":bool(data.get("employee",false)),
			"exp":clampi(int(data.get("staff_exp",0)),0,MAX_EXP),
			"zone":clampi(int(data.get("staff_zone",-1)),-1,2),
		}
	return state

static func _integer(value,low:int,high:int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=low and value<=high

static func validate(raw_staff)->String:
	if not raw_staff is Dictionary or raw_staff.size()!=ROLES.size(): return "员工编制数据无效"
	for role in ROLES:
		if not raw_staff.has(role) or not raw_staff[role] is Dictionary: return "员工岗位数据无效："+role
		var row=raw_staff[role]
		if row.size()!=3 or not row.has("hired") or not row.hired is bool: return "员工雇佣状态无效："+role
		if not _integer(row.get("exp"),0,MAX_EXP): return "员工经验无效："+role
		if not _integer(row.get("zone"),-1,2): return "员工排班分区无效："+role
	return ""

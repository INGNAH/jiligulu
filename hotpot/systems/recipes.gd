extends RefCounted

# Each ingredient ID corresponds to one unit of raw stock in research,
# and one plated portion in service. A saved formula lists its extra ingredients.
const NAMES=["香煎霜牛","清渍酸甜萝卜","椒香跳跳虾"]
const TOOLS=["煎锅","调味碗","炒锅"]
const CORES=[[1],[5],[2,3]]
const TAGS=["鲜香","肉类","海鲜","辣味","清淡","甜酸"]
const FLAVORS=[["肉类","鲜香"],["清淡","甜酸"],["海鲜","辣味"]]
const FORBIDDEN=[[],["辣味"],[]]

static func match_inputs(inputs:Array)->Dictionary:
	var best=-1
	var size=0
	var tied=false
	for j in range(CORES.size()):
		if not CORES[j].all(func(food): return food in inputs): continue
		if CORES[j].size()>size:
			best=j
			size=CORES[j].size()
			tied=false
		elif CORES[j].size()==size: tied=true
	if best<0: return {"error":"核心食材不齐，没做成一道菜。"}
	if tied: return {"error":"两道原方同样接近，主料不明确。"}
	var extras=inputs.duplicate()
	for food in CORES[best]: extras.erase(food)
	var conflict=conflict_tag(best,extras)
	if not conflict.is_empty(): return {"error":"做坏了：%s和%s的原方冲突。"%[conflict,NAMES[best]]}
	return {"recipe":best,"extras":extras}

static func conflict_tag(j:int,extras:Array)->String:
	for food in extras:
		if TAGS[food] in FORBIDDEN[j]: return TAGS[food]
	return ""

static func tags(j:int,extras:Array)->Array:
	var result=FLAVORS[j].duplicate()
	for food in extras:
		if TAGS[food] not in result: result.append(TAGS[food])
	return result

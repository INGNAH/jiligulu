extends RefCounted
const LIMIT=30

static func record(history: Array, entry: Dictionary) -> Array:
	var result=history.duplicate(true)
	for i in range(result.size()-1,-1,-1):
		if result[i].day==entry.day: result.remove_at(i)
	result.append(entry.duplicate(true))
	result.sort_custom(func(a,b): return a.day<b.day)
	while result.size()>LIMIT: result.pop_front()
	return result

static func totals(history: Array, count: int=7) -> Dictionary:
	var result={"days":0,"income":0,"spending":0,"profit":0,"served":0,"score_total":0,"rating":0,"plates":0}
	for i in range(maxi(0,history.size()-count),history.size()):
		var entry=history[i]
		result.days+=1
		for key in ["income","spending","served","score_total","plates"]: result[key]+=int(entry[key])
	result.profit=result.income-result.spending
	result.rating=int(float(result.score_total)/result.served) if result.served>0 else 0
	return result

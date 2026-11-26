extends RefCounted
const Dishes=preload("res://systems/dishes.gd")
const TEMPLATES=[
	["鲜香",["甜酸"],6,3],["肉类",["甜酸"],7,0],["海鲜",[],8,2],
	["辣味",["清淡"],9,2],["清淡",["辣味"],10,1],["甜酸",["辣味"],11,1]
]

static func profile(ticket:int,rng:RandomNumberGenerator)->Dictionary:
	var row=TEMPLATES[1 if ticket==2 else rng.randi_range(0,TEMPLATES.size()-1)]
	return {"preference":row[0],"dislikes":row[1],"regular":row[2],"special_want":row[3],"wish":Dishes.by_id(row[2]).core[0]}

static func likes(p:Dictionary,tags:Array)->bool:
	return p.preference in tags and not tags.any(func(tag):return tag in p.dislikes)

static func choose(p:Dictionary,options:Array,rng:RandomNumberGenerator)->int:
	var best=-100
	var candidates=[]
	for id in options:
		var tags=Dishes.by_id(id).tags
		var score=4 if p.preference in tags else 0
		if tags.any(func(tag):return tag in p.dislikes): score-=10
		if id==p.regular: score+=1
		if score>best: candidates.clear();best=score
		if score==best: candidates.append(id)
	if candidates.is_empty(): return -1
	return candidates[rng.randi_range(0,candidates.size()-1)]

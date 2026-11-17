extends RefCounted

# Recommendations do not consume stock. Existing cooked dishes count first.
static func plan(raw: Array, ready: Array, prices: Array, guests: int) -> Dictionary:
	var total=0
	for n in ready: total+=int(n)
	var missing=maxi(0,guests*3-total)
	var targets=[]
	var purchases=[]
	var cost=0
	var remaining=missing
	for i in range(6): targets.append(int(ready[i]))
	# Balance the available menu without discarding existing stock.
	while remaining>0:
		var chosen=0
		for i in range(1,6):
			if targets[i]<targets[chosen]: chosen=i
		targets[chosen]+=2
		remaining-=2
	for i in range(6):
		var needed=maxi(0,int((targets[i]-int(ready[i]))/2)-int(raw[i]))
		var packs=int(ceil(needed/3.0))
		purchases.append(packs*3)
		cost+=packs*3*int(prices[i])
	return {"targets":targets,"purchases":purchases,"cost":cost,"missing":missing,"recommended":guests*3,"total":total}

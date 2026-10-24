extends RefCounted
## Historical local histogram arithmetic, excluded from shipping.
const COMPARISON_BINS: int = 16
static func distribution(values: Array[float], marker: float) -> Dictionary:
	if values.is_empty(): return {}
	var rounded: Array[float] = []
	for value: float in values: rounded.append(roundi(value*1000.0)/1000.0)
	marker = roundi(marker*1000.0)/1000.0
	var low: float = rounded.min()
	var high: float = rounded.max()
	var bins: Array[int] = []
	bins.resize(mini(COMPARISON_BINS,maxi(1,ceili(sqrt(rounded.size())))))
	bins.fill(0)
	var span: float = maxf(high-low,0.001)
	for value: float in rounded: bins[clampi(int((value-low)/span*bins.size()),0,bins.size()-1)] += 1
	var edges: Array[float] = []
	for index: int in range(bins.size()+1): edges.append((low+span*index/bins.size())*1000.0)
	return {"bins":bins,"min_ms":low*1000.0,"max_ms":high*1000.0,"edges_ms":edges,"player_bin":clampi(int((marker-low)/span*bins.size()),0,bins.size()-1)}


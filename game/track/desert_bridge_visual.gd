class_name DesertBridgeVisual
extends RefCounted
## Original sandstone masonry. Cosmetic only, within the existing rail footprint.
const REVISION: String = "desert-bridge-2"
const STONE: Color = Color("a89b83")
const CAP: Color = Color(0.74,0.69,0.59,0.0)

static func append(tool: SurfaceTool, deck: SurfaceTool, span: Dictionary, bridges: Array = [], road_phase: Dictionary = {}) -> void:
	# Coping is cut stone: do not average normals across its top and bevels.
	tool.set_smooth_group(-1)
	var rails: Dictionary = {}
	for side: float in [-1.0,1.0]: rails[side] = CreatorBridges.rail_runs(span,bridges,0,float(span.length),side)
	var length: float = span.length
	var half: float = float(span.width)*0.5
	var count: int = ceili(length/0.4)
	for i: int in range(count):
		var a: float = length*i/count
		var b: float = length*(i+1)/count
		CreatorBridgeVisual.strip(deck,span,a,b,-half,half,0.025,Color.WHITE,road_phase)
		for side: float in [-1.0,1.0]:
			for run: Vector2 in CreatorBridges.clip_runs(rails[side],a,b):
				var inner: float = (half+0.04)*side
				var outer: float = (half+0.70)*side
				face(tool,span,Vector3(run.x,0.02,inner),Vector3(run.y,0.02,inner),Vector3(run.y,0.57,inner),Vector3(run.x,0.57,inner),STONE)
				# Shallow arch soffit never intrudes into the canonical open underpass.
				var low_a: float = underside(span,run.x)
				var low_b: float = underside(span,run.y)
				face(tool,span,Vector3(run.x,low_a,outer),Vector3(run.y,low_b,outer),Vector3(run.y,0.57,outer),Vector3(run.x,0.57,outer),STONE)
				if side < 0:
					face(tool,span,Vector3(run.x,low_a,-half-0.70),Vector3(run.y,low_b,-half-0.70),Vector3(run.y,low_b,half+0.70),Vector3(run.x,low_a,half+0.70),STONE.darkened(0.22))
		# Individual overhanging coping stones break the silhouette without extra draws.
	var blocks: int = ceili(length/0.95)
	for i: int in range(blocks):
		var a: float = length*i/blocks+0.012
		var b: float = length*(i+1)/blocks-0.012
		var top: float = 0.72+sin(i*7.13)*0.018
		for side: float in [-1.0,1.0]:
			for run: Vector2 in CreatorBridges.clip_runs(rails[side],a,b):
				block(tool,span,run.x,run.y,(half+0.01)*side,(half+0.74)*side,0.56,top,CAP)
	var posts: int = maxi(1,ceili(length/7.5))
	for i: int in range(posts+1):
		var a: float = clampf(length*i/posts-0.30,0.0,length-0.60)
		for side: float in [-1.0,1.0]:
			if CreatorBridges.clip_runs(rails[side],a,a+0.60) != [Vector2(a,a+0.60)]: continue
			block(tool,span,a,a+0.60,half*side,(half+0.75)*side,-0.12,0.86,STONE)
			block(tool,span,a,a+0.60,half*side,(half+0.75)*side,0.86,0.98,CAP)
	for u: float in [0.0,length]:
		for side: float in [-1.0,1.0]:
			if CreatorBridges.clip_runs(rails[side],u,u+0.001).is_empty(): continue
			face(tool,span,Vector3(u,-0.1,half*side),Vector3(u,-0.1,(half+0.75)*side),Vector3(u,0.72,(half+0.75)*side),Vector3(u,0.72,half*side),STONE)

static func underside(span: Dictionary, u: float) -> float:
	var length: float = span.length
	var height: float = CreatorBridges.height(span,Vector2(span.position[0],span.position[1])+Vector2(u,0).rotated(deg_to_rad(float(span.heading))))
	if height < CreatorBridges.UNDERPASS_CLEARANCE:
		return minf(-0.06,-height+lerpf(-0.05,CreatorBridges.UNDERPASS_CLEARANCE,smoothstep(1.0,CreatorBridges.UNDERPASS_CLEARANCE,height)))
	var t: float = clampf((u-CreatorBridges.RAMP)/(length-2.0*CreatorBridges.RAMP),0.0,1.0)
	return maxf(CreatorBridges.UNDERPASS_CLEARANCE-height,-0.42-0.65*(1.0-sin(t*PI)))

static func block(tool: SurfaceTool, span: Dictionary, a: float, b: float, inner: float, outer: float, low: float, high: float, color: Color) -> void:
	var bevel: float = minf(0.022,(high-low)*0.15)
	var inset: float = signf(outer-inner)*bevel
	var shoulder: float = high-bevel
	face(tool,span,Vector3(a+bevel,high,inner+inset),Vector3(b-bevel,high,inner+inset),Vector3(b-bevel,high,outer-inset),Vector3(a+bevel,high,outer-inset),color)
	face(tool,span,Vector3(a,low,inner),Vector3(b,low,inner),Vector3(b,shoulder,inner),Vector3(a,shoulder,inner),color)
	face(tool,span,Vector3(a,low,outer),Vector3(b,low,outer),Vector3(b,shoulder,outer),Vector3(a,shoulder,outer),color)
	face(tool,span,Vector3(a,shoulder,inner),Vector3(b,shoulder,inner),Vector3(b-bevel,high,inner+inset),Vector3(a+bevel,high,inner+inset),color)
	face(tool,span,Vector3(a,shoulder,outer),Vector3(b,shoulder,outer),Vector3(b-bevel,high,outer-inset),Vector3(a+bevel,high,outer-inset),color)
	for u: float in [a,b]:
		var tip: float = u+bevel if u == a else u-bevel
		face(tool,span,Vector3(u,low,inner),Vector3(u,low,outer),Vector3(u,shoulder,outer),Vector3(u,shoulder,inner),color)
		face(tool,span,Vector3(u,shoulder,inner),Vector3(u,shoulder,outer),Vector3(tip,high,outer-inset),Vector3(tip,high,inner+inset),color)

static func face(tool: SurfaceTool, span: Dictionary, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	tool.set_color(color)
	var top: bool = absf(a.y-c.y) < 0.001
	for p: Vector3 in [a,c,b,a,d,c]:
		var v: Vector3 = CreatorBridgeVisual.vertex(span,p.x,p.z,p.y)
		tool.set_uv(Vector2(p.x,p.z if top else v.y))
		tool.add_vertex(v)

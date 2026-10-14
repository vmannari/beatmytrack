class_name GarageDrain
extends RefCounted
## Original inset drainage channel and removable stainless grate sections.
const CENTER := Vector3(-6.5,-0.025,-1.45)
const WIDTH: float = 0.72
const LENGTH: float = 3.30

static func build(parent: Node3D) -> void:
	var drain := Node3D.new()
	drain.name = "GarageDrain"
	drain.position = CENTER
	parent.add_child(drain)
	var dark: Material = GarageMaterials.finish("drainwell","172128",0.10,0.83,0)
	var steel: Material = GarageEnvironment.surface("draingrate","798a91",0.66,0.39)
	var trim: Material = GarageEnvironment.surface("drainframe","a1a9ab",0.64,0.33)
	GarageEnvironment.box(drain,Vector3(0,-0.095,0),Vector3(WIDTH-0.09,0.025,LENGTH-0.09),dark)
	for x: float in [-WIDTH*0.5,WIDTH*0.5]:
		GarageEnvironment.box(drain,Vector3(x,-0.038,0),Vector3(0.042,0.10,LENGTH+0.065),steel)
		GarageEnvironment.box(drain,Vector3(x,0.003,0),Vector3(0.065,0.012,LENGTH+0.065),trim)
	for z: float in [-LENGTH*0.5,LENGTH*0.5]:
		GarageEnvironment.box(drain,Vector3(0,-0.038,z),Vector3(WIDTH,0.10,0.045),steel)
		GarageEnvironment.box(drain,Vector3(0,0.003,z),Vector3(WIDTH+0.06,0.012,0.065),trim)
	for x: float in [-0.22,0.22]: GarageEnvironment.box(drain,Vector3(x,-0.038,0),Vector3(0.024,0.025,LENGTH-0.1),steel)
	for section: int in range(3):
		var z: float = (section-1)*1.065
		for end: float in [-0.515,0.515]: GarageEnvironment.box(drain,Vector3(0,0.003,z+end),Vector3(WIDTH-0.07,0.026,0.034),steel)
		for index: int in range(23):
			var bar: MeshInstance3D = GarageEnvironment.box(drain,Vector3(0,-0.010,z-0.484+index*0.044),Vector3(WIDTH-0.085,0.025,0.023),steel)
			bar.name = "DrainGrateBar"
		for x: float in [-0.32,0.32]:
			var bolt: MeshInstance3D = GarageFurnishings.tube(drain,Vector3(x,0.008,z),Vector3(x,0.016,z),0.014,trim,6)
			bolt.name = "DrainFrameFastener"

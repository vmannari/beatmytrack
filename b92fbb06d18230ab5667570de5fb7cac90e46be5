extends SceneTree
func _initialize() -> void:
	for tier: String in ["full","simple"]:
		for view: String in ["front","rear","side"]:
			var folder: String = "res://../docs/evidence/challenger-surface-joins-2026-11-12/opaque/mobile/"
			var a := Image.load_from_file(folder+tier+"-"+view+".png")
			var b := Image.load_from_file(folder+tier+"-"+view+"-probe.png")
			var count: int = 0;var samples: Array = []
			for y: int in range(a.get_height()):
				for x: int in range(a.get_width()):
					if a.get_pixel(x,y)!=b.get_pixel(x,y):
						count+=1
						if samples.size()<12:samples.append([x,y,a.get_pixel(x,y).to_html(),b.get_pixel(x,y).to_html()])
			print(tier," ",view," ",count," ",samples)
	quit()

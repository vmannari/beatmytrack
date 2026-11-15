extends "res://tests/test_shared_car_pictures.gd"
## Measure actual live-preview growth and readable card geometry in the real App.

func rect(value: Control) -> Array:
	var bounds: Rect2 = value.get_global_rect()
	return [bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]

func shot(label: String) -> void:
	await super.shot(label)
	if not observations.has("layout"): observations.layout = {}
	observations.layout[label] = {"preview":rect(page.preview),"carousel":rect(page.gallery),"actions":rect(page.actions),"viewport_pixels":str(page.showroom.showroom_viewport.size)}
	for card: Control in page.cards.get_children():
		var id: String = VehicleCatalog.IDS[card.get_index()]
		var title: Control = card.find_child("CarCardTitle_"+id,true,false)
		var badge: Control = card.find_child("CarEquipped_"+id,true,false)
		check(card.get_global_rect().encloses(title.get_global_rect()),"complete title fits "+label+"/"+id)
		if badge.visible: check(card.get_global_rect().encloses(badge.get_global_rect()),"Selected badge fits "+label+"/"+id)
	check(page.preview.get_global_rect().end.y<=page.gallery.get_global_rect().position.y,"3D view does not overlap carousel "+label)
	check(page.gallery.get_global_rect().end.y<=page.actions.get_global_rect().position.y,"carousel does not overlap actions "+label)

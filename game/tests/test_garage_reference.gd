extends "res://tests/test_garage_car_stats.gd"
## GRD01–GRD05: revised owner layout, stock comparisons and real selection state.

class WalletFixture extends Node:
	signal changed
	var coins: int = 3500
	func authenticated() -> bool: return true
	func balance() -> int: return coins

func capture(label: String) -> void:
	await super.capture(label)
	if label != "super_rally-2560": return
	var wallet: Control = root.find_child("GarageHeaderWallet",true,false)
	var app: Node = wallet.app
	var economy: Node = app.cosmetic_economy
	var fixture := WalletFixture.new()
	app.cosmetic_economy = fixture
	wallet._balance()
	check(wallet._amount.text == "3,500","header formats authenticated coin balance")
	fixture.coins = 1280
	wallet._balance()
	check(wallet._amount.text == "1,280","header follows changed account coin balance")
	app.cosmetic_economy = economy
	wallet._balance()
	fixture.free()
	var identity: int = page.get_instance_id()
	app._navigate_menu_page("tracks")
	app._finish_menu_page_slide()
	await settle(10)
	check(root.find_child("GarageHeaderWallet",true,false).visible,"shared coin header remains after leaving Garage")
	var track_tab: Button = root.find_child("Tab_tracks",true,false)
	check(track_tab.get_theme_color("font_color") == MenuStyle.ACCENT,"shared navigation retains correct active tab")
	check(track_tab.get_theme_stylebox("normal").bg_color != Color.TRANSPARENT,"Race retains the original filled button style")
	app._navigate_menu_page("garage")
	app._finish_menu_page_slide()
	await settle(10)
	check(root.find_child("GaragePage",true,false).get_instance_id() == identity,"header navigation retains Garage page")
	check(root.find_child("GarageHeaderWallet",true,false).visible,"returning to Garage restores its header")

func check_content(id: String) -> void:
	super.check_content(id)
	check(page._car_stats._title.text == VehicleCatalog.title(id),"profile title follows browsed car "+id)
	var data: Dictionary = Stats.performance(id)
	check(page._car_stats.stat_rows.acceleration.row.tooltip_text == GameText.message("0–60 km/h: {time} s",{"time":"%.1f" % data.acceleration}),"acceleration tooltip retains exact measured value "+id)
	for key: String in ["acceleration","handling","top_speed"]:
		var bar: Control = page._car_stats.stat_rows[key].bar
		check(bar.rating >= 1 and bar.rating <= 5,"qualified five-segment rating "+id+"/"+key)
		check(bar.rating == page._car_stats.ratings[key],"visible segments follow car rating "+id+"/"+key)
	if id == "super_rally": check(page._car_stats.ratings == {"acceleration":4,"handling":4,"top_speed":3},"Super Rally matches owner draft comparisons")
	if id == "kart": check(page._car_stats.ratings.handling > Stats.comparison("hovercraft").handling,"precise Kart and sliding Hover retain distinct handling character")
	var thumbnail: Node = page.thumbnails[id]
	if thumbnail.preview_service._default(thumbnail):
		check(thumbnail._image.texture != null and thumbnail._image.texture.get_size() == Vector2(512,288),"sharp stock selection portrait "+id)
		check(thumbnail._image.texture.get_image().get_pixel(0,0).a == 0.0,"stock portrait has transparent surround "+id)
	var visible_bounds: Rect2
	var first: bool = true
	for mesh: MeshInstance3D in page.showroom.car.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh == null or not mesh.is_visible_in_tree() or mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		for corner: int in range(8):
			var at: Vector2 = page.showroom.camera.unproject_position(mesh.global_transform*mesh.get_aabb().get_endpoint(corner))
			visible_bounds = Rect2(at,Vector2.ZERO) if first else visible_bounds.expand(at)
			first = false
	check(Rect2(Vector2.ZERO,Vector2(page.showroom.showroom_viewport.size)).encloses(visible_bounds),"entire default car silhouette fits selection view "+id)

func check_layout() -> void:
	super.check_layout()
	check(not page.heading.visible and page._car_stats._title.visible,"car name appears once inside profile")
	check(page.select_button.get_global_rect().position.x > page.actions.get_global_rect().position.x+50,"selection actions align to the right")
	check(page.select_button.size.x < page.actions.size.x*0.55,"Select vehicle does not fill the entire footer")
	var header: Control = root.find_child("MenuHeader",true,false)
	check(header.get_global_rect().end.x <= root.size.x+1,"header fits viewport "+str(root.size))
	var wallet: Control = header.get_node("GarageHeaderWallet")
	check(wallet.visible,"account coins appear in header")
	var tab: Button = root.find_child("Tab_garage",true,false)
	check(tab.get_theme_stylebox("normal").bg_color != Color.TRANSPARENT,"Garage tab uses the original filled button style")
	for card: Control in page.cards.get_children():
		var id: String = VehicleCatalog.IDS[card.get_index()]
		var caption: Control = card.find_child("CarCardTitle_"+id,true,false)
		check(card.get_global_rect().encloses(caption.get_global_rect()),"card caption fits "+id+"/"+str(root.size))
		check(card.get_global_rect().end.y <= page.gallery.get_global_rect().end.y+1,"carousel exposes complete card footer "+id+"/"+str(root.size))
		check(card.find_child("CarEquipped_"+id,true,false).visible == (id == page._selected_vehicle_id),"selected badge represents equipped car "+id)
		if not card.get_global_rect().encloses(caption.get_global_rect()):
			print("REFERENCE_CARD_BOUNDS ",id," ",card.get_global_rect()," caption ",caption.get_global_rect()," model ",page.thumbnails[id].size)
	if not page.preview.get_global_rect().encloses(page._car_stats.get_global_rect()):
		print("REFERENCE_PROFILE_BOUNDS ",root.size," preview ",page.preview.size," profile ",page._car_stats.size)

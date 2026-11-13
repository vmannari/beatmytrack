extends SceneTree
const Shop = preload("res://persistence/cosmetic_catalog.gd")
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: "+message)
func _initialize() -> void:
	var wallet: Dictionary = {"schema":1,"balance":900,"revision":3,"owned":[],"prices":Shop.items()}
	check(Shop.valid_wallet(wallet),"the complete current server catalogue is accepted with the reward wallet")
	var excessive: Dictionary = wallet.duplicate(true)
	for index: int in range(maxi(256,Shop.items().size())+1): excessive.prices["unknown/"+str(index)] = 1
	check(not Shop.valid_wallet(excessive),"an oversized catalogue remains bounded")
	var invalid: Dictionary = wallet.duplicate(true)
	invalid.prices[invalid.prices.keys()[0]] = 0
	check(not Shop.valid_wallet(invalid),"free or invalid purchase prices remain rejected")
	wallet.balance = -1
	check(not Shop.valid_wallet(wallet),"negative server balances remain rejected")
	print("COSMETIC_WALLET_CAPACITY_TESTS: 4 checks, %d failures; %d prices" % [failures,Shop.items().size()])
	quit(1 if failures else 0)

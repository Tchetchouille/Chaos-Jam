extends Node

## Persists shop economy for the session
signal economy_changed
signal building_unlocked(building_id: int)

## Spendable currency (flowers).
var flowers: int = 0

var building_counts: Dictionary = {}
var building_names: Dictionary = {}
var unlocked_count: int = 0
static var flower_collection_multiplier: float = 1.0

func get_flower_collection_multiplier() -> float:
	var multiplier: float = 1.0
	for building_id in building_counts:
		# Rk × nk × mk (nk = number of buildings of type k, mk = multiplier for building type k, Rk = base collection rate for building type k)
		# Rk = (k^( k/2 +2)× 10)/10
		var base_rate: float = (building_id^( building_id/2 + 2) * 10) / 10
		multiplier += base_rate * building_counts[building_id] * get_building_multiplier(building_id)
	return multiplier

func get_building_multiplier(_building_id: int) -> float:
	return 1.0

func get_owned(building_id: int) -> int:
	return int(building_counts.get(building_id, 0))


func get_price(building_id: int) -> int:
	var owned: int = get_owned(building_id)
	var base: float = 10.0 + float(building_id) * 50.0
	return int(ceil(base * pow(1.15, float(owned + 1))))


func get_building_name(building_id: int) -> String:
	return building_names.get(building_id, "???")


func can_afford(building_id: int) -> bool:
	return flowers >= get_price(building_id)


func try_purchase(building_id: int) -> void:
	if not can_afford(building_id):
		return
	flowers -= get_price(building_id)
	building_counts[building_id] = get_owned(building_id) + 1
	economy_changed.emit()


func unlock_next_building() -> void:
	var new_id: int = unlocked_count
	building_counts[new_id] = 0
	building_names[new_id] = BrainrotGenerator.generate_name() + " " + BrainrotGenerator.generate_name()
	unlocked_count += 1
	building_unlocked.emit(new_id)

func on_shop_opened() -> void:
	var changed := false
	# # Seed the shop with a building
	if unlocked_count == 0:
		unlock_next_building()
		changed = true

	while true:
		var next_building_id: int = unlocked_count + 1
		if flowers >= get_price(next_building_id):
			unlock_next_building()
			changed = true
		else:
			break

	if changed:
		economy_changed.emit()

func collect_flower() -> void:
	flowers += int(floor(1 * flower_collection_multiplier))
	economy_changed.emit()

func on_shop_exited() -> void:
	flower_collection_multiplier = get_flower_collection_multiplier()

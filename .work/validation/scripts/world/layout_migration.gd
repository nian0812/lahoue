extends RefCounted

## Versioned, idempotent conversion of the former 40-plot / 10-tier layout.
## Surplus crops and interrupted meals become claimable items, never discarded.
static func migrate(source: Dictionary, data: Node) -> Dictionary:
	var state: Dictionary = source.duplicate(true)
	if int(state.get("layout_version", 1)) >= 2:
		return state
	var reserve: Dictionary = (state.get("migration_inventory", {}) as Dictionary).duplicate(true)
	var plots: Variant = state.get("purchased_farm_plots", [])
	var crops: Variant = state.get("crops", {})
	var growth: Variant = state.get("crop_growth", {})
	if not state.has("purchased_farm_plots") and crops is Dictionary:
		for id: Variant in crops:
			if id is String and String(id).begins_with("farm_"):
				var number: int = String(id).trim_prefix("farm_").to_int()
				if number >= 29 and number <= 40 and id == "farm_%02d" % number: plots.append(id)
	if plots is Array and crops is Dictionary and growth is Dictionary:
		var retained: Array = []
		for id: Variant in plots:
			var number: int = String(id).trim_prefix("farm_").to_int() if id is String else 0
			if number >= 29 and number <= 40:
				state["money"] = int(state.get("money", 0)) + data.get_farm_plot_purchase_cost()
				if crops.has(id):
					var crop: Variant = data.get_entry("crops", String(crops[id]))
					if crop is Dictionary:
						var ripe: bool = float(growth.get(id, 0.0)) >= data.get_crop_growth_time_seconds(String(crops[id]))
						var item: String = String(crop.get("harvest_item" if ripe else "seed_item", ""))
						_credit(reserve, item, int(crop.get("yield", 1)) if ripe else 1)
						crops.erase(id)
						growth.erase(id)
			else:
				retained.append(id)
		if state.has("purchased_farm_plots"):
			state["purchased_farm_plots"] = retained
	var old_level: int = int(state.get("restaurant_level", 0))
	if old_level > 0 and old_level <= 10:
		var level: int = mini(old_level, 5)
		state["restaurant_level"] = level
		state["kitchen_level"] = level
		# Return the price of tiers that no longer exist; no new EXP is awarded.
		var retired_costs: Array[int] = [10000000, 20000000, 30000000, 50000000, 100000000]
		for i: int in range(5, old_level):
			state["money"] = int(state.get("money", 0)) + retired_costs[i - 5]
		var tables: Variant = state.get("restaurant_tables", {})
		var customers: Variant = state.get("restaurant_customers", {})
		var jobs: Variant = state.get("restaurant_cooking", {})
		if tables is Dictionary and customers is Dictionary and jobs is Dictionary:
			var cap: int = data.get_restaurant_table_capacity(level)
			if not state.has("purchased_restaurant_tables"):
				state["purchased_restaurant_tables"] = clampi(tables.size(), 2, cap)
			for id: Variant in tables.keys():
				if String(id).trim_prefix("table_").to_int() > cap:
					tables.erase(id)
			for id: Variant in customers.keys():
				var customer: Variant = customers[id]
				if not customer is Dictionary:
					continue
				if String(customer.get("table_id", "")).trim_prefix("table_").to_int() > cap:
					if jobs.has(id) and jobs[id] is Dictionary:
						var job: Dictionary = jobs[id]
						if String(job.get("state", "")) != "paid":
							var recipe: Variant = data.get_entry("recipes", String(job.get("recipe_id", "")))
							var ingredients: Dictionary = recipe.get("ingredients", {}) if recipe is Dictionary else {}
							for item: String in ingredients:
								_credit(reserve, item, int(ingredients[item]) * int(job.get("quantity", 1)))
					jobs.erase(id)
					customers.erase(id)
				else:
					# Paths are rebuilt against fixed slots by the restaurant on load.
					customer["walk_path"] = []
			var staff: Variant = state.get("staff", {})
			if staff is Dictionary:
				for worker: Variant in staff.values():
					if worker is Dictionary and worker.get("active_job", {}) is Dictionary:
						var job: Dictionary = worker.get("active_job", {})
						if String(job.get("job_type", "")) in ["cook", "serve", "payment", "clean"]:
							worker["active_job"] = {}
							worker["state"] = "idle"
	# Existing animals remain; purchases still obey the new canonical capacities.
	var allowance: Dictionary = {}
	var animals: Variant = state.get("animals", {})
	if animals is Dictionary:
		for animal: Variant in animals.values():
			if animal is Dictionary and String(animal.get("state", "")) != "completed":
				var entry: Variant = data.get_entry("animals", String(animal.get("animal_id", "")))
				if entry is Dictionary:
					var housing: String = String(entry.get("housing", ""))
					allowance[housing] = int(allowance.get(housing, 0)) + 1
	state["legacy_housing_allowance"] = allowance
	state["migration_inventory"] = reserve
	state["layout_version"] = 2
	return state


static func _credit(reserve: Dictionary, item: String, amount: int) -> void:
	if not item.is_empty() and amount > 0:
		reserve[item] = int(reserve.get(item, 0)) + amount

extends Node

const customer_script: Script = preload("res://scripts/restaurant/customer.gd")
const restaurant_script: Script = preload("res://scripts/restaurant/restaurant.gd")
const staff_script: Script = preload("res://scripts/restaurant/staff.gd")
const vnd_format: GDScript = preload("res://scripts/ui/vnd_formatter.gd")

const premium_specs: Dictionary = {
	"st25_wagyu_rice": {"level": 35, "ingredients": {"st25_rice": 1, "wagyu": 1}},
	"norwegian_salmon_rice": {"level": 35, "ingredients": {"salmon": 1, "st25_rice": 1, "olive_oil": 1}},
	"alaska_lobster_rice": {"level": 37, "ingredients": {"lobster": 1, "butter": 1}},
	"japanese_scallop_rice": {"level": 39, "ingredients": {"japanese_scallop": 1, "cheese": 1, "st25_rice": 1}},
	"king_crab_butter": {"level": 41, "ingredients": {"king_crab": 1, "butter": 1}},
	"bluefin_tuna_rice": {"level": 43, "ingredients": {"bluefin_tuna": 1, "st25_rice": 1}},
	"wagyu_steak": {"level": 45, "ingredients": {"wagyu": 1, "butter": 1, "olive_oil": 1}},
	"butter_grilled_alaska_lobster": {"level": 47, "ingredients": {"lobster": 1, "butter": 1, "saffron": 1}},
	"cheese_salmon": {"level": 49, "ingredients": {"salmon": 1, "cheese": 1, "olive_oil": 1}},
	"king_crab_rice": {"level": 51, "ingredients": {"king_crab": 1, "st25_rice": 1, "saffron": 1}},
	"truffle_wagyu_steak": {"level": 53, "ingredients": {"truffle": 1, "wagyu": 1, "butter": 1}},
	"royal_seafood_platter": {
		"level": 55,
		"ingredients": {
			"lobster": 1,
			"king_crab": 1,
			"japanese_scallop": 1,
			"bluefin_tuna": 1,
			"olive_oil": 1,
			"saffron": 1,
		},
	},
}

var failures: int = 0

@onready var world: Node = get_parent()


func _ready() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var user_directory: String = ProjectSettings.globalize_path("user://").to_lower()
	if not user_directory.contains("lahoue_codex_premium_recipes_test"):
		push_error("premium_recipes_test: refusing to run outside the isolated test directory")
		get_tree().quit(1)
		return

	_cleanup_save_files()
	save_manager.create_new_game()
	game_manager.stop_gameplay()
	inventory_manager.clear()

	_validate_recipe_data()
	_validate_level_gating()
	_validate_recipe_ui()

	_reach_level(35)
	var restaurant: Node = world.get_node("restaurant")
	game_manager.money = 11000000
	_expect(bool(world.call("upgrade_system", "restaurant")), "Restaurant purchase fixture failed")
	_expect(game_manager.level == 35, "level progression did not reach Level 35")
	_expect(not (restaurant.call("get_menu_entry", "st25_wagyu_rice") as Dictionary).is_empty(), "Level 35 restaurant menu did not refresh with premium recipes")
	_expect((restaurant.call("get_menu_entry", "alaska_lobster_rice") as Dictionary).is_empty(), "Level 37 recipe entered the Level 35 restaurant menu")

	var customer: Node = restaurant.call("spawn_customer", "premium_customer", "st25_wagyu_rice") as Node
	_expect(customer != null, "Level 35 premium customer could not spawn")
	await get_tree().process_frame
	await get_tree().process_frame
	_finish_customer_entry(restaurant, customer)
	_expect(customer != null and String((customer.get("order") as Dictionary).get("recipe_id", "")) == "st25_wagyu_rice", "customer did not create the unlocked premium order")
	_expect(String(customer.get("current_state")) == customer_script.state_waiting_food, "premium customer is not waiting for food")

	_expect(inventory_manager.add_item("wagyu", 1), "Wagyu import fixture could not be added")
	_expect(inventory_manager.add_item("st25_rice", 1), "ST25 Rice import fixture could not be added")
	_expect(inventory_manager.add_item("lobster", 1), "saved imported ingredient fixture could not be added")
	_expect(save_manager.save_game(), "imported ingredients and premium order could not be saved")
	inventory_manager.clear()
	_expect(save_manager.load_game(), "imported ingredients and premium order could not be loaded")
	restaurant = world.get_node("restaurant")
	customer = restaurant.call("get_customer", "premium_customer") as Node
	_expect(inventory_manager.get_amount("wagyu") == 1, "save/load lost or duplicated Wagyu")
	_expect(inventory_manager.get_amount("st25_rice") == 1, "save/load lost or duplicated ST25 Rice")
	_expect(inventory_manager.get_amount("lobster") == 1, "save/load lost or duplicated the remaining imported ingredient")
	_expect(customer != null and String((customer.get("order") as Dictionary).get("recipe_id", "")) == "st25_wagyu_rice", "save/load lost the premium customer order")

	game_manager.money = 10000000
	var chef: Node = restaurant.call("hire_staff", "premium_chef", "chef") as Node
	_expect(chef != null, "Chef could not be hired for a premium order")
	_expect(restaurant.call("dispatch_staff_jobs"), "Chef did not see the valid premium cooking job")
	_expect(_active_job_type(chef) == staff_script.job_cook, "Chef did not claim the premium cooking job")
	_expect(restaurant.call("advance_staff", 10.0), "Chef did not reach the existing kitchen flow")
	var job: Dictionary = restaurant.call("get_cooking_job", "premium_customer") as Dictionary
	_expect(String(job.get("state", "")) == restaurant_script.cooking_state_cooking, "Chef did not start normal timed cooking for the premium recipe")
	_expect(inventory_manager.get_amount("wagyu") == 0 and inventory_manager.get_amount("st25_rice") == 0, "premium cooking did not consume the exact ingredients")
	_expect(inventory_manager.get_amount("lobster") == 1, "premium cooking consumed an unrelated imported ingredient")
	_expect(not restaurant.call("start_cooking", "premium_customer"), "duplicate premium cooking job was accepted")

	_expect(restaurant.call("advance_cooking", float(job.get("cooking_duration", 0.0))), "premium cooking timer did not finish")
	job = restaurant.call("get_cooking_job", "premium_customer") as Dictionary
	_expect(String(job.get("state", "")) == restaurant_script.cooking_state_ready, "premium dish did not become ready")
	_expect(save_manager.save_game(), "ready premium dish could not be saved")
	inventory_manager.clear()
	restaurant.set("cooking_jobs", {})
	_expect(save_manager.load_game(), "ready premium dish could not be loaded")
	restaurant = world.get_node("restaurant")
	customer = restaurant.call("get_customer", "premium_customer") as Node
	job = restaurant.call("get_cooking_job", "premium_customer") as Dictionary
	_expect(String(job.get("state", "")) == restaurant_script.cooking_state_ready, "save/load did not preserve the ready premium dish")
	_expect(inventory_manager.get_amount("wagyu") == 0 and inventory_manager.get_amount("st25_rice") == 0, "save/load duplicated consumed premium ingredients")
	_expect(inventory_manager.get_amount("lobster") == 1, "save/load lost the unconsumed imported ingredient")

	var waiter: Node = restaurant.call("hire_staff", "premium_waiter", "waiter") as Node
	_expect(waiter != null, "Waiter could not be hired for the premium serve/payment flow")
	_expect(restaurant.call("dispatch_staff_jobs"), "ready premium dish was not dispatched to Waiter")
	_expect(_active_job_type(waiter) == staff_script.job_serve, "Waiter did not claim the premium serving job")
	_expect(restaurant.call("advance_staff", 10.0), "Waiter did not serve the premium dish")
	_expect(String(customer.get("current_state")) == customer_script.state_eating, "premium customer did not enter EATING after service")
	_expect(restaurant.call("advance_staff", 10.0), "Waiter did not return after serving")

	var wallet_before_payment: int = game_manager.get_wallet_balance()
	var expected_revenue: int = int((restaurant.call("get_menu_entry", "st25_wagyu_rice") as Dictionary).get("selling_price", 0))
	var exp_before_payment: int = game_manager.current_exp
	_expect(restaurant.call("dispatch_staff_jobs"), "premium payment was not dispatched to Waiter")
	_expect(_active_job_type(waiter) == staff_script.job_payment, "Waiter did not claim the premium payment job")
	_expect(restaurant.call("advance_staff", 10.0), "Waiter did not collect the premium payment")
	_expect(game_manager.get_wallet_balance() == wallet_before_payment + expected_revenue, "premium customer paid the wrong amount")
	_expect(game_manager.current_exp == exp_before_payment + 1000, "10M+ premium payment did not cap Sales EXP at 1000")
	_expect(not restaurant.call("finish_customer_meal", "premium_customer"), "premium payment was accepted twice")
	_expect(game_manager.get_wallet_balance() == wallet_before_payment + expected_revenue, "duplicate premium payment changed money")
	_expect(game_manager.current_exp == exp_before_payment + 1000, "duplicate premium payment granted Sales EXP twice")

	_finish_tests()


func _validate_recipe_data() -> void:
	var entries: Dictionary = data_manager.get_dataset("recipes").get("entries", {}) as Dictionary
	var premium_count: int = 0
	for recipe_value: Variant in entries.values():
		if typeof(recipe_value) == TYPE_DICTIONARY and String((recipe_value as Dictionary).get("category", "")) == "premium":
			premium_count += 1
	_expect(premium_count == premium_specs.size(), "premium recipe data does not contain exactly 12 complete recipes")

	for recipe_id_value: Variant in premium_specs:
		var recipe_id: String = String(recipe_id_value)
		var spec: Dictionary = premium_specs[recipe_id] as Dictionary
		var recipe_value: Variant = entries.get(recipe_id)
		_expect(typeof(recipe_value) == TYPE_DICTIONARY, "premium recipe '%s' is missing" % recipe_id)
		if typeof(recipe_value) != TYPE_DICTIONARY:
			continue
		var recipe: Dictionary = recipe_value as Dictionary
		var expected_ingredients: Dictionary = spec.get("ingredients", {}) as Dictionary
		var ingredients: Dictionary = recipe.get("ingredients", {}) as Dictionary
		_expect(String(recipe.get("category", "")) == "premium", "recipe '%s' has the wrong category" % recipe_id)
		_expect(int(recipe.get("required_level", 0)) == int(spec.get("level", 0)), "recipe '%s' has the wrong unlock level" % recipe_id)
		_expect(_ingredients_match(ingredients, expected_ingredients), "recipe '%s' has the wrong existing item IDs or quantities" % recipe_id)
		_expect(float(recipe.get("cooking_time", 0.0)) > 0.0, "recipe '%s' has no cooking timer" % recipe_id)
		var ingredient_cost: int = 0
		for item_id_value: Variant in ingredients:
			var item_id: String = String(item_id_value)
			var buy_price: int = data_manager.get_item_buy_price(item_id)
			_expect(buy_price > 0, "recipe '%s' references a non-purchasable premium ingredient" % recipe_id)
			ingredient_cost += buy_price * int(ingredients[item_id_value])
		var selling_price: int = int(recipe.get("selling_price", 0))
		_expect(selling_price >= ingredient_cost * 2, "recipe '%s' sells below 2x import cost" % recipe_id)


func _validate_level_gating() -> void:
	for level: int in range(34, 56):
		var menu: Dictionary = data_manager.get_restaurant_menu(level)
		for recipe_id_value: Variant in premium_specs:
			var recipe_id: String = String(recipe_id_value)
			var required_level: int = int((premium_specs[recipe_id] as Dictionary).get("level", 0))
			_expect(menu.has(recipe_id) == (level >= required_level), "recipe '%s' has incorrect Level %d availability" % [recipe_id, level])
	_expect(data_manager.get_restaurant_menu(35).has("garlic_egg_rice"), "Level 35 menu lost normal recipes or became premium-only")


func _validate_recipe_ui() -> void:
	_expect(vnd_format.format_item_name("wagyu") == "Wagyu Beef", "Recipe UI does not use the imported Wagyu display name")
	_expect(vnd_format.format_item_name("st25_rice") == "ST25 Rice", "Recipe UI does not use the imported ST25 Rice display name")
	var recipe_panel: Node = world.get_node("ui/recipe_panel")
	recipe_panel.call("refresh")
	var label_texts: PackedStringArray = []
	_collect_label_texts(recipe_panel, label_texts)
	_expect(_contains_text(label_texts, "Requires Level 35"), "locked Recipe UI does not show the first premium unlock")
	_expect(_contains_text(label_texts, "Serve:"), "Recipe UI does not label the serve value")
	_expect(_contains_text(label_texts, "Wagyu Beef x1"), "Recipe UI shows a raw imported Wagyu ID")
	_expect(_contains_text(label_texts, "ST25 Rice x1"), "Recipe UI shows a raw imported ST25 Rice ID")


func _reach_level(target_level: int) -> void:
	var required_exp: int = 0
	for level_value: int in range(game_manager.level, target_level):
		required_exp += data_manager.get_level_exp(level_value)
	game_manager.add_exp(required_exp)


func _finish_customer_entry(restaurant: Node, customer: Node) -> void:
	if customer == null:
		return
	customer.set("is_walking_in", false)
	var empty_path: Array[Vector2] = []
	customer.set("walk_path", empty_path)
	restaurant.call("_on_customer_arrived_at_table", String(customer.get("customer_id")))


func _active_job_type(staff: Node) -> String:
	if staff == null:
		return ""
	return String((staff.get("active_job") as Dictionary).get("job_type", ""))


func _ingredients_match(actual: Dictionary, expected: Dictionary) -> bool:
	if actual.size() != expected.size():
		return false
	for item_id_value: Variant in expected:
		var item_id: String = String(item_id_value)
		if not actual.has(item_id) or int(actual[item_id]) != int(expected[item_id_value]):
			return false
	return true


func _collect_label_texts(node: Node, output: PackedStringArray) -> void:
	if node is Label:
		output.append((node as Label).text)
	for child: Node in node.get_children():
		_collect_label_texts(child, output)


func _contains_text(values: PackedStringArray, needle: String) -> bool:
	for value: String in values:
		if value.contains(needle):
			return true
	return false


func _finish_tests() -> void:
	if failures == 0:
		print("premium_recipes_test: PASS")
	else:
		push_error("premium_recipes_test: %d failure(s)" % failures)
	game_manager.stop_gameplay()
	_cleanup_save_files()
	get_tree().quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("premium_recipes_test: %s" % message)


func _cleanup_save_files() -> void:
	var user_directory: DirAccess = DirAccess.open("user://")
	if user_directory == null:
		return
	user_directory.list_dir_begin()
	var file_name: String = user_directory.get_next()
	while not file_name.is_empty():
		if not user_directory.current_is_dir() and file_name.begins_with("savegame"):
			user_directory.remove(file_name)
		file_name = user_directory.get_next()
	user_directory.list_dir_end()

extends RefCounted


static func format(amount: int) -> String:
	var is_negative: bool = amount < 0
	var abs_value: int = absi(amount)
	var digits: String = str(abs_value)
	var result: String = ""
	var count: int = 0
	for i: int in range(digits.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "." + result
		result = digits[i] + result
		count += 1
	if is_negative:
		result = "-" + result
	return result + " ₫"


static func format_vnd(amount: int) -> String:
	return format(amount).replace(" ₫", " VNĐ")


static func format_number(amount: int) -> String:
	return format(amount).trim_suffix(" ₫")


static func format_item_name(item_id: String) -> String:
	var item_value: Variant = data_manager.get_entry("items", item_id)
	if typeof(item_value) == TYPE_DICTIONARY:
		var display_name: String = String((item_value as Dictionary).get("display_name", ""))
		if not display_name.is_empty():
			return display_name
	return item_id.replace("_", " ").capitalize()

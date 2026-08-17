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


static func format_item_name(item_id: String) -> String:
	return item_id.replace("_", " ").capitalize()

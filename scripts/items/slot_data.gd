class_name SlotData
extends Resource

@export var item_data: ItemData
@export var quantity: int = 1:
	set(value):
		quantity = value
		if quantity <= 0:
			item_data = null

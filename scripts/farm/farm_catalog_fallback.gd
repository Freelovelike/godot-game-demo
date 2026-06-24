extends Resource
class_name FarmCatalogFallback

@export var crops: Array = []
@export var fertilizers: Array = []

func to_crop_rows() -> Array:
	var rows: Array = []
	for crop in crops:
		if crop is CropDef:
			rows.append(crop.to_catalog_row())
	return rows

func to_fertilizer_rows() -> Array:
	var rows: Array = []
	for fertilizer in fertilizers:
		if fertilizer is FertilizerDef:
			rows.append(fertilizer.to_catalog_row())
	return rows

extends Resource
class_name MapData

var width: int = 0
var height: int = 0
var tile_size: int = 32
var layers: Dictionary = {}
var modified_at: String = ""

func generate_empty(layer_names: Array):
	for name in layer_names:
		var cells = []
		for y in range(height):
			for x in range(width):
				cells.append({
					"x": x,
					"y": y,
					"source_id": -1,
					"atlas_coords_x": 0,
					"atlas_coords_y": 0,
					"has_collision": false
				})
		layers[name] = cells

func to_dict() -> Dictionary:
	return {
		"width": width,
		"height": height,
		"tile_size": tile_size,
		"modified_at": modified_at,
		"layers": layers
	}

func from_dict(data: Dictionary):
	width = data.get("width", 0)
	height = data.get("height", 0)
	tile_size = data.get("tile_size", 32)
	modified_at = data.get("modified_at", "")
	layers = data.get("layers", {})

extends Node

const MapData = preload("res://src/model/MapData.gd")

func save_map(path: String, map_data: MapData) -> void:
	var data = {
		"width": map_data.width,
		"height": map_data.height,
		"tile_size": map_data.tile_size,
		"modified_at": map_data.modified_at,
		"layers": {}
	}

	for layer_name in map_data.layers.keys():
		data["layers"][layer_name] = []
		for cell in map_data.layers[layer_name]:
			data["layers"][layer_name].append({
				"x": cell.get("x", 0),
				"y": cell.get("y", 0),
				"source_id": cell.get("source_id", -1),
				"atlas_coords_x": cell.get("atlas_coords_x", 0),
				"atlas_coords_y": cell.get("atlas_coords_y", 0),
				"has_collision": cell.get("has_collision", false)
			})

	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		print(" Mapa guardado en:", path)
	else:
		push_error("No se pudo guardar el archivo en: " + path)


func load_map(path: String) -> MapData:
	if not FileAccess.file_exists(path):
		push_error("El archivo no existe: " + path)
		return null

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("No se pudo abrir el archivo: " + path)
		return null

	var content = file.get_as_text()
	file.close()

	var result = JSON.parse_string(content)
	if typeof(result) != TYPE_DICTIONARY:
		push_error(" Error al parsear el JSON del mapa.")
		return null

	var map_data = MapData.new()
	map_data.width = result.get("width", 0)
	map_data.height = result.get("height", 0)
	map_data.tile_size = result.get("tile_size", 32)
	map_data.modified_at = result.get("modified_at", "")
	map_data.layers = result.get("layers", {})

	print(" Mapa cargado desde:", path)
	return map_data

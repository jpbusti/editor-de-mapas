extends Node

const MapData = preload("res://src/model/MapData.gd")
const SaveLoad = preload("res://src/io/SaveLoad.gd")

# Nodos de la interfaz
@onready var menu = $MenuPrincipal
@onready var editor_ui = $EditorUI
@onready var palette = $EditorUI/Palette
@onready var tilemap = $EditorUI/TM_Background
@onready var camera = $Camera2D

# Botones del menú principal
@onready var btn_new = $MenuPrincipal/Button
@onready var btn_load = $MenuPrincipal/Button2
@onready var btn_exit = $MenuPrincipal/Button3

# Botones del editor UI
@onready var btn_save = $EditorUI/Palette/ButtonSave
@onready var btn_toggle_collision = $EditorUI/Palette/ButtonToggleCollision
@onready var lbl_mode = $EditorUI/LabelMode
@onready var btn_undo = $EditorUI/ButtonUndo
@onready var btn_redo = $EditorUI/ButtonRedo
@onready var btn_change_color = $EditorUI/Palette/ButtonChangeColor
@onready var btn_export_png = $EditorUI/Palette/ButtonExportPNG

var use_alt_tiles: bool = false


# Datos del mapa actual
var current_map: MapData
# Información del tile activo
var active_tile_info: Dictionary = {"source": 0, "coords": Vector2i(0, 0)}

# Modos de Edición
enum EditMode {TILES, COLLISIONS}
var editing_mode: int = EditMode.TILES

const TILE_MAPPING = {
	0: {"source": 0, "coords": Vector2i(0, 0)}, # Suelo
	1: {"source": 1, "coords": Vector2i(0, 0)}, # Césped
	2: {"source": 2, "coords": Vector2i(0, 0)}, # Ladrillo
}

const BACKGROUND_LAYER = 0
const COLLISION_VISUAL_LAYER = 1
const COLLISION_VISUAL_SOURCE_ID = 3 
const COLLISION_VISUAL_COORDS = Vector2i(0, 0)

const DEFAULT_SAVE_PATH = "res://mapas/mapa_guardado.json"

# Pilas para Deshacer/Rehacer
var undo_stack: Array = []
var redo_stack: Array = []

# Variables para control de mouse
var is_painting := false
var is_erasing := false
var color_mode := 0  

# --------------------------------------------------
# INICIALIZACIÓN
# --------------------------------------------------
var file_dialog_save: FileDialog
var file_dialog_load: FileDialog
func _ready():
	_setup_main_menu()
	_setup_editor_buttons()
	_setup_palette()
	_update_mode_label()

	# Conectar botones undo/redo
	btn_undo.pressed.connect(_undo)
	btn_redo.pressed.connect(_redo)
	_update_undo_redo_buttons()

	set_process_unhandled_input(true)

	for node in editor_ui.get_children():
		if node is Control:
			if node is Button or node is OptionButton or node is LineEdit or node is SpinBox or node is CheckBox:
				continue
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# --------------------------------------------------
	#  CONFIGURAR DIÁLOGOS DE ARCHIVO 
	# --------------------------------------------------
	file_dialog_save = FileDialog.new()
	file_dialog_load = FileDialog.new()
	add_child(file_dialog_save)
	add_child(file_dialog_load)

	file_dialog_save.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog_save.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog_save.filters = PackedStringArray(["*.json"])
	file_dialog_save.title = "Guardar mapa como JSON"
	file_dialog_save.file_selected.connect(_on_file_save_selected)

	file_dialog_load.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog_load.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog_load.filters = PackedStringArray(["*.json"])
	file_dialog_load.title = "Cargar mapa JSON"
	file_dialog_load.file_selected.connect(_on_file_load_selected)
	


# --------------------------------------------------
# CONFIGURACIÓN DE UI
# --------------------------------------------------
func _setup_main_menu():
	btn_new.text = "Nuevo mapa"
	btn_load.text = "Cargar mapa"
	btn_new.pressed.connect(_on_new_map_pressed)
	btn_load.pressed.connect(_on_load_map_pressed)

func _setup_editor_buttons():

	if is_instance_valid(btn_save):
		btn_save.text = "Guardar Mapa"
		# Evitar conectar dos veces
		if not btn_save.pressed.is_connected(_on_save_map_pressed):
			btn_save.pressed.connect(_on_save_map_pressed)
		print("Botón Guardar conectado:", btn_save.name)
	else:
		print("Error: No se encontró el nodo ButtonSave")
	if is_instance_valid(btn_toggle_collision):
		btn_toggle_collision.text = "Modo Colisión"
		if not btn_toggle_collision.pressed.is_connected(_on_toggle_collision_mode):
			btn_toggle_collision.pressed.connect(_on_toggle_collision_mode)
		print("Botón Colisión conectado:", btn_toggle_collision.name)

	if is_instance_valid(btn_change_color):
		btn_change_color.text = "Change Color"
		btn_change_color.pressed.connect(_on_change_color_pressed)
	if is_instance_valid(btn_export_png):
		btn_export_png.text = "Exportar PNG"
		btn_export_png.pressed.connect(_on_export_png_pressed)





func _setup_palette():
	var btn_suelo = palette.get_node("ButtonSuelo")
	var btn_cesped = palette.get_node("ButtonCesped")
	var btn_ladrillo = palette.get_node("ButtonLadrillo")
	btn_suelo.icon = load("res://assets/tiles/suelo.png")
	btn_cesped.icon = load("res://assets/tiles/cesped.png")
	btn_ladrillo.icon = load("res://assets/tiles/ladrillo.png")
	btn_suelo.pressed.connect(_on_tile_selected.bind(0))
	btn_cesped.pressed.connect(_on_tile_selected.bind(1))
	btn_ladrillo.pressed.connect(_on_tile_selected.bind(2))

# --------------------------------------------------
# FUNCIONES DE ARCHIVO
# --------------------------------------------------
func _on_new_map_pressed():
	menu.visible = false
	editor_ui.visible = true
	current_map = MapData.new()
	current_map.width = 128
	current_map.height = 64
	current_map.tile_size = 64
	current_map.generate_empty(["background"])
	tilemap.clear()
	_update_full_tilemap_from_model()
	print("Nuevo mapa creado")

# Guardar mapa (abrir diálogo)
func _on_save_map_pressed():
	if not current_map:
		return
	file_dialog_save.popup_centered_ratio()



func _on_load_map_pressed():
	file_dialog_load.popup_centered_ratio()

func _on_file_save_selected(path: String):
	if current_map:
		current_map.modified_at = Time.get_datetime_string_from_system()
		var saver = SaveLoad.new()
		saver.save_map(path, current_map)

func _on_file_load_selected(path: String):
	var loader = SaveLoad.new()
	var loaded_map = loader.load_map(path)

	if loaded_map:
		current_map = loaded_map
		menu.visible = false
		editor_ui.visible = true
		_update_full_tilemap_from_model()


# --------------------------------------------------
# LÓGICA DE EDICIÓN
# --------------------------------------------------
func _update_mode_label():
	if is_instance_valid(lbl_mode):
		lbl_mode.text = "MODO: PINTAR TILES" if editing_mode == EditMode.TILES else "MODO: PINTAR COLISIONES"
		lbl_mode.modulate = Color.GREEN if editing_mode == EditMode.TILES else Color.RED

func _on_toggle_collision_mode():
	editing_mode = EditMode.COLLISIONS if editing_mode == EditMode.TILES else EditMode.TILES
	_update_mode_label()
	_update_full_tilemap_from_model()

func _on_tile_selected(palette_id: int):
	editing_mode = EditMode.TILES
	_update_mode_label()
	if TILE_MAPPING.has(palette_id):
		active_tile_info = TILE_MAPPING[palette_id]
		print("Tile activo: Source", active_tile_info.source, ", Coords", active_tile_info.coords)

# --------------------------------------------------
# SISTEMA DESHACER / REHACER
# --------------------------------------------------
func _update_undo_redo_buttons() -> void:
	btn_undo.disabled = undo_stack.is_empty()
	btn_redo.disabled = redo_stack.is_empty()

func _register_action(cell_model_ref: Dictionary, new_source_id: int, new_coords: Vector2i) -> void:
	var old_state = {
		"source_id": cell_model_ref["source_id"],
		"coords_x": cell_model_ref["atlas_coords_x"],
		"coords_y": cell_model_ref["atlas_coords_y"]
	}

	var new_state = {
		"source_id": new_source_id,
		"coords_x": new_coords.x,
		"coords_y": new_coords.y
	}

	if old_state["source_id"] == new_state["source_id"] \
	and old_state["coords_x"] == new_state["coords_x"] \
	and old_state["coords_y"] == new_state["coords_y"]:
		return

	var action = {
		"cell_model": cell_model_ref,
		"from": old_state,
		"to": new_state
	}
	undo_stack.append(action)
	redo_stack.clear()

	_apply_action(cell_model_ref, new_state)
	_update_undo_redo_buttons()

func _apply_action(cell_model_ref: Dictionary, state: Dictionary) -> void:
	cell_model_ref["source_id"] = state["source_id"]
	cell_model_ref["atlas_coords_x"] = state["coords_x"]
	cell_model_ref["atlas_coords_y"] = state["coords_y"]

	_update_single_cell_view(cell_model_ref)

func _undo() -> void:
	if undo_stack.is_empty():
		return
	var last_action = undo_stack.pop_back()
	redo_stack.append(last_action)
	_apply_action(last_action["cell_model"], last_action["from"])
	_update_undo_redo_buttons()

func _redo() -> void:
	if redo_stack.is_empty():
		return
	var last_undone = redo_stack.pop_back()
	undo_stack.append(last_undone)
	_apply_action(last_undone["cell_model"], last_undone["to"])
	_update_undo_redo_buttons()

# --------------------------------------------------
# ACTUALIZACIÓN DEL TILEMAP (VISTA)
# --------------------------------------------------
func _update_single_cell_view(cell_model: Dictionary):
	if cell_model.is_empty():
		return

	if not cell_model.has("x") or not cell_model.has("y"):
		return

	var pos = Vector2i(cell_model["x"], cell_model["y"])

	if cell_model.has("source_id") and cell_model["source_id"] != -1:
		var atlas_coords = Vector2i(
			cell_model.get("atlas_coords_x", 0),
			cell_model.get("atlas_coords_y", 0)
		)
		tilemap.set_cell(BACKGROUND_LAYER, pos, cell_model["source_id"], atlas_coords)
	else:
		tilemap.erase_cell(BACKGROUND_LAYER, pos)

	if editing_mode == EditMode.COLLISIONS and cell_model.has("has_collision") and cell_model["has_collision"]:
		tilemap.set_cell(COLLISION_VISUAL_LAYER, pos, COLLISION_VISUAL_SOURCE_ID, COLLISION_VISUAL_COORDS)


func _update_full_tilemap_from_model():
	tilemap.clear()
	if current_map and current_map.layers.has("background"):
		for cell_data in current_map.layers["background"]:
			_update_single_cell_view(cell_data)

# --------------------------------------------------
# INPUT 
# --------------------------------------------------
func _unhandled_input(event):
	if not (editor_ui.visible and current_map): return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT: is_painting = event.pressed
		if event.button_index == MOUSE_BUTTON_RIGHT: is_erasing = event.pressed
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT] and event.pressed:
			_paint_at_mouse_position(is_painting)
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed: camera.zoom /= 1.1
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed: camera.zoom *= 1.1

	if event is InputEventMouseMotion and (is_painting or is_erasing):
		_paint_at_mouse_position(is_painting)

# Atajos de teclado 
func _input(event):
	if event.is_action_pressed("ui_undo"):
		_undo()
	elif event.is_action_pressed("ui_redo"):
		_redo()

# --------------------------------------------------
# FUNCIÓN DE PINTADO CON UNDO/REDO
# --------------------------------------------------
func _paint_at_mouse_position(painting: bool) -> void:
	if not current_map:
		return

	var global_mouse_pos = camera.get_global_mouse_position()
	var local_mouse_pos = tilemap.to_local(global_mouse_pos)
	var cell = tilemap.local_to_map(local_mouse_pos)

	if cell.x < 0 or cell.y < 0 or cell.x >= current_map.width or cell.y >= current_map.height:
		return

	var index = cell.y * current_map.width + cell.x

	if not current_map.layers.has("background"):
		return
	if index >= current_map.layers["background"].size():
		return

	var cell_model = current_map.layers["background"][index]

	if editing_mode == EditMode.TILES:
		var new_source_id: int
		var new_coords: Vector2i

		if painting:
			new_source_id = active_tile_info["source"]
			new_coords = active_tile_info["coords"]

			# Si estás en modo color alternativo
			if color_mode == 1:
				match new_source_id:
					0: new_source_id = 3  # suelo_alt
					1: new_source_id = 4  # cesped_alt
					2: new_source_id = 5  # ladrillo_alt
		else:
			new_source_id = -1
			new_coords = Vector2i.ZERO

		# Aplica el cambio
		_register_action(cell_model, new_source_id, new_coords)
		tilemap.set_cell(BACKGROUND_LAYER, cell, new_source_id, new_coords)

func _on_change_color_pressed():
	color_mode = 1 - color_mode  
	print(" Change color mode:", color_mode)

	var suffix = "_alt" if color_mode == 1 else ""

	var suelo_path = "res://assets/tiles/suelo%s.png" % suffix
	var cesped_path = "res://assets/tiles/cesped%s.png" % suffix
	var ladrillo_path = "res://assets/tiles/ladrillo%s.png" % suffix

	if not FileAccess.file_exists(suelo_path):
		suelo_path = "res://assets/tiles/suelo.png"
	if not FileAccess.file_exists(cesped_path):
		cesped_path = "res://assets/tiles/cesped.png"
	if not FileAccess.file_exists(ladrillo_path):
		ladrillo_path = "res://assets/tiles/ladrillo.png"

	palette.get_node("ButtonSuelo").icon = load(suelo_path)
	palette.get_node("ButtonCesped").icon = load(cesped_path)
	palette.get_node("ButtonLadrillo").icon = load(ladrillo_path)
	btn_change_color.text = "Color Alt" if color_mode == 1 else "Color Normal"

	

	# Redibujar el mapa con el nuevo color

func _refresh_tile_colors():
	if not current_map:
		return

	for cell_data in current_map.layers["background"]:
		if cell_data["source_id"] == -1:
			continue

		var pos = Vector2i(cell_data["x"], cell_data["y"])
		var atlas_coords = Vector2i(
			cell_data.get("atlas_coords_x", 0),
			cell_data.get("atlas_coords_y", 0)
		)

		var source_id = cell_data["source_id"]

		# ✅ Cambiar al tile alternativo (usa tus IDs reales si difieren)
		if color_mode == 1:
			match source_id:
				0: source_id = 3  # suelo → suelo_alt
				1: source_id = 4  # cesped → cesped_alt
				2: source_id = 5  # ladrillo → ladrillo_alt
		else:
			match source_id:
				3: source_id = 0  # suelo_alt → suelo
				4: source_id = 1  # cesped_alt → cesped
				5: source_id = 2  # ladrillo_alt → ladrillo

		# 🔹 Actualizar el modelo también (esto es lo que faltaba)
		cell_data["source_id"] = source_id
func _on_export_png_pressed():
	if not current_map:
		print("⚠️ No hay mapa cargado para exportar.")
		return

	# Tamaño total de la imagen en píxeles
	var width = current_map.width * current_map.tile_size
	var height = current_map.height * current_map.tile_size

	# Crear una imagen vacía
	var img = Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))  # transparente

	# Crear un viewport temporal
	var viewport = SubViewport.new()
	viewport.size = Vector2(width, height)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)

	# Crear un TileMap temporal para dibujar el mapa
	var temp_tilemap = TileMap.new()
	temp_tilemap.tile_set = tilemap.tile_set
	temp_tilemap.position = Vector2.ZERO
	temp_tilemap.cell_quadrant_size = 32
	temp_tilemap.scale = Vector2.ONE

	# Copiar las celdas del mapa actual
	for cell_data in current_map.layers["background"]:
		if cell_data["source_id"] != -1:
			var pos = Vector2i(cell_data["x"], cell_data["y"])
			var atlas_coords = Vector2i(cell_data.get("atlas_coords_x", 0), cell_data.get("atlas_coords_y", 0))
			temp_tilemap.set_cell(0, pos, cell_data["source_id"], atlas_coords)

	viewport.add_child(temp_tilemap)
	await get_tree().process_frame  # esperar un frame para renderizar

	# Capturar el contenido del viewport como imagen
	var tex = viewport.get_texture()
	var image = tex.get_image()
	image.flip_y()  # invertir verticalmente (por cómo renderiza Godot)

	# Guardar
	var path = "user://map_export.png"
	var err = image.save_png(path)

	# Limpiar
	viewport.queue_free()

	if err == OK:
		print("Mapa exportado exitosamente:", path)
	else:
		print("Error al exportar el mapa.")

extends Node
class_name RackManager

# ============================================================================
# GESTIONNAIRE DU CHEVALET (RACK MANAGER)
# ============================================================================
# Ce module gère :
# - La création et l'affichage du chevalet
# - Le remplissage du chevalet avec les tuiles
# - La gestion de l'état du chevalet
# ============================================================================

# Référence au TileManager
var tile_manager: TileManager

# Données du chevalet
var rack: Array = []
var rack_cells: Array = []
var rack_container: Control

# Taille des tuiles du chevalet
var tile_size_rack: float = 70.0

# Référence à la taille de l'écran
var viewport_size: Vector2

# ============================================================================
# FONCTION : Initialiser le RackManager
# ============================================================================
func initialize(viewport_sz: Vector2, tile_mgr: TileManager) -> void:
	viewport_size = viewport_sz
	tile_manager = tile_mgr

# ============================================================================
# FONCTION : Créer le chevalet
# ============================================================================
func create_rack(parent: Node2D) -> void:
	rack_container = Control.new()
	parent.add_child(rack_container)
	
	var total_rack_pixel_size = Vector2(ScrabbleConfig.RACK_SIZE * (tile_size_rack + 2), tile_size_rack)
	var start_x = (viewport_size.x - total_rack_pixel_size.x) / 2
	rack_container.position = Vector2(start_x, viewport_size.y - tile_size_rack - 40)
	rack_container.pivot_offset = total_rack_pixel_size / 2
	
	# Créer les cellules du chevalet
	for i in range(ScrabbleConfig.RACK_SIZE):
		rack.append(null)
		var cell = _create_rack_cell(i)
		rack_container.add_child(cell)
		rack_cells.append(cell)
	
	print("🎯 Chevalet créé avec ", ScrabbleConfig.RACK_SIZE, " emplacements")

# ============================================================================
# FONCTION PRIVÉE : Créer une cellule du chevalet
# ============================================================================
func _create_rack_cell(index: int) -> Panel:
	var cell = Panel.new()
	cell.custom_minimum_size = Vector2(tile_size_rack, tile_size_rack)
	cell.position = Vector2(index * (tile_size_rack + 2), 0)
	cell.modulate = Color(0.9, 0.9, 0.8)
	return cell

# ============================================================================
# FONCTION : Remplir le chevalet
# ============================================================================
func fill_rack() -> void:
	for i in range(ScrabbleConfig.RACK_SIZE):
		if rack[i] == null:
			var tile_data = tile_manager.draw_tile()
			if tile_data:
				rack[i] = tile_data
				tile_manager.create_tile_visual(tile_data, rack_cells[i], tile_size_rack)

# ============================================================================
# FONCTION : Vider le chevalet (retirer toutes les tuiles visuelles)
# ============================================================================
func clear_rack() -> void:
	for i in range(ScrabbleConfig.RACK_SIZE):
		if rack[i] != null:
			var cell = rack_cells[i]
			var tile_node = TileManager.get_tile_in_cell(cell)
			if tile_node:
				tile_node.queue_free()
			rack[i] = null

# ============================================================================
# FONCTION : Obtenir une tuile du chevalet à un index donné
# ============================================================================
func get_tile_at(index: int) -> Variant:
	if index >= 0 and index < rack.size():
		return rack[index]
	return null

# ============================================================================
# FONCTION : Retirer une tuile du chevalet
# ============================================================================
func remove_tile_at(index: int) -> Variant:
	if index >= 0 and index < rack.size():
		var tile = rack[index]
		rack[index] = null
		return tile
	return null

# ============================================================================
# FONCTION : Ajouter une tuile au chevalet
# ============================================================================
func add_tile_at(index: int, tile_data: Dictionary) -> bool:
	if index >= 0 and index < rack.size() and rack[index] == null:
		rack[index] = tile_data
		return true
	return false

# ============================================================================
# FONCTION : Obtenir la cellule du chevalet à un index donné
# ============================================================================
func get_cell_at(index: int) -> Panel:
	if index >= 0 and index < rack_cells.size():
		return rack_cells[index]
	return null

# ============================================================================
# FONCTION : Vérifier si une position est dans le chevalet
# ============================================================================
func is_position_in_rack(global_pos: Vector2) -> int:
	for i in range(ScrabbleConfig.RACK_SIZE):
		var cell = rack_cells[i]
		var cell_rect = Rect2(cell.global_position, cell.size * rack_container.scale)
		if cell_rect.has_point(global_pos):
			return i
	return -1

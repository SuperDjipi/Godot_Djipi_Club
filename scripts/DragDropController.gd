extends Node
class_name DragDropController

# ============================================================================
# CONTRÔLEUR DE DRAG & DROP
# ============================================================================
# Ce module gère :
# - Le drag & drop des tuiles
# - Les animations de resize pendant le drag
# - La détection des zones de dépôt
# - La gestion des tuiles temporaires
# ============================================================================

# Références aux managers
var board_manager: BoardManager
var rack_manager: RackManager
var tile_manager: TileManager

# État du drag
var dragging_tile: Panel = null
var drag_origin: Dictionary = {}
var temp_tiles: Array = []

# Position actuelle de la souris (pour auto-scroll)
var current_mouse_pos: Vector2 = Vector2.ZERO

# ============================================================================
# FONCTION : Initialiser le contrôleur
# ============================================================================
func initialize(board_mgr: BoardManager, rack_mgr: RackManager, tile_mgr: TileManager) -> void:
	board_manager = board_mgr
	rack_manager = rack_mgr
	tile_manager = tile_mgr

# ============================================================================
# FONCTION : Boucle de mise à jour (appelée à chaque frame)
# ============================================================================
# Cette fonction s'exécute environ 60 fois par seconde et permet :
# - L'auto-scroll continu et fluide pendant le drag
# - Pas besoin de bouger la souris, juste maintenir la tuile près du bord
# ============================================================================
func _process(_delta):
	# Auto-scroll continu quand on drag une tuile
	if dragging_tile and board_manager.is_board_focused:
		board_manager.auto_scroll_board(current_mouse_pos)

# ============================================================================
# FONCTION : Démarrer un drag
# ============================================================================
func start_drag(pos: Vector2, parent: Node2D) -> void:
	print("=== Start drag at position:", pos)
	
	# 1. Vérifier le chevalet
	var rack_index = rack_manager.is_position_in_rack(pos)
	if rack_index >= 0:
		var tile_data = rack_manager.get_tile_at(rack_index)
		if tile_data:
			var cell = rack_manager.get_cell_at(rack_index)
			var tile_node = TileManager.get_tile_in_cell(cell)
			if tile_node:
				print("  -> Found tile in rack at index", rack_index)
				_start_drag_from_rack(tile_node, rack_index, parent)
				return
	
	# 2. Vérifier le plateau
	var board_pos = board_manager.get_board_position_at(pos)
	if board_pos != null:
		var tile_data = board_manager.get_tile_at(board_pos)
		if tile_data:
			var cell = board_manager.get_cell_at(board_pos)
			var tile_node = TileManager.get_tile_in_cell(cell)
			if tile_node and tile_node.has_meta("temp"):
				print("  -> Found temp tile on board at", board_pos)
				_start_drag_from_board(tile_node, board_pos, parent)
				return
	
	# 3. Si rien n'est trouvé, essayer de drag le plateau
	if board_manager.start_board_drag(pos):
		print("  -> Starting board drag")
	else:
		print("  -> No tile found at this position")

# ============================================================================
# FONCTION PRIVÉE : Démarrer le drag depuis le chevalet
# ============================================================================
func _start_drag_from_rack(tile_node: Panel, index: int, parent: Node2D) -> void:
	dragging_tile = tile_node
	drag_origin = {"type": "rack", "pos": index}
	rack_manager.remove_tile_at(index)
	
	# Animer vers la vue plateau si nécessaire
	if not board_manager.is_board_focused:
		board_manager.animate_to_board_view()
	
	# Redimensionner la tuile
	var tile_tween = tile_node.create_tween()
	var target_size = Vector2(board_manager.tile_size_board - 4, board_manager.tile_size_board - 4)
	tile_tween.tween_property(tile_node, "custom_minimum_size", target_size, 0.2)
	
	# Repositionner les labels
	var letter_lbl = tile_node.get_node_or_null("LetterLabel")
	var value_lbl = tile_node.get_node_or_null("ValueLabel")
	if letter_lbl and value_lbl:
		tile_tween.tween_property(letter_lbl, "position", Vector2(board_manager.tile_size_board * 0.2, board_manager.tile_size_board * 0.05), 0.2)
		tile_tween.tween_property(value_lbl, "position", Vector2(board_manager.tile_size_board * 0.6, board_manager.tile_size_board * 0.55), 0.2)
	
	tile_node.reparent(parent)
	tile_node.z_index = 100

# ============================================================================
# FONCTION PRIVÉE : Démarrer le drag depuis le plateau
# ============================================================================
func _start_drag_from_board(tile_node: Panel, pos: Vector2i, parent: Node2D) -> void:
	dragging_tile = tile_node
	drag_origin = {"type": "board", "pos": pos}
	board_manager.set_tile_at(pos, null)
	temp_tiles.erase(pos)
	
	tile_node.reparent(parent)
	tile_node.z_index = 100

# ============================================================================
# FONCTION : Mettre à jour le drag
# ============================================================================
func update_drag(pos: Vector2) -> void:
	current_mouse_pos = pos
	
	if dragging_tile:
		var target_size = Vector2(board_manager.tile_size_board, board_manager.tile_size_board)
		dragging_tile.global_position = pos - target_size / 2
		
		# Auto-scroll si on est en mode plateau
		if board_manager.is_board_focused:
			board_manager.auto_scroll_board(pos)
	
	# Mise à jour du drag du plateau
	board_manager.update_board_drag(pos)

# ============================================================================
# FONCTION : Terminer le drag
# ============================================================================
func end_drag(pos: Vector2, parent: Node2D) -> void:
	# Terminer le drag du plateau
	if board_manager.is_dragging_board:
		board_manager.end_board_drag()
		print("  -> Board drag ended")
		return
	
	if not dragging_tile:
		return
	
	print("=== End drag at position:", pos)
	var dropped = false
	
	# 1. Essayer de déposer sur le chevalet
	dropped = _try_drop_on_rack(pos)
	
	# 2. Si pas déposé, essayer le plateau
	if not dropped:
		dropped = _try_drop_on_board(pos)
	
	# 3. Si toujours pas déposé, retourner à l'origine
	if not dropped:
		_return_to_origin()
	
	# Nettoyer l'état du drag
	dragging_tile = null
	drag_origin = {}
	
	# Revenir à la vue chevalet si plus de tuiles temporaires
	if temp_tiles.is_empty():
		board_manager.animate_to_rack_view()

# ============================================================================
# FONCTION PRIVÉE : Essayer de déposer sur le chevalet
# ============================================================================
func _try_drop_on_rack(pos: Vector2) -> bool:
	var rack_index = rack_manager.is_position_in_rack(pos)
	if rack_index >= 0 and rack_manager.get_tile_at(rack_index) == null:
		print("  -> Dropping on rack at index", rack_index)
		
		var tile_data = dragging_tile.get_meta("tile_data")
		rack_manager.add_tile_at(rack_index, tile_data)
		
		# Redimensionner la tuile pour le chevalet
		var tween = dragging_tile.create_tween()
		var target_size = Vector2(rack_manager.tile_size_rack - 4, rack_manager.tile_size_rack - 4)
		tween.tween_property(dragging_tile, "custom_minimum_size", target_size, 0.2)
		
		# Repositionner les labels
		var letter_lbl = dragging_tile.get_node_or_null("LetterLabel")
		var value_lbl = dragging_tile.get_node_or_null("ValueLabel")
		if letter_lbl and value_lbl:
			tween.tween_property(letter_lbl, "position", Vector2(rack_manager.tile_size_rack * 0.2, rack_manager.tile_size_rack * 0.05), 0.2)
			tween.tween_property(value_lbl, "position", Vector2(rack_manager.tile_size_rack * 0.6, rack_manager.tile_size_rack * 0.55), 0.2)
		
		var cell = rack_manager.get_cell_at(rack_index)
		dragging_tile.reparent(cell)
		dragging_tile.position = Vector2(2, 2)
		dragging_tile.z_index = 0
		dragging_tile.remove_meta("temp")
		return true
	
	return false

# ============================================================================
# FONCTION PRIVÉE : Essayer de déposer sur le plateau
# ============================================================================
func _try_drop_on_board(pos: Vector2) -> bool:
	var board_pos = board_manager.get_board_position_at(pos)
	if board_pos != null and board_manager.get_tile_at(board_pos) == null:
		print("  -> Dropping on board at", board_pos)
		
		var tile_data = dragging_tile.get_meta("tile_data")
		board_manager.set_tile_at(board_pos, tile_data)
		
		var cell = board_manager.get_cell_at(board_pos)
		dragging_tile.reparent(cell)
		dragging_tile.position = Vector2(2, 2)
		dragging_tile.z_index = 0
		dragging_tile.set_meta("temp", true)
		
		if not temp_tiles.has(board_pos):
			temp_tiles.append(board_pos)
		
		return true
	
	return false

# ============================================================================
# FONCTION PRIVÉE : Retourner à l'origine
# ============================================================================
func _return_to_origin() -> void:
	print("  -> Returning to origin")
	
	if drag_origin.type == "rack":
		var index = drag_origin.pos
		var tile_data = dragging_tile.get_meta("tile_data")
		rack_manager.add_tile_at(index, tile_data)
		
		# Redimensionner
		var tween = dragging_tile.create_tween()
		var target_size = Vector2(rack_manager.tile_size_rack - 4, rack_manager.tile_size_rack - 4)
		tween.tween_property(dragging_tile, "custom_minimum_size", target_size, 0.2)
		
		# Repositionner les labels
		var letter_lbl = dragging_tile.get_node_or_null("LetterLabel")
		var value_lbl = dragging_tile.get_node_or_null("ValueLabel")
		if letter_lbl and value_lbl:
			tween.tween_property(letter_lbl, "position", Vector2(rack_manager.tile_size_rack * 0.2, rack_manager.tile_size_rack * 0.05), 0.2)
			tween.tween_property(value_lbl, "position", Vector2(rack_manager.tile_size_rack * 0.6, rack_manager.tile_size_rack * 0.55), 0.2)
		
		var cell = rack_manager.get_cell_at(index)
		dragging_tile.reparent(cell)
		dragging_tile.position = Vector2(2, 2)
		dragging_tile.z_index = 0
		dragging_tile.remove_meta("temp")
	
	elif drag_origin.type == "board":
		var pos_vec = drag_origin.pos
		var tile_data = dragging_tile.get_meta("tile_data")
		board_manager.set_tile_at(pos_vec, tile_data)
		
		var cell = board_manager.get_cell_at(pos_vec)
		dragging_tile.reparent(cell)
		dragging_tile.position = Vector2(2, 2)
		dragging_tile.z_index = 0
		dragging_tile.set_meta("temp", true)
		
		if not temp_tiles.has(pos_vec):
			temp_tiles.append(pos_vec)

# ============================================================================
# FONCTION : Obtenir les tuiles temporaires
# ============================================================================
func get_temp_tiles() -> Array:
	return temp_tiles

# ============================================================================
# FONCTION : Vérifier si on est en train de dragger
# ============================================================================
func is_dragging() -> bool:
	return dragging_tile != null or board_manager.is_dragging_board

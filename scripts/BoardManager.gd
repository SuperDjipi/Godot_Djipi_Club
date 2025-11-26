extends Node
class_name BoardManager

# ============================================================================
# GESTIONNAIRE DU PLATEAU (BOARD MANAGER)
# ============================================================================
# Ce module gère :
# - La création et l'affichage du plateau de jeu
# - Les animations de zoom/déplacement
# - L'auto-scroll pendant le drag
# - La gestion des cases bonus
#
# LOGIQUE UNFOCUSED / FOCUSED :
# ------------------------------
# Le plateau a deux modes d'affichage :
# 
# 1. MODE UNFOCUSED (vue d'ensemble) :
#    - Le plateau est réduit pour tenir dans l'écran
#    - Échelle calculée dynamiquement : board_scale_unfocused
#    - Permet de voir tout le plateau d'un coup
#
# 2. MODE FOCUSED (placement de tuiles) :
#    - Le plateau est agrandi (scale = 1.0)
#    - Les tuiles du plateau ont LA MÊME TAILLE que celles du chevalet
#    - Ceci facilite le drag & drop visuel
#    - L'utilisateur peut scroller horizontalement
#
# CALCUL DES TAILLES :
# --------------------
# tile_size_board = tile_size_rack (en mode focused)
# board_scale_unfocused = board_width / (BOARD_SIZE * (tile_size_board + 2))
# ============================================================================

# Données du plateau
var board: Array = []
var board_cells: Array = []
var board_container: Control
var bonus_map: Dictionary = {}

# Taille des tuiles
var tile_size_board: float = 40.0  # Sera calculée en fonction du chevalet
var tile_size_rack: float = 70.0   # Référence depuis le rack

# État du focus
var is_board_focused: bool = false
var board_scale_focused: float = 1.0  # Toujours 1.0 en mode focused
var board_scale_unfocused: float = 0.7  # Sera recalculé dynamiquement

# Variables pour le déplacement du plateau
var is_dragging_board: bool = false
var board_drag_start_pos: Vector2 = Vector2.ZERO
var board_initial_pos: Vector2 = Vector2.ZERO
var board_min_x: float = 0.0
var board_max_x: float = 0.0

# Référence à la taille de l'écran
var viewport_size: Vector2

# ============================================================================
# FONCTION : Initialiser le BoardManager
# ============================================================================
func initialize(viewport_sz: Vector2, rack_tile_size: float) -> void:
	viewport_size = viewport_sz
	bonus_map = ScrabbleConfig.create_bonus_map()
	
	# CALCUL DU PLATEAU UNFOCUSED
	# On veut que le plateau remplisse l'écran en mode unfocused
	var board_width = viewport_size.x - ScrabbleConfig.BOARD_PADDING
	var tile_size_calculated = floor(board_width / (ScrabbleConfig.BOARD_SIZE + 0.5))
	
	# CALCUL DU PLATEAU FOCUSED
	# En mode focused, les tuiles du plateau ont la même taille que celles du chevalet
	tile_size_rack = rack_tile_size
	tile_size_board = tile_size_rack  # Important : même taille que le chevalet !
	
	print("📐 Calculs de taille :")
	print("   - tile_size_calculated (unfocused) : ", tile_size_calculated)
	print("   - tile_size_board (focused) : ", tile_size_board)
	print("   - tile_size_rack : ", tile_size_rack)

# ============================================================================
# FONCTION : Créer le plateau
# ============================================================================
func create_board(parent: Node2D) -> void:
	board_container = Control.new()
	parent.add_child(board_container)
	
	var total_board_pixel_size = ScrabbleConfig.BOARD_SIZE * (tile_size_board + 2)
	var start_x = (viewport_size.x - total_board_pixel_size) / 2
	board_container.position = Vector2(start_x, 80)
	board_container.pivot_offset = Vector2(total_board_pixel_size / 2, total_board_pixel_size / 2)
	
	# Créer les cellules du plateau
	for y in range(ScrabbleConfig.BOARD_SIZE):
		board.append([])
		board_cells.append([])
		for x in range(ScrabbleConfig.BOARD_SIZE):
			board[y].append(null)
			var cell = _create_board_cell(Vector2i(x, y))
			board_container.add_child(cell)
			board_cells[y].append(cell)
	
	# CALCUL DE L'ÉCHELLE UNFOCUSED
	# Le plateau en mode unfocused doit tenir dans l'écran
	var board_width = viewport_size.x - ScrabbleConfig.BOARD_PADDING
	board_scale_unfocused = board_width / total_board_pixel_size
	board_container.scale = Vector2(board_scale_unfocused, board_scale_unfocused)
	
	print("📊 Échelles calculées :")
	print("   - board_scale_unfocused : ", board_scale_unfocused)
	print("   - board_scale_focused : ", board_scale_focused)
	
	# Calculer les limites de déplacement
	calculate_board_limits()
	
	print("🎲 Plateau créé : ", ScrabbleConfig.BOARD_SIZE, "x", ScrabbleConfig.BOARD_SIZE)

# ============================================================================
# FONCTION PRIVÉE : Créer une cellule du plateau
# ============================================================================
func _create_board_cell(pos: Vector2i) -> Panel:
	var cell = Panel.new()
	cell.custom_minimum_size = Vector2(tile_size_board, tile_size_board)
	cell.position = Vector2(pos.x * (tile_size_board + 2), pos.y * (tile_size_board + 2))
	
	# Appliquer la couleur du bonus
	var bonus = bonus_map.get(pos, "")
	cell.modulate = ScrabbleConfig.get_bonus_color(bonus)
	
	# Ajouter un label pour les bonus (sauf CENTER)
	if bonus and bonus != "CENTER":
		var lbl = Label.new()
		lbl.text = bonus
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.position = Vector2(5, 10)
		cell.add_child(lbl)
	
	return cell

# ============================================================================
# FONCTION : Calculer les limites de déplacement du plateau
# ============================================================================
func calculate_board_limits() -> void:
	var total_board_pixel_size = ScrabbleConfig.BOARD_SIZE * (tile_size_board + 2)
	board_max_x = viewport_size.x / 2
	board_min_x = viewport_size.x / 2 - total_board_pixel_size
	print("📏 Limites du plateau: min_x=", board_min_x, " max_x=", board_max_x)

# ============================================================================
# FONCTION : Animer vers la vue "plateau"
# ============================================================================
func animate_to_board_view() -> void:
	if is_board_focused:
		return
	is_board_focused = true
	
	print("🔍 Animation -> Vue Plateau")
	var tween = board_container.create_tween()
	tween.set_parallel(true)
	tween.tween_property(board_container, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_SINE)

# ============================================================================
# FONCTION : Animer vers la vue "chevalet"
# ============================================================================
func animate_to_rack_view() -> void:
	if not is_board_focused:
		return
	is_board_focused = false
	
	print("🎯 Animation -> Vue Chevalet")
	var tween = board_container.create_tween()
	tween.set_parallel(true)
	tween.tween_property(board_container, "scale", Vector2(board_scale_unfocused, board_scale_unfocused), 0.3).set_trans(Tween.TRANS_SINE)
	
	# Recentrer le plateau
	var total_board_pixel_size = ScrabbleConfig.BOARD_SIZE * (tile_size_board + 2)
	var start_x = (viewport_size.x - total_board_pixel_size) / 2
	tween.tween_property(board_container, "position:x", start_x, 0.3).set_trans(Tween.TRANS_SINE)

# ============================================================================
# FONCTION : Auto-scroll du plateau
# ============================================================================
func auto_scroll_board(mouse_pos: Vector2) -> void:
	var scroll_delta = 0.0
	
	# Vérifier le bord gauche
	if mouse_pos.x < ScrabbleConfig.AUTO_SCROLL_MARGIN:
		var intensity = 1.0 - (mouse_pos.x / ScrabbleConfig.AUTO_SCROLL_MARGIN)
		scroll_delta = ScrabbleConfig.AUTO_SCROLL_SPEED * intensity
	
	# Vérifier le bord droit
	elif mouse_pos.x > viewport_size.x - ScrabbleConfig.AUTO_SCROLL_MARGIN:
		var distance_from_right = viewport_size.x - mouse_pos.x
		var intensity = 1.0 - (distance_from_right / ScrabbleConfig.AUTO_SCROLL_MARGIN)
		scroll_delta = -ScrabbleConfig.AUTO_SCROLL_SPEED * intensity
	
	# Appliquer le défilement
	if scroll_delta != 0.0:
		var new_x = board_container.position.x + scroll_delta
		new_x = clamp(new_x, board_min_x, board_max_x)
		board_container.position.x = new_x

# ============================================================================
# FONCTION : Démarrer le drag du plateau
# ============================================================================
func start_board_drag(pos: Vector2) -> bool:
	if not is_board_focused:
		return false
	
	var board_rect = Rect2(
		board_container.global_position,
		Vector2(ScrabbleConfig.BOARD_SIZE * (tile_size_board + 2), 
				ScrabbleConfig.BOARD_SIZE * (tile_size_board + 2)) * board_container.scale
	)
	
	if board_rect.has_point(pos):
		is_dragging_board = true
		board_drag_start_pos = pos
		board_initial_pos = board_container.position
		return true
	
	return false

# ============================================================================
# FONCTION : Mettre à jour le drag du plateau
# ============================================================================
func update_board_drag(pos: Vector2) -> void:
	if is_dragging_board:
		var delta = pos - board_drag_start_pos
		var new_x = board_initial_pos.x + delta.x
		new_x = clamp(new_x, board_min_x, board_max_x)
		board_container.position.x = new_x

# ============================================================================
# FONCTION : Terminer le drag du plateau
# ============================================================================
func end_board_drag() -> void:
	is_dragging_board = false

# ============================================================================
# FONCTION : Vérifier si une position est sur le plateau
# ============================================================================
func get_board_position_at(global_pos: Vector2) -> Variant:
	for y in range(ScrabbleConfig.BOARD_SIZE):
		for x in range(ScrabbleConfig.BOARD_SIZE):
			var cell = board_cells[y][x]
			var cell_rect = Rect2(cell.global_position, cell.size * board_container.scale)
			if cell_rect.has_point(global_pos):
				return Vector2i(x, y)
	return null

# ============================================================================
# FONCTION : Obtenir une tuile du plateau
# ============================================================================
func get_tile_at(pos: Vector2i) -> Variant:
	if pos.y >= 0 and pos.y < board.size() and pos.x >= 0 and pos.x < board[pos.y].size():
		return board[pos.y][pos.x]
	return null

# ============================================================================
# FONCTION : Placer une tuile sur le plateau
# ============================================================================
func set_tile_at(pos: Vector2i, tile_data: Variant) -> void:
	if pos.y >= 0 and pos.y < board.size() and pos.x >= 0 and pos.x < board[pos.y].size():
		board[pos.y][pos.x] = tile_data

# ============================================================================
# FONCTION : Obtenir la cellule du plateau
# ============================================================================
func get_cell_at(pos: Vector2i) -> Panel:
	if pos.y >= 0 and pos.y < board_cells.size() and pos.x >= 0 and pos.x < board_cells[pos.y].size():
		return board_cells[pos.y][pos.x]
	return null

extends Node
class_name MoveValidator

# ============================================================================
# VALIDATEUR DE MOUVEMENT (MOVE VALIDATOR)
# ============================================================================
# Ce module gère :
# - La validation des mouvements du joueur avant envoi au serveur
# - Le calcul du score prévisionnel
# - La vérification des règles du Scrabble
# ============================================================================

var board_manager: BoardManager

# ============================================================================
# FONCTION : Initialiser le validateur
# ============================================================================
func initialize(board_mgr: BoardManager) -> void:
	board_manager = board_mgr

# ============================================================================
# FONCTION : Valider un mouvement
# ============================================================================
# Retourne un dictionnaire avec :
# - valid: bool (le mouvement est-il valide ?)
# - score: int (score calculé)
# - errors: Array[String] (liste des erreurs)
# ============================================================================
func validate_move(temp_tiles: Array) -> Dictionary:
	var result = {
		"valid": false,
		"score": 0,
		"errors": [],
		"words": []
	}
	
	if temp_tiles.is_empty():
		result.errors.append("Aucune tuile placée")
		return result
	
	# 1. Vérifier que les tuiles sont alignées
	if not _are_tiles_aligned(temp_tiles):
		result.errors.append("Les tuiles doivent être alignées (ligne ou colonne)")
		return result
	
	# 2. Vérifier la continuité
	if not _are_tiles_continuous(temp_tiles):
		result.errors.append("Les tuiles doivent être continues (pas de trous)")
		return result
	
	# 3. Vérifier la connexion au plateau existant (sauf premier coup)
	if not _is_connected_to_board(temp_tiles):
		result.errors.append("Les tuiles doivent être connectées aux tuiles existantes")
		return result
	
	# 4. Calculer le score
	var score_data = _calculate_score(temp_tiles)
	result.score = score_data.score
	result.words = score_data.words
	
	# Si on arrive ici, le mouvement est valide
	result.valid = true
	
	return result

# ============================================================================
# FONCTION PRIVÉE : Vérifier l'alignement des tuiles
# ============================================================================
func _are_tiles_aligned(temp_tiles: Array) -> bool:
	if temp_tiles.size() <= 1:
		return true
	
	var first_pos = temp_tiles[0]
	var all_same_row = true
	var all_same_col = true
	
	for i in range(1, temp_tiles.size()):
		var pos = temp_tiles[i]
		if pos.y != first_pos.y:
			all_same_row = false
		if pos.x != first_pos.x:
			all_same_col = false
	
	return all_same_row or all_same_col

# ============================================================================
# FONCTION PRIVÉE : Vérifier la continuité des tuiles
# ============================================================================
func _are_tiles_continuous(temp_tiles: Array) -> bool:
	if temp_tiles.size() <= 1:
		return true
	
	# Trier les positions
	var sorted_tiles = temp_tiles.duplicate()
	var first_pos = sorted_tiles[0]
	
	# Déterminer la direction (horizontal ou vertical)
	var is_horizontal = true
	for pos in sorted_tiles:
		if pos.y != first_pos.y:
			is_horizontal = false
			break
	
	# Trier selon la direction
	if is_horizontal:
		sorted_tiles.sort_custom(func(a, b): return a.x < b.x)
	else:
		sorted_tiles.sort_custom(func(a, b): return a.y < b.y)
	
	# Vérifier la continuité (en incluant les tuiles déjà sur le plateau)
	for i in range(sorted_tiles.size() - 1):
		var current = sorted_tiles[i]
		var next = sorted_tiles[i + 1]
		
		if is_horizontal:
			var expected_x = current.x + 1
			# Vérifier s'il y a des tuiles entre current et next
			var has_gap = true
			for x in range(current.x + 1, next.x):
				if board_manager.get_tile_at(Vector2i(x, current.y)) != null:
					has_gap = false
					break
			
			if next.x > expected_x and has_gap:
				return false
		else:
			var expected_y = current.y + 1
			var has_gap = true
			for y in range(current.y + 1, next.y):
				if board_manager.get_tile_at(Vector2i(current.x, y)) != null:
					has_gap = false
					break
			
			if next.y > expected_y and has_gap:
				return false
	
	return true

# ============================================================================
# FONCTION PRIVÉE : Vérifier la connexion au plateau
# ============================================================================
func _is_connected_to_board(temp_tiles: Array) -> bool:
	# Si c'est le premier coup, vérifier que la case centrale est utilisée
	var board_is_empty = true
	for y in range(ScrabbleConfig.BOARD_SIZE):
		for x in range(ScrabbleConfig.BOARD_SIZE):
			var tile = board_manager.get_tile_at(Vector2i(x, y))
			if tile != null:
				var cell = board_manager.get_cell_at(Vector2i(x, y))
				var tile_node = TileManager.get_tile_in_cell(cell)
				if tile_node and not tile_node.has_meta("temp"):
					board_is_empty = false
					break
		if not board_is_empty:
			break
	
	if board_is_empty:
		# Premier coup : doit inclure la case centrale (7, 7)
		for pos in temp_tiles:
			if pos.x == 7 and pos.y == 7:
				return true
		return false
	
	# Sinon, vérifier qu'au moins une tuile touche une tuile existante
	for pos in temp_tiles:
		# Vérifier les 4 directions
		var neighbors = [
			Vector2i(pos.x - 1, pos.y),
			Vector2i(pos.x + 1, pos.y),
			Vector2i(pos.x, pos.y - 1),
			Vector2i(pos.x, pos.y + 1)
		]
		
		for neighbor_pos in neighbors:
			var tile = board_manager.get_tile_at(neighbor_pos)
			if tile != null:
				var cell = board_manager.get_cell_at(neighbor_pos)
				var tile_node = TileManager.get_tile_in_cell(cell)
				if tile_node and not tile_node.has_meta("temp"):
					return true
	
	return false

# ============================================================================
# FONCTION PRIVÉE : Calculer le score
# ============================================================================
func _calculate_score(temp_tiles: Array) -> Dictionary:
	var result = {
		"score": 0,
		"words": []
	}
	
	# Pour l'instant, calcul simplifié
	# TODO: Implémenter le calcul complet avec les multiplicateurs
	
	var base_score = 0
	for pos in temp_tiles:
		var tile_data = board_manager.get_tile_at(pos)
		if tile_data:
			base_score += tile_data.value
	
	# Bonus si on utilise toutes ses tuiles (50 points)
	if temp_tiles.size() == ScrabbleConfig.RACK_SIZE:
		base_score += 50
	
	result.score = base_score
	result.words = ["MOT_TEMPORAIRE"]  # TODO: Extraire les vrais mots
	
	return result

# ============================================================================
# FONCTION : Obtenir un message de validation formaté
# ============================================================================
func get_validation_message(validation_result: Dictionary) -> String:
	if validation_result.valid:
		return "✅ Mouvement valide ! Score : %d points" % validation_result.score
	else:
		var errors = "\n".join(validation_result.errors)
		return "❌ Mouvement invalide :\n%s" % errors

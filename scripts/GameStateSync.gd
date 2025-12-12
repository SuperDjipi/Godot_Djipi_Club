# game_state_sync.gd
# ============================================================================
# SYNCHRONISEUR D'ÉTAT DE JEU - VERSION COMPLÈTE
# ============================================================================
# Améliorations :
# - Gestion de l'état initial stocké dans NetworkManager
# - Variable game_has_started pour détecter la reprise de partie
# - Gestion améliorée du premier tour
# - 🆕 Sauvegarde et restauration de l'ordre du chevalet
# - 🆕 Nettoyage des race conditions
# - Animation des tuiles nouvellement posées
# - Échange de lettres
# - Compteur de tuiles dans le sac
# ============================================================================

extends Node
class_name GameStateSync

# Références
var network_manager: Node
var scrabble_game: Node2D
var board_manager: BoardManager
var rack_manager: RackManager
var drag_drop_controller: DragDropController

# État local
var current_game_state: Dictionary = {}
var my_player_id: String = ""
var is_my_turn: bool = false
var game_has_started: bool = false  # Pour détecter la reprise

# 🆕 Sauvegarde de l'ordre du chevalet
var saved_rack_order: Array = []  # Array de tile IDs dans l'ordre

# Signaux
signal my_turn_started()
signal my_turn_ended()
signal game_started()
signal game_ended(winner: String)

# ============================================================================
# INITIALISATION
# ============================================================================

func initialize(
	net_mgr: Node,
	game: Node2D,
	board_mgr: BoardManager,
	rack_mgr: RackManager,
	drag_ctrl: DragDropController
) -> void:
	network_manager = net_mgr
	scrabble_game = game
	board_manager = board_mgr
	rack_manager = rack_mgr
	drag_drop_controller = drag_ctrl
	
	# Connexion aux signaux du NetworkManager
	network_manager.game_state_received.connect(_on_game_state_received)
	network_manager.error_received.connect(_on_error_received)
	
	# Récupérer l'ID du joueur
	my_player_id = network_manager.player_id
	
	# Récupérer l'état initial si disponible
	var last_state = network_manager.get_last_game_state()
	
	if not last_state.is_empty():
		call_deferred("_on_game_state_received", last_state)
		network_manager.clear_last_game_state()
	else:
		print("État vide")
	
	print("🔄 GameStateSync initialisé pour le joueur : ", my_player_id)

# ============================================================================
# RÉCEPTION DE L'ÉTAT DU JEU DEPUIS LE SERVEUR
# ============================================================================

func _on_game_state_received(payload: Dictionary) -> void:
	"""
	Appelé quand le serveur envoie une mise à jour de l'état du jeu
	
	Format attendu :
	{
		"gameState": {
			"id": "ABCD",
			"board": [...],
			"players": [...],
			"status": "PLAYING",
			"tileBag": {"tileCount": X},
			"currentPlayerIndex": 0,
			"turnNumber": 1,
			"placedPositions": [...]
		},
		"playerRack": [
			{"id": "tile-1", "letter": "A", "points": 1, ...},
			...
		]
	}
	"""
	
	print("📥 Réception de l'état du jeu")
	
	# 🆕 Sauvegarder l'ordre actuel du chevalet AVANT toute modification
	_save_rack_order()
	
	# 🆕 Nettoyer l'état temporaire AVANT mise à jour
	_cleanup_temporary_state()
	
	current_game_state = payload.get("gameState", {})
	var player_rack = payload.get("playerRack", [])
	var status = current_game_state.get("status", "")
	
	# 1. Vérifier si la partie est en cours (avec game_has_started)
	if status == "PLAYING" and not game_has_started:
		print("🎮 La partie est en cours !")
		game_has_started = true
		game_started.emit()
	
	# 2. Mettre à jour le plateau (avec animation des nouvelles tuiles)
	_update_board(current_game_state.get("board", []), current_game_state.get("placedPositions", []))
	
	# 3. Mettre à jour le chevalet du joueur (avec restauration de l'ordre)
	_update_rack(player_rack)
	
	# 4. Vérifier si c'est notre tour (IMPORTANT pour la reprise)
	_check_if_my_turn()
	
	# 5. Vérifier si la partie est terminée
	if status == "FINISHED":
		_handle_game_end()

# ============================================================================
# NETTOYAGE DE L'ÉTAT TEMPORAIRE (RACE CONDITION FIX)
# ============================================================================

func _cleanup_temporary_state() -> void:
	"""
	🆕 Nettoie toutes les tuiles temporaires et réinitialise l'interface
	AVANT de recevoir le nouvel état du serveur
	
	Cela résout les race conditions entre update_board et update_rack
	"""
	
	# 1. Récupérer les tuiles temporaires
	var temp_tiles = drag_drop_controller.get_temp_tiles().duplicate()
	
	if not temp_tiles.is_empty():
		print("🧹 Nettoyage de ", temp_tiles.size(), " tuiles temporaires")
		
		# Détruire les nodes visuelles des tuiles temporaires
		for pos in temp_tiles:
			var cell = board_manager.get_cell_at(pos)
			var tile_node = TileManager.get_tile_in_cell(cell)
			
			if tile_node:
				tile_node.queue_free()
			
			board_manager.set_tile_at(pos, null)
	
	# 2. Vider la liste des tuiles temporaires
	drag_drop_controller.get_temp_tiles().clear()
	
	# 3. Réinitialiser l'état du drag
	if drag_drop_controller.dragging_tile:
		drag_drop_controller.dragging_tile = null
		drag_drop_controller.drag_origin = {}
	
	# 4. Réinitialiser l'interface (via le jeu principal)
	if scrabble_game.has_method("_hide_validation_ui"):
		scrabble_game._hide_validation_ui()
	
	# 5. Revenir à la vue chevalet si nécessaire
	if board_manager.is_board_focused:
		board_manager.animate_to_rack_view()

# ============================================================================
# SAUVEGARDE ET RESTAURATION DE L'ORDRE DU CHEVALET
# ============================================================================

func _save_rack_order() -> void:
	"""
	🆕 Sauvegarde l'ordre des tuiles dans le chevalet
	Utilise les IDs des tuiles pour les retrouver après mise à jour
	"""
	
	saved_rack_order.clear()
	
	for i in range(ScrabbleConfig.RACK_SIZE):
		var tile_data = rack_manager.get_tile_at(i)
		if tile_data:
			# Sauvegarder l'ID de la tuile (ou sa lettre+valeur si pas d'ID)
			var tile_id = tile_data.get("id", "")
			if tile_id:
				saved_rack_order.append(tile_id)
			else:
				# Fallback : utiliser lettre + valeur comme identifiant
				saved_rack_order.append({
					"letter": tile_data.get("letter", ""),
					"value": tile_data.get("value", 0)
				})
		else:
			saved_rack_order.append(null)
	
	if not saved_rack_order.is_empty():
		print("💾 Ordre du chevalet sauvegardé")

func _restore_rack_with_order(rack_data: Array) -> void:
	"""
	🆕 Place les nouvelles tuiles du serveur dans l'ordre précédent si possible
	"""
	
	print("  📂 Tentative de restauration de l'ordre du chevalet...")
	
	# Créer une copie de rack_data pour tracking
	var remaining_tiles = rack_data.duplicate()
	var placed_count = 0
	
	# 1. Essayer de replacer chaque tuile à sa position d'origine
	for i in range(saved_rack_order.size()):
		var saved_id = saved_rack_order[i]
		
		if saved_id == null:
			continue
		
		# Chercher cette tuile dans les tuiles reçues du serveur
		var found_tile = null
		var found_index = -1
		
		for j in range(remaining_tiles.size()):
			var tile = remaining_tiles[j]
			
			# Comparaison par ID
			if typeof(saved_id) == TYPE_STRING:
				if tile.get("id", "") == saved_id:
					found_tile = tile
					found_index = j
					break
			# Comparaison par lettre+valeur (fallback)
			elif typeof(saved_id) == TYPE_DICTIONARY:
				if tile.get("letter", "") == saved_id.letter and \
				   tile.get("value", 0) == saved_id.value:
					found_tile = tile
					found_index = j
					break
		
		# Si trouvée, placer à la position d'origine
		if found_tile:
			var godot_tile = _convert_server_tile_to_godot(found_tile)
			rack_manager.add_tile_at(i, godot_tile)
			
			# Créer la représentation visuelle
			var cell = rack_manager.get_cell_at(i)
			var tile_manager = scrabble_game.tile_manager
			tile_manager.create_tile_visual(godot_tile, cell, rack_manager.tile_size_rack)
			
			remaining_tiles.remove_at(found_index)
			placed_count += 1
	
	# 2. Placer les tuiles restantes dans les emplacements vides
	var next_empty = 0
	for tile in remaining_tiles:
		# Trouver le prochain emplacement vide
		while next_empty < ScrabbleConfig.RACK_SIZE and rack_manager.get_tile_at(next_empty) != null:
			next_empty += 1
		
		if next_empty < ScrabbleConfig.RACK_SIZE:
			var godot_tile = _convert_server_tile_to_godot(tile)
			rack_manager.add_tile_at(next_empty, godot_tile)
			
			var cell = rack_manager.get_cell_at(next_empty)
			var tile_manager = scrabble_game.tile_manager
			tile_manager.create_tile_visual(godot_tile, cell, rack_manager.tile_size_rack)
			
			next_empty += 1
	
	print("  ✅ Chevalet restauré : ", placed_count, " tuiles à leur position d'origine")

func _fill_rack_default(rack_data: Array) -> void:
	"""
	🆕 Remplissage par défaut du chevalet (sans ordre sauvegardé)
	"""
	
	for i in range(min(rack_data.size(), ScrabbleConfig.RACK_SIZE)):
		var tile_data = rack_data[i]
		var godot_tile = _convert_server_tile_to_godot(tile_data)
		
		# Ajouter au rack
		rack_manager.add_tile_at(i, godot_tile)
		
		# Créer la représentation visuelle
		var cell = rack_manager.get_cell_at(i)
		var tile_manager = scrabble_game.tile_manager
		tile_manager.create_tile_visual(godot_tile, cell, rack_manager.tile_size_rack)

# ============================================================================
# MISE À JOUR DU PLATEAU
# ============================================================================

func _update_board(board_data: Array, placed_positions: Array) -> void:
	"""
	Met à jour le plateau local avec les données du serveur
	
	Format du board serveur :
	[
		[ // Ligne 0
			{"tile": {"letter": "A", ...}, "isLocked": true, ...},
			{"tile": null, ...},
			...
		],
		[ // Ligne 1
			...
		],
		...
	]
	et positions des lettres posées par le précédent joueur : placed_positions
	"""
	
	print("🎲 Mise à jour du plateau")
	
	# Vider le plateau actuel
	for y in range(ScrabbleConfig.BOARD_SIZE):
		for x in range(ScrabbleConfig.BOARD_SIZE):
			var current_tile = board_manager.get_tile_at(Vector2i(x, y))
			if current_tile:
				# Retirer la tuile visuelle
				var cell = board_manager.get_cell_at(Vector2i(x, y))
				var tile_node = TileManager.get_tile_in_cell(cell)
				if tile_node:
					tile_node.queue_free()
				board_manager.set_tile_at(Vector2i(x, y), null)

	# Convertir placed_positions en set pour recherche rapide
	var placed_set = {}
	for pos_dict in placed_positions:
		var x = pos_dict.get("col", -1)
		var y = pos_dict.get("row", -1)
		if x >= 0 and y >= 0:
			placed_set[Vector2i(x, y)] = true
	
	# Placer les nouvelles tuiles
	var newly_placed_tiles = []  # Pour animer après
	
	for y in range(board_data.size()):
		var row = board_data[y]
		for x in range(row.size()):
			var cell_data = row[x]
			var tile_data = cell_data.get("tile", null)
			
			if tile_data:
				# Convertir la tuile serveur en format Godot
				var godot_tile = _convert_server_tile_to_godot(tile_data)
				
				# Créer la représentation visuelle
				var cell = board_manager.get_cell_at(Vector2i(x, y))
				var tile_manager = scrabble_game.tile_manager
				var tile_node = tile_manager.create_tile_visual(godot_tile, cell, board_manager.tile_size_board)
				
				# Mettre à jour les données du plateau
				board_manager.set_tile_at(Vector2i(x, y), godot_tile)
				
				# Marquer comme verrouillée si nécessaire
				var is_locked = cell_data.get("isLocked", false)
				if is_locked:
					# Les tuiles verrouillées ne peuvent pas être déplacées
					tile_node.set_meta("locked", true)
					tile_node.modulate = Color(0.85, 0.85, 0.65)  # Légèrement plus sombre
				
				# Vérifier si cette tuile vient d'être posée
				if placed_set.has(Vector2i(x, y)):
					newly_placed_tiles.append(tile_node)
	
	# Animer les tuiles nouvellement posées
	if not newly_placed_tiles.is_empty():
		_animate_newly_placed_tiles(newly_placed_tiles)

func _animate_newly_placed_tiles(tiles: Array) -> void:
	"""
	Anime les tuiles avec un effet de pulse + flash depuis leur position
	"""
	
	print("✨ Animation de %d tuile(s) nouvellement posée(s)" % tiles.size())
	
	for i in range(tiles.size()):
		var tile_node = tiles[i]
		if not tile_node:
			continue
		
		var original_scale = tile_node.scale
		var original_modulate = Color(1.8, 1.8, 0, 1.0)
		
		# Commencer invisible et petit
		tile_node.scale = Vector2.ZERO
		tile_node.modulate = Color(2.0, 2.0, 1.5, 0.0)
		
		var delay = i * 0.1
		
		var tween = tile_node.create_tween()
		tween.set_parallel(false)
		
		if delay > 0:
			tween.tween_interval(delay)
		
		# Apparition explosive
		tween.set_parallel(true)
		tween.tween_property(tile_node, "scale", original_scale * 1.5, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(tile_node, "modulate", Color(1.8, 1.8, 1.0, 1.0), 0.3)
		
		# Stabilisation avec rebond
		tween.set_parallel(true)
		tween.tween_property(tile_node, "scale", original_scale, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(tile_node, "modulate", original_modulate, 0.4)

# ============================================================================
# MISE À JOUR DU CHEVALET
# ============================================================================

func _update_rack(rack_data: Array) -> void:
	"""
	🆕 Met à jour le chevalet du joueur avec les données du serveur
	Tente de préserver l'ordre précédent si possible
	
	Format du rack serveur :
	[
		{"id": "tile-1", "letter": "A", "points": 1, "isJoker": false, ...},
		{"id": "tile-2", "letter": "E", "points": 1, "isJoker": false, ...},
		...
	]
	"""
	
	print("🎯 Mise à jour du chevalet : ", rack_data.size(), " tuiles")
	
	# Vider le chevalet actuel
	rack_manager.clear_rack()
	
	# 🆕 Si on a un ordre sauvegardé, essayer de le restaurer
	if not saved_rack_order.is_empty():
		_restore_rack_with_order(rack_data)
	else:
		# Sinon, remplir normalement
		_fill_rack_default(rack_data)

# ============================================================================
# CONVERSION DE DONNÉES
# ============================================================================

func _convert_server_tile_to_godot(server_tile: Dictionary) -> Dictionary:
	"""
	Convertit une tuile au format serveur en format Godot
	
	Serveur : {"id": "tile-1", "letter": "A", "points": 1, "isJoker": false, "assignedLetter": null}
	Godot : {"letter": "A", "value": 1, "id": "tile-1", "is_joker": false}
	"""
	
	return {
		"letter": server_tile.get("letter", "?"),
		"value": server_tile.get("points", 0),
		"id": server_tile.get("id", ""),
		"is_joker": server_tile.get("isJoker", false),
		"assigned_letter": server_tile.get("assignedLetter", null)
	}

func _convert_godot_tile_to_server(godot_tile: Dictionary) -> Dictionary:
	"""
	Convertit une tuile au format Godot en format serveur
	"""
	
	return {
		"id": godot_tile.get("id", ""),
		"letter": godot_tile.get("letter", "?"),
		"points": godot_tile.get("value", 0),
		"isJoker": godot_tile.get("is_joker", false),
		"assignedLetter": godot_tile.get("assigned_letter", null)
	}

# ============================================================================
# VÉRIFICATION DU TOUR
# ============================================================================

func _check_if_my_turn() -> void:
	"""
	Vérifie si c'est le tour du joueur local
	"""
	
	var players = current_game_state.get("players", [])
	var current_player_index = current_game_state.get("currentPlayerIndex", 0)
	
	if current_player_index >= 0 and current_player_index < players.size():
		var current_player = players[current_player_index]
		var current_player_id = current_player.get("id", "")
		
		var was_my_turn = is_my_turn
		is_my_turn = (current_player_id == my_player_id)
		
		if is_my_turn and not was_my_turn:
			print("✅ C'est votre tour !")
			my_turn_started.emit()
		
		elif not is_my_turn and was_my_turn:
			print("⏳ En attente de l'autre joueur...")
			my_turn_ended.emit()

# ============================================================================
# ENVOI D'UN COUP AU SERVEUR
# ============================================================================

func send_move_to_server() -> void:
	"""
	Envoie le coup actuel au serveur pour validation
	
	Format attendu par le serveur :
	{
		"type": "PLAY_MOVE",
		"payload": {
			"placedTiles": [
				{
					"boardPosition": {"row": 7, "col": 7},
					"tile": {"id": "tile-1", "letter": "A", "points": 1, ...}
				},
				...
			]
		}
	}
	"""
	
	if not is_my_turn:
		print("⚠️ Ce n'est pas votre tour !")
		return
	
	# Récupérer les tuiles temporaires du drag_drop_controller
	var temp_tiles = drag_drop_controller.get_temp_tiles()
	
	if temp_tiles.is_empty():
		print("⚠️ Aucune tuile à envoyer")
		return
	
	print("📤 Envoi du coup au serveur : ", temp_tiles.size(), " tuiles")
	
	# Convertir les tuiles en format serveur
	var placed_tiles = []
	for board_pos in temp_tiles:
		var tile_data = board_manager.get_tile_at(board_pos)
		if tile_data:
			var server_tile = _convert_godot_tile_to_server(tile_data)
			placed_tiles.append({
				"boardPosition": {
					"row": board_pos.y,
					"col": board_pos.x
				},
				"tile": server_tile
			})
	
	# Envoyer au serveur
	network_manager.play_move(placed_tiles)
	
	# 🆕 Réinitialiser l'ordre sauvegardé (nouveau coup)
	saved_rack_order.clear()
	
	# Vider les tuiles temporaires (elles seront confirmées par le serveur)
	temp_tiles.clear()

# ============================================================================
# PASSER SON TOUR
# ============================================================================

func pass_turn() -> void:
	"""Passe son tour"""
	
	if not is_my_turn:
		print("⚠️ Ce n'est pas votre tour !")
		return
	
	print("⏭️ Passage de tour")
	
	# 🆕 Réinitialiser l'ordre sauvegardé
	saved_rack_order.clear()
	
	network_manager.pass_turn()

# ============================================================================
# ÉCHANGE DE LETTRES
# ============================================================================

func exchange_tiles(tile_indices: Array) -> void:
	"""Échange les lettres spécifiées avec le sac"""
	
	if not is_my_turn:
		print("⚠️ Ce n'est pas votre tour !")
		return

	if tile_indices.is_empty():
		print("⚠️ Aucune lettre à échanger")
		return

	print("🔄 Échange de %d lettre(s)..." % tile_indices.size())

	# Convertir les indices en IDs de tuiles pour le serveur
	var tiles_to_exchange = []
	for index in tile_indices:
		var tile_data = rack_manager.get_tile_at(index)
		if tile_data:
			tiles_to_exchange.append(_convert_godot_tile_to_server(tile_data))

	# Envoyer au serveur
	network_manager.exchange_tiles(tiles_to_exchange)
	
	# 🆕 Réinitialiser l'ordre sauvegardé
	saved_rack_order.clear()

func get_remaining_tiles_in_bag() -> int:
	"""Retourne le nombre de tuiles restantes dans le sac (depuis l'état du jeu)"""
	var remaining_tiles = current_game_state.get("tileBag", {}).get("tileCount", -1)
	return remaining_tiles

# ============================================================================
# FIN DE PARTIE
# ============================================================================

func _handle_game_end() -> void:
	"""Gère la fin de partie"""
	
	print("🏁 Partie terminée !")
	
	var players = current_game_state.get("players", [])
	
	# Trouver le gagnant (score le plus élevé)
	var winner_name = ""
	var max_score = -1
	
	for player in players:
		var score = player.get("score", 0)
		if score > max_score:
			max_score = score
			winner_name = player.get("name", "")
	
	print("🏆 Gagnant : ", winner_name, " avec ", max_score, " points")
	game_ended.emit(winner_name)

# ============================================================================
# GESTION DES ERREURS
# ============================================================================

func _on_error_received(error_message: String) -> void:
	"""Appelé quand le serveur envoie une erreur"""
	
	print("❌ Erreur du serveur : ", error_message)
	
	# TODO: Afficher un message à l'utilisateur
	# Par exemple, si le coup est invalide, on peut remettre les tuiles dans le chevalet

# ============================================================================
# UTILITAIRES
# ============================================================================

func _is_game_started() -> bool:
	"""Vérifie si la partie est en cours"""
	return game_has_started

func get_current_player_name() -> String:
	"""Retourne le nom du joueur dont c'est le tour"""
	var players = current_game_state.get("players", [])
	var current_player_index = current_game_state.get("currentPlayerIndex", 0)
	
	if current_player_index >= 0 and current_player_index < players.size():
		return players[current_player_index].get("name", "")
	
	return ""

func get_my_score() -> int:
	"""Retourne le score du joueur local"""
	var players = current_game_state.get("players", [])
	for player in players:
		if player.get("id", "") == my_player_id:
			return player.get("score", 0)
	return 0

func get_all_scores() -> Array:
	"""Retourne les scores de tous les joueurs"""
	var scores = []
	var players = current_game_state.get("players", [])
	for player in players:
		scores.append({
			"name": player.get("name", ""),
			"score": player.get("score", 0),
			"is_me": player.get("id", "") == my_player_id
		})
	return scores

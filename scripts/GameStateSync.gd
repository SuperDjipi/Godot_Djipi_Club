# game_state_sync.gd
# ============================================================================
# SYNCHRONISEUR D'ÉTAT DE JEU
# ============================================================================
# Ce module fait le pont entre :
# - Le plateau local (ScrabbleGame.gd, BoardManager, RackManager)
# - Le serveur distant (NetworkManager)
#
# Il gère :
# - La synchronisation de l'état du jeu
# - La conversion entre les structures Godot et JSON
# - L'envoi des coups au serveur
# - La réception et application des mises à jour
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
			"currentPlayerIndex": 0,
			"turnNumber": 1
		},
		"playerRack": [
			{"id": "tile-1", "letter": "A", "points": 1, ...},
			...
		]
	}
	"""
	
	print("📥 Réception de l'état du jeu")
	
	current_game_state = payload.get("gameState", {})
	var player_rack = payload.get("playerRack", [])
	var status = current_game_state.get("status", "")
	
	# 1. Vérifier si la partie démarre
	if status == "PLAYING" and not _is_game_started():
		print("🎮 La partie commence !")
		game_started.emit()
	
	# 2. Mettre à jour le plateau
	_update_board(current_game_state.get("board", []))
	
	# 3. Mettre à jour le chevalet du joueur
	_update_rack(player_rack)
	
	# 4. Vérifier si c'est notre tour
	_check_if_my_turn()
	
	# 5. Vérifier si la partie est terminée
	if status == "FINISHED":
		_handle_game_end()

# ============================================================================
# MISE À JOUR DU PLATEAU
# ============================================================================

func _update_board(board_data: Array) -> void:
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
	
	# Placer les nouvelles tuiles
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
				
				# ✅ Si c'est un joker avec une lettre assignée, mettre à jour l'affichage
				if godot_tile.is_joker and godot_tile.assigned_letter != null:
					scrabble_game._update_joker_visual(tile_node, godot_tile.assigned_letter)

				# Mettre à jour les données du plateau
				board_manager.set_tile_at(Vector2i(x, y), godot_tile)

				# Marquer comme verrouillée si nécessaire
				var is_locked = cell_data.get("isLocked", false)
				if is_locked:
					tile_node.set_meta("locked", true)
					tile_node.modulate = Color(0.85, 0.85, 0.65)  # Légèrement plus sombre
					
# ============================================================================
# MISE À JOUR DU CHEVALET
# ============================================================================

func _update_rack(rack_data: Array) -> void:
	"""
	Met à jour le chevalet du joueur avec les données du serveur
	
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
	
	# Remplir avec les nouvelles tuiles
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
	network_manager.pass_turn()

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
	
	# Afficher un message à l'utilisateur
	_show_error_popup(error_message)
	
	# Remettre les tuiles temporaires au chevalet
	if scrabble_game.has_method("_return_temp_tiles_to_rack"):
		scrabble_game._return_temp_tiles_to_rack()
	
	# Réactiver les boutons pour que le joueur puisse rejouer
	if scrabble_game.has_method("_on_my_turn_started"):
		scrabble_game._on_my_turn_started()

# ============================================================================
# FONCTION : Afficher un popup d'erreur
# ============================================================================
func _show_error_popup(error_message: String) -> void:
	"""Affiche un popup avec le message d'erreur du serveur"""
	
	# Appeler une fonction du ScrabbleGame
	if scrabble_game.has_method("_show_server_error"):
		scrabble_game._show_server_error(error_message)

# ============================================================================
# UTILITAIRES
# ============================================================================

func _is_game_started() -> bool:
	"""Vérifie si la partie est en cours"""
	return current_game_state.get("status", "") == "PLAYING"

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

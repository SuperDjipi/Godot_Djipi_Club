# network_manager.gd
# Gère la connexion WebSocket avec le serveur de jeu
# VERSION 2.0 : Avec stockage de l'état initial
extends Node

# Configuration du serveur
const SERVER_URL = "ws://djipi.club:8080"

# Instance WebSocket
var socket = WebSocketPeer.new()
var connection_status = WebSocketPeer.STATE_CLOSED

# Informations du joueur
var player_id: String = ""
var player_name: String = ""
var game_id: String = ""

# ============================================================================
# NOUVEAU : STOCKAGE DE L'ÉTAT INITIAL
# ============================================================================

# Stocker le dernier état reçu pour les connexions tardives
var last_game_state: Dictionary = {}

# ============================================================================
# SIGNAUX
# ============================================================================

# Signaux pour notifier les autres noeuds
signal connected_to_server()
signal disconnected_from_server()
signal connection_error(error_message: String)
signal game_state_received(game_state: Dictionary)
signal error_received(error_message: String)

# ============================================================================
# INITIALISATION
# ============================================================================

func _ready():
	print("NetworkManager initialisé")

func _process(_delta):
	# Mise à jour du socket à chaque frame
	socket.poll()
	var state = socket.get_ready_state()
	
	# Détection des changements de statut
	if state != connection_status:
		connection_status = state
		match state:
			WebSocketPeer.STATE_OPEN:
				print("✅ Connecté au serveur")
				connected_to_server.emit()
			WebSocketPeer.STATE_CLOSED:
				print("❌ Déconnecté du serveur")
				disconnected_from_server.emit()
	
	# Lecture des messages entrants
	while socket.get_ready_state() == WebSocketPeer.STATE_OPEN and socket.get_available_packet_count():
		var packet = socket.get_packet()
		var message = packet.get_string_from_utf8()
		_handle_server_message(message)

# ============================================================================
# CONNEXION AU SERVEUR
# ============================================================================

func connect_to_server(game_id_param: String, player_id_param: String) -> void:
	"""
	Établit une connexion WebSocket au serveur
	Le serveur attend l'URL : ws://djipi.club:8080/{gameId}?playerId={playerId}
	"""
	player_id = player_id_param
	game_id = game_id_param
	
	# Nettoyer l'ancien état
	# clear_last_game_state()
	
	# Format attendu par le serveur : /{gameId}?playerId={playerId}
	var full_url = SERVER_URL + "/" + game_id + "?playerId=" + player_id
	print("🔌 Connexion au serveur : ", full_url)
	
	var error = socket.connect_to_url(full_url)
	if error != OK:
		print("❌ Erreur de connexion : ", error)
		connection_error.emit("Impossible de se connecter au serveur")

func disconnect_from_server() -> void:
	"""Ferme proprement la connexion WebSocket"""
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.close()
		print("🔌 Déconnexion du serveur")
	
	# Nettoyer l'état stocké
	clear_last_game_state()

# ============================================================================
# GESTION DES MESSAGES ENTRANTS
# ============================================================================

func _handle_server_message(message: String) -> void:
	"""Traite les messages JSON reçus du serveur"""
	print("📥 Message reçu dans NM hsm ")
	
	var json = JSON.new()
	var parse_result = json.parse(message)
	
	if parse_result != OK:
		print("⚠️ Erreur de parsing JSON")
		return
	
	var data = json.data
	if not data is Dictionary:
		print("⚠️ Format de message invalide")
		return
	
	var event_type = data.get("type", "")
	
	match event_type:
		"GAME_STATE_UPDATE":
			print("       - ", event_type)
			_handle_game_state_update(data)
		"ERROR":
			print("       - ", event_type)
			_handle_error(data)
		_:
			print("⚠️ Type d'événement inconnu : ", event_type)

func _handle_game_state_update(data: Dictionary) -> void:
	"""Traite une mise à jour de l'état du jeu"""
	var payload = data.get("payload", {})
	var game_state = payload.get("gameState", {})
	var player_rack = payload.get("playerRack", [])
	
	print("🎮 État du jeu mis à jour")
	print("  - Joueurs : ", game_state.get("players", []).size())
	print("  - Chevalet : ", player_rack.size(), " tuiles")
	print("  - Status : ", game_state.get("status", ""))
	
	# NOUVEAU : Stocker l'état
	last_game_state = payload
	print("💾 État stocké dans NetworkManager")
	
	# Émettre le signal pour que le jeu mette à jour l'affichage
	game_state_received.emit(payload)

func _handle_error(data: Dictionary) -> void:
	"""Traite un message d'erreur du serveur"""
	var payload = data.get("payload", {})
	var error_message = payload.get("message", "Erreur inconnue")
	
	print("❌ Erreur du serveur : ", error_message)
	error_received.emit(error_message)

# ============================================================================
# ENVOI DE MESSAGES AU SERVEUR
# ============================================================================

func send_event(event_type: String, payload: Dictionary = {}) -> void:
	"""Envoie un événement au serveur"""
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		print("⚠️ Impossible d'envoyer : non connecté")
		return
	
	var event = {
		"type": event_type,
		"payload": payload
	}
	
	var json_string = JSON.stringify(event)
	print("📤 Envoi : ", json_string)
	
	socket.send_text(json_string)

# ============================================================================
# ACTIONS DE JEU
# ============================================================================

func start_game() -> void:
	"""Demande au serveur de démarrer la partie"""
	send_event("START_GAME")

func play_move(placed_tiles: Array) -> void:
	"""Envoie un coup au serveur pour validation"""
	var payload = {
		"placedTiles": placed_tiles
	}
	send_event("PLAY_MOVE", payload)

func pass_turn() -> void:
	"""Passe son tour"""
	send_event("PASS_TURN")

func exchange_tiles(tiles: Array) -> void:
	"""Envoie une demande d'échange de lettres"""
	var payload = {
			"tilesToExchange": tiles
		}
	send_event("EXCHANGE_TILES", payload)


# ============================================================================
# NOUVEAU : GESTION DE L'ÉTAT STOCKÉ
# ============================================================================

func get_last_game_state() -> Dictionary:
	"""
	Récupère le dernier état reçu
	Utilisé par GameStateSync pour traiter l'état initial
	"""
	return last_game_state

func clear_last_game_state() -> void:
	"""Efface l'état stocké"""
	last_game_state = {}
	print("🗑️ État stocké effacé")

func has_stored_state() -> bool:
	"""Vérifie si un état est stocké"""
	return not last_game_state.is_empty()

# ============================================================================
# UTILITAIRES
# ============================================================================

func is_connected_to_server() -> bool:
	"""Vérifie si on est connecté au serveur"""
	return socket.get_ready_state() == WebSocketPeer.STATE_OPEN

func get_connection_status_string() -> String:
	"""Retourne le statut de connexion en texte"""
	match socket.get_ready_state():
		WebSocketPeer.STATE_CONNECTING:
			return "Connexion en cours..."
		WebSocketPeer.STATE_OPEN:
			return "Connecté"
		WebSocketPeer.STATE_CLOSING:
			return "Déconnexion..."
		WebSocketPeer.STATE_CLOSED:
			return "Déconnecté"
		_:
			return "Statut inconnu"

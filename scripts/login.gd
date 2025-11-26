# login.gd
# Scène d'authentification et de connexion à une partie
extends Control

# Références aux noeuds UI
@onready var player_name_input = $VBoxContainer/PlayerNameInput
@onready var game_code_input = $VBoxContainer/GameCodeInput
@onready var register_button = $VBoxContainer/RegisterButton
@onready var join_button = $VBoxContainer/JoinButton
@onready var create_button = $VBoxContainer/CreateButton
@onready var status_label = $VBoxContainer/StatusLabel
@onready var network_manager = $"/root/NetworkManager"

const SERVER_API_URL = "http://djipi.club:8080/api"

# Variables locales
var player_id: String = ""

func _ready():
	# Configuration des boutons
	register_button.pressed.connect(_on_register_pressed)
	join_button.pressed.connect(_on_join_pressed)
	create_button.pressed.connect(_on_create_pressed)
	
	# Désactiver les boutons de jeu tant qu'on n'est pas enregistré
	join_button.disabled = true
	create_button.disabled = true
	
	# Connexion aux signaux du NetworkManager
	network_manager.connected_to_server.connect(_on_connected_to_server)
	network_manager.game_state_received.connect(_on_game_state_received)
	network_manager.error_received.connect(_on_error_received)
	
	update_status("Entrez votre pseudo pour commencer")

## INSCRIPTION (via API REST)

func _on_register_pressed():
	var name = player_name_input.text.strip_edges()
	
	if name.is_empty():
		update_status("❌ Le pseudo ne peut pas être vide")
		return
	
	update_status("⏳ Inscription en cours...")
	register_button.disabled = true
	
	# Appel API REST pour l'inscription
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_register_completed)
	
	var body = JSON.stringify({
		"name": name,
		"password": "temp123"  # TODO: Vrai système de mot de passe
	})
	
	var headers = ["Content-Type: application/json"]
	http.request(SERVER_API_URL + "/register", headers, HTTPClient.METHOD_POST, body)

func _on_register_completed(result, response_code, headers, body):
	var response = JSON.parse_string(body.get_string_from_utf8())
	
	if response_code == 201:  # Created
		player_id = response.get("playerId", "")
		var name = player_name_input.text.strip_edges()
		update_status("✅ Bienvenue " + name + " !")
		
		# Activer les boutons de jeu
		join_button.disabled = false
		create_button.disabled = false
		register_button.disabled = true
		player_name_input.editable = false
		
		print("✅ Joueur enregistré : ", player_id)
	else:
		var message = response.get("message", "Erreur inconnue")
		update_status("❌ " + message)
		register_button.disabled = false

## CRÉATION DE PARTIE (via API REST)

func _on_create_pressed():
	if player_id.is_empty():
		update_status("❌ Vous devez d'abord vous inscrire")
		return
	
	update_status("⏳ Création de la partie...")
	create_button.disabled = true
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_create_game_completed)
	
	var body = JSON.stringify({
		"creatorId": player_id
	})
	
	var headers = ["Content-Type: application/json"]
	http.request(SERVER_API_URL + "/games", headers, HTTPClient.METHOD_POST, body)

func _on_create_game_completed(result, response_code, headers, body):
	# Attendre un peu avant de parser pour éviter l'abort
	await get_tree().create_timer(0.1).timeout
	
	var response = JSON.parse_string(body.get_string_from_utf8())
	
	if response_code == 201:  # Created
		var game_id = response.get("gameId", "")
		update_status("✅ Partie créée : " + game_id)
		game_code_input.text = game_id
		
		# Se connecter automatiquement à la partie après un délai
		await get_tree().create_timer(0.5).timeout
		_connect_to_game(game_id)
	else:
		var message = response.get("message", "Erreur inconnue")
		update_status("❌ " + message)
		create_button.disabled = false

## REJOINDRE UNE PARTIE

func _on_join_pressed():
	var game_code = game_code_input.text.strip_edges().to_upper()
	
	if game_code.is_empty():
		update_status("❌ Entrez un code de partie")
		return
	
	if player_id.is_empty():
		update_status("❌ Vous devez d'abord vous inscrire")
		return
	
	update_status("⏳ Connexion à la partie...")
	join_button.disabled = true
	
	# D'abord rejoindre via l'API REST
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_join_game_completed.bind(game_code))
	
	var body = JSON.stringify({
		"playerId": player_id
	})
	
	var headers = ["Content-Type: application/json"]
	http.request(SERVER_API_URL + "/games/" + game_code + "/join", headers, HTTPClient.METHOD_POST, body)

func _on_join_game_completed(result, response_code, headers, body, game_code: String):
	# Attendre un peu avant de parser pour éviter l'abort
	await get_tree().create_timer(0.1).timeout
	
	var response = JSON.parse_string(body.get_string_from_utf8())
	
	if response_code == 200:  # OK
		update_status("✅ Partie rejointe !")
		# Attendre un peu que le serveur soit prêt
		await get_tree().create_timer(0.5).timeout
		# Maintenant établir la connexion WebSocket
		_connect_to_game(game_code)
	else:
		var message = response.get("message", "Erreur inconnue")
		update_status("❌ " + message)
		join_button.disabled = false

## CONNEXION WEBSOCKET

func _connect_to_game(game_id: String):
	"""Établit la connexion WebSocket après avoir rejoint via REST"""
	update_status("🔌 Connexion WebSocket...")
	network_manager.connect_to_server(game_id, player_id)

func _on_connected_to_server():
	"""Appelé quand la connexion WebSocket est établie"""
	update_status("✅ Connecté ! En attente d'autres joueurs...")
	
	# Transition vers la scène de jeu (à venir)
	# get_tree().change_scene_to_file("res://scrabble_game.tscn")

func _on_game_state_received(payload: Dictionary):
	"""Appelé quand on reçoit l'état du jeu"""
	var game_state = payload.get("gameState", {})
	var status = game_state.get("status", "")
	
	print("📊 État reçu, statut : ", status)
	
	# Si la partie démarre, passer à la scène de jeu
	if status == "PLAYING":
		update_status("🎮 La partie commence !")
		# TODO: Charger la scène de jeu avec l'état
		# get_tree().change_scene_to_file("res://scrabble_game.tscn")

func _on_error_received(error_message: String):
	"""Appelé quand le serveur envoie une erreur"""
	update_status("❌ " + error_message)
	join_button.disabled = false
	create_button.disabled = false

## UTILITAIRES

func update_status(message: String):
	"""Met à jour le label de statut"""
	status_label.text = message
	print(message)

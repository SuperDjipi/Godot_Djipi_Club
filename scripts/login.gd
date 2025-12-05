# login.gd
# Écran d'accueil - Version 5.0 : Architecture Robuste avec Callbacks Dédiés
extends Control

# ============================================================================
# RÉFÉRENCES AUX NŒUDS UI
# ============================================================================

@onready var player_name_input = $VBoxContainer/PlayerNameInput
@onready var register_button = $VBoxContainer/HBoxContainer/RegisterButton
@onready var login_button = $VBoxContainer/HBoxContainer/LoginButton
@onready var status_label = $VBoxContainer/StatusLabel
@onready var network_manager = $"/root/NetworkManager"

# Références créées dynamiquement
var games_list_container: VBoxContainer
var players_list_container: VBoxContainer

# ============================================================================
# CONSTANTES
# ============================================================================

const SERVER_API_URL = "http://djipi.club:8080"

# ============================================================================
# INITIALISATION
# ============================================================================

func _ready():
	print("🚀 Démarrage de l'écran d'accueil")
	
	# Connexion des signaux
	register_button.pressed.connect(_on_register_pressed)
	login_button.pressed.connect(_on_login_pressed)
	
	# Connexion aux signaux du NetworkManager (seulement ceux utiles)
	network_manager.connected_to_server.connect(_on_connected_to_server)
	network_manager.error_received.connect(_on_error_received)
	
	# Créer les sections dynamiques
	_create_ui_sections()

	# On vérifie l'état de la session au lieu des fichiers de sauvegarde
	if PlayerSession.is_logged_in():
		print("✅ Le joueur est déjà connecté via la session.")
		# Le joueur revient d'une autre scène, il est déjà connecté.
		player_name_input.text = PlayerSession.player_name
		_on_successful_login() # On lance directement l'affichage des listes
	else:
		# C'est le premier lancement du jeu, on vérifie les fichiers sauvegardés
		_check_saved_credentials_and_auto_login()
	
	print("✅ Initialisation terminée")

# ============================================================================
# CRÉATION DE L'INTERFACE
# ============================================================================

func _create_ui_sections() -> void:
	"""Crée les sections Parties en cours et Joueurs en ligne"""
	
	var vbox = $VBoxContainer
	
	# === SECTION 1 : PARTIES EN COURS ===
	
	var games_separator = HSeparator.new()
	vbox.add_child(games_separator)
	
	var games_title = RichTextLabel.new()
	games_title.text = "📋 VOS PARTIES EN COURS"
	games_title.fit_content = true
	games_title.add_theme_font_size_override("normal_font_size", 18)
	games_title.add_theme_color_override("default_color", Color(0, 0.41, 0.41))
	games_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(games_title)
	
	var games_scroll = ScrollContainer.new()
	games_scroll.custom_minimum_size = Vector2(0, 250)
	vbox.add_child(games_scroll)
	
	games_list_container = VBoxContainer.new()
	games_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	games_scroll.add_child(games_list_container)
	
	# === SECTION 2 : JOUEURS EN LIGNE ===
	
	var players_separator = HSeparator.new()
	vbox.add_child(players_separator)
	
	var players_title = RichTextLabel.new()
	players_title.text = "👥 JOUEURS INSCRITS"
	players_title.fit_content = true
	players_title.add_theme_font_size_override("normal_font_size", 18)
	players_title.add_theme_color_override("default_color", Color(0, 0.41, 0.41))
	players_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(players_title)
	
	var players_scroll = ScrollContainer.new()
	players_scroll.custom_minimum_size = Vector2(0, 200)
	vbox.add_child(players_scroll)
	
	players_list_container = VBoxContainer.new()
	players_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	players_scroll.add_child(players_list_container)
	
	print("📋 Sections UI créées")

# ============================================================================
# GESTION DES IDENTIFIANTS
# ============================================================================

func _check_saved_credentials_and_auto_login() -> void:
	"""
	Vérifie les identifiants sauvegardés ET tente une connexion automatique.
	"""
	var config = ConfigFile.new()
	var err = config.load("user://player_data.cfg")

	if err == OK:
		var saved_name = config.get_value("player", "name", "")
		if not saved_name.is_empty():
			print("🔑 Identifiants trouvés pour '", saved_name, "'. Tentative de connexion automatique...")
			player_name_input.text = saved_name
			_on_login_pressed() # On simule un clic sur le bouton de connexion !

func _save_credentials(name: String, id: String) -> void:
	"""Sauvegarde les identifiants"""
	var config = ConfigFile.new()
	config.set_value("player", "name", name)
	config.set_value("player", "id", id)
	config.save("user://player_data.cfg")
	print("💾 Identifiants sauvegardés")

# ============================================================================
# HELPER : REQUÊTE HTTP AVEC CALLBACK DÉDIÉ
# ============================================================================

func _make_http_request(url: String, callback: Callable, method: HTTPClient.Method = HTTPClient.METHOD_GET, body: String = "") -> void:
	"""
	Crée une requête HTTP avec un callback dédié
	
	Args:
		url: L'URL complète de la requête
		callback: La fonction à appeler (doit accepter result, code, headers, body)
		method: GET, POST, etc.
		body: Corps de la requête (pour POST)
	"""
	var http = HTTPRequest.new()
	add_child(http)
	
	# Connecter avec CONNECT_ONE_SHOT pour éviter les fuites
	http.request_completed.connect(func(result, code, headers, response_body):
		# Appeler le callback
		callback.call(result, code, headers, response_body)
		
		# Nettoyer après un petit délai
		await get_tree().create_timer(0.1).timeout
		http.queue_free()
	, CONNECT_ONE_SHOT)
	
	# Lancer la requête
	var headers = ["Content-Type: application/json"]
	http.request(url, headers, method, body)
	
	print("📡 Requête HTTP : ", method, " ", url)

# ============================================================================
# INSCRIPTION
# ============================================================================

func _on_register_pressed() -> void:
	"""Inscription d'un nouveau joueur"""
	var name = player_name_input.text.strip_edges()
	
	if name.is_empty():
		update_status("❌ Le pseudo ne peut pas être vide")
		return
	
	update_status("⏳ Inscription en cours...")
	register_button.disabled = true
	login_button.disabled = true
	
	var url = SERVER_API_URL + "/api/register"
	var body = JSON.stringify({
		"name": name,
		"password": "temp123"
	})
	
	_make_http_request(url, _on_register_completed, HTTPClient.METHOD_POST, body)

func _on_register_completed(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	"""Callback d'inscription"""
	
	var response = JSON.parse_string(body.get_string_from_utf8())
	
	if code == 201:  # Created
		var player_id = response.get("playerId", "")
		var player_name = player_name_input.text.strip_edges()
		PlayerSession.set_player_data(player_id, player_name)
		
		print("✅ Inscription réussie : ", player_name, " (", player_id, ")")
		
		# Sauvegarder les identifiants
		_save_credentials(player_name, player_id)
		
		# Marquer comme connecté
		_on_successful_login()
		
	else:
		var message = response.get("message", "Erreur d'inscription") if response else "Erreur"
		update_status("❌ " + message)
		print("❌ Inscription échouée : ", message)
		register_button.disabled = false
		login_button.disabled = false

# ============================================================================
# CONNEXION
# ============================================================================

func _on_login_pressed() -> void:
	"""Connexion avec un pseudo existant"""
	var name = player_name_input.text.strip_edges()
	
	if name.is_empty():
		update_status("❌ Le pseudo ne peut pas être vide")
		return
	
	update_status("⏳ Connexion en cours...")
	login_button.disabled = true
	register_button.disabled = true
	
	var url = SERVER_API_URL + "/api/login?name=" + name.uri_encode()
	
	_make_http_request(url, _on_login_completed)

func _on_login_completed(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	"""Callback de connexion"""
	
	var response = JSON.parse_string(body.get_string_from_utf8())
	
	if code == 200:  # OK
		# On stocke les infos dans le Singleton
		var p_id = response.get("playerId", "")
		var p_name = response.get("name", "")
		PlayerSession.set_player_data(p_id, p_name)
		
		print("✅ Connexion réussie : ", p_name, " (", p_id, ")")
		_save_credentials(p_name, p_id)		
		# Marquer comme connecté
		_on_successful_login()
		
	else:
		var message = response.get("message", "Joueur non trouvé") if response else "Erreur"
		update_status("❌ " + message)
		print("❌ Connexion échouée : ", message)
		login_button.disabled = false
		register_button.disabled = false

# ============================================================================
# APRÈS CONNEXION RÉUSSIE
# ============================================================================

func _on_successful_login() -> void:
	"""Appelé après une inscription ou connexion réussie"""
	update_status("✅ Bienvenue " + PlayerSession.player_name + " !")
	# is_logged_in = true
	
	# Désactiver les boutons d'authentification
	register_button.disabled = true
	login_button.disabled = true
	player_name_input.editable = false
	
	print("✅ Joueur authentifié : ", PlayerSession.player_id)
	
	# Charger les listes
	refresh_games_list()
	refresh_players_list()

# ============================================================================
# LISTE DES PARTIES
# ============================================================================

func refresh_games_list() -> void:
	"""Demande la liste des parties du joueur"""
	if PlayerSession.player_id.is_empty():
		return
	
	print("📋 Rafraîchissement de la liste des parties...")
	
	var url = SERVER_API_URL + "/api/players/" + PlayerSession.player_id + "/games"
	_make_http_request(url, _on_games_list_received)

func _on_games_list_received(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	"""Callback de la liste des parties"""
	
	var response = JSON.parse_string(body.get_string_from_utf8())
	
	if code == 200 and response is Array:
		print("📋 ", response.size(), " partie(s) reçue(s)")
		display_games_list(response)
	else:
		print("❌ Erreur lors de la récupération des parties")
		display_games_list([])  # Afficher liste vide

func display_games_list(games: Array) -> void:
	"""Affiche les parties dans l'UI"""
	
	# Vider la liste actuelle
	for child in games_list_container.get_children():
		child.queue_free()
	
	if games.is_empty():
		var empty = Label.new()
		empty.text = "Aucune partie en cours"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		games_list_container.add_child(empty)
		return
	
	# Créer les cartes de parties
	for game_info in games:
		var card = _create_game_card(game_info)
		games_list_container.add_child(card)
	
	print("✅ ", games.size(), " carte(s) de partie(s) affichée(s)")

func _create_game_card(game_info: Dictionary) -> PanelContainer:
	"""Crée une carte de partie"""
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 90)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.25, 0.15) if game_info.get("status", "") == "PLAYING" else Color(0.2, 0.2, 0.25)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.3, 0.8, 0.3) if game_info.get("isMyTurn", false) else Color(0.5, 0.5, 0.5)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	panel.add_child(vbox)
	
	# Ligne 1 : ID + Tour
	var hbox1 = HBoxContainer.new()
	vbox.add_child(hbox1)
	
	var id_label = Label.new()
	id_label.text = "🎮 " + game_info.get("gameId", "???")
	id_label.add_theme_font_size_override("font_size", 14)
	hbox1.add_child(id_label)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox1.add_child(spacer)
	
	var turn_label = Label.new()
	if game_info.get("isMyTurn", false):
		turn_label.text = "⬤ Votre tour"
		turn_label.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
	else:
		turn_label.text = "⏳ Adversaire"
		turn_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	turn_label.add_theme_font_size_override("font_size", 12)
	hbox1.add_child(turn_label)
	
	# Ligne 2 : Adversaires
	var opp_label = Label.new()
	var opponents = game_info.get("opponents", [])
	opp_label.text = "vs " + ", ".join(PackedStringArray(opponents))
	opp_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	opp_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(opp_label)
	
	# Ligne 3 : Scores
	var scores_label = Label.new()
	scores_label.text = "Vous : %d | Adversaire : %d" % [game_info.get("myScore", 0), game_info.get("opponentScore", 0)]
	scores_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	scores_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(scores_label)
	
	# Bouton Reprendre
	var btn = Button.new()
	btn.text = "Reprendre"
	btn.custom_minimum_size = Vector2(0, 25)
	var gid = game_info.get("gameId", "")
	btn.pressed.connect(func(): _connect_and_start_game(gid))
	vbox.add_child(btn)
	
	return panel

# ============================================================================
# LISTE DES JOUEURS
# ============================================================================

func refresh_players_list() -> void:
	"""Demande la liste des joueurs"""
	print("👥 Rafraîchissement de la liste des joueurs...")
	
	var url = SERVER_API_URL + "/api/players"
	_make_http_request(url, _on_players_list_received)

func _on_players_list_received(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	"""Callback de la liste des joueurs"""
	
	var response = JSON.parse_string(body.get_string_from_utf8())
	
	if code == 200 and response is Array:
		print("👥 ", response.size(), " joueur(s) reçu(s)")
		display_players_list(response)
	else:
		print("❌ Erreur lors de la récupération des joueurs")
		display_players_list([])  # Afficher liste vide

func display_players_list(players: Array) -> void:
	"""Affiche les joueurs dans l'UI"""
	
	# Vider la liste actuelle
	for child in players_list_container.get_children():
		child.queue_free()
	
	if players.is_empty():
		var empty = Label.new()
		empty.text = "Aucun joueur inscrit"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		players_list_container.add_child(empty)
		return
	
	# Créer les cartes de joueurs (sauf soi-même)
	var displayed_count = 0
	for player_info in players:
		var pid = player_info.get("id", "")
		
		# Ne pas afficher soi-même
		if pid == PlayerSession.player_id:
			continue
		
		var card = _create_player_card(player_info)
		players_list_container.add_child(card)
		displayed_count += 1
	
	if displayed_count == 0:
		var empty = Label.new()
		empty.text = "Aucun autre joueur"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		players_list_container.add_child(empty)
	
	print("✅ ", displayed_count, " carte(s) joueur(s) affichée(s)")

func _create_player_card(player_info: Dictionary) -> PanelContainer:
	"""Crée une carte joueur"""
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 40)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.25)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	panel.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	panel.add_child(hbox)
	
	var name_label = Label.new()
	name_label.text = "👤 " + player_info.get("name", "???")
	name_label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(name_label)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)
	
	var challenge_btn = Button.new()
	challenge_btn.text = "Défier"
	challenge_btn.custom_minimum_size = Vector2(80, 30)
	var opponent_id = player_info.get("id", "")
	challenge_btn.pressed.connect(func(): _challenge_player(opponent_id))
	hbox.add_child(challenge_btn)
	
	return panel

# ============================================================================
# DÉFIER UN JOUEUR
# ============================================================================

func _challenge_player(opponent_id: String) -> void:
	"""Lance un défi à un joueur"""
	print("⚔️ Défi lancé à : ", opponent_id)
	
	update_status("🔄 Envoi du défi...")
	
	var url = SERVER_API_URL + "/api/challenge/" + opponent_id
	var body = JSON.stringify({"playerId": PlayerSession.player_id})
	
	_make_http_request(url, _on_challenge_completed, HTTPClient.METHOD_POST, body)

func _on_challenge_completed(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	"""Callback de défi"""
	
	var response = JSON.parse_string(body.get_string_from_utf8())
	
	if code == 201:  # Created
		var game_id = response.get("gameId", "")
		var game_state = response.get("gameState", {})
		var player_rack = response.get("playerRack", [])
		print("✅ Défi envoyé ! Game ID : ", game_id)
		update_status("✅ Défi envoyé !")
		# Stocker l'état dans NetworkManager AVANT de se connecter
		if not game_state.is_empty():
			network_manager.last_game_state = {
				"gameState": game_state,
				"playerRack": player_rack
			}
		
		# Connecter à la partie créée
		await get_tree().create_timer(0.3).timeout
		_connect_and_start_game(game_id)
		
	else:
		var message = response.get("message", "Erreur lors du défi") if response else "Erreur"
		update_status("❌ " + message)
		print("❌ Défi échoué : ", message)

# ============================================================================
# CONNEXION À UNE PARTIE (AVEC RECONNECT/JOIN)
# ============================================================================

func _connect_and_start_game(game_id: String) -> void:
	"""
	Lance la connexion à une partie
	Essaie d'abord de reconnecter, puis de rejoindre si nécessaire
	"""
	print("🎮 Tentative de connexion à la partie : ", game_id)
	update_status("⏳ Connexion à la partie...")
	
	# Étape 1 : Essayer de reconnecter (si on était déjà dans cette partie)
	_try_reconnect(game_id)

func _try_reconnect(game_id: String) -> void:
	"""Étape 1 : Tenter de reconnecter à une partie existante"""
	print("🔄 Étape 1 : Reconnexion...")
	
	var url = SERVER_API_URL + "/api/games/" + game_id + "/reconnect"
	var body = JSON.stringify({"playerId": PlayerSession.player_id})
	
	_make_http_request(
		url,
		func(result, code, headers, response_body):
			_on_reconnect_completed(result, code, headers, response_body, game_id),
		HTTPClient.METHOD_POST,
		body
	)

func _on_reconnect_completed(result: int, code: int, headers: PackedStringArray, body: PackedByteArray, game_id: String) -> void:
	"""Callback de reconnexion"""
	
	if code == 200:
		# ✅ Reconnexion réussie !
		print("✅ Reconnexion autorisée")
		update_status("✅ Reconnexion réussie !")
		await get_tree().create_timer(0.3).timeout
		_start_websocket(game_id)
	else:
		# ❌ Pas dans cette partie, essayer de rejoindre
		print("⏭️ Reconnexion échouée, tentative de join...")
		_try_join(game_id)

func _try_join(game_id: String) -> void:
	"""Étape 2 : Tenter de rejoindre la partie"""
	print("🤝 Étape 2 : Join...")
	
	var url = SERVER_API_URL + "/api/games/" + game_id + "/join"
	var body = JSON.stringify({"playerId": PlayerSession.player_id})
	
	_make_http_request(
		url,
		func(result, code, headers, response_body):
			_on_join_completed(result, code, headers, response_body, game_id),
		HTTPClient.METHOD_POST,
		body
	)

func _on_join_completed(result: int, code: int, headers: PackedStringArray, body: PackedByteArray, game_id: String) -> void:
	"""Callback de join"""
	
	if code == 200:
		# ✅ Join réussi !
		print("✅ Join autorisé")
		update_status("✅ Partie rejointe !")
		await get_tree().create_timer(0.3).timeout
		_start_websocket(game_id)
	else:
		# ❌ Impossible de rejoindre
		var response = JSON.parse_string(body.get_string_from_utf8())
		var message = response.get("message", "Impossible de rejoindre la partie") if response else "Erreur"
		update_status("❌ " + message)
		print("❌ Erreur : ", message)

func _start_websocket(game_id: String) -> void:
	"""Lance la connexion WebSocket après validation REST"""
	print("🔌 Démarrage WebSocket...")
	update_status("🔌 Connexion WebSocket...")
	
	# Configurer le NetworkManager
	network_manager.player_id = PlayerSession.player_id
	network_manager.player_name = PlayerSession.player_name
	network_manager.game_id = game_id
	
	# Connexion WebSocket
	network_manager.connect_to_server(game_id, PlayerSession.player_id)
	
	# Attendre la connexion puis changer de scène
	await network_manager.connected_to_server
	await get_tree().create_timer(0.3).timeout
	
	print("🎮 Changement de scène vers le jeu...")
	get_tree().change_scene_to_file("res://scenes/ScrabbleGameMultiplayer.tscn")

# ============================================================================
# CALLBACKS RÉSEAU
# ============================================================================

func _on_connected_to_server() -> void:
	"""Appelé quand la connexion WebSocket est établie"""
	print("✅ WebSocket connecté")
	# La transition se fait déjà dans _start_websocket()

func _on_error_received(error: String) -> void:
	"""Appelé quand le serveur envoie une erreur"""
	print("❌ Erreur WebSocket : ", error)
	update_status("❌ " + error)

# ============================================================================
# UTILITAIRES
# ============================================================================

func update_status(message: String) -> void:
	"""Met à jour le label de statut"""
	status_label.text = message
	print("📢 ", message)

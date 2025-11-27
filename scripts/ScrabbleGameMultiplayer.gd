extends Node2D

# ============================================================================
# SCRABBLE GAME - VERSION MULTIJOUEUR
# ============================================================================
# Ce fichier coordonne le jeu en mode multijoueur
# Il fait le lien entre le jeu local et le serveur distant
# ============================================================================

# --- MODULES DU JEU ---
var tile_manager: TileManager
var board_manager: BoardManager
var rack_manager: RackManager
var drag_drop_controller: DragDropController
var game_state_sync: GameStateSync

# --- RÉFÉRENCES RÉSEAU ---
@onready var network_manager = $"/root/NetworkManager"

# --- VARIABLES GLOBALES ---
var viewport_size: Vector2

# --- UI ÉLÉMENTS ---
var turn_label: Label
var score_label: Label
var play_button: Button
var pass_button: Button
var status_label: Label

# ============================================================================
# FONCTION : Initialisation du jeu
# ============================================================================
func _ready():
	randomize()
	viewport_size = get_viewport_rect().size
	
	print("🎮 Démarrage du jeu de Scrabble (Mode Multijoueur)")
	print("📱 Taille de l'écran : ", viewport_size)
	
	# Vérifier qu'on est bien connecté
	if not network_manager.is_connected_to_server():
		print("❌ ERREUR : Pas de connexion au serveur !")
		print("   Retour à l'écran de connexion...")
		get_tree().change_scene_to_file("res://login.tscn")
		return
	
	# 1. Créer et initialiser le TileManager
	tile_manager = TileManager.new()
	add_child(tile_manager)
	# NE PAS init_tile_bag() ici - le serveur gère la pioche !
	
	# 2. Créer et initialiser le RackManager
	rack_manager = RackManager.new()
	add_child(rack_manager)
	rack_manager.initialize(viewport_size, tile_manager)
	rack_manager.create_rack(self)
	# NE PAS fill_rack() ici - on attend les tuiles du serveur !
	
	# 3. Créer et initialiser le BoardManager
	board_manager = BoardManager.new()
	add_child(board_manager)
	board_manager.initialize(viewport_size, rack_manager.tile_size_rack)
	board_manager.create_board(self)
	
	# 4. Créer et initialiser le DragDropController
	drag_drop_controller = DragDropController.new()
	add_child(drag_drop_controller)
	drag_drop_controller.initialize(board_manager, rack_manager, tile_manager)
	
	# 5. Créer et initialiser le GameStateSync
	game_state_sync = GameStateSync.new()
	add_child(game_state_sync)
	game_state_sync.initialize(network_manager, self, board_manager, rack_manager, drag_drop_controller)
	
	# Connexion aux signaux de synchronisation
	game_state_sync.game_started.connect(_on_game_started)
	game_state_sync.my_turn_started.connect(_on_my_turn_started)
	game_state_sync.my_turn_ended.connect(_on_my_turn_ended)
	game_state_sync.game_ended.connect(_on_game_ended)
	
	# 6. Créer l'interface utilisateur
	_create_ui()
	
	print("✅ Jeu initialisé avec succès !")
	print("⏳ En attente du démarrage de la partie...")

# ============================================================================
# FONCTION : Créer l'interface utilisateur
# ============================================================================
func _create_ui() -> void:
	# Label de statut en haut de l'écran
	status_label = Label.new()
	status_label.position = Vector2(20, 10)
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.text = "En attente des autres joueurs..."
	add_child(status_label)
	
	# Label de tour (qui doit jouer)
	turn_label = Label.new()
	turn_label.position = Vector2(20, 40)
	turn_label.add_theme_font_size_override("font_size", 16)
	turn_label.text = ""
	add_child(turn_label)
	
	# Label de score
	score_label = Label.new()
	score_label.position = Vector2(viewport_size.x - 200, 10)
	score_label.add_theme_font_size_override("font_size", 18)
	score_label.text = "Score: 0"
	add_child(score_label)
	
	# Bouton "Jouer"
	play_button = Button.new()
	play_button.text = "✅ Jouer ce coup"
	play_button.position = Vector2(viewport_size.x - 350, viewport_size.y - 100)
	play_button.custom_minimum_size = Vector2(150, 40)
	play_button.disabled = true
	play_button.pressed.connect(_on_play_button_pressed)
	add_child(play_button)
	
	# Bouton "Passer"
	pass_button = Button.new()
	pass_button.text = "⏭️ Passer mon tour"
	pass_button.position = Vector2(viewport_size.x - 180, viewport_size.y - 100)
	pass_button.custom_minimum_size = Vector2(150, 40)
	pass_button.disabled = true
	pass_button.pressed.connect(_on_pass_button_pressed)
	add_child(pass_button)
	
	print("🖼️ Interface utilisateur créée")

# ============================================================================
# FONCTION : Gestion des entrées utilisateur
# ============================================================================
func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				drag_drop_controller.start_drag(event.position, self)
			else:
				drag_drop_controller.end_drag(event.position, self)
	
	elif event is InputEventMouseMotion:
		drag_drop_controller.update_drag(event.position)

# ============================================================================
# FONCTION : Mise à jour continue
# ============================================================================
func _process(_delta):
	# Mettre à jour l'affichage des scores
	if game_state_sync:
		_update_score_display()

# ============================================================================
# CALLBACKS RÉSEAU
# ============================================================================

func _on_game_started() -> void:
	"""Appelé quand la partie démarre"""
	status_label.text = "🎮 Partie en cours"
	print("🎮 La partie a commencé !")

func _on_my_turn_started() -> void:
	"""Appelé quand c'est notre tour de jouer"""
	turn_label.text = "✅ C'est votre tour !"
	turn_label.modulate = Color.GREEN
	status_label.text = "🎮 À vous de jouer !"
	
	# Activer les boutons
	play_button.disabled = false
	pass_button.disabled = false
	
	print("✅ C'est votre tour de jouer !")

func _on_my_turn_ended() -> void:
	"""Appelé quand notre tour se termine"""
	var current_player = game_state_sync.get_current_player_name()
	turn_label.text = "⏳ Tour de " + current_player
	turn_label.modulate = Color.YELLOW
	status_label.text = "⏳ En attente de " + current_player
	
	# Désactiver les boutons
	play_button.disabled = true
	pass_button.disabled = true
	
	print("⏳ Tour de ", current_player)

func _on_game_ended(winner_name: String) -> void:
	"""Appelé quand la partie se termine"""
	status_label.text = "🏁 Partie terminée !"
	turn_label.text = "🏆 Gagnant : " + winner_name
	turn_label.modulate = Color.GOLD
	
	# Désactiver les boutons
	play_button.disabled = true
	pass_button.disabled = true
	
	print("🏁 Partie terminée ! Gagnant : ", winner_name)
	
	# Afficher un popup avec les scores finaux
	_show_end_game_popup(winner_name)

# ============================================================================
# CALLBACKS UI
# ============================================================================

func _on_play_button_pressed() -> void:
	"""Appelé quand on clique sur le bouton Jouer"""
	print("🎯 Envoi du coup au serveur...")
	game_state_sync.send_move_to_server()
	
	# Désactiver temporairement les boutons
	play_button.disabled = true
	pass_button.disabled = true
	status_label.text = "📤 Envoi du coup..."

func _on_pass_button_pressed() -> void:
	"""Appelé quand on clique sur le bouton Passer"""
	print("⏭️ Passage du tour...")
	game_state_sync.pass_turn()
	
	# Désactiver temporairement les boutons
	play_button.disabled = true
	pass_button.disabled = true
	status_label.text = "⏭️ Tour passé..."

# ============================================================================
# FONCTION : Mettre à jour l'affichage des scores
# ============================================================================
func _update_score_display() -> void:
	"""Met à jour l'affichage du score"""
	var my_score = game_state_sync.get_my_score()
	var all_scores = game_state_sync.get_all_scores()
	
	# Afficher mon score
	score_label.text = "Mon score: " + str(my_score)
	
	# Afficher tous les scores en tooltip
	var tooltip_text = "Scores:\n"
	for score_data in all_scores:
		var prefix = "  " if not score_data.is_me else "► "
		tooltip_text += prefix + score_data.name + ": " + str(score_data.score) + "\n"
	
	score_label.tooltip_text = tooltip_text

# ============================================================================
# FONCTION : Afficher le popup de fin de partie
# ============================================================================
func _show_end_game_popup(winner_name: String) -> void:
	"""Affiche un popup avec les résultats de la partie"""
	
	# Créer un fond semi-transparent
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.size = viewport_size
	overlay.position = Vector2.ZERO
	add_child(overlay)
	
	# Créer le panel principal
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(400, 300)
	panel.position = (viewport_size - panel.custom_minimum_size) / 2
	overlay.add_child(panel)
	
	# Conteneur vertical
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(20, 20)
	vbox.size = panel.size - Vector2(40, 40)
	panel.add_child(vbox)
	
	# Titre
	var title = Label.new()
	title.text = "🏁 Partie Terminée !"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Gagnant
	var winner = Label.new()
	winner.text = "🏆 Gagnant : " + winner_name
	winner.add_theme_font_size_override("font_size", 20)
	winner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(winner)
	
	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer1)
	
	# Scores
	var scores_title = Label.new()
	scores_title.text = "Scores finaux :"
	scores_title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(scores_title)
	
	var all_scores = game_state_sync.get_all_scores()
	all_scores.sort_custom(func(a, b): return a.score > b.score)
	
	for score_data in all_scores:
		var score_line = Label.new()
		var prefix = "🥇 " if score_data == all_scores[0] else "   "
		score_line.text = prefix + score_data.name + " : " + str(score_data.score) + " points"
		score_line.add_theme_font_size_override("font_size", 16)
		vbox.add_child(score_line)
	
	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer2)
	
	# Bouton retour
	var back_button = Button.new()
	back_button.text = "Retour au menu"
	back_button.custom_minimum_size = Vector2(200, 40)
	back_button.pressed.connect(_on_back_to_menu)
	vbox.add_child(back_button)
	
	# Centrer le bouton
	var button_container = CenterContainer.new()
	button_container.add_child(back_button)
	vbox.add_child(button_container)

func _on_back_to_menu() -> void:
	"""Retour au menu principal"""
	network_manager.disconnect_from_server()
	get_tree().change_scene_to_file("res://login.tscn")

# ============================================================================
# FONCTIONS D'ANIMATION (héritées de la version locale)
# ============================================================================

func animate_to_board_view() -> void:
	board_manager.animate_to_board_view()
	
	var tween = rack_manager.rack_container.create_tween()
	tween.set_parallel(true)
	tween.tween_property(rack_manager.rack_container, "scale", Vector2(0.8, 0.8), 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_property(rack_manager.rack_container, "position:y", viewport_size.y - 60, 0.3).set_trans(Tween.TRANS_SINE)

func animate_to_rack_view() -> void:
	board_manager.animate_to_rack_view()
	
	var tween = rack_manager.rack_container.create_tween()
	tween.set_parallel(true)
	tween.tween_property(rack_manager.rack_container, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_property(rack_manager.rack_container, "position:y", viewport_size.y - rack_manager.tile_size_rack - 40, 0.3).set_trans(Tween.TRANS_SINE)

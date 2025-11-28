extends Node2D

# ============================================================================
# SCRABBLE GAME - VERSION MULTIJOUEUR AVEC STRUCTURE UI
# ============================================================================
# Version avec scène UI structurée similaire à Jetpack Compose
# ============================================================================

# --- MODULES DU JEU ---
var tile_manager: TileManager
var board_manager: BoardManager
var rack_manager: RackManager
var drag_drop_controller: DragDropController
var game_state_sync: GameStateSync
var move_validator: MoveValidator

# --- RÉFÉRENCES RÉSEAU ---
@onready var network_manager = $"/root/NetworkManager"

# --- VARIABLES GLOBALES ---$MainContainer/VBoxContainer/ScoreBoard/MarginContainer/HBoxContainer/StatusLabel
var viewport_size: Vector2

# --- RÉFÉRENCES UI (depuis la scène) ---
@onready var status_label = $MainContainer/VBoxContainer/ScoreBoard/MarginContainer/HBoxContainer/StatusLabel
@onready var turn_label = $MainContainer/VBoxContainer/ScoreBoard/MarginContainer/HBoxContainer/TurnLabel
@onready var score_label = $MainContainer/VBoxContainer/ScoreBoard/MarginContainer/HBoxContainer/ScoreLabel
@onready var validation_label = $MainContainer/VBoxContainer/ValidationPanel/MarginContainer/ValidationLabel
@onready var board_container = $MainContainer/VBoxContainer/BoardContainer
@onready var rack_container = $MainContainer/VBoxContainer/RackContainer
@onready var undo_button = $MainContainer/VBoxContainer/ActionButtons/MarginContainer/HBoxContainer/UndoButton
@onready var shuffle_button = $MainContainer/VBoxContainer/ActionButtons/MarginContainer/HBoxContainer/ShuffleButton
@onready var pass_button = $MainContainer/VBoxContainer/ActionButtons/MarginContainer/HBoxContainer/PassButton
@onready var play_button = $MainContainer/VBoxContainer/ActionButtons/MarginContainer/HBoxContainer/PlayButton

# ============================================================================
# FONCTION : Initialisation du jeu
# ============================================================================
func _ready():
	randomize()
	viewport_size = get_viewport_rect().size
	
	print("🎮 Démarrage du jeu de Scrabble (Mode Multijoueur - Structure UI)")
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
	
	# 2. Créer et initialiser le RackManager
	rack_manager = RackManager.new()
	add_child(rack_manager)
	rack_manager.initialize(viewport_size, tile_manager)
	
	# 3. Créer et initialiser le BoardManager
	board_manager = BoardManager.new()
	add_child(board_manager)
	board_manager.initialize(viewport_size, rack_manager.tile_size_rack)
	# On crée le plateau dans le conteneur de la scène
	board_manager.create_board(board_container)
	# On crée le chevalet dans le conteneur de la scène
	rack_manager.create_rack(rack_container)
	
	# 4. Créer et initialiser le MoveValidator
	move_validator = MoveValidator.new()
	add_child(move_validator)
	move_validator.initialize(board_manager)
	
	# 5. Créer et initialiser le DragDropController
	drag_drop_controller = DragDropController.new()
	add_child(drag_drop_controller)
	drag_drop_controller.initialize(board_manager, rack_manager, tile_manager)
	
	# 6. Créer et initialiser le GameStateSync
	game_state_sync = GameStateSync.new()
	add_child(game_state_sync)
	game_state_sync.initialize(network_manager, self, board_manager, rack_manager, drag_drop_controller)
	
	# Connexion aux signaux de synchronisation
	game_state_sync.game_started.connect(_on_game_started)
	game_state_sync.my_turn_started.connect(_on_my_turn_started)
	game_state_sync.my_turn_ended.connect(_on_my_turn_ended)
	game_state_sync.game_ended.connect(_on_game_ended)
	
	# 7. Connecter les boutons
	_connect_buttons()
	
	# 8. Initialiser l'UI
	_initialize_ui()
	
	print("✅ Jeu initialisé avec succès !")
	print("⏳ En attente du démarrage de la partie...")

# ============================================================================
# FONCTION : Connecter les boutons
# ============================================================================
func _connect_buttons() -> void:
	undo_button.pressed.connect(_on_undo_pressed)
	shuffle_button.pressed.connect(_on_shuffle_pressed)
	pass_button.pressed.connect(_on_pass_pressed)
	play_button.pressed.connect(_on_play_pressed)

# ============================================================================
# FONCTION : Initialiser l'UI
# ============================================================================
func _initialize_ui() -> void:
	status_label.text = "En attente des joueurs..."
	turn_label.text = ""
	score_label.text = "Score: 0"
	validation_label.text = ""
	validation_label.modulate = Color(1, 1, 1, 0)
	
	# Désactiver tous les boutons au départ
	undo_button.disabled = true
	shuffle_button.disabled = true
	pass_button.disabled = true
	play_button.disabled = true

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
				# Après le drop, valider le mouvement
				_validate_current_move()
	
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
# FONCTION : Valider le mouvement actuel
# ============================================================================
func _validate_current_move() -> void:
	var temp_tiles = drag_drop_controller.get_temp_tiles()
	
	if temp_tiles.is_empty():
		_hide_validation_ui()
		# Revenir à la vue chevalet si aucune tuile temporaire
		animate_to_rack_view()
		return
	
	# Valider le mouvement
	var validation_result = move_validator.validate_move(temp_tiles)
	
	# Afficher le résultat
	_show_validation_result(validation_result)

# ============================================================================
# FONCTION : Afficher le résultat de validation
# ============================================================================
func _show_validation_result(result: Dictionary) -> void:
	# Mettre à jour le label
	validation_label.text = move_validator.get_validation_message(result)
	
	if result.valid:
		validation_label.modulate = Color(0.2, 1.0, 0.2)  # Vert
		# Activer le bouton "Jouer" dès que le mouvement est valide
		play_button.disabled = false
		undo_button.disabled = false
	else:
		validation_label.modulate = Color(1.0, 0.3, 0.3)  # Rouge
		# Désactiver le bouton "Jouer" si le mouvement est invalide
		play_button.disabled = true
		undo_button.disabled = false
	
	# Animer l'apparition
	var tween = validation_label.create_tween()
	tween.tween_property(validation_label, "modulate:a", 1.0, 0.3)

# ============================================================================
# FONCTION : Cacher l'UI de validation
# ============================================================================
func _hide_validation_ui() -> void:
	var tween = validation_label.create_tween()
	tween.tween_property(validation_label, "modulate:a", 0.0, 0.3)
	undo_button.disabled = true

# ============================================================================
# FONCTION : Retourner les tuiles temporaires au chevalet
# ============================================================================
func _return_temp_tiles_to_rack() -> void:
	var temp_tiles = drag_drop_controller.get_temp_tiles().duplicate()
	
	for pos in temp_tiles:
		var tile_data = board_manager.get_tile_at(pos)
		var cell = board_manager.get_cell_at(pos)
		var tile_node = TileManager.get_tile_in_cell(cell)
		
		if tile_node and tile_data:
			# Trouver un emplacement vide dans le chevalet
			for i in range(ScrabbleConfig.RACK_SIZE):
				if rack_manager.get_tile_at(i) == null:
					# Animer le retour au chevalet
					_animate_tile_to_rack(tile_node, tile_data, i)
					board_manager.set_tile_at(pos, null)
					break
	
	# Vider la liste des tuiles temporaires
	drag_drop_controller.get_temp_tiles().clear()

# ============================================================================
# FONCTION : Animer le retour d'une tuile au chevalet
# ============================================================================
func _animate_tile_to_rack(tile_node: Panel, tile_data: Dictionary, rack_index: int) -> void:
	# Reparenter au jeu pour l'animation
	tile_node.reparent(self)
	tile_node.z_index = 100
	
	# Calculer la position cible
	var target_cell = rack_manager.get_cell_at(rack_index)
	var target_pos = target_cell.global_position + Vector2(2, 2)
	
	# Créer l'animation
	var tween = tile_node.create_tween()
	tween.set_parallel(true)
	
	# Animer la position
	tween.tween_property(tile_node, "global_position", target_pos, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Animer la taille
	var target_size = Vector2(rack_manager.tile_size_rack - 4, rack_manager.tile_size_rack - 4)
	tween.tween_property(tile_node, "custom_minimum_size", target_size, 0.3)
	
	# Repositionner les labels
	var letter_lbl = tile_node.get_node_or_null("LetterLabel")
	var value_lbl = tile_node.get_node_or_null("ValueLabel")
	if letter_lbl and value_lbl:
		tween.tween_property(letter_lbl, "position", Vector2(rack_manager.tile_size_rack * 0.2, rack_manager.tile_size_rack * 0.05), 0.3)
		tween.tween_property(value_lbl, "position", Vector2(rack_manager.tile_size_rack * 0.6, rack_manager.tile_size_rack * 0.55), 0.3)
	
	# Restaurer la couleur normale
	tween.tween_property(tile_node, "modulate", Color(1, 1, 1), 0.3)
	
	# À la fin de l'animation, reparenter correctement
	tween.finished.connect(func():
		tile_node.reparent(target_cell)
		tile_node.position = Vector2(2, 2)
		tile_node.z_index = 0
		tile_node.remove_meta("temp")
		rack_manager.add_tile_at(rack_index, tile_data)
	)

# ============================================================================
# CALLBACKS BOUTONS UI
# ============================================================================

func _on_undo_pressed() -> void:
	"""Annuler le coup en cours"""
	print("↶ Annulation du coup...")
	_return_temp_tiles_to_rack()
	_hide_validation_ui()
	animate_to_rack_view()

func _on_shuffle_pressed() -> void:
	"""Mélanger les tuiles du chevalet"""
	print("🔀 Mélange du chevalet...")
	# TODO: Implémenter le mélange
	pass

func _on_pass_pressed() -> void:
	"""Passer son tour"""
	print("⏭️ Passage du tour...")
	game_state_sync.pass_turn()
	
	# Désactiver temporairement les boutons
	play_button.disabled = true
	pass_button.disabled = true
	status_label.text = "⏭️ Tour passé..."

func _on_play_pressed() -> void:
	"""Jouer le coup (envoi au serveur)"""
	print("🎯 Envoi du coup au serveur...")
	game_state_sync.send_move_to_server()
	
	# Désactiver temporairement les boutons
	play_button.disabled = true
	pass_button.disabled = true
	undo_button.disabled = true
	status_label.text = "📤 Envoi du coup..."
	
	# Nettoyer les métadonnées des tuiles
	var temp_tiles = drag_drop_controller.get_temp_tiles()
	for pos in temp_tiles:
		var cell = board_manager.get_cell_at(pos)
		var tile_node = TileManager.get_tile_in_cell(cell)
		if tile_node:
			tile_node.remove_meta("temp")
			tile_node.modulate = Color(1, 1, 1)
	
	# Vider la liste des tuiles temporaires
	drag_drop_controller.get_temp_tiles().clear()

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
	
	# Activer les boutons appropriés
	shuffle_button.disabled = false
	pass_button.disabled = false
	# play_button sera activé automatiquement si un mouvement valide est placé
	play_button.disabled = true
	
	print("✅ C'est votre tour de jouer !")

func _on_my_turn_ended() -> void:
	"""Appelé quand notre tour se termine"""
	var current_player = game_state_sync.get_current_player_name()
	turn_label.text = "⏳ Tour de " + current_player
	turn_label.modulate = Color.YELLOW
	status_label.text = "⏳ En attente de " + current_player
	
	# Désactiver tous les boutons d'action
	play_button.disabled = true
	pass_button.disabled = true
	undo_button.disabled = true
	shuffle_button.disabled = true
	
	# Cacher l'UI de validation
	_hide_validation_ui()
	
	# Revenir à la vue chevalet
	animate_to_rack_view()
	
	print("⏳ Tour de ", current_player)

func _on_game_ended(winner_name: String) -> void:
	"""Appelé quand la partie se termine"""
	status_label.text = "🏁 Partie terminée !"
	turn_label.text = "🏆 Gagnant : " + winner_name
	turn_label.modulate = Color.GOLD
	
	# Désactiver tous les boutons
	play_button.disabled = true
	pass_button.disabled = true
	undo_button.disabled = true
	shuffle_button.disabled = true
	
	# Cacher l'UI de validation
	_hide_validation_ui()
	
	print("🏁 Partie terminée ! Gagnant : ", winner_name)
	
	# Afficher un popup avec les scores finaux
	_show_end_game_popup(winner_name)

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
# FONCTIONS D'ANIMATION
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

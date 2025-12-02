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
@onready var score_board_container = $CanvasLayer/MainContainer/VBoxContainer/ScoreBoard
@onready var validation_label = $CanvasLayer/MainContainer/VBoxContainer/ValidationPanel/MarginContainer/ValidationLabel
@onready var board_container = $CanvasLayer/MainContainer/VBoxContainer/BoardContainer
@onready var rack_container = $CanvasLayer/MainContainer/VBoxContainer/RackContainer
@onready var undo_button = $CanvasLayer/MainContainer/VBoxContainer/ActionButtons/MarginContainer/HBoxContainer/UndoButton
@onready var shuffle_button = $CanvasLayer/MainContainer/VBoxContainer/ActionButtons/MarginContainer/HBoxContainer/ShuffleButton
@onready var pass_button = $CanvasLayer/MainContainer/VBoxContainer/ActionButtons/MarginContainer/HBoxContainer/PassButton
@onready var play_button = $CanvasLayer/MainContainer/VBoxContainer/ActionButtons/MarginContainer/HBoxContainer/PlayButton

# ============================================================================
# FONCTION : Initialisation du jeu
# ============================================================================
func _ready():
	randomize()
	viewport_size = get_viewport_rect().size
	
	print("🎮 Démarrage du jeu de Scrabble (Mode Multijoueur - Structure UI)")
	
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
	
	# Forcer explicitement l'état unfocused après l'initialisation complète
	call_deferred("_force_initial_view")
	print("✅ Jeu initialisé avec succès ! après fiv")

func _force_initial_view() -> void:
	"""Force la vue initiale (unfocused) après l'initialisation"""
	board_manager.is_board_focused = true  # On triche : on dit qu'il est focused
	board_manager.animate_to_rack_view()   # Pour qu'il anime vers unfocused
	print("✅ Jeu initialisé avec succès ! in fiv")
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
	validation_label.text = ""
	validation_label.modulate = Color(1, 1, 1, 0)
	
	# Désactiver tous les boutons au départ
	undo_button.disabled = false
	shuffle_button.disabled = false
	pass_button.disabled = true
	play_button.disabled = true

	# Afficher un message d'attente dans le ScoreBoard
	_show_waiting_message()
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
				# Après le drop, valider le mouvement et pas de joker
				if not _has_unassigned_joker():
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
		undo_button.disabled = true
		# Revenir à la vue chevalet si aucune tuile temporaire
		animate_to_rack_view()
		return
	undo_button.disabled = false
	# Valider le mouvement
	var validation_result = move_validator.validate_move(temp_tiles)
	
	# Afficher le résultat
	_show_validation_result(validation_result)

# ============================================================================
# FONCTION : Afficher le résultat de validation (version finale)
# ============================================================================
func _show_validation_result(result: Dictionary) -> void:
	"""Affiche les mots avec couleurs et scores"""
	
	var message = ""
	
	# Cas 1 : Erreur de règle (pas de mots à afficher)
	if result.rule_error != "":
		message = "[color=#e74c3c]✗ %s[/color]" % result.rule_error
	
	# Cas 2 : Mots formés
	elif result.words.size() > 0:
		for word_info in result.words:
			if word_info.valid:
				# Mot valide : vert avec score
				message += "[color=#2ecc71]✓ %s[/color] [color=#95a5a6]%d pts[/color]\n" % [word_info.text, word_info.score]
			else:
				# Mot invalide : rouge sans score
				message += "[color=#e74c3c]✗ %s[/color]\n" % word_info.text
		
		# Bonus Scrabble
		if result.bonus_scrabble > 0:
			message += "[color=#f39c12]★ BONUS[/color] [color=#95a5a6]+50 pts[/color]\n"
		
		# Score total si valide
		if result.valid and result.total_score > 0:
			message += "[color=#bdc3c7]―――――――――[/color]\n"
			message += "[color=#27ae60][b]%d points[/b][/color]" % result.total_score
	
	# Cas 3 : Aucun mot (ne devrait pas arriver)
	else:
		message = "[color=#e74c3c]✗ Aucun mot formé[/color]"
	
	# Afficher
	validation_label.text = message
	validation_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	
	# Gestion des boutons
	if result.valid:
		play_button.disabled = not (game_state_sync and game_state_sync.is_my_turn)
		undo_button.disabled = false
	else:
		play_button.disabled = true
		undo_button.disabled = false

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
	print("  Retour de ", temp_tiles.size(), " tuile(s) au chevalet")
	for pos in temp_tiles:
		var tile_data = board_manager.get_tile_at(pos)
		var cell = board_manager.get_cell_at(pos)
		var tile_node = TileManager.get_tile_in_cell(cell)
		
		if tile_node and tile_data:
			# ✅ Réinitialiser le joker si c'en est un
			if tile_data.is_joker and tile_data.assigned_letter != null:
				tile_data.assigned_letter = null
				_reset_joker_visual(tile_node)
			# Trouver un emplacement vide dans le chevalet
			var placed = false
			for i in range(ScrabbleConfig.RACK_SIZE):
				if rack_manager.get_tile_at(i) == null:
					print("    Tuile ", tile_data.letter, " → chevalet[", i, "]")
					rack_manager.add_tile_at(i, tile_data)
					# Animer le retour au chevalet
					_animate_tile_to_rack(tile_node, tile_data, i)
					board_manager.set_tile_at(pos, null)
					placed = true
					break
			if not placed:
				print("    ⚠️ ERREUR : Pas de place dans le chevalet pour ", tile_data.letter)
		else:
			print("    ⚠️ Tuile manquante à la position ", pos)
	
	# Vider la liste des tuiles temporaires
	drag_drop_controller.get_temp_tiles().clear()
	print("  ✅ Toutes les tuiles rappelées")
	
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
		# rack_manager.add_tile_at(rack_index, tile_data)
	)

# ============================================================================
# CALLBACKS BOUTONS UI
# ============================================================================

func _on_undo_pressed() -> void:
	"""Rappeler les tuiles au chevalet"""
	print("↶ Rappel des tuiles au chevalet...")	
	# Vérifier qu'il y a des tuiles à rappeler
	var temp_tiles = drag_drop_controller.get_temp_tiles()	
	if temp_tiles.is_empty():
		print("  Aucune tuile à rappeler")
		return	
	print("  Rappel de ", temp_tiles.size(), " tuile(s)")	
	# Retourner les tuiles au chevalet
	_return_temp_tiles_to_rack()	
	# Cacher l'UI de validation
	_hide_validation_ui()	
	# Revenir à la vue chevalet
	animate_to_rack_view()	
	# Désactiver le bouton Play (plus de tuiles sur le plateau)
	play_button.disabled = true

func _on_shuffle_pressed() -> void:
	"""Mélanger les tuiles du chevalet"""
	print("🔀 Mélange du chevalet...")	
	# Mélanger le chevalet
	rack_manager.shuffle_rack()
	pass

func _on_pass_pressed() -> void:
	"""Passer son tour"""
	print("⏭️ Passage du tour...")
	game_state_sync.pass_turn()
	
	# Désactiver temporairement les boutons
	play_button.disabled = true
	pass_button.disabled = true

func _on_play_pressed() -> void:
	"""Jouer le coup (envoi au serveur)"""
	print("🎯 Envoi du coup au serveur...")
	game_state_sync.send_move_to_server()
	
	# Désactiver temporairement les boutons
	play_button.disabled = true
	pass_button.disabled = true
	undo_button.disabled = true
	
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
	print("🎮 La partie a commencé !")
	# Créer le tableau des scores
	_create_score_board()

func _on_my_turn_started() -> void:
	"""Appelé quand c'est notre tour de jouer"""
	# Activer les boutons appropriés
	shuffle_button.disabled = false
	pass_button.disabled = false
	# play_button sera activé automatiquement si un mouvement valide est placé
	play_button.disabled = true
	
	print("✅ C'est votre tour de jouer !")

func _on_my_turn_ended() -> void:
	"""Appelé quand notre tour se termine"""
	var current_player = game_state_sync.get_current_player_name()
	
	# Désactiver tous les boutons d'action
	play_button.disabled = true
	pass_button.disabled = true
	#undo_button.disabled = true
	#shuffle_button.disabled = true
	
	# Cacher l'UI de validation
	_hide_validation_ui()
	
	# Revenir à la vue chevalet
	animate_to_rack_view()
	
	print("⏳ Tour de ", current_player)

func _on_game_ended(winner_name: String) -> void:
	"""Appelé quand la partie se termine"""
	
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
	
	# Recréer le tableau des scores pour refléter les changements
	if game_state_sync and game_state_sync.current_game_state.has("players"):
		_create_score_board()

# ============================================================================
# FONCTION : Créer le tableau des scores (version horizontale)
# ============================================================================
func _create_score_board() -> void:
	"""Crée un tableau des scores horizontal avec cartes colorées"""
	
	# Supprimer l'ancien contenu
	for child in score_board_container.get_children():
		child.queue_free()
	
	# Créer un conteneur horizontal principal
	var main_hbox = HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 10)
	score_board_container.add_child(main_hbox)
	
	# Obtenir les scores de tous les joueurs
	var all_scores = game_state_sync.get_all_scores()
	
	# Trier par score décroissant
	all_scores.sort_custom(func(a, b): return a.score > b.score)
	
	# Créer une carte pour chaque joueur
	for score_data in all_scores:
		var player_card = _create_player_card_horizontal(score_data, all_scores)
		main_hbox.add_child(player_card)
	
	# Spacer pour pousser à gauche
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(spacer)

# ============================================================================
# FONCTION : Créer une carte joueur (version horizontale)
# ============================================================================
func _create_player_card_horizontal(score_data: Dictionary, all_scores: Array) -> PanelContainer:
	"""Crée une carte compacte avec bordures colorées pour un joueur"""
	
	# Conteneur principal avec bordure
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(120, 60)
	
	# Style du panel selon l'état
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	
	var current_player_name = game_state_sync.get_current_player_name()
	
	if score_data.name == current_player_name:
		# Joueur actif : fond vert + bordure épaisse
		style.bg_color = Color(0.85, 1.0, 0.85)
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.border_color = Color(0.3, 0.8, 0.3)
	elif score_data.is_me:
		# Nous : fond bleu
		style.bg_color = Color(0.85, 0.92, 1.0)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.4, 0.6, 1.0)
	else:
		# Autres : fond gris
		style.bg_color = Color(0.95, 0.95, 0.95)
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.7, 0.7, 0.7)
	
	panel.add_theme_stylebox_override("panel", style)
	
	# Conteneur vertical pour nom + score
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)
	
	# Nom du joueur
	var name_label = Label.new()
	name_label.text = score_data.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.8))
	
	# Mettre en couleur si c'est nous
	if score_data.is_me:
		name_label.text = "Moi"
		name_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.8))
	
	vbox.add_child(name_label)
	
	# Conteneur horizontal pour indicateur + score
	var score_hbox = HBoxContainer.new()
	score_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(score_hbox)
	
	# Indicateur du joueur actif
	if score_data.name == current_player_name:
		var indicator = Label.new()
		indicator.text = "⬤"  # Point lumineux
		indicator.add_theme_font_size_override("font_size", 12)
		indicator.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
		score_hbox.add_child(indicator)
	
	# Score
	var score_label = Label.new()
	score_label.text = str(score_data.score)
	score_label.add_theme_font_size_override("font_size", 18)
	score_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	score_hbox.add_child(score_label)
	
	# Unité "pts"
	var pts_label = Label.new()
	pts_label.text = " pts"
	pts_label.add_theme_font_size_override("font_size", 10)
	pts_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	score_hbox.add_child(pts_label)
	
	# Médaille pour le leader
	if all_scores.size() > 0 and all_scores[0] == score_data and score_data.score > 0:
		var medal = Label.new()
		medal.text = "🏆"
		medal.add_theme_font_size_override("font_size", 14)
		score_hbox.add_child(medal)
	
	return panel
# ============================================================================
# FONCTION : Afficher un message d'attente
# ============================================================================
func _show_waiting_message() -> void:
	"""Affiche un message pendant l'attente des joueurs"""
	
	# Nettoyer le conteneur
	for child in score_board_container.get_children():
		child.queue_free()
	
	# Créer un label centré
	var center = CenterContainer.new()
	score_board_container.add_child(center)
	
	var label = Label.new()
	label.text = "⏳ Chargement ..."
	label.add_theme_font_size_override("font_size", 18)
	center.add_child(label)
# ============================================================================
# FONCTION : Afficher le popup de fin de partie
# ============================================================================
func _show_end_game_popup(winner_name: String) -> void:
	"""Affiche un popup avec les résultats de la partie"""
		# Chercher le CanvasLayer parent
	var canvas_layer = get_node_or_null("CanvasLayer")
	
	if not canvas_layer:
		print("❌ ERREUR : CanvasLayer introuvable !")
		return
	# Créer un fond semi-transparent
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.size = viewport_size
	overlay.position = Vector2.ZERO
	canvas_layer.add_child(overlay)
	
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
	get_tree().change_scene_to_file("res://scenes/login.tscn")

# ============================================================================
# FONCTION : Créer le popup de sélection de lettre pour joker
# ============================================================================
func _create_joker_letter_popup(joker_pos: Vector2i, tile_node: Panel) -> void:
	"""Affiche un popup pour choisir la lettre du joker"""
	
	print("🃏 Sélection de lettre pour joker à la position ", joker_pos)
	# Chercher le CanvasLayer parent
	var canvas_layer = get_node_or_null("CanvasLayer")
	
	if not canvas_layer:
		print("❌ ERREUR : CanvasLayer introuvable !")
		return
	
	# Créer un fond semi-transparent
	var overlay = ColorRect.new()
	overlay.name = "JokerOverlay"
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.size = viewport_size
	overlay.position = Vector2.ZERO
	canvas_layer.add_child(overlay)  # ✅ Ajouter au CanvasLayer existant
	
	# Créer le panel principal
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(400, 300)
	panel.position = (viewport_size - panel.custom_minimum_size) / 2
	overlay.add_child(panel)
	
	# Conteneur vertical
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(20, 20)
	vbox.size = panel.size - Vector2(40, 40)
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	# Titre
	var title = Label.new()
	title.text = "🃏 Choisissez une lettre pour le joker"
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Grille de lettres (3 lignes de ~9 lettres)
	var letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	var grid_container = GridContainer.new()
	grid_container.columns = 9
	grid_container.add_theme_constant_override("h_separation", 5)
	grid_container.add_theme_constant_override("v_separation", 5)
	vbox.add_child(grid_container)
	
	# Créer un bouton pour chaque lettre
	for letter in letters:
		var button = Button.new()
		button.text = letter
		button.custom_minimum_size = Vector2(40, 40)
		button.add_theme_font_size_override("font_size", 18)
		
		# Connecter le clic
		button.pressed.connect(func():
			_on_joker_letter_selected(letter, joker_pos, tile_node, overlay)
		)
		
		grid_container.add_child(button)
	
	# Bouton Annuler
	var cancel_button = Button.new()
	cancel_button.text = "Annuler"
	cancel_button.custom_minimum_size = Vector2(150, 40)
	cancel_button.pressed.connect(func():
		_on_joker_selection_cancelled(joker_pos, tile_node, overlay)
	)
	
	# Centrer le bouton
	var button_center = CenterContainer.new()
	button_center.add_child(cancel_button)
	vbox.add_child(button_center)

# ============================================================================
# FONCTION : Callback quand une lettre est sélectionnée
# ============================================================================
func _on_joker_letter_selected(letter: String, joker_pos: Vector2i, tile_node: Panel, overlay: ColorRect) -> void:
	print("✅ Lettre sélectionnée pour joker : ", letter)
	
	# Récupérer les données de la tuile
	var tile_data = board_manager.get_tile_at(joker_pos)
	if tile_data:
		# Assigner la lettre
		tile_data.assigned_letter = letter
		
		# Mettre à jour l'affichage visuel
		_update_joker_visual(tile_node, letter)
	
	# Fermer le popup
	overlay.queue_free()
	
	# Revalider le mouvement
	_validate_current_move()

# ============================================================================
# FONCTION : Callback si l'utilisateur annule
# ============================================================================
func _on_joker_selection_cancelled(joker_pos: Vector2i, tile_node: Panel, overlay: ColorRect) -> void:
	print("❌ Sélection annulée, retour du joker au chevalet")
	
	# Retirer le joker du plateau
	var tile_data = board_manager.get_tile_at(joker_pos)
	board_manager.set_tile_at(joker_pos, null)
	
	# Retirer de la liste des temp_tiles
	drag_drop_controller.get_temp_tiles().erase(joker_pos)
	
	# Remettre au chevalet
	if tile_data:
		for i in range(ScrabbleConfig.RACK_SIZE):
			if rack_manager.get_tile_at(i) == null:
				rack_manager.add_tile_at(i, tile_data)
				_animate_tile_to_rack(tile_node, tile_data, i)
				break
	
	# Fermer le popup
	overlay.queue_free()
	
	# Revalider
	_validate_current_move()
	
	# ============================================================================
# FONCTION : Vérifier s'il y a un joker sans lettre assignée
# ============================================================================
func _has_unassigned_joker() -> bool:
	"""Vérifie si au moins un joker temporaire n'a pas de lettre assignée"""
	var temp_tiles = drag_drop_controller.get_temp_tiles()
	
	for pos in temp_tiles:
		var tile_data = board_manager.get_tile_at(pos)
		if tile_data and tile_data.is_joker and tile_data.assigned_letter == null:
			return true
	
	return false
	
# ============================================================================
# FONCTION : Réinitialiser l'affichage visuel d'un joker
# ============================================================================
func _reset_joker_visual(tile_node: Panel) -> void:
	"""Remet le joker à son affichage d'origine (?)"""
	
	var letter_lbl = tile_node.get_node_or_null("LetterLabel")
	if letter_lbl:
		letter_lbl.text = "?"
	
	# Supprimer l'indicateur si existant
	var joker_indicator = tile_node.get_node_or_null("JokerIndicator")
	if joker_indicator:
		joker_indicator.queue_free()
# ============================================================================
# FONCTION : Mettre à jour l'affichage visuel d'un joker
# ============================================================================
func _update_joker_visual(tile_node: Panel, assigned_letter: String) -> void:
	"""Met à jour l'affichage pour montrer la lettre assignée"""
	
	var letter_lbl = tile_node.get_node_or_null("LetterLabel")
	
	if letter_lbl:
		# Afficher la lettre assignée en plus petit + le "?"
		letter_lbl.text = assigned_letter
		
		# Ajouter un petit "?" en coin pour indiquer que c'est un joker
		#var joker_indicator = tile_node.get_node_or_null("JokerIndicator")
		#if not joker_indicator:
			#joker_indicator = Label.new()
			#joker_indicator.name = "JokerIndicator"
			#joker_indicator.text = "?"
			#joker_indicator.add_theme_font_size_override("font_size", int(board_manager.tile_size_board * 0.2))
			#joker_indicator.position = Vector2(board_manager.tile_size_board * 0.05, board_manager.tile_size_board * 0.7)
			#joker_indicator.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			#tile_node.add_child(joker_indicator)

# ============================================================================
# FONCTION : Afficher une erreur serveur
# ============================================================================
func _show_server_error(error_message: String) -> void:
	"""Affiche un popup avec l'erreur du serveur"""
	
	print("🚨 Affichage erreur serveur : ", error_message)
	
	# Utiliser le même système que le popup de fin de partie
	var canvas_layer = get_node_or_null("CanvasLayer")
	if not canvas_layer:
		return
	
	# Créer un fond semi-transparent
	var overlay = ColorRect.new()
	overlay.name = "ErrorOverlay"
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.size = viewport_size
	overlay.position = Vector2.ZERO
	canvas_layer.add_child(overlay)
	
	# Créer le panel principal
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(400, 200)
	panel.position = (viewport_size - panel.custom_minimum_size) / 2
	overlay.add_child(panel)
	
	# Conteneur vertical
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(20, 20)
	vbox.size = panel.size - Vector2(40, 40)
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	# Titre
	var title = Label.new()
	title.text = "❌ Erreur"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	vbox.add_child(title)
	
	# Message d'erreur
	var message = Label.new()
	message.text = error_message
	message.add_theme_font_size_override("font_size", 16)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size = Vector2(360, 0)
	vbox.add_child(message)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)
	
	# Bouton OK
	var ok_button = Button.new()
	ok_button.text = "OK"
	ok_button.custom_minimum_size = Vector2(150, 40)
	ok_button.pressed.connect(func():
		overlay.queue_free()
	)
	
	# Centrer le bouton
	var button_center = CenterContainer.new()
	button_center.add_child(ok_button)
	vbox.add_child(button_center)

# ============================================================================
# FONCTIONS D'ANIMATION
# ============================================================================

func animate_to_board_view() -> void:
	board_manager.animate_to_board_view()
	
	#var tween = rack_manager.rack_container.create_tween()
	#tween.set_parallel(true)
	#tween.tween_property(rack_manager.rack_container, "scale", Vector2(0.8, 0.8), 0.3).set_trans(Tween.TRANS_SINE)
	#tween.tween_property(rack_manager.rack_container, "position:y", viewport_size.y - 60, 0.3).set_trans(Tween.TRANS_SINE)

func animate_to_rack_view() -> void:
	board_manager.animate_to_rack_view()
	
	#var tween = rack_manager.rack_container.create_tween()
	#tween.set_parallel(true)
	#tween.tween_property(rack_manager.rack_container, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_SINE)
	#tween.tween_property(rack_manager.rack_container, "position:y", viewport_size.y - rack_manager.tile_size_rack - 40, 0.3).set_trans(Tween.TRANS_SINE)

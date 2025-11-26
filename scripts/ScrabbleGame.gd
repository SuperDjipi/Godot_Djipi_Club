extends Node2D

# ============================================================================
# SCRABBLE GAME - ORCHESTRATEUR PRINCIPAL
# ============================================================================
# Ce fichier est le point d'entrée principal du jeu.
# Il coordonne tous les modules et gère les interactions de haut niveau.
# ============================================================================

# --- MODULES DU JEU ---
var tile_manager: TileManager
var board_manager: BoardManager
var rack_manager: RackManager
var drag_drop_controller: DragDropController

# --- VARIABLES GLOBALES ---
var viewport_size: Vector2

# ============================================================================
# FONCTION : Initialisation du jeu
# ============================================================================
func _ready():
	randomize()
	viewport_size = get_viewport_rect().size
	
	print("🎮 Démarrage du jeu de Scrabble")
	print("📱 Taille de l'écran : ", viewport_size)
	
	# 1. Créer et initialiser le TileManager
	tile_manager = TileManager.new()
	add_child(tile_manager)
	tile_manager.init_tile_bag()
	
	# 2. Créer et initialiser le RackManager (AVANT le BoardManager !)
	rack_manager = RackManager.new()
	add_child(rack_manager)
	rack_manager.initialize(viewport_size, tile_manager)
	rack_manager.create_rack(self)
	
	# 3. Créer et initialiser le BoardManager (APRÈS le RackManager)
	# On passe la taille des tuiles du chevalet pour que le plateau focused ait la même taille
	board_manager = BoardManager.new()
	add_child(board_manager)
	board_manager.initialize(viewport_size, rack_manager.tile_size_rack)
	board_manager.create_board(self)
	
	# 4. Créer et initialiser le DragDropController
	drag_drop_controller = DragDropController.new()
	add_child(drag_drop_controller)
	drag_drop_controller.initialize(board_manager, rack_manager, tile_manager)
	
	# 5. Remplir le chevalet initial
	rack_manager.fill_rack()
	
	print("✅ Jeu initialisé avec succès !")

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
# FONCTION : Animer vers la vue plateau (appelée depuis le RackManager)
# ============================================================================
func animate_to_board_view() -> void:
	board_manager.animate_to_board_view()
	
	# Animer aussi le chevalet
	var tween = rack_manager.rack_container.create_tween()
	tween.set_parallel(true)
	tween.tween_property(rack_manager.rack_container, "scale", Vector2(0.8, 0.8), 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_property(rack_manager.rack_container, "position:y", viewport_size.y - 60, 0.3).set_trans(Tween.TRANS_SINE)

# ============================================================================
# FONCTION : Animer vers la vue chevalet (appelée depuis le BoardManager)
# ============================================================================
func animate_to_rack_view() -> void:
	board_manager.animate_to_rack_view()
	
	# Animer aussi le chevalet
	var tween = rack_manager.rack_container.create_tween()
	tween.set_parallel(true)
	tween.tween_property(rack_manager.rack_container, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_property(rack_manager.rack_container, "position:y", viewport_size.y - rack_manager.tile_size_rack - 40, 0.3).set_trans(Tween.TRANS_SINE)

# ============================================================================
# FONCTIONS FUTURES POUR LE MULTIJOUEUR
# ============================================================================

# TODO: Fonction pour envoyer un coup au serveur
func send_move_to_server() -> void:
	var temp_tiles = drag_drop_controller.get_temp_tiles()
	if temp_tiles.is_empty():
		print("⚠️ Aucune tuile à envoyer")
		return
	
	print("📤 Envoi du coup au serveur...")
	# Ici on enverra les données via WebSocket
	pass

# TODO: Fonction pour recevoir un état de jeu du serveur
func receive_game_state(game_state: Dictionary) -> void:
	print("📥 Réception de l'état du jeu...")
	# Mettre à jour le plateau et les chevalets
	pass

# TODO: Fonction pour se connecter au serveur
func connect_to_server(game_id: String, player_id: String) -> void:
	print("🔌 Connexion au serveur...")
	# Établir la connexion WebSocket
	pass

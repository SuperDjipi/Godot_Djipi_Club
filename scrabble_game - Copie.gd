extends Node2D

# Configuration du jeu
const BOARD_SIZE = 15
const TILE_SIZE = 40
const RACK_SIZE = 7

# Couleurs des cases bonus
const COLOR_NORMAL = Color(0.8, 0.8, 0.7)
const COLOR_LETTER_DOUBLE = Color(0.6, 0.8, 1.0)
const COLOR_LETTER_TRIPLE = Color(0.2, 0.5, 1.0)
const COLOR_WORD_DOUBLE = Color(1.0, 0.8, 0.8)
const COLOR_WORD_TRIPLE = Color(1.0, 0.3, 0.3)
const COLOR_CENTER = Color(1.0, 0.8, 1.0)

# Distribution des lettres en français
const LETTER_DISTRIBUTION = {
	"A": {"count": 9, "value": 1}, "B": {"count": 2, "value": 3},
	"C": {"count": 2, "value": 3}, "D": {"count": 3, "value": 2},
	"E": {"count": 15, "value": 1}, "F": {"count": 2, "value": 4},
	"G": {"count": 2, "value": 2}, "H": {"count": 2, "value": 4},
	"I": {"count": 8, "value": 1}, "J": {"count": 1, "value": 8},
	"K": {"count": 1, "value": 10}, "L": {"count": 5, "value": 1},
	"M": {"count": 3, "value": 2}, "N": {"count": 6, "value": 1},
	"O": {"count": 6, "value": 1}, "P": {"count": 2, "value": 3},
	"Q": {"count": 1, "value": 8}, "R": {"count": 6, "value": 1},
	"S": {"count": 6, "value": 1}, "T": {"count": 6, "value": 1},
	"U": {"count": 6, "value": 1}, "V": {"count": 2, "value": 4},
	"W": {"count": 1, "value": 10}, "X": {"count": 1, "value": 10},
	"Y": {"count": 1, "value": 10}, "Z": {"count": 1, "value": 10},
	"?": {"count": 2, "value": 0}  # Jokers
}

# Variables globales
var viewport_size : Vector2
const BOARD_PADDING = 20
var tile_size = 40.0
var board = []
var rack = []
var tile_bag = []
var dragging_tile = null
var drag_origin = null
var board_cells = []
var rack_cells = []
var temp_tiles = []

var board_container: Control
var rack_container: Control
var tile_size_board = 40.0
var tile_size_rack = 70.0
var board_scale_focused = 1.0
var board_scale_unfocused = 0.7
var is_board_focused = false

# Variables pour le déplacement du plateau
var is_dragging_board = false
var board_drag_start_pos = Vector2.ZERO
var board_initial_pos = Vector2.ZERO
var board_min_x = 0.0
var board_max_x = 0.0

# Variables pour le défilement automatique
const AUTO_SCROLL_MARGIN = 80.0  # Distance depuis le bord pour déclencher le scroll
const AUTO_SCROLL_SPEED = 8.0     # Vitesse du défilement automatique
var current_mouse_pos = Vector2.ZERO  # Position actuelle de la souris

# Positions bonus sur le plateau
var bonus_map = {}

func _ready():
	randomize()
	viewport_size = get_viewport_rect().size
	var board_width = viewport_size.x - (BOARD_PADDING)
	tile_size = floor(board_width / (BOARD_SIZE + 0.5))
	tile_size_board = tile_size_rack

	print("Taille tuile plateau: ", tile_size_board, " | Taille tuile chevalet: ", tile_size_rack)
	print("variables : ", viewport_size, board_width, tile_size)
	
	setup_bonus_map()
	init_tile_bag()
	create_board()
	create_rack()
	
	var total_board_pixel_size = BOARD_SIZE * (tile_size_board + 2)
	board_scale_unfocused = board_width / total_board_pixel_size
	board_container.scale = Vector2(board_scale_unfocused, board_scale_unfocused)
	
	# Calculer les limites de déplacement du plateau
	calculate_board_limits()
	
	fill_rack()

func calculate_board_limits():
	# Calculer la largeur réelle du plateau à l'échelle 1.0
	var total_board_pixel_size = BOARD_SIZE * (tile_size_board + 2)
	
	# Limites quand le plateau est agrandi (scale = 1.0)
	# On veut que les bords du plateau puissent atteindre le centre de l'écran
	board_max_x = viewport_size.x / 2  # Limite droite
	board_min_x = viewport_size.x / 2 - total_board_pixel_size  # Limite gauche
	
	print("Board limits: min_x=", board_min_x, " max_x=", board_max_x)

func setup_bonus_map():
	for pos in [Vector2i(0,0), Vector2i(0,7), Vector2i(0,14), Vector2i(7,0), 
				Vector2i(7,14), Vector2i(14,0), Vector2i(14,7), Vector2i(14,14)]:
		bonus_map[pos] = "W3"
	
	for i in range(1, 5):
		for pos in [Vector2i(i,i), Vector2i(i,14-i), Vector2i(14-i,i), Vector2i(14-i,14-i)]:
			bonus_map[pos] = "W2"
	
	for pos in [Vector2i(1,5), Vector2i(1,9), Vector2i(5,1), Vector2i(5,5),
				Vector2i(5,9), Vector2i(5,13), Vector2i(9,1), Vector2i(9,5),
				Vector2i(9,9), Vector2i(9,13), Vector2i(13,5), Vector2i(13,9)]:
		bonus_map[pos] = "L3"
	
	for pos in [Vector2i(0,3), Vector2i(0,11), Vector2i(2,6), Vector2i(2,8),
				Vector2i(3,0), Vector2i(3,7), Vector2i(3,14), Vector2i(6,2),
				Vector2i(6,6), Vector2i(6,8), Vector2i(6,12), Vector2i(7,3),
				Vector2i(7,11), Vector2i(8,2), Vector2i(8,6), Vector2i(8,8),
				Vector2i(8,12), Vector2i(11,0), Vector2i(11,7), Vector2i(11,14),
				Vector2i(12,6), Vector2i(12,8), Vector2i(14,3), Vector2i(14,11)]:
		bonus_map[pos] = "L2"
	
	bonus_map[Vector2i(7,7)] = "CENTER"

func init_tile_bag():
	for letter in LETTER_DISTRIBUTION:
		var data = LETTER_DISTRIBUTION[letter]
		for i in range(data.count):
			tile_bag.append({"letter": letter, "value": data.value})
	tile_bag.shuffle()

func create_board():
	board_container = Control.new()
	add_child(board_container)
	var total_board_pixel_size = BOARD_SIZE * (tile_size_board + 2)
	var start_x = (viewport_size.x - total_board_pixel_size) / 2
	board_container.position = Vector2(start_x, 80)
	board_container.pivot_offset = Vector2(total_board_pixel_size / 2, total_board_pixel_size / 2)
	
	for y in range(BOARD_SIZE):
		board.append([])
		board_cells.append([])
		for x in range(BOARD_SIZE):
			board[y].append(null)
			var cell = create_cell(Vector2i(x, y), true, tile_size_board)
			board_container.add_child(cell)
			board_cells[y].append(cell)

func create_rack():
	rack_container = Control.new()
	add_child(rack_container)
	var total_rack_pixel_size = Vector2(RACK_SIZE * (tile_size_rack + 2), tile_size_rack)
	var start_x = (viewport_size.x - total_rack_pixel_size.x) / 2
	rack_container.position = Vector2(start_x, viewport_size.y - tile_size_rack - 40)
	rack_container.pivot_offset = total_rack_pixel_size / 2
	
	for i in range(RACK_SIZE):
		rack.append(null)
		var cell = create_cell(i, false, tile_size_rack)
		rack_container.add_child(cell)
		rack_cells.append(cell)

func create_cell(pos, is_board: bool, tile_size_arg: float):
	var cell = Panel.new()
	cell.custom_minimum_size = Vector2(tile_size_arg, tile_size_arg)
	
	if is_board:
		cell.position = Vector2(pos.x * (tile_size_arg + 2), pos.y * (tile_size_arg + 2))
		var bonus = bonus_map.get(pos, "")
		match bonus:
			"W3": cell.modulate = COLOR_WORD_TRIPLE
			"W2": cell.modulate = COLOR_WORD_DOUBLE
			"L3": cell.modulate = COLOR_LETTER_TRIPLE
			"L2": cell.modulate = COLOR_LETTER_DOUBLE
			"CENTER": cell.modulate = COLOR_CENTER
			_: cell.modulate = COLOR_NORMAL
		
		if bonus and bonus != "CENTER":
			var lbl = Label.new()
			lbl.text = bonus
			lbl.add_theme_font_size_override("font_size", 10)
			lbl.position = Vector2(5, 10)
			cell.add_child(lbl)
	else:
		cell.position = Vector2(pos * (tile_size_arg + 2), 0)
		cell.modulate = Color(0.9, 0.9, 0.8)
	
	return cell

func fill_rack():
	for i in range(RACK_SIZE):
		if rack[i] == null and tile_bag.size() > 0:
			var tile_data = tile_bag.pop_back()
			rack[i] = tile_data
			create_tile_visual(tile_data, rack_cells[i], tile_size_rack)

func create_tile_visual(tile_data, parent, tile_size_arg: float):
	var tile = Panel.new()
	tile.custom_minimum_size = Vector2(tile_size_arg - 4, tile_size_arg - 4)
	tile.position = Vector2(2, 2)
	tile.modulate = Color(0.95, 0.9, 0.7)
	
	var letter_lbl = Label.new()
	letter_lbl.name = "LetterLabel"
	letter_lbl.text = tile_data.letter
	letter_lbl.add_theme_font_size_override("font_size", int(tile_size_arg * 0.5))
	letter_lbl.position = Vector2(tile_size_arg * 0.2, tile_size_arg * 0.05)
	tile.add_child(letter_lbl)
	
	var value_lbl = Label.new()
	value_lbl.name = "ValueLabel"
	value_lbl.text = str(tile_data.value)
	value_lbl.add_theme_font_size_override("font_size", int(tile_size_arg * 0.25))
	value_lbl.position = Vector2(tile_size_arg * 0.6, tile_size_arg * 0.55)
	tile.add_child(value_lbl)
	
	tile.set_meta("tile_data", tile_data)
	parent.add_child(tile)
	return tile

func _process(_delta):
	# Défilement automatique continu quand on drag une tuile
	if dragging_tile and is_board_focused:
		auto_scroll_board(current_mouse_pos)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				start_drag(event.position)
			else:
				end_drag(event.position)
	
	elif event is InputEventMouseMotion:
		current_mouse_pos = event.position  # Toujours mettre à jour la position
		
		if dragging_tile:
			var target_size = Vector2(tile_size_board, tile_size_board)
			dragging_tile.global_position = event.position - target_size / 2
		elif is_dragging_board:
			# Déplacer le plateau
			var delta = event.position - board_drag_start_pos
			var new_x = board_initial_pos.x + delta.x
			
			# Appliquer les limites
			new_x = clamp(new_x, board_min_x, board_max_x)
			
			board_container.position.x = new_x

func auto_scroll_board(mouse_pos: Vector2):
	"""Fait défiler le plateau automatiquement quand la tuile approche les bords"""
	var scroll_delta = 0.0
	
	# Vérifier le bord gauche
	if mouse_pos.x < AUTO_SCROLL_MARGIN:
		# Plus on est proche du bord, plus on scrolle vite
		var intensity = 1.0 - (mouse_pos.x / AUTO_SCROLL_MARGIN)
		scroll_delta = AUTO_SCROLL_SPEED * intensity
		
	# Vérifier le bord droit
	elif mouse_pos.x > viewport_size.x - AUTO_SCROLL_MARGIN:
		var distance_from_right = viewport_size.x - mouse_pos.x
		var intensity = 1.0 - (distance_from_right / AUTO_SCROLL_MARGIN)
		scroll_delta = -AUTO_SCROLL_SPEED * intensity
	
	# Appliquer le défilement s'il y en a un
	if scroll_delta != 0.0:
		var new_x = board_container.position.x + scroll_delta
		new_x = clamp(new_x, board_min_x, board_max_x)
		board_container.position.x = new_x

func start_drag(pos: Vector2):
	print("=== Start drag at position:", pos)
	
	# Vérifier le chevalet
	for i in range(RACK_SIZE):
		var cell = rack_cells[i]
		var cell_rect = Rect2(cell.global_position, cell.size * rack_container.scale)
		if cell_rect.has_point(pos) and rack[i]:
			var tile_node = get_tile_in_cell(cell)
			if tile_node:
				print("  -> Found tile in rack at index", i, "letter:", tile_node.get_meta("tile_data").letter)
				dragging_tile = tile_node
				drag_origin = {"type": "rack", "pos": i}
				rack[i] = null
				
				if not is_board_focused:
					animate_to_board_view()
				
				var tile_tween = create_tween()
				var target_size = Vector2(tile_size_board - 4, tile_size_board - 4)
				tile_tween.tween_property(dragging_tile, "custom_minimum_size", target_size, 0.2)
				
				var letter_lbl = dragging_tile.get_node_or_null("LetterLabel")
				var value_lbl = dragging_tile.get_node_or_null("ValueLabel")
				if letter_lbl and value_lbl:
					tile_tween.tween_property(letter_lbl, "position", Vector2(tile_size_board * 0.2, tile_size_board * 0.05), 0.2)
					tile_tween.tween_property(value_lbl, "position", Vector2(tile_size_board * 0.6, tile_size_board * 0.55), 0.2)
				
				dragging_tile.reparent(self)
				dragging_tile.z_index = 100
				return
	
	# Vérifier le plateau
	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			var cell = board_cells[y][x]
			var cell_rect = Rect2(cell.global_position, cell.size * board_container.scale)
			if cell_rect.has_point(pos) and board[y][x]:
				var tile_node = get_tile_in_cell(cell)
				if tile_node and tile_node.has_meta("temp"):
					print("  -> Found temp tile on board at", x, ",", y)
					dragging_tile = tile_node
					drag_origin = {"type": "board", "pos": Vector2i(x, y)}
					board[y][x] = null
					temp_tiles.erase(Vector2i(x, y))
					
					dragging_tile.reparent(self)
					dragging_tile.z_index = 100
					return
	
	# Si on clique sur le plateau sans tuile et qu'on est en mode focus, démarrer le drag du plateau
	if is_board_focused:
		var board_rect = Rect2(board_container.global_position, 
							   Vector2(BOARD_SIZE * (tile_size_board + 2), 
									   BOARD_SIZE * (tile_size_board + 2)) * board_container.scale)
		if board_rect.has_point(pos):
			print("  -> Starting board drag")
			is_dragging_board = true
			board_drag_start_pos = pos
			board_initial_pos = board_container.position
			return
	
	print("  -> No tile found at this position")

func end_drag(pos: Vector2):
	# Arrêter le drag du plateau
	if is_dragging_board:
		is_dragging_board = false
		print("  -> Board drag ended")
		return
	
	if not dragging_tile:
		return
	
	print("=== End drag at position:", pos)
	var dropped = false
	
	# Essayer de déposer sur le chevalet
	for i in range(RACK_SIZE):
		var cell = rack_cells[i]
		var cell_rect = Rect2(cell.global_position, cell.size * rack_container.scale)
		if cell_rect.has_point(pos):
			if rack[i] == null:
				print("  -> Dropping on rack at index", i)
				rack[i] = dragging_tile.get_meta("tile_data")
				var tween = create_tween()
				var target_size = Vector2(tile_size_rack - 4, tile_size_rack - 4)
				tween.tween_property(dragging_tile, "custom_minimum_size", target_size, 0.2)
				
				var letter_lbl = dragging_tile.get_node_or_null("LetterLabel")
				var value_lbl = dragging_tile.get_node_or_null("ValueLabel")
				if letter_lbl and value_lbl:
					tween.tween_property(letter_lbl, "position", Vector2(tile_size_rack * 0.2, tile_size_rack * 0.05), 0.2)
					tween.tween_property(value_lbl, "position", Vector2(tile_size_rack * 0.6, tile_size_rack * 0.55), 0.2)
				
				dragging_tile.reparent(cell)
				dragging_tile.position = Vector2(2, 2)
				dragging_tile.z_index = 0
				dragging_tile.remove_meta("temp")
				dropped = true
				break
	
	# Essayer de déposer sur le plateau
	if not dropped:
		for y in range(BOARD_SIZE):
			for x in range(BOARD_SIZE):
				var cell = board_cells[y][x]
				var cell_rect = Rect2(cell.global_position, cell.size * board_container.scale)
				if cell_rect.has_point(pos):
					if board[y][x] == null:
						print("  -> Dropping on board at", x, ",", y)
						board[y][x] = dragging_tile.get_meta("tile_data")
						dragging_tile.reparent(cell)
						dragging_tile.position = Vector2(2, 2)
						dragging_tile.z_index = 0
						dragging_tile.set_meta("temp", true)
						if not temp_tiles.has(Vector2i(x,y)):
							temp_tiles.append(Vector2i(x, y))
						dropped = true
						break
			if dropped:
				break
	
	# Si pas déposé, retourner à l'origine
	if not dropped:
		print("  -> Returning to origin")
		if drag_origin.type == "rack":
			var i = drag_origin.pos
			rack[i] = dragging_tile.get_meta("tile_data")
			var tween = create_tween()
			var target_size = Vector2(tile_size_rack - 4, tile_size_rack - 4)
			tween.tween_property(dragging_tile, "custom_minimum_size", target_size, 0.2)
			
			var letter_lbl = dragging_tile.get_node_or_null("LetterLabel")
			var value_lbl = dragging_tile.get_node_or_null("ValueLabel")
			if letter_lbl and value_lbl:
				tween.tween_property(letter_lbl, "position", Vector2(tile_size_rack * 0.2, tile_size_rack * 0.05), 0.2)
				tween.tween_property(value_lbl, "position", Vector2(tile_size_rack * 0.6, tile_size_rack * 0.55), 0.2)
			
			dragging_tile.reparent(rack_cells[i])
			dragging_tile.position = Vector2(2, 2)
			dragging_tile.z_index = 0
			dragging_tile.remove_meta("temp")
		else:
			var pos_vec = drag_origin.pos
			board[pos_vec.y][pos_vec.x] = dragging_tile.get_meta("tile_data")
			dragging_tile.reparent(board_cells[pos_vec.y][pos_vec.x])
			dragging_tile.position = Vector2(2, 2)
			dragging_tile.z_index = 0
			dragging_tile.set_meta("temp", true)
			if not temp_tiles.has(pos_vec):
				temp_tiles.append(pos_vec)
	
	dragging_tile = null
	drag_origin = null
	
	if temp_tiles.is_empty():
		animate_to_rack_view()

func get_tile_in_cell(cell: Panel):
	for child in cell.get_children():
		if child is Panel and child.has_meta("tile_data"):
			return child
	return null

func animate_to_board_view():
	if is_board_focused:
		return
	is_board_focused = true
	
	print("Animation -> Vue Plateau")
	var tween = create_tween()
	tween.set_parallel(true)
	
	tween.tween_property(board_container, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_property(rack_container, "scale", Vector2(0.8, 0.8), 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_property(rack_container, "position:y", viewport_size.y - 60, 0.3).set_trans(Tween.TRANS_SINE)

func animate_to_rack_view():
	if not is_board_focused:
		return
	is_board_focused = false
	
	print("Animation -> Vue Chevalet")
	var tween = create_tween()
	tween.set_parallel(true)
	
	tween.tween_property(board_container, "scale", Vector2(board_scale_unfocused, board_scale_unfocused), 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_property(rack_container, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_property(rack_container, "position:y", viewport_size.y - tile_size_rack - 40, 0.3).set_trans(Tween.TRANS_SINE)
	
	# Recentrer le plateau
	var total_board_pixel_size = BOARD_SIZE * (tile_size_board + 2)
	var start_x = (viewport_size.x - total_board_pixel_size) / 2
	tween.tween_property(board_container, "position:x", start_x, 0.3).set_trans(Tween.TRANS_SINE)

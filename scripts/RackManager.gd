extends Node
class_name RackManager

# ============================================================================
# GESTIONNAIRE DU CHEVALET (RACK MANAGER)
# ============================================================================
# Ce module gère :
# - La création et l'affichage du chevalet
# - Le remplissage du chevalet avec les tuiles
# - La gestion de l'état du chevalet
# - La réorganisation dynamique pendant le drag & drop
# ============================================================================

# Référence au TileManager
var tile_manager: TileManager

# Données du chevalet
var rack: Array = []
var rack_cells: Array = []
var rack_container: Control

# Taille des tuiles du chevalet
var tile_size_rack: float = 70.0

# Référence à la taille de l'écran
var viewport_size: Vector2

# ============================================================================
# NOUVELLES VARIABLES POUR LA RÉORGANISATION DYNAMIQUE
# ============================================================================
var hover_insert_index: int = -1  # Index où la tuile serait insérée (-1 = pas de hover)
var is_hovering_rack: bool = false
var ghost_cell: Panel = null  # Indicateur visuel de la future position
var original_positions: Array = []  # Positions originales des cellules pour l'animation

# ============================================================================
# FONCTION : Initialiser le RackManager
# ============================================================================
func initialize(viewport_sz: Vector2, tile_mgr: TileManager) -> void:
	viewport_size = viewport_sz
	tile_manager = tile_mgr

# ============================================================================
# FONCTION : Créer le chevalet
# ============================================================================
func create_rack(parent: Node2D) -> void:
	rack_container = Control.new()
	parent.add_child(rack_container)
	
	var total_rack_pixel_size = Vector2(ScrabbleConfig.RACK_SIZE * (tile_size_rack + 2), tile_size_rack)
	var start_x = (viewport_size.x - total_rack_pixel_size.x) / 2
	rack_container.position = Vector2(start_x, viewport_size.y - tile_size_rack - 40)
	rack_container.pivot_offset = total_rack_pixel_size / 2
	
	# Créer les cellules du chevalet
	for i in range(ScrabbleConfig.RACK_SIZE):
		rack.append(null)
		var cell = _create_rack_cell(i)
		rack_container.add_child(cell)
		rack_cells.append(cell)
		original_positions.append(cell.position)
	
	# Créer la cellule fantôme (invisible par défaut)
	_create_ghost_cell()
	
	print("🎯 Chevalet créé avec ", ScrabbleConfig.RACK_SIZE, " emplacements")

# ============================================================================
# FONCTION PRIVÉE : Créer une cellule du chevalet
# ============================================================================
func _create_rack_cell(index: int) -> Panel:
	var cell = Panel.new()
	cell.custom_minimum_size = Vector2(tile_size_rack, tile_size_rack)
	cell.position = Vector2(index * (tile_size_rack + 2), 0)
	cell.modulate = Color(0.9, 0.9, 0.8)
	return cell

# ============================================================================
# FONCTION PRIVÉE : Créer la cellule fantôme pour le preview
# ============================================================================
func _create_ghost_cell() -> void:
	ghost_cell = Panel.new()
	ghost_cell.custom_minimum_size = Vector2(tile_size_rack, tile_size_rack)
	ghost_cell.modulate = Color(0.5, 1.0, 0.5, 0.5)  # Vert translucide
	ghost_cell.visible = false
	ghost_cell.z_index = 50  # Au-dessus des cellules normales mais sous la tuile draggée
	rack_container.add_child(ghost_cell)

# ============================================================================
# NOUVELLE FONCTION : Calculer l'index d'insertion pendant le drag
# ============================================================================
func calculate_insert_index(global_pos: Vector2, dragged_from_rack_index: int = -1) -> int:
	"""
	Calcule à quel index la tuile serait insérée si on la lâchait maintenant.
	Prend en compte si la tuile vient du chevalet pour ne pas compter sa position actuelle.
	Retourne -1 si la position n'est pas sur le chevalet.
	"""
	# Vérifier si on est au-dessus du chevalet
	var rack_rect = Rect2(
		rack_container.global_position,
		Vector2((ScrabbleConfig.RACK_SIZE * (tile_size_rack + 2)), tile_size_rack) * rack_container.scale
	)
	
	if not rack_rect.has_point(global_pos):
		return -1
	
	# Calculer la position relative au chevalet
	var local_x = (global_pos.x - rack_container.global_position.x) / rack_container.scale.x
	
	# Trouver l'index le plus proche
	var best_index = 0
	var min_distance = INF
	
	for i in range(ScrabbleConfig.RACK_SIZE):
		var cell_center_x = rack_cells[i].position.x + (tile_size_rack / 2)
		var distance = abs(local_x - cell_center_x)
		
		if distance < min_distance:
			min_distance = distance
			best_index = i
	
	# Si la tuile vient du chevalet, ajuster l'index
	# (on ne veut pas créer un "trou" inutile)
	if dragged_from_rack_index >= 0:
		if best_index > dragged_from_rack_index:
			# On insère après, donc on garde l'index tel quel
			pass
		elif best_index == dragged_from_rack_index:
			# On reste au même endroit
			return dragged_from_rack_index
	
	return best_index

# ============================================================================
# NOUVELLE FONCTION : Mettre à jour le preview de réorganisation
# ============================================================================
func update_rack_preview(global_pos: Vector2, dragged_from_rack_index: int = -1) -> void:
	"""
	Met à jour l'affichage du chevalet pour montrer où la tuile serait insérée.
	Anime les tuiles existantes pour qu'elles se décalent.
	"""
	var new_insert_index = calculate_insert_index(global_pos, dragged_from_rack_index)
	
	# Si on n'est plus sur le chevalet
	if new_insert_index == -1:
		if is_hovering_rack:
			_clear_rack_preview()
		return
	
	# Si l'index d'insertion a changé
	if new_insert_index != hover_insert_index:
		hover_insert_index = new_insert_index
		is_hovering_rack = true
		_animate_rack_reorganization(dragged_from_rack_index)

# ============================================================================
# FONCTION PRIVÉE : Animer la réorganisation du chevalet
# ============================================================================
func _animate_rack_reorganization(dragged_from_rack_index: int = -1) -> void:
	"""
	Anime les tuiles du chevalet pour montrer la future organisation.
	"""
	# Afficher la cellule fantôme à la position d'insertion
	ghost_cell.visible = true
	ghost_cell.position = Vector2(hover_insert_index * (tile_size_rack + 2), 0)
	
	# Animer chaque cellule vers sa nouvelle position
	for i in range(ScrabbleConfig.RACK_SIZE):
		var cell = rack_cells[i]
		var target_x: float
		
		# Calculer la position cible en fonction de l'insertion
		if dragged_from_rack_index >= 0:
			# La tuile vient du chevalet - on la retire temporairement de la liste
			if i == dragged_from_rack_index:
				# La cellule d'origine reste invisible (sa tuile est en train d'être draggée)
				continue
			elif i < dragged_from_rack_index and i < hover_insert_index:
				# Avant la position d'origine et d'insertion : pas de changement
				target_x = original_positions[i].x
			elif i < dragged_from_rack_index and i >= hover_insert_index:
				# On décale vers la droite pour faire de la place
				target_x = original_positions[i + 1].x
			elif i > dragged_from_rack_index and i < hover_insert_index:
				# On décale vers la gauche pour combler le trou
				target_x = original_positions[i - 1].x
			elif i > dragged_from_rack_index and i >= hover_insert_index:
				# Après les deux positions : pas de changement
				target_x = original_positions[i].x
			else:
				target_x = original_positions[i].x
		else:
			# La tuile vient du plateau - simple décalage
			if i >= hover_insert_index:
				# Décaler vers la droite
				target_x = original_positions[i + 1].x if i < ScrabbleConfig.RACK_SIZE - 1 else original_positions[i].x
			else:
				# Pas de changement
				target_x = original_positions[i].x
		
		# Animer vers la position cible
		if cell.position.x != target_x:
			var tween = cell.create_tween()
			tween.tween_property(cell, "position:x", target_x, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# ============================================================================
# NOUVELLE FONCTION : Effacer le preview de réorganisation
# ============================================================================
func _clear_rack_preview() -> void:
	"""
	Remet le chevalet dans son état normal (sans preview d'insertion).
	"""
	is_hovering_rack = false
	hover_insert_index = -1
	ghost_cell.visible = false
	
	# Remettre toutes les cellules à leur position d'origine
	for i in range(ScrabbleConfig.RACK_SIZE):
		var cell = rack_cells[i]
		if cell.position.x != original_positions[i].x:
			var tween = cell.create_tween()
			tween.tween_property(cell, "position:x", original_positions[i].x, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# ============================================================================
# NOUVELLE FONCTION : Insérer une tuile à un index spécifique
# ============================================================================
func insert_tile_at(index: int, tile_data: Dictionary, from_rack_index: int = -1) -> bool:
	"""
	Insère une tuile à un index donné et réorganise le chevalet.
	Si from_rack_index >= 0, cela signifie qu'on déplace une tuile déjà dans le chevalet.
	Retourne true si l'insertion a réussi.
	"""
	if index < 0 or index >= ScrabbleConfig.RACK_SIZE:
		return false
	
	# Si la tuile vient du chevalet, on fait un simple swap/réorganisation
	if from_rack_index >= 0:
		# Retirer la tuile de son ancienne position
		var moving_tile = rack[from_rack_index]
		rack[from_rack_index] = null
		
		# Décaler les tuiles entre les deux positions
		if from_rack_index < index:
			# Déplacement vers la droite
			for i in range(from_rack_index, index):
				rack[i] = rack[i + 1]
		else:
			# Déplacement vers la gauche
			for i in range(from_rack_index, index, -1):
				rack[i] = rack[i - 1]
		
		# Placer la tuile à sa nouvelle position
		rack[index] = moving_tile
	else:
		# La tuile vient du plateau - on insère et on décale tout vers la droite
		# Trouver une place libre ou écraser la dernière
		for i in range(ScrabbleConfig.RACK_SIZE - 1, index, -1):
			rack[i] = rack[i - 1]
		
		rack[index] = tile_data
	
	# Rafraîchir l'affichage
	_refresh_rack_visuals()
	_clear_rack_preview()
	
	return true

# ============================================================================
# FONCTION PRIVÉE : Rafraîchir l'affichage du chevalet
# ============================================================================
func _refresh_rack_visuals() -> void:
	"""
	Reconstruit visuellement toutes les tuiles du chevalet.
	Utilisé après une réorganisation.
	"""
	# Nettoyer toutes les tuiles existantes
	for i in range(ScrabbleConfig.RACK_SIZE):
		var cell = rack_cells[i]
		var old_tile = TileManager.get_tile_in_cell(cell)
		if old_tile:
			old_tile.queue_free()
	
	# Recréer les tuiles à leur bonne position
	for i in range(ScrabbleConfig.RACK_SIZE):
		if rack[i] != null:
			tile_manager.create_tile_visual(rack[i], rack_cells[i], tile_size_rack)

# ============================================================================
# FONCTION : Remplir le chevalet
# ============================================================================
func fill_rack() -> void:
	for i in range(ScrabbleConfig.RACK_SIZE):
		if rack[i] == null:
			var tile_data = tile_manager.draw_tile()
			if tile_data:
				rack[i] = tile_data
				tile_manager.create_tile_visual(tile_data, rack_cells[i], tile_size_rack)

# ============================================================================
# FONCTION : Vider le chevalet (retirer toutes les tuiles visuelles)
# ============================================================================
func clear_rack() -> void:
	for i in range(ScrabbleConfig.RACK_SIZE):
		if rack[i] != null:
			var cell = rack_cells[i]
			var tile_node = TileManager.get_tile_in_cell(cell)
			if tile_node:
				tile_node.queue_free()
			rack[i] = null

# ============================================================================
# FONCTION : Obtenir une tuile du chevalet à un index donné
# ============================================================================
func get_tile_at(index: int) -> Variant:
	if index >= 0 and index < rack.size():
		return rack[index]
	return null

# ============================================================================
# FONCTION : Retirer une tuile du chevalet
# ============================================================================
func remove_tile_at(index: int) -> Variant:
	if index >= 0 and index < rack.size():
		var tile = rack[index]
		rack[index] = null
		return tile
	return null

# ============================================================================
# FONCTION : Ajouter une tuile au chevalet
# ============================================================================
func add_tile_at(index: int, tile_data: Dictionary) -> bool:
	if index >= 0 and index < rack.size() and rack[index] == null:
		rack[index] = tile_data
		return true
	return false

# ============================================================================
# FONCTION : Obtenir la cellule du chevalet à un index donné
# ============================================================================
func get_cell_at(index: int) -> Panel:
	if index >= 0 and index < rack_cells.size():
		return rack_cells[index]
	return null

# ============================================================================
# FONCTION : Vérifier si une position est dans le chevalet
# ============================================================================
func is_position_in_rack(global_pos: Vector2) -> int:
	for i in range(ScrabbleConfig.RACK_SIZE):
		var cell = rack_cells[i]
		var cell_rect = Rect2(cell.global_position, cell.size * rack_container.scale)
		if cell_rect.has_point(global_pos):
			return i
	return -1

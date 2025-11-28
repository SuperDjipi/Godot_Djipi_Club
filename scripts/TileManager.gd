extends Node
class_name TileManager

# ============================================================================
# GESTIONNAIRE DES TUILES (TILE MANAGER)
# ============================================================================
# Ce module gère :
# - Le sac de tuiles (tile_bag)
# - La pioche de tuiles
# - La création visuelle des tuiles
# ============================================================================

# Sac de tuiles (sera rempli au démarrage)
var tile_bag: Array = []

# ============================================================================
# FONCTION : Initialiser le sac de tuiles
# ============================================================================
func init_tile_bag() -> void:
	tile_bag.clear()
	
	for letter in ScrabbleConfig.LETTER_DISTRIBUTION:
		var data = ScrabbleConfig.LETTER_DISTRIBUTION[letter]
		for i in range(data.count):
			tile_bag.append({"letter": letter, "value": data.value})
	
	tile_bag.shuffle()
	print("🎲 Sac de tuiles initialisé avec ", tile_bag.size(), " tuiles")

# ============================================================================
# FONCTION : Piocher une tuile
# ============================================================================
func draw_tile() -> Variant:
	if tile_bag.size() > 0:
		return tile_bag.pop_back()
	return null

# ============================================================================
# FONCTION : Piocher plusieurs tuiles
# ============================================================================
func draw_tiles(count: int) -> Array:
	var drawn = []
	for i in range(count):
		var tile = draw_tile()
		if tile:
			drawn.append(tile)
		else:
			break
	return drawn

# ============================================================================
# FONCTION : Créer une représentation visuelle d'une tuile
# ============================================================================
# Retourne un Panel avec la lettre et la valeur affichées
# ============================================================================
func create_tile_visual(tile_data: Dictionary, parent: Control, tile_size_arg: float) -> Panel:
	var tile = Panel.new()
	tile.custom_minimum_size = Vector2(tile_size_arg - 4, tile_size_arg - 4)
	tile.position = Vector2(2, 2)
	tile.modulate = Color(0.95, 0.9, 0.7)
	
	# Label pour la lettre
	var letter_lbl = Label.new()
	letter_lbl.name = "LetterLabel"
	letter_lbl.text = tile_data.letter
	letter_lbl.add_theme_font_size_override("font_size", int(tile_size_arg * 0.5))
	letter_lbl.position = Vector2(tile_size_arg * 0.2, tile_size_arg * 0.05)
	tile.add_child(letter_lbl)
	
	# Label pour la valeur (affichage en float si nécessaire)
	var value_lbl = Label.new()
	value_lbl.name = "ValueLabel"
	# Afficher sans décimale si c'est un nombre entier
	var value = tile_data.value
	if value == floor(value):
		value_lbl.text = str(int(value))
	else:
		value_lbl.text = "%.1f" % value
	value_lbl.add_theme_font_size_override("font_size", int(tile_size_arg * 0.25))
	value_lbl.position = Vector2(tile_size_arg * 0.6, tile_size_arg * 0.55)
	tile.add_child(value_lbl)
	
	# Stocker les données de la tuile dans les métadonnées
	tile.set_meta("tile_data", tile_data)
	
	parent.add_child(tile)
	return tile

# ============================================================================
# FONCTION UTILITAIRE : Récupérer une tuile dans une cellule
# ============================================================================
static func get_tile_in_cell(cell: Panel) -> Panel:
	for child in cell.get_children():
		if child is Panel and child.has_meta("tile_data"):
			return child
	return null

# ============================================================================
# FONCTION : Obtenir le nombre de tuiles restantes
# ============================================================================
func get_remaining_tiles_count() -> int:
	return tile_bag.size()

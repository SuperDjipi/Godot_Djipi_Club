extends Node

# ============================================================================
# CONFIGURATION STATIQUE DU JEU DE SCRABBLE
# ============================================================================
# Ce fichier contient toutes les constantes et configurations du jeu.
# Il est conçu comme un autoload global accessible via ScrabbleConfig.
# ============================================================================

# --- DIMENSIONS DU JEU ---
const BOARD_SIZE = 15
const TILE_SIZE = 40
const RACK_SIZE = 7
const BOARD_PADDING = 20

# --- COULEURS DES CASES BONUS ---
const COLOR_NORMAL = Color(0.8, 0.8, 0.7)
const COLOR_LETTER_DOUBLE = Color(0.6, 0.8, 1.0)
const COLOR_LETTER_TRIPLE = Color(0.2, 0.5, 1.0)
const COLOR_WORD_DOUBLE = Color(1.0, 0.8, 0.8)
const COLOR_WORD_TRIPLE = Color(1.0, 0.3, 0.3)
const COLOR_CENTER = Color(1.0, 0.8, 1.0)

# --- DISTRIBUTION DES LETTRES EN FRANÇAIS ---
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

# --- PARAMÈTRES D'AUTO-SCROLL ---
const AUTO_SCROLL_MARGIN = 80.0  # Distance depuis le bord pour déclencher le scroll
const AUTO_SCROLL_SPEED = 8.0     # Vitesse du défilement automatique

# --- PARAMÈTRES D'ÉCHELLE ---
const BOARD_SCALE_FOCUSED = 1.0
const BOARD_SCALE_UNFOCUSED = 0.7

# ============================================================================
# FONCTION : Créer la map des bonus du plateau
# ============================================================================
# Retourne un dictionnaire qui associe chaque position du plateau à son bonus
# ============================================================================
func create_bonus_map() -> Dictionary:
	var bonus_map = {}
	
	# Mot Compte Triple (W3) - Coins
	for pos in [Vector2i(0,0), Vector2i(0,7), Vector2i(0,14), Vector2i(7,0), 
				Vector2i(7,14), Vector2i(14,0), Vector2i(14,7), Vector2i(14,14)]:
		bonus_map[pos] = "W3"
	
	# Mot Compte Double (W2) - Diagonales
	for i in range(1, 5):
		for pos in [Vector2i(i,i), Vector2i(i,14-i), Vector2i(14-i,i), Vector2i(14-i,14-i)]:
			bonus_map[pos] = "W2"
	
	# Lettre Compte Triple (L3)
	for pos in [Vector2i(1,5), Vector2i(1,9), Vector2i(5,1), Vector2i(5,5),
				Vector2i(5,9), Vector2i(5,13), Vector2i(9,1), Vector2i(9,5),
				Vector2i(9,9), Vector2i(9,13), Vector2i(13,5), Vector2i(13,9)]:
		bonus_map[pos] = "L3"
	
	# Lettre Compte Double (L2)
	for pos in [Vector2i(0,3), Vector2i(0,11), Vector2i(2,6), Vector2i(2,8),
				Vector2i(3,0), Vector2i(3,7), Vector2i(3,14), Vector2i(6,2),
				Vector2i(6,6), Vector2i(6,8), Vector2i(6,12), Vector2i(7,3),
				Vector2i(7,11), Vector2i(8,2), Vector2i(8,6), Vector2i(8,8),
				Vector2i(8,12), Vector2i(11,0), Vector2i(11,7), Vector2i(11,14),
				Vector2i(12,6), Vector2i(12,8), Vector2i(14,3), Vector2i(14,11)]:
		bonus_map[pos] = "L2"
	
	# Case centrale (étoile)
	bonus_map[Vector2i(7,7)] = "CENTER"
	
	return bonus_map

# ============================================================================
# FONCTION : Obtenir la couleur d'un bonus
# ============================================================================
func get_bonus_color(bonus: String) -> Color:
	match bonus:
		"W3": return COLOR_WORD_TRIPLE
		"W2": return COLOR_WORD_DOUBLE
		"L3": return COLOR_LETTER_TRIPLE
		"L2": return COLOR_LETTER_DOUBLE
		"CENTER": return COLOR_CENTER
		_: return COLOR_NORMAL

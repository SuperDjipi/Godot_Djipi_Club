extends Node
class_name DictionaryManager

# ============================================================================
# GESTIONNAIRE DE DICTIONNAIRE
# ============================================================================
# Charge et gère les dictionnaires de mots français
# Optimisé pour la recherche rapide (HashSet)
# ============================================================================

# Dictionnaires par longueur de mot
var dictionaries: Dictionary = {}  # {2: {...}, 3: {...}, ..., 15: {...}}
var is_loaded: bool = false

# Chemins des fichiers
const DICT_BASE_PATH = "res://assets/dictionaries/"
const DICT_FILES = {
	2: "deux.txt",
	3: "trois.txt",
	4: "quatre.txt",
	5: "cinq.txt",
	6: "six.txt",
	7: "sept.txt",
	8: "huit.txt",
	9: "neuf.txt",
	10: "dix.txt",
	11: "onze.txt",
	12: "douze.txt",
	13: "treize.txt",
	14: "quatorze.txt",
	15: "quinze.txt"
}
# ============================================================================
# FONCTION : Choix de la plateforme
# ============================================================================
func _get_platform_path() -> String:
	match OS.get_name():
		"Android":
			return "user://dictionaries/"  # Chemin persistant Android
		"Web":
			return "res://assets/dictionaries/"  # Intégré dans l'export web
		_:
			return "res://assets/dictionaries/"  # PC/Mac/Linux
# ============================================================================
# FONCTION : Charger tous les dictionnaires
# ============================================================================
func load_dictionaries() -> bool:
	print("📖 Chargement des dictionnaires...")
	
	var base_path = _get_platform_path()
	
	for length in DICT_FILES:
		var filename = DICT_FILES[length]
		var path = base_path + filename
		
		if not _load_dictionary_file(path, length):
			print("❌ Erreur lors du chargement de ", filename)
			return false
	
	is_loaded = true
	print("✅ Dictionnaires chargés avec succès")
	return true

# ============================================================================
# FONCTION PRIVÉE : Charger un fichier dictionnaire
# ============================================================================
func _load_dictionary_file(path: String, length: int) -> bool:
	# Vérifier si le fichier existe
	if not FileAccess.file_exists(path):
		print("⚠️ Fichier non trouvé : ", path)
		return false
	
	# Ouvrir le fichier
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("❌ Impossible d'ouvrir : ", path)
		return false
	
	# Créer un dictionnaire (HashSet) pour cette longueur
	dictionaries[length] = {}
	
	# Lire tout le contenu
	var content = file.get_as_text()
	file.close()
	
	# Séparer par virgules et nettoyer
	var words = content.split(",")
	var word_count = 0
	
	for word in words:
		var cleaned_word = word.strip_edges().to_upper()
		if cleaned_word.length() > 0:
			dictionaries[length][cleaned_word] = true  # HashSet
			word_count += 1
	
	print("  ✓ ", path.get_file(), " : ", word_count, " mots")
	return true

# ============================================================================
# FONCTION : Vérifier si un mot existe
# ============================================================================
func is_valid_word(word: String) -> bool:
	if not is_loaded:
		print("⚠️ Dictionnaires non chargés !")
		return false
	
	var normalized_word = word.to_upper().strip_edges()
	var length = normalized_word.length()
	
	# Vérifier que la longueur est valide
	if length < 2 or length > 15:
		return false
	
	# Vérifier dans le dictionnaire correspondant
	if not dictionaries.has(length):
		return false
	
	return dictionaries[length].has(normalized_word)

# ============================================================================
# FONCTION : Vérifier plusieurs mots
# ============================================================================
func validate_words(words: Array) -> Dictionary:
	"""
	Retourne : {
		"all_valid": bool,
		"results": [
			{"word": "CHAT", "valid": true},
			{"word": "XYZ", "valid": false},
			...
		]
	}
	"""
	var results = []
	var all_valid = true
	
	for word in words:
		var is_valid = is_valid_word(word)
		results.append({
			"word": word,
			"valid": is_valid
		})
		if not is_valid:
			all_valid = false
	
	return {
		"all_valid": all_valid,
		"results": results
	}

# ============================================================================
# FONCTION : Obtenir des statistiques
# ============================================================================
func get_stats() -> Dictionary:
	var total_words = 0
	var stats = {}
	
	for length in dictionaries:
		var count = dictionaries[length].size()
		stats[length] = count
		total_words += count
	
	return {
		"total": total_words,
		"by_length": stats
	}

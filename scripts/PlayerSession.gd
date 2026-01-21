extends Node

var player_id: String = ""
var player_name: String = ""

func is_logged_in() -> bool:
	return not player_id.is_empty()

func set_player_data(p_id: String, p_name: String) -> void:
	player_id = p_id
	player_name = p_name
	print("👤 Session Joueur mise à jour : ", player_name, " (", player_id, ")")

func clear_player_data() -> void:
	player_id = ""
	player_name = ""
	print("👤 Session Joueur effacée.")

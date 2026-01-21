# DebugConsole.gd
# Console de debug flottante pour Android
extends CanvasLayer

#var console_label: RichTextLabel
var console_label: Label
var console_panel: PanelContainer
var logs: Array[String] = []
const MAX_LOGS = 20  # Nombre maximum de lignes

func _ready():
	
	# Créer le panel
	console_panel = PanelContainer.new()
	console_panel.anchor_top = 1.0
	console_panel.anchor_bottom = 1.0
	console_panel.anchor_left = 0.0
	console_panel.anchor_right = 1.0
	console_panel.offset_top = 0  # Hauteur de 200px -> -200
	console_panel.offset_bottom = 0
	
	# Style semi-transparent
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.8)
	console_panel.add_theme_stylebox_override("panel", style)
	
	add_child(console_panel)
	
	# ScrollContainer
	var scroll = ScrollContainer.new()
	scroll.follow_focus = true
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	console_panel.add_child(scroll)
	
	# Label pour les logs
	#console_label = RichTextLabel.new()
	#console_label.bbcode_enabled = true
	#console_label.scroll_following = true
	#console_label.fit_content = false
	#console_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL 
	#console_label.custom_minimum_size = Vector2(0, 0)
	#console_label.add_theme_font_size_override("normal_font_size", 12)
	#scroll.add_child(console_label)
	#
	
	# ✅ SIMPLE : Label classique
	console_label = Label.new()
	console_label.add_theme_font_size_override("font_size", 12)
	console_label.add_theme_color_override("font_color", Color.WHITE)
	console_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	console_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	console_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	console_label.custom_minimum_size = Vector2(0, 190)
	console_panel.add_child(console_label)
	
	# Intercepter les prints
	_hook_print()
	
	debug("[color=green]✅ Debug Console initialisée[/color]")

func _hook_print():
	"""Intercepte les print() du jeu"""
	# On ne peut pas vraiment intercepter print() en GDScript
	# Mais on peut utiliser notre propre fonction log()
	pass

func debug(message: String):
	"""Ajoute un message au log"""
	logs.append(message)
	
	# Limiter le nombre de lignes
	if logs.size() > MAX_LOGS:
		logs.pop_front()
	
	# Mettre à jour l'affichage
	console_label.text = "\n".join(logs)
	
	# Scroll vers le bas
	await get_tree().process_frame
	if console_label.get_parent() is ScrollContainer:
		var scroll = console_label.get_parent() as ScrollContainer
		scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value

func clear():
	"""Efface la console"""
	logs.clear()
	console_label.text = ""

func toggle_visibility():
	"""Affiche/cache la console"""
	console_panel.visible = not console_panel.visible

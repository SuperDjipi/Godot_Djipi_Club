# 🎨 Structure UI Godot inspirée de Jetpack Compose

## 📋 Vue d'ensemble

Cette structure reproduit l'organisation du `GameContent.kt` Jetpack Compose dans Godot, avec une hiérarchie UI claire et modulaire.

## 🏗️ Hiérarchie de la Scène

```
ScrabbleGameMultiplayer (Node2D)
└── MainContainer (Control - anchors full screen)
    └── VBoxContainer (8dp spacing)
        ├── ScoreBoard (PanelContainer)
        │   └── MarginContainer
        │       └── HBoxContainer
        │           ├── StatusLabel
        │           ├── Spacer (weight=1)
        │           ├── TurnLabel
        │           ├── Spacer (weight=1)
        │           └── ScoreLabel
        │
        ├── ValidationPanel (PanelContainer)
        │   └── MarginContainer
        │       └── ValidationLabel
        │
        ├── BoardContainer (CenterContainer - weight=1)
        │   └── BoardViewport (SubViewportContainer)
        │       └── SubViewport
        │           └── [Plateau créé dynamiquement]
        │
        ├── RackContainer (CenterContainer)
        │   └── MarginContainer
        │       └── [Chevalet créé dynamiquement]
        │
        └── ActionButtons (PanelContainer)
            └── MarginContainer
                └── HBoxContainer
                    ├── UndoButton
                    ├── ShuffleButton
                    ├── Spacer (weight=1)
                    ├── PassButton
                    └── PlayButton
```

## 🔄 Correspondance Jetpack Compose ↔ Godot

| Jetpack Compose | Godot Équivalent | Notes |
|-----------------|------------------|-------|
| `Column` | `VBoxContainer` | Arrangement vertical |
| `Row` | `HBoxContainer` | Arrangement horizontal |
| `Modifier.weight(1f)` | `size_flags_vertical = 3` ou Spacer avec `size_flags_horizontal = 3` | Prend l'espace disponible |
| `Modifier.padding()` | `MarginContainer` | Espacement intérieur |
| `Spacer` | `Control` vide avec `size_flags` | Espace flexible |
| `Button` | `Button` | Bouton d'action |
| `OutlinedButton` | `Button` (personnalisable) | Bouton avec bordure |
| `Text` / `Label` | `Label` | Affichage de texte |
| `Card` / `Surface` | `PanelContainer` | Conteneur avec fond |

## 📐 Sections de l'UI

### 1. ScoreBoard (Tableau de scores)
```gdscript
@onready var status_label = $MainContainer/VBoxContainer/ScoreBoard/.../StatusLabel
@onready var turn_label = $MainContainer/VBoxContainer/ScoreBoard/.../TurnLabel
@onready var score_label = $MainContainer/VBoxContainer/ScoreBoard/.../ScoreLabel
```

**Affiche** :
- Statut de la partie ("En attente", "En cours", etc.)
- Joueur actuel ("C'est votre tour !", "Tour de Alice")
- Score du joueur local (avec tooltip pour tous les scores)

### 2. ValidationPanel (Feedback de validation)
```gdscript
@onready var validation_label = $MainContainer/VBoxContainer/ValidationPanel/.../ValidationLabel
```

**Affiche** :
- ✅ "Mouvement valide ! Score : 23 points" (vert)
- ❌ "Mouvement invalide : Les tuiles doivent être alignées" (rouge)

### 3. BoardContainer (Plateau de jeu)
```gdscript
@onready var board_container = $MainContainer/VBoxContainer/BoardContainer
```

**Contient** :
- Le plateau de jeu créé dynamiquement
- Prend tout l'espace vertical disponible (`weight = 1`)
- Centré horizontalement

### 4. RackContainer (Chevalet)
```gdscript
@onready var rack_container = $MainContainer/VBoxContainer/RackContainer/MarginContainer
```

**Contient** :
- Le chevalet du joueur créé dynamiquement
- Taille fixe (100dp de hauteur)
- Centré horizontalement

### 5. ActionButtons (Boutons d'action)
```gdscript
@onready var undo_button = $MainContainer/VBoxContainer/ActionButtons/.../UndoButton
@onready var shuffle_button = $MainContainer/VBoxContainer/ActionButtons/.../ShuffleButton
@onready var pass_button = $MainContainer/VBoxContainer/ActionButtons/.../PassButton
@onready var play_button = $MainContainer/VBoxContainer/ActionButtons/.../PlayButton
```

**Boutons** :
- **↶ Annuler** : Annule le placement en cours
- **🔀 Mélanger** : Mélange les tuiles du chevalet
- **⏭ Passer** : Passe le tour
- **✅ Jouer** : Envoie le coup au serveur

## 🎯 Gestion de l'État des Boutons

### État Initial
```gdscript
func _initialize_ui() -> void:
    undo_button.disabled = true
    shuffle_button.disabled = true
    pass_button.disabled = true
    play_button.disabled = true
```

### Quand c'est le tour du joueur
```gdscript
func _on_my_turn_started() -> void:
    shuffle_button.disabled = false  # Toujours actif
    pass_button.disabled = false     # Actif si aucune tuile placée
    play_button.disabled = true      # Actif seulement si mouvement valide
```

### Après placement de tuiles valides
```gdscript
func _show_validation_result(result: Dictionary) -> void:
    if result.valid:
        play_button.disabled = false  # ← Activation automatique
        undo_button.disabled = false
    else:
        play_button.disabled = true
        undo_button.disabled = false  # Permet d'annuler un mouvement invalide
```

### Après envoi du coup
```gdscript
func _on_play_pressed() -> void:
    play_button.disabled = true
    pass_button.disabled = true
    undo_button.disabled = true
```

## 🔌 Intégration des Composants Dynamiques

### Création du Plateau
```gdscript
func _create_board_in_scene() -> void:
    var board_control = Control.new()
    board_control.name = "BoardControl"
    board_container.add_child(board_control)
    
    board_manager.create_board(board_control)
    
    var board_size = ScrabbleConfig.BOARD_SIZE * (board_manager.tile_size_board + 2)
    board_control.custom_minimum_size = Vector2(board_size, board_size)
```

### Création du Chevalet
```gdscript
func _create_rack_in_scene() -> void:
    rack_manager.create_rack(rack_container)
```

## 🎨 Personnalisation de l'UI

### Thème
Vous pouvez créer un thème Godot pour personnaliser :
- Couleurs des boutons
- Polices
- Tailles de texte
- Bordures des panels

### Exemple de thème personnalisé
```gdscript
# Dans la scène ou via code
var theme = Theme.new()

# Bouton principal (Play)
var play_style = StyleBoxFlat.new()
play_style.bg_color = Color(0.2, 0.7, 0.3)  # Vert
play_style.corner_radius_top_left = 8
play_style.corner_radius_top_right = 8
play_style.corner_radius_bottom_left = 8
play_style.corner_radius_bottom_right = 8
theme.set_stylebox("normal", "Button", play_style)

play_button.theme = theme
```

## 📱 Responsive Design

La structure s'adapte automatiquement à différentes tailles d'écran :

1. **ScoreBoard** : Hauteur fixe (80dp)
2. **ValidationPanel** : Hauteur fixe (60dp)
3. **BoardContainer** : Prend tout l'espace restant (`weight=1`)
4. **RackContainer** : Hauteur fixe (100dp)
5. **ActionButtons** : Hauteur fixe (60dp)

```
┌──────────────────────────────┐
│ ScoreBoard (80dp)            │
├──────────────────────────────┤
│ ValidationPanel (60dp)       │
├──────────────────────────────┤
│                              │
│ Board (flexible - weight 1)  │
│                              │
│                              │
├──────────────────────────────┤
│ Rack (100dp)                 │
├──────────────────────────────┤
│ Buttons (60dp)               │
└──────────────────────────────┘
```

## 🚀 Avantages de Cette Structure

1. **Séparation claire** : Chaque section a son rôle
2. **Facile à modifier** : Changez la scène sans toucher au code
3. **Testable** : Chaque composant peut être testé indépendamment
4. **Évolutif** : Ajoutez facilement de nouvelles sections
5. **Maintenable** : Structure claire et documentée

## 📦 Fichiers

### À copier dans votre projet :
1. **ScrabbleGameMultiplayer.tscn** - La scène UI
2. **ScrabbleGameMultiplayer_WithScene.gd** - Le script adapté

### Renommage suggéré :
```bash
# Remplacer votre fichier actuel
mv ScrabbleGameMultiplayer_WithScene.gd scripts/ScrabbleGameMultiplayer.gd

# Placer la scène
mv ScrabbleGameMultiplayer.tscn scenes/ScrabbleGameMultiplayer.tscn
```

## 🎓 Pour Aller Plus Loin

### Ajout d'animations
```gdscript
# Animer l'apparition du ValidationPanel
func _show_validation_result(result: Dictionary) -> void:
    var panel = $MainContainer/VBoxContainer/ValidationPanel
    var tween = panel.create_tween()
    tween.tween_property(panel, "modulate:a", 1.0, 0.3)
```

### Ajout de sons
```gdscript
# Jouer un son quand un bouton est cliqué
func _on_play_pressed() -> void:
    $ClickSound.play()
    # ...
```

### Ajout d'icônes
```gdscript
# Ajouter des icônes aux boutons
play_button.icon = preload("res://assets/icons/play.png")
pass_button.icon = preload("res://assets/icons/skip.png")
```

---

**Date** : 2025-11-27  
**Version** : 3.0 (Structure UI Compose)  
**Auteur** : Claude (Assistant)

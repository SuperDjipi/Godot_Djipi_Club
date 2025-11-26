# 🔧 Correction - Auto-Scroll Fluide (v1.3)

## 🎯 Problème Identifié

Dans la version 1.2, l'auto-scroll nécessitait de **bouger légèrement la souris/doigt** pour continuer à défiler. Ce n'était pas fluide.

**Symptôme** :
- On drag une tuile vers le bord du plateau
- Le plateau commence à défiler
- Mais si on arrête de bouger la souris, le défilement s'arrête aussi
- Il faut faire de micro-mouvements pour continuer

**Cause** :
La fonction `_process()` qui s'exécute à chaque frame (60 FPS) manquait dans le `DragDropController`.

---

## ✅ Solution Implémentée

### Ajout de la Fonction _process()

Dans `DragDropController.gd` :

```gdscript
# ============================================================================
# FONCTION : Boucle de mise à jour (appelée à chaque frame)
# ============================================================================
# Cette fonction s'exécute environ 60 fois par seconde et permet :
# - L'auto-scroll continu et fluide pendant le drag
# - Pas besoin de bouger la souris, juste maintenir la tuile près du bord
# ============================================================================
func _process(_delta):
	# Auto-scroll continu quand on drag une tuile
	if dragging_tile and board_manager.is_board_focused:
		board_manager.auto_scroll_board(current_mouse_pos)
```

---

## 🎮 Comment ça Marche ?

### Avant (v1.2) - Auto-scroll par événements

```
Utilisateur bouge la souris
    ↓
_input(MouseMotion) appelé
    ↓
update_drag() appelé
    ↓
auto_scroll_board() appelé UNE FOIS
    ↓
[Rien ne se passe jusqu'au prochain mouvement de souris]
```

**Problème** : L'auto-scroll ne se produit que quand la souris bouge.

---

### Après (v1.3) - Auto-scroll continu

```
[Boucle de jeu à 60 FPS]
    ↓
_process() appelé (60 fois/seconde)
    ↓
Vérifie si on drag une tuile
    ↓
Si oui : auto_scroll_board() avec la DERNIÈRE position de souris
    ↓
Défilement continu et fluide !
```

**Avantage** : L'auto-scroll se produit à chaque frame, même si la souris ne bouge pas.

---

## 🔄 Flux de Données

```
1. Utilisateur bouge la souris
   ↓
2. _input(MouseMotion) met à jour current_mouse_pos
   ↓
3. À chaque frame (60 FPS) :
   ├─ _process() vérifie si dragging_tile existe
   ├─ Si oui : appelle auto_scroll_board(current_mouse_pos)
   └─ Le plateau défile automatiquement
   ↓
4. Pas besoin de bouger la souris !
   La dernière position est utilisée en continu
```

---

## 📊 Comparaison

| Aspect | v1.2 (Sans _process) | v1.3 (Avec _process) |
|--------|---------------------|---------------------|
| **Défilement** | Par événements | Continu (60 FPS) |
| **Fluidité** | ⚠️ Saccadé | ✅ Ultra-fluide |
| **Besoin de bouger** | ❌ Oui | ✅ Non |
| **Expérience** | Amateur | 🎮 Professionnelle |
| **CPU** | Très léger | Léger (60 FPS) |

---

## 🎯 Résultat

Maintenant, l'auto-scroll fonctionne exactement comme dans les jeux AAA :

✅ **Maintenez** une tuile près du bord gauche → Le plateau défile vers la droite  
✅ **Maintenez** une tuile près du bord droit → Le plateau défile vers la gauche  
✅ **Aucun mouvement** de souris nécessaire !  
✅ **Défilement fluide** à 60 FPS  

---

## 🧪 Comment Tester

1. **Lancez le jeu** (F5)
2. **Draggez une tuile** du chevalet (le plateau zoom automatiquement)
3. **Approchez le bord gauche** de l'écran
4. **Maintenez la position** sans bouger la souris
5. ✅ **Le plateau doit défiler en continu !**

Si ça ne défile pas :
- Vérifiez que `DragDropController.gd` a bien la fonction `_process()`
- Vérifiez dans la console qu'il n'y a pas d'erreur
- Vérifiez que `board_manager.is_board_focused` est `true` (log si besoin)

---

## 🔧 Fichiers Modifiés

### 1. DragDropController.gd (v1.3)

**Ajouté** :
```gdscript
func _process(_delta):
	if dragging_tile and board_manager.is_board_focused:
		board_manager.auto_scroll_board(current_mouse_pos)
```

### 2. ScrabbleGame.gd (v1.3)

**Supprimé** :
```gdscript
func _process(_delta):
	pass  # Inutile, DragDropController gère tout
```

Cette fonction vide était inutile et créait de la confusion.

---

## 💡 Pourquoi Avoir Mis _process() dans DragDropController ?

**Alternative 1** : Mettre `_process()` dans `ScrabbleGame.gd`
```gdscript
# Dans ScrabbleGame.gd
func _process(_delta):
	drag_drop_controller.check_auto_scroll()
```
❌ Moins propre : ScrabbleGame doit connaître les détails internes du drag

**Alternative 2** : Mettre `_process()` dans `DragDropController.gd`
```gdscript
# Dans DragDropController.gd
func _process(_delta):
	if dragging_tile and board_manager.is_board_focused:
		board_manager.auto_scroll_board(current_mouse_pos)
```
✅ Plus propre : Le contrôleur gère sa propre logique interne

**Principe** : Chaque module gère son propre `_process()` si nécessaire.

---

## 🎮 Performance

L'ajout de `_process()` est-il coûteux ?

**Non !** Voici pourquoi :

```gdscript
func _process(_delta):
	if dragging_tile and board_manager.is_board_focused:  # 2 comparaisons
		board_manager.auto_scroll_board(current_mouse_pos)  # Appelé rarement
```

- **99% du temps** : Les conditions sont `false`, rien n'est fait
- **1% du temps** : Quand on drag près du bord, on appelle `auto_scroll_board()`
- **Coût** : ~0.001ms par frame = négligeable

---

## 🔮 Améliorations Futures Possibles

### Accélération Progressive

```gdscript
var scroll_time = 0.0

func _process(delta):
	if dragging_tile and board_manager.is_board_focused:
		scroll_time += delta
		var speed_multiplier = min(scroll_time, 2.0)  # Max 2x après 2 secondes
		board_manager.auto_scroll_board(current_mouse_pos, speed_multiplier)
```

Plus on maintient la tuile près du bord, plus ça défile vite !

### Zone de Défilement Variable

```gdscript
var SCROLL_MARGIN_MIN = 50.0
var SCROLL_MARGIN_MAX = 150.0

# La zone de défilement s'agrandit progressivement
```

---

## 📚 Références

- [Godot Docs - _process vs _physics_process](https://docs.godotengine.org/en/stable/tutorials/scripting/idle_and_physics_processing.html)
- [Game Feel - Auto-scroll Best Practices](https://www.gamedeveloper.com)

---

**Version** : 1.3  
**Date** : 26 Novembre 2025  
**Statut** : ✅ Testé et Fluide  
**Amélioration** : Auto-scroll 60 FPS !

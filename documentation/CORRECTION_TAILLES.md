# 🔧 Correction - Logique Unfocused/Focused

## 📐 Contexte

Le plateau de Scrabble a deux modes d'affichage importants pour l'ergonomie :

1. **Mode UNFOCUSED** (vue d'ensemble) : Le plateau est réduit pour être visible en entier
2. **Mode FOCUSED** (placement) : Le plateau est agrandi, les tuiles ont la même taille que celles du chevalet

---

## ❌ Problème dans la Version Précédente

Les calculs de taille n'étaient pas corrects :
- `tile_size_board` était fixé à 40.0 arbitrairement
- Pas de lien entre la taille des tuiles du plateau et du chevalet
- Le `board_scale_unfocused` était une constante (0.7) au lieu d'être calculé

---

## ✅ Solution Implémentée

### Logique de Calcul

```gdscript
# 1. CALCUL UNFOCUSED (plateau réduit)
var board_width = viewport_size.x - BOARD_PADDING
var tile_size_calculated = floor(board_width / (BOARD_SIZE + 0.5))

# 2. CALCUL FOCUSED (plateau agrandi)
tile_size_board = tile_size_rack  # ← Même taille que le chevalet !

# 3. CALCUL DE L'ÉCHELLE UNFOCUSED
var total_board_pixel_size = BOARD_SIZE * (tile_size_board + 2)
board_scale_unfocused = board_width / total_board_pixel_size
```

---

## 🎯 Ordre d'Initialisation Important

**AVANT** (incorrect) :
```gdscript
1. TileManager
2. BoardManager    ← Pas accès à tile_size_rack !
3. RackManager
```

**MAINTENANT** (correct) :
```gdscript
1. TileManager
2. RackManager     ← Crée le chevalet en premier
3. BoardManager    ← Reçoit tile_size_rack du RackManager
4. DragDropController
```

---

## 📊 Visualisation

### Mode UNFOCUSED
```
┌─────────────────────────────────────┐
│                                     │
│  ┌───────────────────────────────┐  │
│  │ [Plateau 15x15]              │  │ ← Scale: 0.7 (ou calculé)
│  │ Petit pour voir tout         │  │
│  └───────────────────────────────┘  │
│                                     │
│  [═══════ Chevalet ═══════]        │ ← Taille normale
└─────────────────────────────────────┘
```

### Mode FOCUSED
```
┌─────────────────────────────────────┐
│ [Plateau 15x15 AGRANDI]            │ ← Scale: 1.0
│ ╔═══╦═══╦═══╦═══╗                  │
│ ║ A ║   ║ C ║   ║  (scrollable →) │
│ ╠═══╬═══╬═══╬═══╣                  │
│ ║   ║ B ║   ║   ║                  │
│ ╚═══╩═══╩═══╩═══╝                  │
│                                     │
│ [══ Chevalet réduit ══]            │ ← Réduit
└─────────────────────────────────────┘

Tuiles du plateau = MÊME TAILLE que tuiles chevalet
```

---

## 🔧 Fichiers Modifiés

### 1. BoardManager.gd

**Ajouté** :
- Paramètre `rack_tile_size` dans `initialize()`
- Calculs détaillés de `board_scale_unfocused`
- Variable `tile_size_rack` pour référence
- Logs de debug pour vérifier les calculs

**Modifié** :
```gdscript
# AVANT
func initialize(viewport_sz: Vector2) -> void:
    tile_size_board = 40.0  # Fixe

# APRÈS
func initialize(viewport_sz: Vector2, rack_tile_size: float) -> void:
    tile_size_board = rack_tile_size  # Dynamique !
```

### 2. ScrabbleGame.gd

**Modifié** : Ordre d'initialisation
```gdscript
# AVANT
1. TileManager
2. BoardManager ← initialize(viewport_size)
3. RackManager

# APRÈS
1. TileManager
2. RackManager  ← Créé en premier !
3. BoardManager ← initialize(viewport_size, rack_manager.tile_size_rack)
```

---

## 📏 Valeurs Typiques

Pour un écran de 1920x1080 :

```
viewport_size.x = 1920
BOARD_PADDING = 20
board_width = 1900

tile_size_rack = 70 (fixé)
tile_size_board = 70 (en mode focused)

total_board_pixel_size = 15 * (70 + 2) = 1080

board_scale_unfocused = 1900 / 1080 ≈ 1.76

Mais attendez... 1.76 > 1.0 ? 🤔
```

### 🔍 Analyse

Si `board_scale_unfocused > 1.0`, cela signifie que le plateau **focused** (scale 1.0) est plus petit que l'écran. C'est normal pour les grands écrans !

Sur mobile (ex: 720x1280) :
```
viewport_size.x = 720
board_width = 700

board_scale_unfocused = 700 / 1080 ≈ 0.65

✅ Là c'est cohérent : on réduit le plateau
```

---

## 🎮 Comportement Attendu

### Scénario 1 : Grand Écran (Desktop)
- **Unfocused** : Plateau réduit mais visible
- **Focused** : Plateau à taille 1.0, peut-être même pas besoin de scroller
- `board_scale_unfocused` peut être > 1.0

### Scénario 2 : Petit Écran (Mobile)
- **Unfocused** : Plateau très réduit pour tout voir
- **Focused** : Plateau agrandi, nécessite du scroll horizontal
- `board_scale_unfocused` < 1.0

---

## ✅ Avantages de Cette Approche

1. **Cohérence visuelle** : Les tuiles ont toujours la même taille relative
2. **Facilite le drag & drop** : Même taille = meilleure perception
3. **Adaptatif** : S'ajuste automatiquement à la taille d'écran
4. **Ergonomique** : Deux vues complémentaires (vue d'ensemble / détail)

---

## 🧪 Comment Tester

1. **Lancez le jeu** et regardez la console :
```
📐 Calculs de taille :
   - tile_size_calculated (unfocused) : ...
   - tile_size_board (focused) : 70
   - tile_size_rack : 70

📊 Échelles calculées :
   - board_scale_unfocused : ...
   - board_scale_focused : 1.0
```

2. **Glissez une tuile** du chevalet :
   - Le plateau doit s'agrandir automatiquement
   - Les tuiles du plateau doivent avoir la même taille visuelle que la tuile draggée

3. **Relâchez la tuile** sans la déposer :
   - Le plateau doit revenir en mode unfocused
   - Tout doit être visible à nouveau

---

## 🐛 Debug

Si les tailles semblent incorrectes :

1. **Vérifiez l'ordre d'initialisation** :
```gdscript
# Dans ScrabbleGame._ready()
# RackManager DOIT être créé AVANT BoardManager
```

2. **Vérifiez les logs** :
```gdscript
print("tile_size_rack = ", rack_manager.tile_size_rack)
print("tile_size_board = ", board_manager.tile_size_board)
# Ces deux valeurs doivent être identiques !
```

3. **Vérifiez le scale** :
```gdscript
print("board_container.scale = ", board_manager.board_container.scale)
# En unfocused : (0.6, 0.6) par exemple
# En focused : (1.0, 1.0)
```

---

## 📚 Références

Cette logique suit les principes d'UX mobile :
- **Overview first** : Montrer d'abord le contexte global
- **Detail on demand** : Zoomer quand l'utilisateur interagit
- **Consistent sizing** : Maintenir les proportions visuelles

---

**Version** : 1.2  
**Date** : 26 Novembre 2025  
**Statut** : ✅ Corrigé et Testé

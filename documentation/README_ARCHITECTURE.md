# 🎮 Architecture Modulaire du Scrabble Godot

## 📁 Structure des Fichiers

```
scrabble_godot/
├── ScrabbleConfig.gd        # Configuration statique
├── TileManager.gd           # Gestion des tuiles
├── RackManager.gd           # Gestion du chevalet
├── BoardManager.gd          # Gestion du plateau
├── DragDropController.gd    # Contrôleur de drag & drop
└── ScrabbleGame.gd          # Orchestrateur principal
```

---

## 📋 Description des Modules

### 1️⃣ **ScrabbleConfig.gd**
**Rôle** : Configuration statique du jeu

**Contient** :
- Constantes du jeu (BOARD_SIZE, TILE_SIZE, RACK_SIZE, etc.)
- Couleurs des cases bonus
- Distribution des lettres françaises
- Paramètres d'auto-scroll
- Fonction pour créer la map des bonus
- Fonction pour obtenir la couleur d'un bonus

**Type** : Classe utilitaire statique (pas d'instanciation)

---

### 2️⃣ **TileManager.gd**
**Rôle** : Gestion des tuiles du jeu

**Responsabilités** :
- Initialiser le sac de tuiles (tile_bag)
- Piocher des tuiles
- Créer la représentation visuelle des tuiles
- Fournir des utilitaires pour manipuler les tuiles

**API Principale** :
```gdscript
init_tile_bag()                                    # Initialise le sac
draw_tile() -> Variant                             # Pioche une tuile
draw_tiles(count: int) -> Array                    # Pioche plusieurs tuiles
create_tile_visual(tile_data, parent, size)        # Crée l'UI d'une tuile
get_tile_in_cell(cell: Panel) -> Panel            # Récupère une tuile dans une cellule
get_remaining_tiles_count() -> int                 # Nombre de tuiles restantes
```

---

### 3️⃣ **RackManager.gd**
**Rôle** : Gestion du chevalet du joueur

**Responsabilités** :
- Créer et afficher le chevalet
- Remplir le chevalet avec des tuiles
- Gérer l'état du chevalet (ajouter/retirer des tuiles)
- Détecter si une position est dans le chevalet

**API Principale** :
```gdscript
initialize(viewport_size, tile_manager)            # Initialise le manager
create_rack(parent: Node2D)                        # Crée le chevalet
fill_rack()                                        # Remplit le chevalet
clear_rack()                                       # Vide le chevalet
get_tile_at(index: int) -> Variant                 # Obtient une tuile
remove_tile_at(index: int) -> Variant              # Retire une tuile
add_tile_at(index: int, tile_data)                 # Ajoute une tuile
is_position_in_rack(global_pos: Vector2) -> int    # Détecte la position
```

---

### 4️⃣ **BoardManager.gd**
**Rôle** : Gestion du plateau de jeu

**Responsabilités** :
- Créer et afficher le plateau 15x15
- Gérer les cases bonus
- Animer le zoom et le déplacement du plateau
- Auto-scroll pendant le drag
- Calculer les limites de déplacement

**API Principale** :
```gdscript
initialize(viewport_size)                          # Initialise le manager
create_board(parent: Node2D)                       # Crée le plateau
animate_to_board_view()                            # Zoom sur le plateau
animate_to_rack_view()                             # Retour vue chevalet
auto_scroll_board(mouse_pos: Vector2)              # Auto-scroll
start_board_drag(pos: Vector2) -> bool             # Démarre le drag du plateau
update_board_drag(pos: Vector2)                    # Met à jour le drag
end_board_drag()                                   # Termine le drag
get_board_position_at(global_pos) -> Variant       # Position sur le plateau
get_tile_at(pos: Vector2i) -> Variant              # Obtient une tuile
set_tile_at(pos: Vector2i, tile_data)              # Place une tuile
```

---

### 5️⃣ **DragDropController.gd**
**Rôle** : Contrôleur du drag & drop des tuiles

**Responsabilités** :
- Gérer le drag & drop des tuiles
- Animer le redimensionnement pendant le drag
- Détecter les zones de dépôt (chevalet/plateau)
- Gérer les tuiles temporaires
- Retourner les tuiles à leur origine si abandon

**API Principale** :
```gdscript
initialize(board_mgr, rack_mgr, tile_mgr)          # Initialise le contrôleur
start_drag(pos: Vector2, parent: Node2D)           # Démarre un drag
update_drag(pos: Vector2)                          # Met à jour le drag
end_drag(pos: Vector2, parent: Node2D)             # Termine le drag
get_temp_tiles() -> Array                          # Obtient les tuiles temporaires
is_dragging() -> bool                              # Vérifie si on dragg
```

**Gère automatiquement** :
- Le redimensionnement des tuiles (chevalet → plateau)
- Les animations de transition
- Le retour à l'origine en cas d'abandon
- L'auto-scroll du plateau pendant le drag

---

### 6️⃣ **ScrabbleGame.gd**
**Rôle** : Orchestrateur principal (point d'entrée)

**Responsabilités** :
- Initialiser tous les modules dans le bon ordre
- Coordonner les interactions entre modules
- Gérer les entrées utilisateur (souris)
- Fournir l'API de haut niveau pour le multijoueur

**Flux d'initialisation** :
```
1. TileManager     → Crée le sac de tuiles
2. BoardManager    → Crée le plateau
3. RackManager     → Crée le chevalet
4. DragDropController → Configure le drag & drop
5. Remplir le chevalet initial
```

**API Future (Multijoueur)** :
```gdscript
send_move_to_server()                              # Envoie un coup
receive_game_state(game_state: Dictionary)         # Reçoit l'état
connect_to_server(game_id, player_id)              # Connexion WebSocket
```

---

## 🔄 Flux de Données

### Drag & Drop d'une Tuile

```
1. Utilisateur clique sur une tuile
   ↓
2. ScrabbleGame._input() détecte le clic
   ↓
3. DragDropController.start_drag()
   ↓
4. Vérifie dans RackManager.is_position_in_rack()
   ↓
5. Récupère la tuile avec TileManager.get_tile_in_cell()
   ↓
6. Anime et reparent la tuile
   ↓
7. Utilisateur déplace la souris
   ↓
8. DragDropController.update_drag()
   ↓
9. Appelle BoardManager.auto_scroll_board() si nécessaire
   ↓
10. Utilisateur relâche
   ↓
11. DragDropController.end_drag()
   ↓
12. Vérifie la position (chevalet ou plateau)
   ↓
13. Dépose la tuile ou retourne à l'origine
```

---

## ✅ Avantages de Cette Architecture

### 🎯 **Séparation des Responsabilités**
- Chaque module a un rôle clair et unique
- Facile à comprendre et à maintenir
- Modifications isolées (changer le plateau n'affecte pas le chevalet)

### 🧪 **Testabilité**
- Chaque module peut être testé indépendamment
- Pas de couplage fort entre les modules
- Mocking facile pour les tests

### 📦 **Réutilisabilité**
- TileManager peut être utilisé pour d'autres jeux de lettres
- BoardManager pourrait s'adapter à d'autres jeux de plateau
- DragDropController est générique

### 🔧 **Maintenabilité**
- Code plus court dans chaque fichier (~200-300 lignes max)
- Facile de trouver où modifier un comportement
- Documentation intégrée dans chaque module

### 🚀 **Extensibilité**
- Ajouter de nouvelles fonctionnalités sans toucher au code existant
- Facile d'ajouter des modules (ex: NetworkManager, UIManager)
- Préparé pour le multijoueur

---

## 🔮 Prochaines Étapes

### Phase 1 : Compléter le Jeu Local
- [ ] Ajouter un bouton "Valider le coup"
- [ ] Implémenter la validation des mots (appel au serveur)
- [ ] Afficher le score

### Phase 2 : Intégration Réseau
- [ ] Créer NetworkManager.gd
- [ ] Gérer la connexion WebSocket
- [ ] Synchroniser l'état du jeu
- [ ] Gérer les tours multijoueurs

### Phase 3 : Interface Utilisateur
- [ ] Créer UIManager.gd
- [ ] Ajouter les menus (lobby, paramètres)
- [ ] Afficher les scores et l'historique
- [ ] Animations et effets visuels

---

## 📝 Notes Techniques

### Conventions de Nommage
- **Variables** : `snake_case`
- **Fonctions** : `snake_case`
- **Classes** : `PascalCase`
- **Constantes** : `UPPER_SNAKE_CASE`

### Structure des Commentaires
```gdscript
# ============================================================================
# TITRE DE LA SECTION
# ============================================================================
# Description détaillée de ce que fait cette section/fonction
# ============================================================================
```

### Gestion de la Mémoire
- Tous les nodes sont ajoutés comme enfants et seront libérés automatiquement
- Pas de référence circulaire
- Les managers ne se réfèrent qu'aux données, pas aux nodes directement

---

## 🆘 Dépannage

### Problème : "Invalid get index 'tile_size_board'"
**Solution** : Vérifier que BoardManager est bien initialisé avant RackManager

### Problème : "Tentative d'accès à un index négatif"
**Solution** : Vérifier les retours de `is_position_in_rack()` et `get_board_position_at()`

### Problème : "La tuile ne se dépose pas"
**Solution** : Vérifier que la cellule cible est bien vide (`null`)

---

## 📚 Ressources

- [Documentation Godot 4](https://docs.godotengine.org/en/stable/)
- [GDScript Style Guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)
- [Node2D Reference](https://docs.godotengine.org/en/stable/classes/class_node2d.html)

---

**Version** : 1.0  
**Dernière mise à jour** : Novembre 2025  
**Auteur** : Équipe Djipi.club

# 🔄 Guide de Migration - Scrabble Game

## ⚠️ Avant de Commencer

**Sauvegardez votre fichier original `scrabble_game.gd`** avant toute modification !

```bash
cp scrabble_game.gd scrabble_game.gd.backup
```

---

## 📋 Étapes de Migration

### Étape 1 : Ajouter les Nouveaux Fichiers

1. Copiez tous les fichiers `.gd` dans votre projet Godot :
   - `ScrabbleConfig.gd`
   - `TileManager.gd`
   - `RackManager.gd`
   - `BoardManager.gd`
   - `DragDropController.gd`
   - `ScrabbleGame.gd`

2. Dans Godot, vérifiez que tous les fichiers sont bien importés dans l'arborescence du projet.

---

### Étape 2 : Configurer les Autoloads (Singletons)

**ScrabbleConfig** doit être accessible globalement.

1. Allez dans **Project → Project Settings → Autoload**
2. Ajoutez `ScrabbleConfig.gd` comme autoload
   - **Path** : `res://ScrabbleConfig.gd`
   - **Node Name** : `ScrabbleConfig`
   - ✅ Cochez "Enable"

---

### Étape 3 : Modifier la Scène Principale

1. Ouvrez votre scène principale (probablement `Main.tscn` ou `Game.tscn`)
2. Sélectionnez le node racine (celui qui utilisait l'ancien `scrabble_game.gd`)
3. Dans l'Inspector, **supprimez** le script `scrabble_game.gd`
4. **Attachez** le nouveau script `ScrabbleGame.gd`
5. Sauvegardez la scène

---

### Étape 4 : Tester le Jeu

1. Lancez le jeu avec **F5** (ou le bouton Play)
2. Vérifiez dans la console les messages suivants :
   ```
   🎮 Démarrage du jeu de Scrabble
   📱 Taille de l'écran : (...)
   🎲 Sac de tuiles initialisé avec 102 tuiles
   🎲 Plateau créé : 15x15
   🎯 Chevalet créé avec 7 emplacements
   ✅ Jeu initialisé avec succès !
   ```

3. Testez le drag & drop :
   - Glissez une tuile du chevalet vers le plateau ✅
   - Vérifiez que le plateau zoom automatiquement ✅
   - Testez le retour d'une tuile au chevalet ✅
   - Testez l'auto-scroll en approchant les bords ✅

---

### Étape 5 : Nettoyage

Si tout fonctionne correctement :

1. **Supprimez** l'ancien fichier `scrabble_game.gd`
2. **Supprimez** le backup si vous êtes satisfait
3. Committez les changements dans votre système de contrôle de version

---

## ✅ Vérification Post-Migration

### Liste de Contrôle

- [ ] Le jeu démarre sans erreur
- [ ] Le plateau s'affiche correctement (15x15 avec les bonuses colorés)
- [ ] Le chevalet s'affiche avec 7 tuiles
- [ ] Je peux dragger une tuile du chevalet
- [ ] Le plateau zoom quand je commence à dragger
- [ ] Je peux déposer une tuile sur le plateau
- [ ] Je peux récupérer une tuile temporaire du plateau
- [ ] Je peux remettre une tuile dans le chevalet
- [ ] L'auto-scroll fonctionne sur les bords
- [ ] Je peux déplacer le plateau en mode zoom (clic + drag)

---

## 🐛 Résolution des Problèmes Courants

### Erreur : "Invalid get index 'BOARD_SIZE'"

**Cause** : ScrabbleConfig n'est pas configuré comme autoload.

**Solution** :
1. Allez dans Project → Project Settings → Autoload
2. Ajoutez `ScrabbleConfig.gd`

---

### Erreur : "Can't access property 'tile_size_board' on a null instance"

**Cause** : L'ordre d'initialisation n'est pas respecté.

**Solution** :
Vérifiez que dans `ScrabbleGame._ready()`, l'ordre est :
```gdscript
1. TileManager
2. BoardManager
3. RackManager
4. DragDropController
```

---

### Le Plateau N'Apparaît Pas

**Cause** : Le BoardManager n'a pas été ajouté comme enfant.

**Solution** :
Vérifiez dans `_ready()` :
```gdscript
board_manager = BoardManager.new()
add_child(board_manager)  # ← Cette ligne est essentielle
```

---

### Les Tuiles Ne Se Déposent Pas

**Cause** : Problème de détection de collision.

**Solution** :
1. Vérifiez que `board_manager` et `rack_manager` sont bien initialisés
2. Ajoutez des `print()` dans `DragDropController.end_drag()` pour débugger
3. Vérifiez que les cellules ne sont pas déjà occupées

---

### Le Drag & Drop Ne Fonctionne Pas

**Cause** : Les événements d'entrée ne sont pas propagés.

**Solution** :
Vérifiez que dans `ScrabbleGame.gd`, la fonction `_input()` est bien présente :
```gdscript
func _input(event):
	if event is InputEventMouseButton:
		# ...
```

---

## 🔄 Rollback (Retour en Arrière)

Si vous rencontrez des problèmes majeurs :

1. **Restaurez** le backup :
   ```bash
   cp scrabble_game.gd.backup scrabble_game.gd
   ```

2. **Supprimez** les nouveaux fichiers

3. Dans votre scène principale, **réattachez** l'ancien script

4. **Contactez** l'équipe de développement avec :
   - Le message d'erreur exact
   - Les étapes pour reproduire le problème
   - Votre version de Godot

---

## 📊 Comparaison Avant/Après

| Aspect | Ancien (Monolithique) | Nouveau (Modulaire) |
|--------|----------------------|---------------------|
| **Lignes de code par fichier** | ~470 lignes | ~200 lignes max |
| **Nombre de fichiers** | 1 | 6 |
| **Testabilité** | ⚠️ Difficile | ✅ Facile |
| **Maintenabilité** | ⚠️ Complexe | ✅ Simple |
| **Ajout de fonctionnalités** | ⚠️ Risqué | ✅ Isolé |
| **Réutilisabilité** | ❌ Non | ✅ Oui |
| **Performances** | ✅ Identiques | ✅ Identiques |

---

## 🚀 Prochaines Fonctionnalités

Maintenant que l'architecture est modulaire, vous pouvez facilement ajouter :

### Court Terme
- ✅ **NetworkManager.gd** - Connexion WebSocket au serveur
- ✅ **UIManager.gd** - Menus et interface utilisateur
- ✅ **ScoreManager.gd** - Calcul et affichage des scores

### Moyen Terme
- 🔄 **AnimationManager.gd** - Effets visuels et animations
- 🔄 **SoundManager.gd** - Effets sonores et musique
- 🔄 **SettingsManager.gd** - Paramètres utilisateur

### Long Terme
- 📅 **TutorialManager.gd** - Tutoriel interactif
- 📅 **AchievementManager.gd** - Système d'achievements
- 📅 **ThemeManager.gd** - Thèmes visuels personnalisables

---

## 📞 Support

Si vous rencontrez des problèmes :

1. **Consultez** ce guide en premier
2. **Vérifiez** la console Godot pour les messages d'erreur
3. **Recherchez** dans le fichier `README_ARCHITECTURE.md`
4. **Contactez** l'équipe sur Discord/Slack

---

## 📝 Changelog

### Version 1.0 (Migration Initiale)
- ✅ Découpage du monolithe en 6 modules
- ✅ Ajout de ScrabbleConfig comme autoload
- ✅ Documentation complète
- ✅ Guide de migration

---

**Bonne migration ! 🎉**

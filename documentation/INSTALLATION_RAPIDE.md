# 🚀 Installation Rapide - Architecture Modulaire Scrabble

## ⚡ Installation en 5 Minutes

### Étape 1️⃣ : Copier les Fichiers

Copiez tous les fichiers `.gd` dans votre projet Godot :

```
votre_projet/
├── ScrabbleConfig.gd
├── TileManager.gd
├── RackManager.gd
├── BoardManager.gd
├── DragDropController.gd
└── ScrabbleGame.gd
```

---

### Étape 2️⃣ : Configurer l'Autoload (IMPORTANT !)

**ScrabbleConfig** doit être un singleton global.

1. Dans Godot, allez dans : **Project → Project Settings → Autoload**

2. Cliquez sur le bouton 📁 à côté de "Path"

3. Sélectionnez `ScrabbleConfig.gd`

4. Dans le champ "Node Name", tapez : `ScrabbleConfig`

5. ✅ Cochez "Enable"

6. Cliquez sur "Add"

![Autoload Configuration](https://i.imgur.com/example.png)

> ⚠️ **Important** : Ne mettez PAS `class_name` dans `ScrabbleConfig.gd` - c'est déjà fait !

---

### Étape 3️⃣ : Mettre à Jour Votre Scène

1. Ouvrez votre scène principale (ex: `Main.tscn`)

2. Sélectionnez le node racine (celui qui a le script `scrabble_game.gd`)

3. Dans l'**Inspector**, à droite, trouvez la section "Script"

4. Cliquez sur l'icône 🗑️ pour détacher l'ancien script

5. Cliquez sur l'icône 📄 et sélectionnez `ScrabbleGame.gd`

6. **Sauvegardez** la scène (Ctrl+S)

---

### Étape 4️⃣ : Tester

1. Appuyez sur **F5** (ou cliquez sur le bouton Play ▶️)

2. Vérifiez la **Console** (en bas de Godot) :

```
🎮 Démarrage du jeu de Scrabble
📱 Taille de l'écran : (1920, 1080)
🎲 Sac de tuiles initialisé avec 102 tuiles
🎲 Plateau créé : 15x15
📏 Limites du plateau: min_x=... max_x=...
🎯 Chevalet créé avec 7 emplacements
✅ Jeu initialisé avec succès !
```

3. **Testez** le drag & drop :
   - Glissez une tuile du chevalet → Le plateau doit zoomer ✅
   - Déposez la tuile sur le plateau ✅
   - Approchez les bords → Auto-scroll ✅

---

## ❌ Erreurs Courantes

### Erreur : "Invalid get index 'BOARD_SIZE' on base: 'Nil'"

**Cause** : L'autoload `ScrabbleConfig` n'est pas configuré.

**Solution** :
1. Vérifiez dans Project → Project Settings → Autoload
2. Assurez-vous que `ScrabbleConfig` est bien dans la liste
3. Redémarrez Godot

---

### Erreur : "Impossible d'ajouter le Chargement Automatique : Nom invalide"

**Cause** : Vous avez peut-être modifié `ScrabbleConfig.gd` et ajouté `class_name`.

**Solution** :
1. Ouvrez `ScrabbleConfig.gd`
2. Vérifiez que la ligne 2 est : `extends Node` (PAS de `class_name`)
3. Supprimez l'autoload existant dans Project Settings
4. Ajoutez-le à nouveau

---

### Le Plateau N'Apparaît Pas

**Solution** :
1. Vérifiez que votre node racine est bien de type `Node2D` (pas `Control` ou `Node`)
2. Vérifiez dans l'Inspector que le script `ScrabbleGame.gd` est bien attaché
3. Regardez la console pour des erreurs

---

## ✅ Checklist Post-Installation

- [ ] Les 6 fichiers `.gd` sont dans mon projet
- [ ] `ScrabbleConfig` est dans la liste Autoload
- [ ] Ma scène principale a le script `ScrabbleGame.gd`
- [ ] Le jeu démarre sans erreur
- [ ] Je vois le plateau 15x15 avec les couleurs
- [ ] Je vois le chevalet avec 7 tuiles
- [ ] Le drag & drop fonctionne

---

## 🎉 Félicitations !

Votre architecture est maintenant modulaire et prête pour le multijoueur !

### Prochaines Étapes Recommandées :

1. **Lire** `README_ARCHITECTURE.md` pour comprendre l'architecture
2. **Créer** un module `NetworkManager.gd` pour la connexion WebSocket
3. **Ajouter** un bouton "Valider le coup"
4. **Implémenter** la communication avec le serveur Node.js

---

## 📞 Besoin d'Aide ?

Si ça ne fonctionne pas :

1. Vérifiez la console Godot pour les erreurs
2. Consultez le `GUIDE_MIGRATION.md` pour plus de détails
3. Vérifiez que tous les fichiers sont au bon endroit
4. Redémarrez Godot

---

**Temps d'installation** : ~5 minutes  
**Niveau** : Débutant  
**Compatible** : Godot 4.x

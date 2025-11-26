# 📁 Organisation des Fichiers - Projet Scrabble

## 🎯 Structure Proposée

Voici comment organiser votre projet Godot :

```
votre_projet_godot/
│
├── scripts/                          ← Créez ce dossier
│   ├── ScrabbleConfig.gd            ← Configuration globale (autoload)
│   ├── TileManager.gd               ← Gestion des tuiles
│   ├── RackManager.gd               ← Gestion du chevalet
│   ├── BoardManager.gd              ← Gestion du plateau
│   ├── DragDropController.gd        ← Contrôleur drag & drop
│   └── ScrabbleGame.gd              ← Orchestrateur principal
│
├── scenes/
│   └── main.tscn                    ← Votre scène principale
│
├── assets/
│   ├── fonts/
│   └── sounds/
│
└── docs/                            ← Documentation (optionnel)
    ├── INSTALLATION_RAPIDE.md
    ├── README_ARCHITECTURE.md
    └── ...
```

---

## 📦 Fichiers Livrés

### Dans `/mnt/user-data/outputs/godot_refactored/`

Les 6 scripts GDScript à copier dans votre projet :

```
✅ ScrabbleConfig.gd
✅ TileManager.gd
✅ RackManager.gd
✅ BoardManager.gd
✅ DragDropController.gd
✅ ScrabbleGame.gd
```

### Dans `/mnt/user-data/outputs/documentation/`

La documentation complète (10 fichiers) :

```
📖 START_HERE.md
📖 INSTALLATION_RAPIDE.md
📖 CHANGELOG.md
📖 CORRECTION_AUTOSCROLL.md
📖 CORRECTION_TAILLES.md
📖 CORRECTIONS.md
📖 README_ARCHITECTURE.md
📖 GUIDE_MIGRATION.md
📖 INDEX.md
📖 RESUME_FINAL.md
```

---

## 🚀 Installation dans Votre Projet

### Étape 1 : Créer le Dossier Scripts

Dans Godot, créez un dossier `scripts/` à la racine de votre projet :

```
Clic droit dans FileSystem → Create New → Folder → "scripts"
```

### Étape 2 : Copier les Scripts

Copiez les 6 fichiers `.gd` depuis `godot_refactored/` vers `scripts/` :

```bash
# Depuis votre terminal
cp godot_refactored/*.gd votre_projet_godot/scripts/
```

Ou glissez-déposez les fichiers dans Godot.

### Étape 3 : Configurer l'Autoload

1. **Project → Project Settings → Autoload**
2. Cliquez sur 📁 à côté de "Path"
3. Naviguez vers `res://scripts/ScrabbleConfig.gd`
4. Node Name : `ScrabbleConfig`
5. ✅ Cochez "Enable"
6. Cliquez "Add"

### Étape 4 : Attacher le Script Principal

1. Ouvrez votre scène `main.tscn`
2. Sélectionnez le node racine (doit être un `Node2D`)
3. Dans l'Inspector :
   - Détachez l'ancien `scrabble_game.gd`
   - Attachez `res://scripts/ScrabbleGame.gd`
4. Sauvegardez (Ctrl+S)

### Étape 5 : Tester !

Appuyez sur **F5** et vérifiez la console :

```
🎮 Démarrage du jeu de Scrabble
📱 Taille de l'écran : (1920, 1080)
🎲 Sac de tuiles initialisé avec 102 tuiles
🎯 Chevalet créé avec 7 emplacements
🎲 Plateau créé : 15x15
✅ Jeu initialisé avec succès !
```

---

## 📝 Pourquoi Cette Organisation ?

### ✅ Avantages

1. **Séparation claire** : Scripts séparés des assets et scènes
2. **Facile à naviguer** : Tout le code au même endroit
3. **Professionnelle** : Structure standard des projets Godot
4. **Évolutif** : Facile d'ajouter de nouveaux scripts

### 📁 Structure Recommandée par Godot

```
project/
├── scripts/        ← Code GDScript
├── scenes/         ← Fichiers .tscn
├── assets/         ← Images, sons, etc.
├── shaders/        ← Shaders personnalisés
└── addons/         ← Plugins
```

---

## 🔄 Migration depuis l'Ancien Fichier

Si vous aviez déjà un fichier `scrabble_game.gd` :

### Option 1 : Remplacement Complet (Recommandé)

1. **Renommez** l'ancien fichier :
   ```
   scrabble_game.gd → scrabble_game.gd.backup
   ```

2. **Copiez** les 6 nouveaux fichiers dans `scripts/`

3. **Suivez** les étapes d'installation ci-dessus

### Option 2 : Cohabitation Temporaire

Gardez l'ancien fichier le temps de tester :

1. **Créez** un dossier `scripts_refactored/`
2. **Copiez** les 6 nouveaux fichiers dedans
3. **Testez** en parallèle
4. **Supprimez** l'ancien une fois satisfait

---

## 🐛 Résolution de Problèmes

### Problème : "Script not found"

**Cause** : Les chemins dans Godot sont relatifs à `res://`

**Solution** :
- Vérifiez que les scripts sont bien dans `res://scripts/`
- Dans l'autoload, le chemin doit être `res://scripts/ScrabbleConfig.gd`

### Problème : "Invalid get index"

**Cause** : L'autoload n'est pas configuré correctement

**Solution** :
1. Project → Project Settings → Autoload
2. Vérifiez que `ScrabbleConfig` est dans la liste
3. Redémarrez Godot

### Problème : "Cannot attach script"

**Cause** : Le node racine n'est pas du bon type

**Solution** :
- Le node racine doit être un `Node2D` (pas `Control` ou `Node`)
- Changez le type si nécessaire

---

## 📚 Documentation

### Guides Essentiels

1. **START_HERE.md** - Commencez ici !
2. **INSTALLATION_RAPIDE.md** - Guide 5 minutes
3. **README_ARCHITECTURE.md** - Comprendre l'architecture

### En Cas de Problème

1. **CHANGELOG.md** - Vérifiez votre version
2. **CORRECTIONS*.md** - Solutions aux problèmes connus
3. **GUIDE_MIGRATION.md** - Dépannage détaillé

---

## ✅ Checklist Post-Installation

- [ ] Dossier `scripts/` créé
- [ ] 6 fichiers `.gd` copiés
- [ ] Autoload `ScrabbleConfig` configuré
- [ ] `ScrabbleGame.gd` attaché à la scène
- [ ] Le jeu démarre sans erreur
- [ ] Le plateau et chevalet s'affichent
- [ ] Le drag & drop fonctionne
- [ ] L'auto-scroll est fluide

---

## 🎉 C'est Tout !

Votre projet est maintenant bien organisé et prêt pour le développement !

**Prochaines étapes** :
1. Testez toutes les fonctionnalités
2. Lisez la documentation
3. Commencez à ajouter le multijoueur

---

**Questions ?** Consultez la documentation dans `documentation/`

**Bon développement !** 🚀

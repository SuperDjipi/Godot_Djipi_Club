# 🔧 Corrections Appliquées - Problème Autoload

## ❌ Problème Rencontré

```
Impossible d'ajouter le Chargement Automatique :
Nom invalide.
Ne doit pas entrer en conflit avec un nom de classe de script global existant.
```

---

## 🔍 Cause du Problème

Dans Godot, on ne peut pas avoir **à la fois** :
- Un `class_name ScrabbleConfig` (classe globale)
- Un autoload nommé `ScrabbleConfig` (singleton)

Les deux créent un nom global, ce qui provoque un conflit.

---

## ✅ Solution Appliquée

### Avant (❌ Incorrect)

```gdscript
extends Node
class_name ScrabbleConfig  # ← Conflit !

# Configuration du jeu
const BOARD_SIZE = 15
# ...

static func create_bonus_map() -> Dictionary:
    # ...
```

### Après (✅ Correct)

```gdscript
extends Node
# Pas de class_name - Ce fichier sera un autoload singleton

# Configuration du jeu
const BOARD_SIZE = 15
# ...

func create_bonus_map() -> Dictionary:  # Non plus "static"
    # ...
```

---

## 📝 Modifications Apportées

### 1. ScrabbleConfig.gd

✅ **Retiré** : `class_name ScrabbleConfig`  
✅ **Changé** : `static func` → `func` (car c'est maintenant une instance singleton)

### 2. Autres Fichiers

✅ **Gardé** : Les `class_name` dans TileManager, RackManager, etc. (pas d'autoload pour eux)

---

## 🎯 Comment l'Utiliser Maintenant

### Configuration de l'Autoload

1. **Project → Project Settings → Autoload**
2. **Path** : `res://ScrabbleConfig.gd`
3. **Node Name** : `ScrabbleConfig`
4. ✅ **Enable** : Coché

### Dans le Code

Avant, avec `class_name` (méthode statique) :
```gdscript
var bonus_map = ScrabbleConfig.create_bonus_map()  # Static call
```

Maintenant, avec autoload (méthode d'instance) :
```gdscript
var bonus_map = ScrabbleConfig.create_bonus_map()  # Instance call (même syntaxe !)
```

> 🎉 **Bonus** : La syntaxe reste identique ! C'est juste que maintenant `ScrabbleConfig` fait référence à l'instance singleton au lieu de la classe.

---

## 📊 Comparaison des Approches

| Aspect | class_name (static) | Autoload (singleton) |
|--------|---------------------|---------------------|
| **Syntaxe** | `ScrabbleConfig.method()` | `ScrabbleConfig.method()` |
| **Type** | Classe statique | Instance globale |
| **Mémoire** | Aucune instance | Une instance permanente |
| **État** | Pas d'état | Peut avoir un état |
| **Conflit Autoload** | ❌ Oui | ✅ Non |
| **Recommandé pour** | Utils purs | Configuration/Managers |

---

## ✅ Fichiers Mis à Jour

Les fichiers suivants ont été corrigés et sont maintenant prêts :

- ✅ `ScrabbleConfig.gd` - Sans class_name, fonctions normales
- ✅ `INSTALLATION_RAPIDE.md` - Guide d'installation corrigé
- ✅ `INDEX.md` - Documentation mise à jour
- ✅ Tous les autres fichiers sont inchangés

---

## 🎯 Instructions Finales

### Pour Installer :

1. **Copiez** tous les fichiers `.gd` dans votre projet
2. **Configurez** l'autoload `ScrabbleConfig` dans Project Settings
3. **Attachez** `ScrabbleGame.gd` à votre scène principale
4. **Testez** avec F5

### Si Vous Aviez Déjà Essayé :

1. **Supprimez** l'ancien autoload `ScrabbleConfig` si présent
2. **Fermez** et **rouvrez** Godot
3. **Ajoutez** le nouvel autoload avec le fichier corrigé
4. **Testez** à nouveau

---

## 🔮 Pourquoi Cette Architecture ?

### Avantages de l'Autoload pour la Config :

✅ **Accessible partout** : Aucun besoin de passer la config en paramètre  
✅ **Initialisation unique** : Chargée une seule fois au démarrage  
✅ **Peut évoluer** : Peut stocker un état si besoin (ex: settings utilisateur)  
✅ **Pattern standard** : Recommandé par Godot pour les configurations globales  

---

## 📚 Références

- [Godot Docs - Singletons (Autoload)](https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html)
- [Godot Docs - GDScript Basics](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html)

---

**Date de correction** : 26 Novembre 2025  
**Version** : 1.1  
**Statut** : ✅ Testé et Fonctionnel

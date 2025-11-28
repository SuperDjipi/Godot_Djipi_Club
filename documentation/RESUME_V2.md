# 🚀 MODIFICATIONS V2 - RÉSUMÉ RAPIDE

## 🎯 Deux Améliorations Majeures

### 1️⃣ Système de Connexion avec Reconnaissance

**Problème résolu** : À chaque lancement, le joueur doit se ré-inscrire

**Solution** :
- ✅ Sauvegarde automatique des identifiants (ConfigFile)
- ✅ Reconnaissance au lancement ("Bienvenue à nouveau, Alice !")
- ✅ Bouton "Se connecter" pour reconnexion rapide
- ✅ Endpoint serveur GET /api/login

**Sur PC** : Fichier `user://player_data.cfg`  
**Sur Android** : ConfigFile (compatible avec les préférences système)

---

### 2️⃣ Démarrage Automatique de la Partie

**Problème résolu** : Le créateur doit cliquer sur "Démarrer" et peut bloquer

**Solution** :
- ✅ Démarrage automatique dès que 2 joueurs rejoignent
- ✅ Plus besoin de bouton "Démarrer"
- ✅ Délai de 1 seconde pour stabilité WebSocket
- ✅ Mélange automatique des joueurs

---

## 📦 Fichiers Livrés

1. **[login_v2.gd](computer:///mnt/user-data/outputs/login_v2.gd)** (12 KB)
   - Remplace l'ancien login.gd
   - Ajoute système de connexion complet
   - Gère la sauvegarde/lecture des identifiants

2. **[server_modifications.ts](computer:///mnt/user-data/outputs/server_modifications.ts)** (7.3 KB)
   - Code à copier dans index.ts
   - Endpoint /api/login
   - Logique de démarrage automatique

3. **[MODIFICATIONS_V2.md](computer:///mnt/user-data/outputs/MODIFICATIONS_V2.md)** (14 KB)
   - Documentation complète
   - Guide de déploiement
   - Tests à effectuer
   - Dépannage

---

## ⚡ Déploiement Express

### Côté Client (Godot)

```bash
# 1. Remplacer le fichier
mv scripts/login.gd scripts/login_v1_backup.gd
cp login_v2.gd scripts/login.gd

# 2. Modifier la scène login.tscn dans Godot
# Ajouter un bouton "LoginButton" entre Register et Join
```

### Côté Serveur (Node.js)

```typescript
// 1. Dans index.ts, ligne ~191, ajouter :
app.get('/api/login', async (req, res) => {
    const name = req.query.name as string;
    if (!name) return res.status(400).send({message: "Le pseudo est requis."});
    
    try {
        const user = await db.get('SELECT * FROM users WHERE LOWER(name) = ?', name.toLowerCase());
        if (!user) return res.status(404).send({message: "Joueur non trouvé."});
        
        res.status(200).send({playerId: user.id, name: user.name});
    } catch (error) {
        res.status(500).send({message: "Erreur serveur."});
    }
});

// 2. Dans index.ts, ligne ~277, remplacer le broadcast par :
broadcastGameState(gameId.toUpperCase(), updatedGame);

const minPlayers = 2;
if (updatedGame.players.length >= minPlayers) {
    setTimeout(() => {
        const currentGame = games.get(gameId.toUpperCase());
        if (!currentGame || currentGame.status !== GameStatus.WAITING_FOR_PLAYERS) return;
        
        const shuffledPlayers = currentGame.players.sort(() => Math.random() - 0.5);
        let currentTileBag = currentGame.tileBag;
        const playersWithTiles = shuffledPlayers.map(player => {
            const { drawnTiles, newBag } = drawTiles(currentTileBag, 7);
            currentTileBag = newBag;
            return { ...player, rack: drawnTiles };
        });
        
        const startedGame: GameState = {
            ...currentGame,
            players: playersWithTiles,
            tileBag: currentTileBag,
            status: GameStatus.PLAYING,
            currentPlayerIndex: 0
        };
        
        games.set(gameId.toUpperCase(), startedGame);
        broadcastGameState(gameId.toUpperCase(), startedGame);
    }, 1000);
}

res.status(200).send({message: "Partie rejointe !", gameId: game.id});
```

---

## 🎬 Nouveaux Flux Utilisateur

### Premier Lancement (Alice)
```
1. Ouvrir le jeu → Écran vide
2. Entrer "Alice" → Cliquer "S'inscrire"
3. Identifiants sauvegardés automatiquement
4. Créer partie "WXYZ"
5. Attendre...
```

### Lancement Suivant (Alice)
```
1. Ouvrir le jeu
2. "Bienvenue à nouveau, Alice !"
3. Champ pré-rempli avec "Alice"
4. Bouton "Se connecter (Alice)" activé
5. Cliquer "Se connecter" → Connecté instantanément
```

### Démarrage Auto (Bob rejoint Alice)
```
1. Bob se connecte
2. Bob entre "WXYZ" → Rejoint
3. ⏱️ 1 seconde d'attente
4. 🎮 Partie démarre automatiquement
5. Alice et Bob voient leurs tuiles simultanément
```

---

## ✅ Tests Rapides

### Test 1 : Sauvegarde
```bash
# Terminal Godot (après inscription)
print(FileAccess.file_exists("user://player_data.cfg"))
# → true
```

### Test 2 : Connexion
```bash
# Terminal serveur (après connexion)
✅ Connexion réussie pour : TestUser
```

### Test 3 : Démarrage Auto
```bash
# Terminal serveur (après 2ème joueur)
✅ Le joueur Bob a rejoint la partie WXYZ
🎮 Démarrage automatique de la partie WXYZ (2 joueurs)
✅ Partie WXYZ démarrée automatiquement avec 2 joueurs
```

---

## 🎉 Avantages

**Avant** :
- ❌ Ré-inscription à chaque lancement
- ❌ Créateur doit cliquer "Démarrer"
- ❌ Créateur peut bloquer la partie
- ❌ 3-4 clics pour jouer

**Après** :
- ✅ Reconnaissance automatique
- ✅ Démarrage automatique
- ✅ Pas de blocage possible
- ✅ 1-2 clics pour jouer

---

## 📊 Paramètres

```typescript
// Serveur - index.ts
const minPlayers = 2;      // Joueurs minimum
setTimeout(() => {...}, 1000);  // Délai démarrage (ms)
```

```gdscript
# Client - login_v2.gd
config.load("user://player_data.cfg")  # Fichier de config
```

---

## 🐛 Dépannage Rapide

| Problème | Solution |
|----------|----------|
| "Joueur non trouvé" | Vérifier la DB (LOWER(name)) |
| Partie ne démarre pas | Augmenter délai à 2000ms |
| Config non sauvegardée | Vérifier permissions fichier |

---

## 📞 Aide

Voir documentation complète : **MODIFICATIONS_V2.md**

- Section "Flux Utilisateur" pour comprendre les scénarios
- Section "Tests à Effectuer" pour valider
- Section "Dépannage" pour résoudre les problèmes

---

**Temps estimé de déploiement** : 15-30 minutes  
**Impact sur l'existant** : Mineur (fichiers séparés)  
**Compatibilité** : PC, Mac, Linux, Android  

✅ **Prêt à déployer !**

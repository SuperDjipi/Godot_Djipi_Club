# 🔄 MODIFICATIONS V2 - SYSTÈME DE CONNEXION ET DÉMARRAGE AUTO

## 📋 Vue d'Ensemble

Cette mise à jour ajoute deux fonctionnalités majeures :

### ✅ Point 1 : Système de Connexion/Reconnaissance
- Sur **PC** : Sauvegarde dans fichier de configuration (`user://player_data.cfg`)
- Sur **Android** : Utilise ConfigFile (compatible avec les préférences Android)
- Bouton **"Se connecter"** pour reconnexion rapide
- Endpoint serveur **GET /api/login?name=PSEUDO**

### ✅ Point 2 : Démarrage Automatique de la Partie
- La partie démarre **automatiquement** dès que 2 joueurs rejoignent
- Plus besoin de bouton "Démarrer"
- Délai de 1 seconde pour stabilité WebSocket
- Le créateur ne peut plus bloquer le démarrage

---

## 📦 FICHIERS À MODIFIER

### 1. CLIENT GODOT

#### **login.gd** → Remplacer ENTIÈREMENT par login_v2.gd

**Nouvelles fonctionnalités** :
```gdscript
# ✅ Vérification des identifiants sauvegardés au démarrage
func _check_saved_credentials()

# ✅ Sauvegarde des identifiants après inscription/connexion
func _save_credentials(name: String, id: String)

# ✅ Nouveau bouton "Se connecter"
@onready var login_button = $VBoxContainer/LoginButton

# ✅ Endpoint de connexion
func _on_login_pressed()
func _on_login_completed(...)
```

**Structure UI mise à jour** :
```
Control (login.gd)
└── VBoxContainer
      ├── PlayerNameInput (LineEdit)
      ├── GameCodeInput (LineEdit)
      ├── RegisterButton (Button) - "S'inscrire"
      ├── LoginButton (Button) - "Se connecter" ← NOUVEAU
      ├── JoinButton (Button) - "Rejoindre"
      ├── CreateButton (Button) - "Créer une partie"
      └── StatusLabel (Label)
```

**Fichiers de sauvegarde** :
- Emplacement : `user://player_data.cfg`
- Sur Linux/Mac : `~/.local/share/godot/app_userdata/[ProjectName]/player_data.cfg`
- Sur Windows : `%APPDATA%\Godot\app_userdata\[ProjectName]\player_data.cfg`
- Sur Android : `[internal storage]/Android/data/[package]/files/player_data.cfg`

**Format du fichier** :
```ini
[player]
name="Alice"
id="12345678-1234-1234-1234-123456789abc"
```

---

### 2. SERVEUR NODE.JS

#### **index.ts** - Modifications à apporter

##### **A. Ajouter l'endpoint de LOGIN**

Insérer APRÈS l'API d'inscription (ligne ~191) :

```typescript
// --- DÉBUT DE L'API DE CONNEXION ---
/**
 * Route API pour la connexion d'un joueur existant.
 * Attend une requête GET sur /api/login?name=PSEUDO
 */
app.get('/api/login', async (req, res) => {
    const name = req.query.name as string;
    
    if (!name) {
        return res.status(400).send({ message: "Le pseudo est requis." });
    }

    try {
        // Chercher le joueur dans la base de données
        const user = await db.get('SELECT * FROM users WHERE LOWER(name) = ?', name.toLowerCase());
        
        if (!user) {
            return res.status(404).send({ 
                message: "Joueur non trouvé. Veuillez vous inscrire." 
            });
        }

        console.log(`✅ Connexion réussie pour : ${user.name}`);
        res.status(200).send({ 
            message: `Bienvenue à nouveau, ${user.name} !`, 
            playerId: user.id,
            name: user.name
        });

    } catch (error) {
        console.error("Erreur lors de la connexion:", error);
        res.status(500).send({ message: "Erreur interne du serveur." });
    }
});
// --- FIN DE L'API DE CONNEXION ---
```

##### **B. Modifier la route /api/games/:gameId/join**

Remplacer les lignes 275-280 par :

```typescript
            // 5. NOTIFIER TOUT LE MONDE en temps réel !
            broadcastGameState(gameId.toUpperCase(), updatedGame);

            // 6. NOUVEAU : DÉMARRAGE AUTOMATIQUE SI 2 JOUEURS OU PLUS
            const minPlayers = 2; // Nombre minimum de joueurs pour démarrer
            if (updatedGame.players.length >= minPlayers) {
                console.log(`🎮 Démarrage automatique de la partie ${gameId.toUpperCase()} (${updatedGame.players.length} joueurs)`);
                
                // Attendre un court instant pour que tous les clients soient connectés
                setTimeout(() => {
                    const currentGame = games.get(gameId.toUpperCase());
                    if (!currentGame || currentGame.status !== GameStatus.WAITING_FOR_PLAYERS) {
                        return; // La partie a déjà été démarrée ou n'existe plus
                    }

                    // --- LOGIQUE DE DÉMARRAGE ---
                    // 1. Mélanger la liste des joueurs
                    const shuffledPlayers = currentGame.players.sort(() => Math.random() - 0.5);

                    // 2. Piocher les tuiles pour chaque joueur
                    let currentTileBag = currentGame.tileBag;
                    const playersWithTiles = shuffledPlayers.map(player => {
                        const { drawnTiles, newBag } = drawTiles(currentTileBag, 7);
                        currentTileBag = newBag;
                        return { ...player, rack: drawnTiles };
                    });

                    // 3. Créer le nouvel état de jeu
                    const startedGame: GameState = {
                        ...currentGame,
                        players: playersWithTiles,
                        tileBag: currentTileBag,
                        status: GameStatus.PLAYING,
                        currentPlayerIndex: 0
                    };

                    // 4. Sauvegarder et diffuser le nouvel état
                    games.set(gameId.toUpperCase(), startedGame);
                    broadcastGameState(gameId.toUpperCase(), startedGame);
                    
                    console.log(`✅ Partie ${gameId.toUpperCase()} démarrée automatiquement avec ${startedGame.players.length} joueurs`);
                }, 1000); // Délai de 1 seconde
            }

            // 7. Renvoyer une réponse de succès
            res.status(200).send({ 
                message: "Vous avez rejoint la partie avec succès !", 
                gameId: game.id 
            });
```

##### **C. Optionnel : Sécuriser l'événement START_GAME**

Dans **webSocketManager.ts**, ajouter une vérification (ligne ~40) :

```typescript
if (event.type === "START_GAME") {
    const currentGame = games.get(gameId)!;

    // NOUVEAU : Vérifier que la partie n'a pas déjà démarré
    if (currentGame.status !== GameStatus.WAITING_FOR_PLAYERS) {
        console.log(`⚠️ Partie ${gameId} déjà démarrée, ignorer START_GAME`);
        return;
    }

    // Reste du code inchangé...
}
```

---

## 🔄 FLUX UTILISATEUR COMPLET

### Scénario 1 : Premier Joueur (Alice)

```
1. Alice ouvre le jeu
   → Écran de login vide

2. Alice entre "Alice" et clique "S'inscrire"
   → POST /api/register
   → Serveur crée le compte
   → Serveur retourne playerId: "abc-123"
   → Client sauvegarde dans user://player_data.cfg

3. Alice clique "Créer une partie"
   → POST /api/games
   → Serveur crée partie "WXYZ"
   → Client établit WebSocket
   → Changement de scène → Jeu
   → Status: "En attente d'autres joueurs..."
```

### Scénario 2 : Joueur Existant (Bob)

```
1. Bob ouvre le jeu
   → Lecture de user://player_data.cfg
   → Champ rempli avec "Bob"
   → Message: "Bienvenue à nouveau, Bob !"
   → Bouton "Se connecter (Bob)" activé

2. Bob clique "Se connecter (Bob)"
   → GET /api/login?name=Bob
   → Serveur vérifie la DB
   → Serveur retourne playerId: "def-456"

3. Bob entre "WXYZ" et clique "Rejoindre"
   → POST /api/games/WXYZ/join
   → Serveur ajoute Bob à la partie
   → Broadcast nouvel état
   
4. DÉMARRAGE AUTO (côté serveur)
   → Détection: 2 joueurs présents
   → Délai de 1 seconde
   → Mélange des joueurs
   → Distribution de 7 tuiles chacun
   → Status → PLAYING
   → Broadcast à Alice et Bob

5. Alice et Bob voient simultanément
   → "🎮 Partie en cours"
   → Plateau et chevalet remplis
   → "✅ C'est votre tour !" (pour un des deux)
   → "⏳ Tour de [autre]" (pour l'autre)
```

### Scénario 3 : Nouveau Joueur Sans Compte

```
1. Charlie ouvre le jeu
   → Aucun fichier de config trouvé
   → Écran de login vide

2. Charlie entre "Charlie" et clique "Se connecter"
   → GET /api/login?name=Charlie
   → Serveur répond 404 "Joueur non trouvé"
   → Message: "❌ Joueur non trouvé. Veuillez vous inscrire."

3. Charlie clique "S'inscrire"
   → POST /api/register
   → Compte créé
   → Identifiants sauvegardés
```

---

## ⚙️ PARAMÈTRES CONFIGURABLES

### Côté Serveur (index.ts)

```typescript
// Nombre minimum de joueurs pour démarrage auto
const minPlayers = 2;  // Changer à 3 ou 4 si besoin

// Délai avant démarrage (en millisecondes)
setTimeout(() => { ... }, 1000);  // Augmenter si connexions lentes
```

### Côté Client (login_v2.gd)

```gdscript
# Emplacement du fichier de config
config.load("user://player_data.cfg")

# Pour tester avec un autre nom de fichier :
# config.load("user://player_prefs.cfg")
```

---

## ✅ TESTS À EFFECTUER

### Test 1 : Première Inscription
- [ ] Champ pseudo vide au démarrage
- [ ] S'inscrire avec "TestUser1"
- [ ] Vérifier message de bienvenue
- [ ] Fermer et rouvrir le jeu
- [ ] Vérifier que "TestUser1" est pré-rempli
- [ ] Vérifier que bouton "Se connecter" est actif

### Test 2 : Connexion Existante
- [ ] Avoir un compte "TestUser2" enregistré
- [ ] Cliquer "Se connecter"
- [ ] Vérifier connexion réussie
- [ ] Boutons "Créer" et "Rejoindre" activés

### Test 3 : Démarrage Automatique
- [ ] Joueur 1 crée partie "TEST"
- [ ] Vérifier status "En attente..."
- [ ] Joueur 2 rejoint "TEST"
- [ ] Vérifier démarrage automatique dans les 2 secondes
- [ ] Vérifier que les deux joueurs ont leurs tuiles
- [ ] Vérifier qu'un des deux voit "C'est votre tour"

### Test 4 : Pas de Double Démarrage
- [ ] Joueur 3 tente de rejoindre partie déjà lancée
- [ ] Vérifier message "Partie déjà commencée"
- [ ] Pas de crash côté serveur

### Test 5 : Persistance Mobile (Android)
- [ ] Installer sur Android
- [ ] S'inscrire avec "MobileUser"
- [ ] Fermer l'app complètement
- [ ] Rouvrir l'app
- [ ] Vérifier que "MobileUser" est reconnu

---

## 📊 LOGS À SURVEILLER

### Console Serveur (Connexion)
```
✅ Connexion réussie pour : Alice
```

### Console Serveur (Démarrage Auto)
```
✅ Le joueur Bob a rejoint la partie WXYZ
🎮 Démarrage automatique de la partie WXYZ (2 joueurs)
✅ Partie WXYZ démarrée automatiquement avec 2 joueurs
📣 Diffusion du nouvel état pour la partie WXYZ à 2 joueur(s)...
```

### Console Client (Reconnaissance)
```
💾 Identifiants sauvegardés : Alice (abc-123)
```

### Console Client (Connexion)
```
✅ Joueur authentifié : abc-123
```

---

## 🐛 DÉPANNAGE

### Problème : "Joueur non trouvé" alors qu'il existe

**Cause** : Problème de casse (majuscules/minuscules)

**Solution** : Le serveur utilise `LOWER(name)` pour ignorer la casse. Vérifier que la DB a bien été créée avec cette colonne.

---

### Problème : Partie ne démarre pas automatiquement

**Vérifications** :
1. Serveur : Vérifier que les 2 joueurs ont bien rejoint
   ```
   console.log(updatedGame.players.length)
   ```
2. Serveur : Vérifier que le status est bien WAITING_FOR_PLAYERS
3. Client : Vérifier que les WebSocket sont bien connectés

**Solution** : Augmenter le délai de 1000ms à 2000ms si connexions lentes

---

### Problème : Fichier de config non trouvé (Android)

**Cause** : Problème de permissions ou de chemin

**Solution** :
```gdscript
# Ajouter des logs de debug
print("Chemin user:// = ", OS.get_user_data_dir())
print("Fichier existe ? ", FileAccess.file_exists("user://player_data.cfg"))
```

---

### Problème : Double démarrage

**Cause** : Deux joueurs rejoignent exactement en même temps

**Solution** : Ajouter un verrou (mutex) ou vérifier le status avant de démarrer (déjà implémenté)

---

## 📈 AMÉLIORATIONS FUTURES

### Court Terme
- [ ] Ajouter un vrai système de mot de passe (hash)
- [ ] Permettre de changer de pseudo
- [ ] Bouton "Déconnexion" pour changer de compte

### Moyen Terme
- [ ] Configurer le nombre de joueurs (2-4)
- [ ] Timer de démarrage visible ("La partie démarre dans 3...")
- [ ] Annuler la partie si un joueur se déconnecte avant le début

### Long Terme
- [ ] Système d'amis
- [ ] Historique des parties jouées
- [ ] Statistiques du joueur
- [ ] Classement global

---

## 📝 CHECKLIST DE DÉPLOIEMENT

### Serveur
- [ ] Ajouter endpoint GET /api/login
- [ ] Modifier route POST /api/games/:gameId/join (démarrage auto)
- [ ] Optionnel : Sécuriser événement START_GAME
- [ ] Redémarrer le serveur
- [ ] Tester l'endpoint login avec curl/Postman

### Client
- [ ] Remplacer login.gd par login_v2.gd
- [ ] Modifier la scène login.tscn (ajouter bouton "Se connecter")
- [ ] Tester l'inscription
- [ ] Tester la connexion
- [ ] Tester la sauvegarde (fermer/rouvrir)

### Tests Complets
- [ ] Test inscription + création + attente
- [ ] Test connexion + rejoint + démarrage auto
- [ ] Test avec 3 joueurs
- [ ] Test sur Android (persistance)

---

## 🎉 RÉSULTAT FINAL

Après ces modifications, vous aurez :

✅ **Système de connexion complet**
- Reconnaissance automatique au lancement
- Sauvegarde locale des identifiants
- Connexion rapide en un clic

✅ **Démarrage automatique fluide**
- Plus de bouton "Démarrer" inutile
- Expérience utilisateur améliorée
- Pas de blocage par l'hôte

✅ **Meilleure expérience utilisateur**
- Moins de clics nécessaires
- Démarrage instantané quand tous les joueurs sont là
- Compatible PC et Android

---

**Version** : 2.0  
**Date** : 2025  
**Statut** : ✅ Prêt à Déployer

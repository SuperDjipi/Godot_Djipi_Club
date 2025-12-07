# Schémas des Flux de Communication - Scrabble Multijoueur

Ce document présente les différents flux de communication entre le client Godot et le serveur Node.js.

---

## Vue d'Ensemble - Architecture Complète

```mermaid
graph TB
    subgraph "Client Godot"
        Login[Login.gd<br/>Écran d'accueil]
        NetMgr[NetworkManager<br/>Autoload]
        Game[ScrabbleGame.gd<br/>Jeu principal]
        GameSync[GameStateSync.gd<br/>Synchronisation]
    end
    
    subgraph "Serveur Node.js"
        REST[API REST<br/>Express]
        WS[WebSocket<br/>Socket.io]
        GameEngine[Game Engine<br/>Validation]
        GameState[Game State<br/>État du jeu]
    end
    
    Login -->|HTTP POST/GET| REST
    Login -.->|Signaux| NetMgr
    NetMgr <-->|WebSocket| WS
    Game -.->|Signaux| NetMgr
    GameSync -->|send_event| NetMgr
    NetMgr -.->|Signaux| GameSync
    
    WS --> GameEngine
    GameEngine --> GameState
    GameState --> WS
    
    style Login fill:#4A90E2
    style NetMgr fill:#7B68EE
    style Game fill:#4A90E2
    style GameSync fill:#4A90E2
    style REST fill:#50C878
    style WS fill:#50C878
    style GameEngine fill:#FFB347
    style GameState fill:#FFB347
```

---

## Flux 1 : Authentification et Liste des Parties

```mermaid
sequenceDiagram
    participant L as Login.gd
    participant HTTP as HTTPRequest
    participant API as Serveur REST<br/>(djipi.club:8080)
    
    Note over L,API: Phase 1 : Inscription / Connexion
    
    L->>HTTP: POST /api/register<br/>{name, password}
    HTTP->>API: HTTP Request
    API-->>HTTP: 201 Created<br/>{playerId, name}
    HTTP-->>L: Callback
    Note over L: Sauvegarde player_id<br/>dans ConfigFile
    
    alt Connexion existante
        L->>HTTP: GET /api/login?name=xxx
        HTTP->>API: HTTP Request
        API-->>HTTP: 200 OK<br/>{playerId, name}
        HTTP-->>L: Callback
    end
    
    Note over L,API: Phase 2 : Liste des parties
    
    L->>HTTP: GET /api/games?playerId=xxx
    HTTP->>API: HTTP Request
    API-->>HTTP: 200 OK<br/>[{gameId, status, isMyTurn, ...}]
    HTTP-->>L: Callback
    Note over L: Affiche les parties<br/>en cours dans l'UI
    
    Note over L,API: Phase 3 : Liste des joueurs
    
    L->>HTTP: GET /api/players
    HTTP->>API: HTTP Request
    API-->>HTTP: 200 OK<br/>[{id, name, ...}]
    HTTP-->>L: Callback
    Note over L: Affiche les joueurs<br/>disponibles
    
    Note over L,API: Phase 4 : Défi d'un joueur
    
    L->>HTTP: POST /api/challenge/opponentId<br/>{playerId}
    HTTP->>API: HTTP Request
    API-->>HTTP: 201 Created<br/>{gameId, players}
    HTTP-->>L: Callback
    Note over L: Nouvelle partie créée !
```

---

## Flux 2 : Connexion WebSocket et Initialisation

```mermaid
sequenceDiagram
    participant L as Login.gd
    participant NM as NetworkManager
    participant WS as Serveur WebSocket
    participant GS as Game State
    participant G as ScrabbleGame.gd
    
    Note over L,G: L'utilisateur clique sur "Reprendre" ou "Défier"
    
    L->>NM: connect_to_server(gameId, playerId)
    Note over NM: Stocke gameId<br/>et playerId
    
    NM->>WS: WebSocket connect<br/>ws://djipi.club:8080/{gameId}?playerId={playerId}
    WS-->>NM: Connection established
    NM-->>L: Signal: connected_to_server()
    
    Note over L: Attente 0.5s puis<br/>change_scene_to_file()
    
    L->>G: Changement de scène
    
    Note over G: _ready() appelé
    Note over G: Initialisation des managers<br/>(Board, Rack, TileManager...)
    
    G->>NM: Connexion aux signaux<br/>(game_state_received, etc.)
    
    WS->>GS: Récupération état actuel
    WS->>NM: GAME_STATE_UPDATE<br/>{gameState, playerRack}
    NM-->>G: Signal: game_state_received(payload)
    
    Note over G: GameStateSync reçoit le signal
    
    G->>G: _update_board(board_data)
    G->>G: _update_rack(player_rack)
    G->>G: _check_if_my_turn()
    
    alt C'est mon tour
        G-->>G: Signal: my_turn_started()
        Note over G: Active les boutons<br/>d'action
    else Ce n'est pas mon tour
        G-->>G: Signal: my_turn_ended()
        Note over G: Désactive les boutons
    end
```

---

## Flux 3 : Jouer un Coup (PLAY_MOVE)

```mermaid
sequenceDiagram
    participant U as Joueur
    participant G as ScrabbleGame.gd
    participant DD as DragDropController
    participant MV as MoveValidator
    participant GSS as GameStateSync
    participant NM as NetworkManager
    participant WS as Serveur WebSocket
    participant GE as Game Engine
    participant P as Autres Joueurs
    
    Note over U,P: Le joueur place des tuiles sur le plateau
    
    U->>G: Drag & Drop tuiles
    G->>DD: start_drag(position)
    DD->>DD: Stocke dragging_tile<br/>et drag_origin
    U->>G: Mouvement souris
    G->>DD: update_drag(position)
    U->>G: Relâche souris
    G->>DD: end_drag(position)
    DD->>DD: _try_drop_on_board()
    DD->>DD: Ajoute à temp_tiles[]
    
    G->>MV: validate_move(temp_tiles)
    MV->>MV: _are_tiles_aligned()
    MV->>MV: _are_tiles_continuous()
    MV->>MV: _is_connected_to_board()
    MV->>MV: _calculate_score()
    MV-->>G: {valid: true, score: 45}
    
    Note over G: Affiche "✅ Valide ! 45 pts"<br/>Active le bouton "Jouer"
    
    U->>G: Clic sur "Jouer"
    G->>GSS: send_move_to_server()
    
    GSS->>GSS: Convertit temp_tiles<br/>en format serveur
    GSS->>NM: play_move(placed_tiles)
    NM->>WS: PLAY_MOVE<br/>{placedTiles: [...]}
    
    WS->>GE: processPlayMove(payload)
    
    alt Coup valide
        GE->>GE: Valide le coup
        GE->>GE: Met à jour scores
        GE->>GE: Remplit chevalet
        GE->>GE: Passe au joueur suivant
        GE-->>WS: État mis à jour
        
        WS->>NM: GAME_STATE_UPDATE (broadcast)
        WS->>P: GAME_STATE_UPDATE (broadcast)
        
        NM-->>GSS: Signal: game_state_received()
        GSS->>G: _update_board()
        GSS->>G: _update_rack()
        GSS->>G: _check_if_my_turn()
        GSS-->>G: Signal: my_turn_ended()
        
        Note over G: "⏳ Tour de Bob"<br/>Désactive les boutons
        
        Note over P: Autres joueurs reçoivent<br/>la mise à jour en temps réel
        
    else Coup invalide
        GE-->>WS: Erreur de validation
        WS->>NM: ERROR<br/>{message: "..."}
        NM-->>GSS: Signal: error_received()
        
        Note over G: "❌ Coup invalide"<br/>Réactive les boutons
    end
```

---

## Flux 4 : Passer son Tour (PASS_TURN)

```mermaid
sequenceDiagram
    participant U as Joueur
    participant G as ScrabbleGame.gd
    participant GSS as GameStateSync
    participant NM as NetworkManager
    participant WS as Serveur WebSocket
    participant GE as Game Engine
    participant P as Autres Joueurs
    
    Note over U,P: C'est le tour du joueur
    
    U->>G: Clic sur "Passer"
    G->>GSS: pass_turn()
    
    GSS->>GSS: Vérifie is_my_turn
    GSS->>NM: pass_turn()
    NM->>WS: PASS_TURN<br/>{}
    
    Note over G: "⏭️ Tour passé..."<br/>Désactive les boutons
    
    WS->>GE: Traite PASS_TURN
    
    GE->>GE: Vérifie que c'est bien<br/>le tour du joueur
    GE->>GE: Incrémente turnNumber
    GE->>GE: Passe au joueur suivant<br/>(currentPlayerIndex++)
    GE-->>WS: État mis à jour
    
    WS->>NM: GAME_STATE_UPDATE (broadcast)
    WS->>P: GAME_STATE_UPDATE (broadcast)
    
    NM-->>GSS: Signal: game_state_received()
    GSS->>G: _update_board()
    GSS->>G: _update_rack()
    GSS->>G: _check_if_my_turn()
    
    alt C'est toujours mon tour (dernier joueur)
        GSS-->>G: Signal: my_turn_started()
        Note over G: "✅ C'est votre tour !"
    else C'est le tour d'un autre
        GSS-->>G: Signal: my_turn_ended()
        Note over G: "⏳ Tour de Alice"
    end
    
    Note over P: Autres joueurs reçoivent<br/>la mise à jour
```

---

## Flux 5 : Synchronisation Multi-Joueurs

```mermaid
sequenceDiagram
    participant A as Joueur A<br/>(Client Godot)
    participant S as Serveur<br/>(Node.js)
    participant B as Joueur B<br/>(Client Godot)
    participant C as Joueur C<br/>(Client Godot)
    
    Note over A,C: Partie à 3 joueurs en cours
    
    rect rgb(200, 255, 200)
        Note over A,C: Tour du Joueur A
        A->>S: PLAY_MOVE<br/>{placedTiles: [...]}
        S->>S: Valide le coup<br/>Score: +35 points
        S->>S: Remplit chevalet A<br/>Tour suivant: B
        S-->>A: GAME_STATE_UPDATE<br/>{gameState, playerRack}
        S-->>B: GAME_STATE_UPDATE<br/>{gameState, playerRack}
        S-->>C: GAME_STATE_UPDATE<br/>{gameState, playerRack}
        
        Note over A: Affiche nouveau score<br/>"⏳ Tour de B"
        Note over B: Affiche nouveau score<br/>"✅ C'est votre tour !"
        Note over C: Affiche nouveau score<br/>"⏳ Tour de B"
    end
    
    rect rgb(200, 230, 255)
        Note over A,C: Tour du Joueur B
        B->>S: PLAY_MOVE<br/>{placedTiles: [...]}
        S->>S: Valide le coup<br/>Score: +28 points
        S->>S: Remplit chevalet B<br/>Tour suivant: C
        S-->>A: GAME_STATE_UPDATE
        S-->>B: GAME_STATE_UPDATE
        S-->>C: GAME_STATE_UPDATE
        
        Note over A: "⏳ Tour de C"
        Note over B: "⏳ Tour de C"
        Note over C: "✅ C'est votre tour !"
    end
    
    rect rgb(255, 230, 200)
        Note over A,C: Tour du Joueur C
        C->>S: PASS_TURN<br/>{}
        S->>S: Pas de validation<br/>Tour suivant: A
        S-->>A: GAME_STATE_UPDATE
        S-->>B: GAME_STATE_UPDATE
        S-->>C: GAME_STATE_UPDATE
        
        Note over A: "✅ C'est votre tour !"
        Note over B: "⏳ Tour de A"
        Note over C: "⏳ Tour de A"
    end
```

---

## Flux 6 : Gestion des Erreurs

```mermaid
sequenceDiagram
    participant U as Joueur
    participant G as ScrabbleGame.gd
    participant NM as NetworkManager
    participant WS as Serveur WebSocket
    participant GE as Game Engine
    
    rect rgb(255, 200, 200)
        Note over U,GE: Erreur : Coup invalide
        
        U->>G: Place tuiles non alignées
        G->>G: Validation locale OK<br/>(pas exhaustive)
        U->>G: Clic "Jouer"
        G->>NM: PLAY_MOVE
        NM->>WS: PLAY_MOVE
        WS->>GE: Validation serveur
        GE->>GE: ❌ Tuiles non alignées
        GE-->>WS: Erreur
        WS->>NM: ERROR<br/>{message: "Les tuiles doivent être alignées"}
        NM-->>G: Signal: error_received()
        
        Note over G: Affiche "❌ Coup invalide"<br/>Réactive les boutons<br/>Tuiles restent temporaires
        
        Note over U: Le joueur peut<br/>corriger son coup
    end
    
    rect rgb(255, 200, 200)
        Note over U,GE: Erreur : Ce n'est pas son tour
        
        U->>G: Tente de jouer
        G->>G: Vérifie is_my_turn = false
        G-->>U: Boutons désactivés
        
        Note over G: Le client empêche<br/>l'action invalide
    end
    
    rect rgb(255, 200, 200)
        Note over U,GE: Erreur : Déconnexion
        
        WS->>NM: Connection closed
        NM-->>G: Signal: disconnected_from_server()
        
        Note over G: Affiche "❌ Déconnecté"
        
        alt Reconnexion automatique
            G->>NM: connect_to_server()
            NM->>WS: Reconnexion
            WS-->>NM: Connection established
            NM-->>G: Signal: connected_to_server()
            WS->>NM: GAME_STATE_UPDATE
            Note over G: "✅ Reconnecté"
        else Échec de reconnexion
            Note over G: Retour à l'écran login
        end
    end
```

---

## Flux 7 : Fin de Partie

```mermaid
sequenceDiagram
    participant A as Joueur A
    participant S as Serveur
    participant B as Joueur B
    
    Note over A,B: Plus de tuiles dans la pioche<br/>Un joueur n'a plus de tuiles
    
    A->>S: PLAY_MOVE (dernière tuile)
    S->>S: Valide le coup
    S->>S: Calcule scores finaux
    S->>S: status = "FINISHED"
    S->>S: Détermine le gagnant
    
    S-->>A: GAME_STATE_UPDATE<br/>{status: "FINISHED", ...}
    S-->>B: GAME_STATE_UPDATE<br/>{status: "FINISHED", ...}
    
    Note over A: GameStateSync détecte<br/>status == "FINISHED"
    A->>A: Signal: game_ended(winner)
    
    Note over A: Affiche popup:<br/>"🏁 Partie terminée !"<br/>"🏆 Gagnant : Alice"<br/>Scores finaux
    
    Note over B: Affiche popup:<br/>"🏁 Partie terminée !"<br/>"🏆 Gagnant : Alice"<br/>Scores finaux
    
    Note over A: Bouton "Retour au menu"
    Note over B: Bouton "Retour au menu"
    
    A->>S: Déconnexion WebSocket
    A->>A: change_scene_to_file("login.tscn")
    
    B->>S: Déconnexion WebSocket
    B->>B: change_scene_to_file("login.tscn")
```

---

## Flux 8 : Structure des Données Échangées

```mermaid
graph LR
    subgraph "Client Godot - Format Interne"
        GT[Godot Tile<br/>{letter, value, id, is_joker}]
        GB[Godot Board<br/>Array 15x15 de Dictionary]
        GR[Godot Rack<br/>Array de 7 Dictionary]
    end
    
    subgraph "Conversion"
        C1[_convert_godot_tile_to_server]
        C2[_convert_server_tile_to_godot]
    end
    
    subgraph "Serveur Node.js - Format API"
        ST[Server Tile<br/>{id, letter, points, isJoker}]
        SB[Server Board<br/>Array 15x15 de Object]
        SR[Server Rack<br/>Array de Object]
    end
    
    GT -->|Envoi| C1
    C1 --> ST
    
    ST -->|Réception| C2
    C2 --> GT
    
    GB -.-> GR
    SB -.-> SR
    
    style GT fill:#4A90E2
    style GB fill:#4A90E2
    style GR fill:#4A90E2
    style C1 fill:#FFB347
    style C2 fill:#FFB347
    style ST fill:#50C878
    style SB fill:#50C878
    style SR fill:#50C878
```

---

## Récapitulatif des Événements

### Client → Serveur (WebSocket)

| Événement | Description | Payload | Réponse |
|-----------|-------------|---------|---------|
| `PLAY_MOVE` | Jouer un coup | `{placedTiles: [...]}` | `GAME_STATE_UPDATE` ou `ERROR` |
| `PASS_TURN` | Passer son tour | `{}` | `GAME_STATE_UPDATE` |

### Serveur → Client (WebSocket)

| Événement | Description | Quand | Destinataire |
|-----------|-------------|-------|--------------|
| `GAME_STATE_UPDATE` | Synchronisation état | Connexion initiale, après chaque action | Tous les joueurs |
| `ERROR` | Erreur d'action | Action invalide | Joueur concerné uniquement |

### Client → Serveur (REST API)

| Endpoint | Méthode | Description | Réponse |
|----------|---------|-------------|---------|
| `/api/register` | POST | Inscription | `{playerId, name}` |
| `/api/login` | GET | Connexion | `{playerId, name}` |
| `/api/games` | GET | Liste des parties | `[{gameId, status, ...}]` |
| `/api/players` | GET | Liste des joueurs | `[{id, name, ...}]` |
| `/api/challenge/:id` | POST | Défier un joueur | `{gameId, players}` |

---

## Légende des Couleurs

- 🔵 **Bleu** : Composants Client (Godot)
- 🟢 **Vert** : Composants Serveur (Node.js)
- 🟠 **Orange** : Logique métier / Validation
- 🟢 **Vert clair** : Actions valides
- 🔴 **Rouge clair** : Erreurs / Actions invalides
- 🟡 **Jaune clair** : Transitions d'état

---

## Notes Importantes

1. **Tous les événements WebSocket** sont au format JSON : `{type: "...", payload: {...}}`
2. **La synchronisation est en temps réel** : tous les joueurs reçoivent `GAME_STATE_UPDATE` simultanément
3. **Le chevalet est privé** : chaque joueur ne reçoit que son propre chevalet dans `playerRack`
4. **La pioche est masquée** : les clients ne voient que le nombre de tuiles restantes
5. **Les tuiles verrouillées** (`isLocked: true`) ne peuvent pas être déplacées
6. **Le client fait une validation locale** (légère) avant d'envoyer au serveur
7. **Le serveur fait la validation finale** (complète) et renvoie une erreur si invalide

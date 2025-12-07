# Documentation des Événements WebSocket

Cette documentation décrit le protocole de communication en temps réel utilisé pour la synchronisation du jeu, une fois la connexion WebSocket établie.

La communication est basée sur l'échange d'objets JSON avec une structure `{ "type": "...", "payload": { ... } }`.

---

## 1. Événements du Client vers le Serveur (`ClientToServerEvent`)

Ce sont les actions que le client (le jeu Godot) peut envoyer au serveur.

### `PLAY_MOVE`

**Description :** L'action principale du jeu. Le joueur soumet un ensemble de tuiles posées sur le plateau pour validation.

- **type :** `"PLAY_MOVE"`
- **payload (JSON) :**

```json
{
  "placedTiles": [
    {
      "letter": "A",
      "points": 1,
      "id": "tile_uuid_1",
      "position": { "x": 7, "y": 7 }
    },
    {
      "letter": "M",
      "points": 2,
      "id": "tile_uuid_2",
      "position": { "x": 7, "y": 8 }
    },
    {
      "letter": "I",
      "points": 1,
      "id": "tile_uuid_3",
      "position": { "x": 7, "y": 9 }
    }
  ]
}
```

**Logique côté serveur :**

- Le serveur délègue la validation du coup au `GameEngine` (`processPlayMove`).
- Si le coup est valide, le serveur met à jour l'état de la partie (scores, pioche, chevalets), vérifie si la partie est terminée, et diffuse le nouvel état à tous les joueurs via un événement `GAME_STATE_UPDATE`.
- Si le coup est invalide, le serveur renvoie un événement `ERROR` uniquement au joueur qui a tenté le coup.

---

### `PASS_TURN`

**Description :** Le joueur choisit de passer son tour sans jouer de coup.

- **type :** `"PASS_TURN"`
- **payload :** `{}` (le payload est vide)

**Logique côté serveur :**

- Le serveur vérifie que c'est bien le tour du joueur qui a envoyé l'événement.
- Il met à jour l'état du jeu en passant au joueur suivant (`currentPlayerIndex`) et en incrémentant le numéro de tour (`turnNumber`).
- Il diffuse le nouvel état à tous les joueurs via `GAME_STATE_UPDATE`.

---

## 2. Événements du Serveur vers le Client (`ServerToClientEvent`)

Ce sont les messages que le serveur envoie aux clients pour les tenir informés.

### `GAME_STATE_UPDATE`

**Description :** L'événement le plus important. Il est envoyé pour synchroniser l'état du jeu sur l'écran de tous les joueurs. Il est envoyé :

1. À un joueur seul lors de sa connexion initiale.
2. À tous les joueurs après chaque coup valide (joué ou passé).

- **type :** `"GAME_STATE_UPDATE"`
- **payload (JSON) :**

```json
{
  "gameState": {
    // L'objet GameState complet, mais avec une pioche "cachée"
    // (le client ne voit que le NOMBRE de tuiles restantes, pas leur contenu)
    "id": "TEST-GAME-UUID",
    "board": [ /* ... */ ],
    "players": [ /* ... */ ],
    "tileBag": { "tileCount": 48 }, // Pioche masquée
    "status": "PLAYING",
    "currentPlayerIndex": 1
    // ...etc
  },
  "playerRack": [
    // Le chevalet personnel du joueur qui reçoit cet événement.
    // Chaque joueur ne reçoit que son propre chevalet.
    { "letter": "E", "points": 1, "id": "tile_uuid_4" },
    { "letter": "R", "points": 1, "id": "tile_uuid_5" }
    // ...
  ]
}
```

---

### `ERROR`

**Description :** Envoyé uniquement à un joueur spécifique lorsqu'une de ses actions est invalide.

- **type :** `"ERROR"`
- **payload (JSON) :**

```json
{
  "message": "Votre coup est invalide."
}
```

**Logique côté client :** Le jeu doit afficher ce message d'erreur à l'utilisateur et lui permettre de corriger son coup (par exemple, en ne retirant pas les tuiles du plateau).

---

## Stack Technique

- **Serveur :** Node.js avec Express et Socket.io (adresse : djipi.club)
- **Client :** Godot 4.5.1 (GDScript)
- **Protocole :** REST API + WebSocket pour temps réel

## Conventions de Code

- **GDScript :** `snake_case` pour les variables/fonctions
- Commentaires en français
- Logs détaillés pour le debug

## Architecture

- Salon de jeux multi-joueurs (Scrabble, Yam, Boggle, Dames et autres)
- Système d'amis et de salons privés
- Jeu en temps réel avec synchronisation

## Priorités

1. Connexion client Godot ↔ serveur
2. Multi-joueurs Scrabble
3. Système de salons/rooms
4. Ajout d'autres jeux

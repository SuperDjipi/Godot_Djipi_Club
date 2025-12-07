# Résumé des Routes API du Serveur Scrabble

---

## 1. Authentification des Joueurs

### a. Inscription d'un nouveau joueur

-   **Méthode :** `POST`
-   **URL :** `/api/register`
    -**Paramètres (Corps JSON) :**
    -   `name` (string) : Le pseudo souhaité.
    -   `password` (string) : Le mot de passe (actuellement non haché).
-   **Description :** Crée un nouvel utilisateur dans la base de données avec un UUID unique, après avoir vérifié que le pseudo n'est pas déjà pris.

### b. Connexion d'un joueur existant

-   **Méthode :** `GET`
-   **URL :** `/api/login`
-   **Paramètres (Query String) :**
    -   `?name=PSEUDO` (string) : Le pseudo de l'utilisateur qui se connecte.
-   **Description :** Cherche un utilisateur par son pseudo dans la base de données et, en cas de succès, renvoie son profil incluant son ID unique (`playerId`).

---

## 2. Gestion des Parties (pour un joueur connecté)

### a. Lister les parties en cours d'un joueur

-   **Méthode :** `GET`
-   **URL :** `/api/players/:playerId/games`
-   **Paramètres (URL) :**
    -   `:playerId` (string) : L'UUID du joueur dont on veut lister les parties.
-   **Description :** C'est la nouvelle route clé pour votre écran d'accueil. Elle renvoie une liste de toutes les parties actives (non terminées) où le joueur est présent, avec des informations utiles comme le nom des adversaires, le score, et si c'est son tour de jouer.

### b. Créer une nouvelle partie

-   **Méthode :** `POST`
-   **URL :** `/api/games/create`
-   **Paramètres (Corps JSON) :**
    -   `playerId` (string) : L'UUID du joueur qui crée la partie (il devient l'hôte).
-   **Description :** Crée une nouvelle partie avec un UUID unique, ajoute le créateur comme premier joueur, et met la partie en état `WAITING_FOR_PLAYERS`.

### c. Rejoindre une partie en attente

-   **Méthode :** `POST`
-   **URL :** `/api/games/:gameId/join`
-   **Paramètres (URL) :**
    -   `:gameId` (string) : L'UUID de la partie à rejoindre.
-   **Paramètres (Corps JSON) :**
    -   `playerId` (string) : L'UUID du joueur qui souhaite rejoindre.
-   **Description :** Permet à un joueur de rejoindre une partie qui est en état `WAITING_FOR_PLAYERS`. Si la partie atteint 2 joueurs, elle démarre automatiquement après un court délai.

### d. Se reconnecter à une partie déjà en cours

-   **Méthode :** `POST`
-   **URL :** `/api/games/:gameId/reconnect`
-   **Paramètres (URL) :**
    -   `:gameId` (string) : L'UUID de la partie ("TEST" pour votre partie de test, par exemple).
-   **Paramètres (Corps JSON) :**
    -   `playerId` (string) : L'UUID du joueur qui se reconnecte.
-   **Description :** Route cruciale pour votre partie de test et pour la reprise de jeu. Elle vérifie si un joueur fait bien partie d'une partie déjà commencée et l'autorise à établir la connexion WebSocket.


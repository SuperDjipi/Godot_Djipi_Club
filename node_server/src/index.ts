/**
 * Ce fichier est le point d'entrée principal et le cœur du serveur de jeu Node.js.
 * Il est responsable de :
 * 1. Démarrer un serveur web Express.
 * 2. Lancer un serveur WebSocket par-dessus le serveur Express pour la communication en temps réel.
 * 3. Gérer les connexions, déconnexions et messages des clients.
 * 4. Maintenir l'état de toutes les parties en mémoire.
 * 5. Agir comme un "contrôleur" qui reçoit les événements des clients et délègue la logique
 *    de jeu au "moteur de jeu" (`GameEngine`).
 */

import express from 'express';
import { WebSocketServer, WebSocket } from 'ws';
// Import des modèles de données et des types d'événements
import type { ClientToServerEvent, ServerToClientEvent } from './models/GameEvents.js';
import type { GameState, Tile, UserProfile, Player, PlacedTile } from './models/GameModels.js';
import { GameStatus } from './models/GameModels.js';
// Import des modules de logique métier
import { createTileBag, drawTiles } from './logic/TileBag.js';
import { createEmptyBoard, createNewBoard } from './models/BoardModels.js';
import { gameStateToString } from './models/toStrings.js';
import { URL } from 'url'; // Utile pour parser l'URL de connexion
import { v4 as generateUUID } from 'uuid';
import { initializeDatabase } from './db/database.js';
import { handleNewConnection } from './services/webSocketManager.js';

// --- GESTION DES PARTIES EN MÉMOIRE ---

/**
 * La "base de données" en mémoire pour toutes les parties actives.
 * C'est une Map qui associe un identifiant de partie (`gameId`) à son état complet (`GameState`).
 * NOTE : Ces données sont volatiles et seront perdues si le serveur redémarre.
 */
export const games = new Map<string, GameState>();

/**
 * La gestion des connexions WebSocket actives.
 * C'est une structure de données imbriquée :
 * Map<gameId, Map<playerId, WebSocket>>
 * - La clé externe est l'ID de la partie.
 * - La valeur est une autre Map qui associe l'ID d'un joueur (`playerId`) à son instance WebSocket.
 * Cela nous permet de savoir qui est qui et d'envoyer des messages ciblés.
 */
export const connections = new Map<string, Map<string, WebSocket>>();

/**
 * Initialise le conteneur de connexions pour une partie donnée si ce n'est pas déjà fait.
 */
export function initGameConnections(gameId: string) {
    if (!connections.has(gameId)) {
        connections.set(gameId, new Map<string, WebSocket>());
    }
}
/**
 * Génère un code de partie simple de 4 lettres majuscules.
 */
function generateGameCode(): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    let code = '';
    for (let i = 0; i < 4; i++) {
        code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    // TODO: Plus tard, on vérifiera que ce code n'est pas déjà utilisé.
    return code;
}


/**
 * Prépare une version personnalisée du `GameState` pour un joueur spécifique.
 * Cette fonction est cruciale pour la sécurité et la confidentialité :
 * - Elle vide les chevalets (`rack`) de tous les autres joueurs.
 * - Elle ne révèle pas le contenu de la pioche (`tileBag`).
 * @param gameState L'état de jeu officiel et complet.
 * @param playerId L'ID du joueur pour qui l'état est préparé.
 * @returns Un objet contenant l'état "public" et le chevalet privé du joueur.
 */
export function prepareStateForPlayer(gameState: GameState, playerId: string): { stateForPlayer: GameState, playerRack: Tile[] } {
    let playerRack: Tile[] = [];
    const stateForPlayer: GameState = {
        ...gameState,
        players: gameState.players.map(p => {
            if (p.id === playerId) {
                playerRack = p.rack;
            }
            return { ...p, rack: [] }; // On vide le chevalet pour les autres
        }),
        tileBag: [] // On ne révèle jamais la pioche au client
    };
    return { stateForPlayer, playerRack };
}


/**
 * Diffuse (broadcast) un nouvel état de jeu à tous les joueurs connectés
 * à une partie spécifique. Chaque joueur reçoit une version personnalisée de l'état.
 *
 * @param gameId L'ID de la partie à notifier.
 * @param gameState L'état de jeu complet et officiel (avec tous les chevalets).
 */
export function broadcastGameState(gameId: string, gameState: GameState) {
    const gameConnections = connections.get(gameId);
    if (!gameConnections) {
        console.warn(`Tentative de diffusion à une partie inexistante ou sans connexions : ${gameId}`);
        return;
    }

    console.log(`📣 Diffusion du nouvel état pour la partie ${gameId} à ${gameConnections.size} joueur(s)...`);

    // On boucle sur tous les joueurs définis dans le GameState
    gameState.players.forEach(player => {
        const clientWs = gameConnections.get(player.id);

        // On vérifie si ce joueur est bien connecté
        if (clientWs && clientWs.readyState === WebSocket.OPEN) {
            // 1. On prépare la version de l'état spécifique à ce joueur
            const { stateForPlayer, playerRack } = prepareStateForPlayer(gameState, player.id);

            // 2. On construit l'événement de mise à jour
            const updateEvent: ServerToClientEvent = {
                type: "GAME_STATE_UPDATE",
                payload: {
                    gameState: stateForPlayer,
                    playerRack: playerRack // Le chevalet privé est envoyé ici
                }
            };

            // 3. On envoie l'événement au client
            clientWs.send(JSON.stringify(updateEvent));
            console.log(`   - État envoyé à ${player.name} (${player.id})`);
        } else {
            console.log(`   - Joueur ${player.name} non connecté, envoi ignoré.`);
        }
    });
}

// --- DÉMARRAGE DU SERVEUR ---

async function startServer() {
    const db = await initializeDatabase(); // On initialise la DB en premier
    const app = express();
    // Middleware pour servir les fichiers statiques (HTML, CSS, JS) du dossier 'public'.
    app.use(express.static('public'));
    // Middleware pour permettre à Express de comprendre le JSON envoyé dans le corps des requêtes POST.
    app.use(express.json());

    const port = 8080;
    // On lance le serveur HTTP Express...
    const server = app.listen(port, () => {
        console.log(`✅ Serveur démarré et à l'écoute sur http://localhost:${port}`);
    });
    // ...et on attache le serveur WebSocket à ce serveur HTTP.
    const wss = new WebSocketServer({ server });

    // --- DÉBUT DE L'API D'INSCRIPTION ---

    /**
     * Route API pour l'inscription d'un nouveau joueur.
     * Attend une requête POST sur /api/register avec un corps JSON
     * contenant 'name' et 'password'.*/
    app.post('/api/register', async (req, res) => {// La fonction devient async
        const { name, password } = req.body;
        if (!name || !password) {
            return res.status(400).send({ message: "Le pseudo et le mot de passe sont requis." });
        }

        try {
            // On vérifie si le nom existe déjà dans la base de données
            const existingUser = await db.get('SELECT * FROM users WHERE LOWER(name) = ?', name.toLowerCase());
            if (existingUser) {
                return res.status(409).send({ message: "Ce pseudo est déjà pris." });
            }

            // Création du profil
            const newPlayerId = generateUUID();
            const hashedPassword = password; // TODO: HASH ME!

            // On exécute la requête SQL pour insérer le nouvel utilisateur
            await db.run(
                'INSERT INTO users (id, name, hashedPassword) VALUES (?, ?, ?)',
                [newPlayerId, name, hashedPassword]
            );

            console.log(`✅ Nouveau joueur inséré dans la DB : ${name}`);
            res.status(201).send({ message: `Profil pour '${name}' créé avec succès !`, playerId: newPlayerId });

        } catch (error) {
            console.error("Erreur lors de l'inscription:", error);
            res.status(500).send({ message: "Erreur interne du serveur." });
        }
    });
    // --- FIN DE L'API D'INSCRIPTION ---

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
            return res.status(404).send({ message: "Joueur non trouvé. Veuillez vous inscrire." });
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

/**
 * Route API pour récupérer la liste des parties en cours pour un joueur spécifique.
 */
app.get('/api/players/:playerId/games', (req, res) => {
    const { playerId } = req.params;

    if (!playerId) {
        return res.status(400).send({ message: "L'ID du joueur est requis." });
    }

    // On parcourt toutes les parties en mémoire.
    const activeGamesForPlayer = Array.from(games.values())
        .filter(game => game.players.some(p => p.id === playerId)) // On ne garde que les parties où le joueur est présent
        .filter(game => game.status !== GameStatus.FINISHED) // On exclut les parties terminées
        .map(game => {
            // On ne renvoie que les informations publiques, jamais les chevalets ou la pioche.
            return {
                gameId: game.id,
                players: game.players.map(p => p.name),
                currentPlayerId: game.players[game.currentPlayerIndex]?.id,
                status: game.status,
                turnNumber: game.turnNumber
            };
        });

    console.log(`🔎 Requête pour les parties de ${playerId}. ${activeGamesForPlayer.length} partie(s) trouvée(s).`);

    res.status(200).json(activeGamesForPlayer);
});

    /**
     * Route API pour permettre à un joueur de rejoindre une partie existante.
     * Attend une requête POST sur /api/games/:gameId/join
     * @param gameId L'ID de la partie à rejoindre (dans l'URL).
     * @body { "playerId": "xxxx-yyyy-zzzz" }
     */
    app.post('/api/games/:gameId/join', async (req, res) => {
        const { gameId } = req.params; // On récupère l'ID de la partie depuis l'URL
        const { playerId } = req.body; // On récupère l'ID du joueur depuis le corps de la requête

        if (!playerId) {
            return res.status(400).send({ message: "L'ID du joueur est requis." });
        }

        const game = games.get(gameId.toUpperCase());

        // 1. Vérifications de base
        if (!game) {
            return res.status(404).send({ message: "Partie non trouvée." }); // 404 Not Found
        }
        if (game.status !== GameStatus.WAITING_FOR_PLAYERS) {
            return res.status(403).send({ message: "Cette partie a déjà commencé ou est terminée." }); // 403 Forbidden
        }
        if (game.players.some(p => p.id === playerId)) {
            // Le joueur est déjà dans la partie, on le laisse juste continuer.
            console.log(`ℹ️ Le joueur ${playerId} tente de rejoindre une partie où il est déjà.`);
            return res.status(200).send({ message: "Vous êtes déjà dans la partie.", gameId: game.id });
        }

        try {
            // 2. Récupérer le profil du joueur depuis la base de données
            const userProfile = await db.get('SELECT * FROM users WHERE id = ?', playerId);
            if (!userProfile) {
                return res.status(404).send({ message: "Profil joueur non trouvé dans la base de données." });
            }

            // 3. Ajouter le joueur à l'état de la partie
            const newPlayer: Player = {
                id: userProfile.id,
                name: userProfile.name,
                score: 0,
                rack: [],
                isActive: false
            };
            const updatedPlayers = [...game.players, newPlayer];
            const updatedGame = { ...game, players: updatedPlayers };

            // 4. Mettre à jour l'état de la partie en mémoire
            games.set(gameId.toUpperCase(), updatedGame);

            console.log(`✅ Le joueur ${userProfile.name} a rejoint la partie ${gameId.toUpperCase()}`);

            // 5. NOTIFIER TOUT LE MONDE en temps réel !
            broadcastGameState(gameId.toUpperCase(), updatedGame);

            // 6. NOUVEAU : DÉMARRER AUTOMATIQUEMENT SI 2 JOUEURS OU PLUS
            const minPlayers = 2; // Nombre minimum de joueurs pour démarrer
            if (updatedGame.players.length >= minPlayers) {
                console.log(`🎮 Démarrage automatique de la partie ${gameId.toUpperCase()} (${updatedGame.players.length} joueurs)`);
                
                // Attendre un court instant pour que tous les clients soient connectés
                setTimeout(() => {
                    const currentGame = games.get(gameId.toUpperCase());
                    if (!currentGame || currentGame.status !== GameStatus.WAITING_FOR_PLAYERS) {
                        return; // La partie a déjà été démarrée ou n'existe plus
                    }

                    // --- LOGIQUE DE DÉMARRAGE (identique à START_GAME) ---
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
                        status: GameStatus.PLAYING, // La partie commence !
                        currentPlayerIndex: 0 // Le premier joueur de la liste mélangée commence
                    };

                    // 4. Sauvegarder et diffuser le nouvel état
                    games.set(gameId.toUpperCase(), startedGame);
                    broadcastGameState(gameId.toUpperCase(), startedGame);
                    
                    console.log(`✅ Partie ${gameId.toUpperCase()} démarrée automatiquement avec ${startedGame.players.length} joueurs`);
                }, 1000); // Délai de 1 seconde pour laisser le temps aux WebSockets de se connecter
            }

            // 7. Renvoyer une réponse de succès au joueur qui vient de rejoindre
            res.status(200).send({ message: "Vous avez rejoint la partie avec succès !", gameId: game.id });


        } catch (error) {
            console.error("Erreur pour rejoindre la partie:", error);
            res.status(500).send({ message: "Erreur interne du serveur." });
        }
    });
    // --- DÉBUT DE L'API DE CRÉATION DE PARTIE ---
    /**
     * Route API pour créer une nouvelle partie.
     * Attend une requête POST sur /api/games.
     * Le corps de la requête doit contenir l'ID du joueur qui crée la partie.
     * @body { "creatorId": "xxxx-yyyy-zzzz" }
     */
    app.post('/api/games', async (req, res) => {
        const { creatorId } = req.body;

        if (!creatorId) {
            return res.status(400).send({ message: "L'ID du créateur est requis." });
        }
        try {
            // 1. Générer un code de partie simple et unique
            const gameId = generateGameCode();

            // 2. Récupérer le VRAI profil du créateur depuis la base de données
            const creatorProfile = await db.get<UserProfile>('SELECT * FROM users WHERE id = ?', creatorId);
            if (!creatorProfile) {
                return res.status(404).send({ message: "Profil du créateur non trouvé." });
            }

            // 3. Créer le nouvel état de la partie
            const newGame: GameState = {
                id: gameId,
                hostId: creatorId,
                board: createEmptyBoard(),
                players: [
                    {
                        id: creatorProfile.id,
                        name: creatorProfile.name,
                        score: 0,
                        rack: [], // Le chevalet sera rempli plus tard, au démarrage
                        isActive: true
                    }
                ],
                tileBag: createTileBag(),
                status: GameStatus.WAITING_FOR_PLAYERS,
                moves: [],
                turnNumber: 1,
                currentPlayerIndex: 0,
            };

            // 4. Sauvegarder la nouvelle partie en mémoire
            games.set(gameId, newGame);
            initGameConnections(gameId); // On prépare le "salon" WebSocket pour cette partie

            console.log(`✅ Nouvelle partie créée par ${creatorProfile.name}. Code: ${gameId}`);

            // 5. Renvoyer une réponse de succès au client
            res.status(201).send({
                message: "Partie créée avec succès !",
                gameId: gameId
            });
        } catch (error) {
            console.error("Erreur lors de la création de la partie:", error);
            res.status(500).send({ message: "Erreur interne du serveur." });
        }
    });

    // --- FIN DE L'API DE CRÉATION DE PARTIE ---


    // --- LOGIQUE PRINCIPALE DE CONNEXION ---

    /**
     * Ce bloc est exécuté à chaque fois qu'un nouveau client établit une connexion WebSocket.
     */
            wss.on('connection', (ws, req) => { handleNewConnection(ws, req); });
}

// On lance le serveur
startServer().catch(error => {
    console.error("Impossible de démarrer le serveur:", error);
});
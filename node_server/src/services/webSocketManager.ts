import WebSocket from 'ws';
import type { ClientToServerEvent, ServerToClientEvent } from '../models/GameEvents.js';
//import { UserProfile } from '../models/GameModels.js';
import { gameStateToString } from '../models/toStrings.js';
import { games, connections, initGameConnections } from '../index.js';
import { broadcastGameState, prepareStateForPlayer } from '../index.js';
import { createTileBag, drawTiles } from '../logic/TileBag.js';
import { URL } from 'url';
import type { GameState } from '../models/GameModels.js';
import { GameStatus } from '../models/GameModels.js';
import { processPlayMove, processExchangeTiles } from '../logic/GameEngine.js'; // Le moteur de jeu principal

export function handleNewConnection(ws: WebSocket, req: any) {
    // On parse l'URL pour extraire le gameId et le playerId
    const requestUrl = new URL(req.url!, `http://${req.headers.host}`);
    const gameId = requestUrl.pathname.split('/').pop()?.split('?')[0]; // Extrait l'ID de la partie de l'URL
    const playerId = requestUrl.searchParams.get('playerId'); // Extrait l'ID du joueur des paramètres de l'URL

    // Sécurité : on vérifie que les informations sont valides
    if (!gameId || !playerId || !games.has(gameId)) {
        console.log(`❌ Tentative de connexion invalide: gameId=${gameId}, playerId=${playerId}`);
        ws.close();
        return;
    }

    initGameConnections(gameId);
    const gameConnections = connections.get(gameId)!;

    // On associe l'instance WebSocket au joueur
    gameConnections.set(playerId, ws);
    console.log(`Joueur ${playerId} vient de se connecter à la partie ${gameId}.`);

    // --- ENVOI DE L'ÉTAT INITIAL ---
    const initialGameState = games.get(gameId)!;
    const { stateForPlayer, playerRack } = prepareStateForPlayer(initialGameState, playerId);
    const welcomeEvent: ServerToClientEvent = {
        type: "GAME_STATE_UPDATE",
        payload: {
            gameState: stateForPlayer,
            playerRack: playerRack
        }
    };
    ws.send(JSON.stringify(welcomeEvent));
    console.log(`Envoyé l'état initial personnalisé pour ${playerId}.\n${gameStateToString(stateForPlayer)}`);

    /**
     * Ce bloc est exécuté à chaque fois qu'un message est reçu de ce client spécifique.
     */
    ws.on('message', (message) => {
        try {
            const event: ClientToServerEvent = JSON.parse(message.toString());

            // Aiguillage des événements reçus du client
            if (event.type === "PLAY_MOVE") {
                const currentGame = games.get(gameId)!;
                const { placedTiles } = event.payload;

                // On délègue TOUTE la logique de traitement du coup au GameEngine.
                const nextGameState = processPlayMove(currentGame, placedTiles);

                if (nextGameState) {
                    // Si le moteur retourne un nouvel état, le coup était valide.
                    games.set(gameId, nextGameState); // Mise à jour de l'état maître.
                    // --- DÉBUT DE LA LOGIQUE DE FIN DE PARTIE ---
                    let isGameOver = false;

                    // Scénario A : Le chevalet du joueur actuel est vide ET la pioche est vide.
                    // 1. On identifie le joueur QUI VIENT DE JOUER.
                    //    Son index est dans l'état AVANT le traitement du coup (`currentGame`).
                    const playerWhoPlayed = currentGame.players[currentGame.currentPlayerIndex];
                    if (!playerWhoPlayed) {
                        console.warn(`Impossible de trouver le joueur qui vient de jouer (index: ${currentGame.currentPlayerIndex}). La vérification de fin de partie est annulée.`);
                        // On diffuse simplement l'état normal et on arrête.
                        broadcastGameState(gameId, nextGameState);
                        return; // On sort de la gestion de l'événement 'PLAY_MOVE'
                    }
                    // 2. On récupère la version MISE À JOUR de ce joueur depuis le nouvel état.
                    //    Il a pioché de nouvelles tuiles, donc son chevalet a peut-être changé.
                    const updatedPlayerWhoPlayed = nextGameState.players.find(p => p.id === playerWhoPlayed.id);

                    // 3. On vérifie la condition de fin de partie sur CE joueur.
                    if (updatedPlayerWhoPlayed && updatedPlayerWhoPlayed.rack.length === 0 && nextGameState.tileBag.length === 0) {
                        isGameOver = true;
                    }


                    if (isGameOver && updatedPlayerWhoPlayed) {
                        console.log(`🏁 La partie ${gameId} est terminée ! Calcul du score final.`);
                        // Le joueur qui a terminé est `updatedPlayerWhoPlayed`.
                        const winningPlayer = updatedPlayerWhoPlayed;

                        // 1. Calculer les points restants...
                        let remainingPoints = 0;
                        nextGameState.players.forEach(p => {
                            if (p.id !== winningPlayer.id) {
                                p.rack.forEach(tile => { remainingPoints += tile.points; });
                            }
                        });

                        // 2. Mettre à jour les scores finaux...
                        const finalPlayers = nextGameState.players.map(p => {
                            if (p.id === winningPlayer.id) {
                                return { ...p, score: p.score + remainingPoints };
                            } else {
                                let playerRemainingPoints = 0;
                                p.rack.forEach(tile => playerRemainingPoints += tile.points);
                                return { ...p, score: p.score - playerRemainingPoints };
                            }
                        });
                        // 3. Créer l'état de jeu final
                        const finalGameState = {
                            ...nextGameState,
                            players: finalPlayers,
                            status: GameStatus.FINISHED // <-- On change le statut
                        };

                        // 4. On sauvegarde et on diffuse l'état FINAL
                        games.set(gameId, finalGameState);
                        broadcastGameState(gameId, finalGameState);
                    } else {
                        // Diffusion (broadcast) de l'état mis à jour à tous les joueurs connectés.
                        console.log(`✅ Coup validé! Diffusion du nouvel état personnalisé.`);
                        broadcastGameState(gameId, nextGameState);
                    }
                } else {
                    // Si le moteur retourne null, le coup était invalide.
                    console.log("❌ Coup invalide! Envoi d'un message d'erreur.");
                    const errorEvent: ServerToClientEvent = {
                        type: "ERROR",
                        payload: { message: "Votre coup est invalide." }
                    };
                    ws.send(JSON.stringify(errorEvent));
                }
            }

            if (event.type === 'PASS_TURN') {
                const currentGame = games.get(gameId);
                if (!currentGame || playerId !== currentGame.players[currentGame.currentPlayerIndex]?.id) {
                    // Sécurité : on ignore si ce n'est pas le tour de ce joueur.
                    return;
                }

                console.log(`➡️  Le joueur ${playerId} a passé son tour pour la partie ${gameId}.`);

                // On passe simplement au joueur suivant
                const nextPlayerIndex = (currentGame.currentPlayerIndex + 1) % currentGame.players.length;
                const forceEndGame = currentGame.forceEndGame + 1;

                const nextGameState: GameState = {
                    ...currentGame,
                    placedPositions: [], // Pas de lettres posées
                    currentPlayerIndex: nextPlayerIndex,
                    turnNumber: currentGame.turnNumber + 1, // On incrémente le numéro de tour
                    forceEndGame: forceEndGame
                };
                // --- VÉRIFICATION DE FIN DE PARTIE ---
                if (forceEndGame > currentGame.players.length) {
                    console.log(`🏁 La partie ${gameId} est terminée (fin forcée ${forceEndGame}) ! Calcul du score final.`);
                    // 1. Mettre à jour les scores finaux...
                    const finalPlayers = nextGameState.players.map(p => {
                        let playerRemainingPoints = 0;
                        p.rack.forEach(tile => playerRemainingPoints += tile.points);
                        return { ...p, score: p.score - playerRemainingPoints };
                    });
                    // 2. Créer l'état de jeu final
                    const finalGameState = {
                        ...nextGameState,
                        players: finalPlayers,
                        status: GameStatus.FINISHED // <-- On change le statut
                    };
                    // On sauvegarde et on diffuse le nouvel état
                    games.set(gameId, finalGameState);
                    broadcastGameState(gameId, finalGameState);
                } else {
                    // On sauvegarde et on diffuse le nouvel état
                    games.set(gameId, nextGameState);
                    broadcastGameState(gameId, nextGameState);
                }
            }

            if (event.type === 'EXCHANGE_TILES') {
                const currentGame = games.get(gameId);
                if (!currentGame || playerId !== currentGame.players[currentGame.currentPlayerIndex]?.id) {
                    // Sécurité : on ignore si ce n'est pas le tour de ce joueur.
                    return;
                }
                const player = currentGame.players.find(p => p.id === playerId);
                if (!player) {
                    console.warn(`Impossible de trouver le joueur ${playerId} dans la partie ${gameId}. L'échange de tuiles est annulé.`);
                    return;
                }
                const { tilesToExchange } = event.payload;
                const updatedGame = processExchangeTiles(currentGame, player, tilesToExchange);
                games.set(gameId, updatedGame); // On met à jour
                broadcastGameState(gameId, updatedGame);
            }

        } catch (error) {
            console.error("Erreur lors du traitement du message:", error);
        }
    });

    /**
     * Ce bloc est exécuté lorsque le client ferme sa connexion.
     */
    ws.on('close', () => {
        console.log(`👋 Joueur ${playerId} déconnecté.`);
        gameConnections.delete(playerId); // On le retire de la liste des connexions actives.
    });
}
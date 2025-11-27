/**
 * Ce fichier contient le "Moteur de Jeu" (Game Engine).
 *
 * Son rôle est d'encapsuler toute la logique et les règles du jeu de Scrabble.
 * Il est conçu pour être "pur", ce qui signifie qu'il ne dépend pas du réseau (WebSockets)
 * ou de l'interface utilisateur. Il ne fait que prendre des états de jeu en entrée
 * et retourner de nouveaux états de jeu en sortie.
 *
 * Cette séparation des responsabilités le rend très facile à tester et à maintenir.
 * Si une règle du jeu change, c'est le seul fichier qui doit être modifié.
 */

// --- IMPORTS ---
// On importe les types de données (GameState, PlacedTile, etc.)
import type { GameState, PlacedTile, Player, Board } from '../models/GameModels.js';
// On importe les fonctions utilitaires et les modules de logique spécifiques.
import { createNewBoard } from '../models/BoardModels.js';
import { isPlacementValid, isMoveConnected } from './MoveValidator.js';
import { findAllWordsFormedByMove } from './WordFinder.js';
import { isWordValid } from './Dictionary.js';
import { calculateTotalScore } from './ScoreCalculator.js';
import { drawTiles } from './TileBag.js';

/**
 * Traite un coup joué par un utilisateur ("Play Move").
 *
 * Cette fonction exécute l'intégralité de la séquence de validation et de mise à jour pour un coup.
 * Elle est la fonction la plus complexe et la plus importante du moteur de jeu.
 *
 * @param currentGame L'état actuel de la partie, avant que le coup ne soit appliqué.
 * @param placedTiles La liste des tuiles que le joueur a posées sur le plateau.
 * @returns Le nouvel état `GameState` si le coup est valide, ou `null` si le coup est invalide.
 */
export function processPlayMove(
    currentGame: GameState,
    placedTiles: PlacedTile[]
): GameState | null {

    const placedPositions = placedTiles.map(p => p.boardPosition);
    const originalBoard = currentGame.board;

    // --- Étape 1 : Création du plateau temporaire ---
    // On crée une nouvelle version du plateau qui inclut les tuiles que le joueur vient de poser.
    // C'est sur ce plateau "potentiel" que toutes les validations seront effectuées.
    const newBoard = createNewBoard(originalBoard, placedTiles);

    // --- Étape 2 : Validation complète du coup ---
    // On enchaîne toutes les règles de validation du Scrabble.
    const foundWords = findAllWordsFormedByMove(newBoard, placedTiles);
    const placementIsValid = isPlacementValid(originalBoard, placedPositions);
    const connectedIsValid = isMoveConnected(originalBoard, placedPositions, currentGame.turnNumber);
    const allWordsInDico = foundWords.size > 0 && Array.from(foundWords).every(word => isWordValid(word.text));

    // Le coup n'est valide que si toutes les conditions sont remplies.
    const isMoveFullyValid = placementIsValid && connectedIsValid && allWordsInDico;

    console.log(`MOTEUR DE JEU - VALIDATION: Placement=${placementIsValid}, Connexion=${connectedIsValid}, Dico=${allWordsInDico} -> Final=${isMoveFullyValid}`);

    // Si une seule règle n'est pas respectée, on rejette le coup en retournant `null`.
    if (!isMoveFullyValid) {
        return null;
    }

    // --- Étape 3 : Mise à jour de l'état du jeu (si le coup est valide) ---
    // Si on arrive ici, le coup est accepté et on calcule le nouvel état officiel de la partie.

    // a) Calcul du score et mise à jour du joueur
    const score = calculateTotalScore(foundWords, newBoard, placedPositions);
    const currentPlayerId = currentGame.players[currentGame.currentPlayerIndex]!.id;
    const updatedPlayers = currentGame.players.map(player => {
        if (player.id === currentPlayerId) {
            // On retourne une nouvelle copie du joueur avec son score mis à jour.
            return { ...player, score: player.score + score };
        }
        return player;
    });

    // b) Verrouillage des tuiles sur le plateau
    // On crée une copie du nouveau plateau et on marque les tuiles qui viennent d'être posées
    // comme étant "verrouillées" (`isLocked = true`).
    const lockedBoard = JSON.parse(JSON.stringify(newBoard)); // Copie profonde pour éviter les mutations
    placedPositions.forEach(pos => {
        if (lockedBoard[pos.row]?.[pos.col]?.tile) { // La vérification `?` est une sécurité
            lockedBoard[pos.row][pos.col].isLocked = true;
        }
    });

    // c) Pioche de nouvelles tuiles pour le joueur
    let currentTileBag = currentGame.tileBag;
    const { drawnTiles, newBag } = drawTiles(currentTileBag, placedTiles.length);
    currentTileBag = newBag; // La pioche est mise à jour.

    // Mise à jour du chevalet du joueur : on retire les tuiles jouées et on ajoute les nouvelles.
    const finalPlayers = updatedPlayers.map(player => {
        if (player.id === currentPlayerId) {
            const playedTileIds = new Set(placedTiles.map(p => p.tile.id));
            const remainingRack = player.rack.filter(t => !playedTileIds.has(t.id));
            const newRack = [...remainingRack, ...drawnTiles];
            return { ...player, rack: newRack };
        }
        return player;
    });

    // d) Passage au joueur suivant
    // L'opérateur modulo (%) garantit que l'index revient à 0 après le dernier joueur.
    const nextPlayerIndex = (currentGame.currentPlayerIndex + 1) % currentGame.players.length;

    // --- Étape 4 : Assemblage final du nouvel état ---
    // On combine toutes les nouvelles informations pour créer le `GameState` final.
    const nextGameState: GameState = {
        ...currentGame, // On garde les propriétés non modifiées (comme l'ID)
        board: lockedBoard,
        players: finalPlayers,
        tileBag: currentTileBag,
        moves: [], // TODO: Implémenter l'historique des coups
        turnNumber: currentGame.turnNumber + 1,
        currentPlayerIndex: nextPlayerIndex,
    };

    // On retourne le nouvel état de jeu. Le contrôleur (`index.ts`) se chargera de le sauvegarder
    // et de le diffuser aux clients.
    return nextGameState;
}

// TODO: Ajouter ici d'autres fonctions pures pour gérer les autres actions du jeu.
// export function processPassTurn(currentGame: GameState): GameState { ... }
// export function processExchangeTiles(currentGame: GameState, tilesToExchange: Tile[]): GameState | null { ... }
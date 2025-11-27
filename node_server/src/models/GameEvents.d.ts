import type { GameState, PlacedTile, Tile } from "./GameModels.js";
export interface JoinGameEvent {
    type: "JOIN_GAME";
    payload: {
        gameId: string;
        playerId: string;
    };
}
export interface PlayMoveEvent {
    type: "PLAY_MOVE";
    payload: {
        placedTiles: PlacedTile[];
    };
}
export interface RegisterProfileEvent {
    type: "REGISTER_PROFILE";
    payload: {
        name: string;
    };
}
export type ClientToServerEvent = JoinGameEvent | PlayMoveEvent | RegisterProfileEvent;
export interface GameStateUpdateEvent {
    type: "GAME_STATE_UPDATE";
    payload: {
        gameState: GameState;
        playerRack: Tile[];
    };
}
export interface ErrorEvent {
    type: "ERROR";
    payload: {
        message: string;
    };
}
export type ServerToClientEvent = GameStateUpdateEvent | ErrorEvent;
//# sourceMappingURL=GameEvents.d.ts.map
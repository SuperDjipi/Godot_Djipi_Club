export interface BoardPosition {
    row: number;
    col: number;
}
export interface Tile {
    id: string;
    letter: string;
    points: number;
    isJoker: boolean;
    assignedLetter?: string | null;
}
export interface PlacedTile {
    tile: Tile;
    boardPosition: BoardPosition;
}
export interface Player {
    id: string;
    name: string;
    score: number;
    rack: Tile[];
    isActive: boolean;
}
export declare enum GameStatus {
    WAITING = "WAITING",
    PLAYING = "PLAYING",
    FINISHED = "FINISHED"
}
export interface BoardCell {
    boardPosition: BoardPosition;
    bonus: string;
    tile: Tile | null;
}
export type Board = BoardCell[][];
export interface Move {
    playerId: string;
    tiles: PlacedTile[];
    score: number;
    timestamp: number;
}
export declare enum Direction {
    HORIZONTAL = "HORIZONTAL",
    VERTICAL = "VERTICAL"
}
export interface FoundWord {
    text: string;
    direction: Direction;
    tiles: {
        tile: Tile;
        boardPosition: BoardPosition;
    }[];
    start: BoardPosition;
}
export interface GameState {
    id: string;
    board: Board;
    players: Player[];
    tileBag: Tile[];
    moves: Move[];
    status: GameStatus;
    turnNumber: number;
    currentPlayerIndex: number;
}
//# sourceMappingURL=GameModels.d.ts.map
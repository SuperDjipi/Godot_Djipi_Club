import type { Board, BoardPosition } from '../models/GameModels.js';

const BOARD_SIZE = 15;

function getTile(board: Board, position: BoardPosition): any | null {
    // ... (copiez la même fonction getTile que dans WordFinder)
    if (position.row >= 0 && position.row < BOARD_SIZE && position.col >= 0 && position.col < BOARD_SIZE) {
        return board[position.row]![position.col]!.tile;
    }
    return null;
}

export function isPlacementValid(board: Board, placedTiles: BoardPosition[]): boolean {
    if (placedTiles.length <= 1) return true;

    const rows = new Set(placedTiles.map(p => p.row));
    const cols = new Set(placedTiles.map(p => p.col));

    const allOnSameRow = rows.size === 1;
    const allOnSameCol = cols.size === 1;

    if (!allOnSameRow && !allOnSameCol) {
        console.log("Validation échec : les tuiles posées ne sont pas sur la même ligne/colonne.");
        return false;
    }

    if (allOnSameRow) {
        const row = placedTiles[0]!.row;
        const minCol = Math.min(...placedTiles.map(p => p.col));
        const maxCol = Math.max(...placedTiles.map(p => p.col));

        for (let col = minCol; col <= maxCol; col++) {
            const currentPos = { row, col };
            const hasExistingTile = getTile(board, currentPos) !== null;
            const isNewTile = placedTiles.some(p => p.row === row && p.col === col);
            if (!hasExistingTile && !isNewTile) {
                console.log(`Validation échec : trou dans le mot principal horizontal.`);
                return false;
            }
        }
    } else { // All on same column
        const col = placedTiles[0]!.col;
        const minRow = Math.min(...placedTiles.map(p => p.row));
        const maxRow = Math.max(...placedTiles.map(p => p.row));

        for (let row = minRow; row <= maxRow; row++) {
            const currentPos = { row, col };
            const hasExistingTile = getTile(board, currentPos) !== null;
            const isNewTile = placedTiles.some(p => p.row === row && p.col === col);
            if (!hasExistingTile && !isNewTile) {
                console.log(`Validation échec : trou dans le mot principal vertical.`);
                return false;
            }
        }
    }

    return true;
}

export function isMoveConnected(board: Board, placedTiles: BoardPosition[], turnNumber: number): boolean {
    const centerPos = Math.floor(BOARD_SIZE / 2);

    if (turnNumber === 1) {
        return placedTiles.some(p => p.row === centerPos && p.col === centerPos);
    }

    const adjacentOffsets = [{row: -1, col: 0}, {row: 1, col: 0}, {row: 0, col: -1}, {row: 0, col: 1}];
    const placedSet = new Set(placedTiles.map(p => `${p.row},${p.col}`));

    for (const pos of placedTiles) {
        for (const offset of adjacentOffsets) {
            const adjacentPos = { row: pos.row + offset.row, col: pos.col + offset.col };
            if (getTile(board, adjacentPos) !== null && !placedSet.has(`${adjacentPos.row},${adjacentPos.col}`)) {
                return true; // C'est connecté !
            }
        }
    }

    return false;
}
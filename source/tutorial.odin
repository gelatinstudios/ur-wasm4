
package wasm4_ur

import "w4"

Screen_Graphic :: enum u8 {
    Start_Positions,
    Arrows,
    Middle,
    End_Positions,
    Rosettes,
    Middle_Rosette,

    P1_Start,
    P1_Example,

    P2_Example,
    P1_Killed,
}

Tutorial_Screen :: struct {
    text: string,
    graphics: []Screen_Graphic,
}

tutorial_screens := [?]Tutorial_Screen {
    {"Ur is a board game from ancient Mesopotamia", {}},
    {"It's at least 4000 years old", {}},
    {"Ur is a racing game", {}},
    {"So the object of the game is to be the first to get your pieces from start to finish", {}},
    {"Each player's piece starts here", {.Start_Positions}},
    {"Here are the paths each player's pieces must take", {.Start_Positions, .Arrows}},
    {"Each player must land each of their pieces here", {.Arrows, .End_Positions}},
    {"An exact roll to the invisible end spot here is required", {.Arrows, .End_Positions}},
    {"When a player gets all 7 of their pieces to the end, they win", {.Arrows, .End_Positions}},
    {"You may not move a piece to a spot with one of your pieces already there", {.P1_Example, .P1_Start}},
    {"You may land a piece on an enemy piece to remove it from the board and start it over", {.P2_Example, .P1_Killed}},
    {"Due to the paths players take, this only happens in the middle column", {.Arrows, .Middle}},
    {"Rosettes are special tiles", {.Rosettes}},
    {"If a player lands on a Rosette, they may roll again", {.Rosettes}},
    {"You may not knock another player's piece off of a Rosette", {.Rosettes}},
    {"Which, due to player paths again, only applies to this Rosette", {.Middle_Rosette}},
    {"Rolling or confirming a piece to move is done with X", {}}, // make interactive??
    {"Cycling through moves is done with UP and DOWN", {}}, // make interactive??
    {"Good luck and have fun!", {}},
}

TUTORIAL_SCREEN_COUNT :: len(tutorial_screens)

Arrow_Kind :: enum u8 { None, up, down, left, right, lr, start, end }

Arrow :: struct {
    kind: Arrow_Kind,
    color: u8,
}

arrow_image := [?]byte {
    0b00000000, 0b01000000, 0b00000000, 0b00011100,
    0b00000000, 0b00000111, 0b11000000, 0b00000001,
    0b11111100, 0b00000000, 0b01111111, 0b11000000,
    0b00011101, 0b11011100, 0b00000111, 0b00111001,
    0b11000001, 0b11000111, 0b00011100, 0b01110000,
    0b11100001, 0b11000000, 0b00011100, 0b00000000,
    0b00000011, 0b10000000, 0b00000000, 0b01110000,
    0b00000000, 0b00001110, 0b00000000, 0b00000001,
    0b11000000, 0b00000000, 0b00111000, 0b00000000,
    0b00000111, 0b00000000, 0b00000000, 0b11100000,
    0b00000000, 0b00011100, 0b00000000, 0b00000011,
    0b10000000, 0b00000000,
}
board_arrows :: [?]Arrow {
    {.right, 3}, {.down, 2}, {.left, 4},
    {   .up, 3}, {.down, 2}, {  .up, 4},
    {   .up, 3}, {.down, 2}, {  .up, 4},
    {   .up, 3}, {.down, 2}, {  .up, 4},
    { .None, 0}, {.down, 2}, {.None, 0},
    { .None, 0}, {.down, 2}, {.None, 0},
    {   .up, 3}, {.down, 2}, {  .up, 4},
    {   .up, 3}, {  .lr, 0}, {  .up, 4},
}

draw_tutorial :: proc(game: Game_State) {
    offset :: 3
    text_offset :: (offset + board_width)
    
    draw_board(game, offset)

    using screen := tutorial_screens[game.tutorial_screen]
    
    // draw tutorial graphics
    pp :: proc(column, row: int) -> (i32, i32) {
        x, y := tile_position(column, row, offset)
        return x+1, y+1
    }
    draw_circles :: proc(row: int) {
        draw_piece(.One, pp(0, row), false)
        draw_piece(.Two, pp(2, row), false)
    }
    mask_tile :: proc(column, row: int) {
        w4.DRAW_COLORS^ = 0x11
        w4.rect(tile_position(column, row, offset), 19, 19)
    }
    
    for sg, i in graphics {
        should_draw := true
        if i == len(graphics)-1 {
            oscillation_length :: 30
            should_draw = game.frame_count % (oscillation_length*2) < oscillation_length
        }
        if !should_draw do continue
        switch sg {
            case .Start_Positions:
                draw_circles(4)
                
            case .Arrows:
                for arrow, i in board_arrows {
                    using arrow
                    
                    if kind == .None do continue
                    
                    x, y := tile_position(i%3, i/3, offset)
                    
                    if kind == .lr {
                        w4.DRAW_COLORS^ = 0x31
                        w4.blit(&arrow_image[0], x, y, 19, 19/2 + 1, {.ROTATE_CCW_90})
                        w4.DRAW_COLORS^ = 0x41
                        w4.blit(&arrow_image[0], x + 19/2 + 1, y, 19, 19/2, {.ROTATE_CCW_90, .FLIPY})
                    } else {
                        w4.DRAW_COLORS^ = u16(color) << 4 | 1

                        flag_tab := #partial [Arrow_Kind]w4.Blit_Flags {
                            .up = {},
                            .down = {.FLIPY},
                            .left = {.ROTATE_CCW_90},
                            .right = {.ROTATE_CCW_90, .FLIPY},
                        }
                        
                        w4.blit(&arrow_image[0], x, y, 19, 19, flag_tab[kind])
                    }
                }

            case .Middle:
                for row in 0..<8 {
                    mask_tile(1, row)
                }
                
	    case .End_Positions:
                draw_circles(5)

	    case .Rosettes:
                mask_tile(0, 0)
                mask_tile(2, 0)
                mask_tile(1, 3)
                mask_tile(0, 6)
                mask_tile(2, 6)
                
            case .Middle_Rosette:
                mask_tile(1, 3)

            case .P1_Start:   draw_piece(.One, pp(0, 4)) // blinks
            case .P1_Example:
                w4.DRAW_COLORS^ = 3
                centered_text(10, "ROLL: 2", text_offset)
                draw_piece(.One, pp(0, 2))

            case .P2_Example:
                w4.DRAW_COLORS^ = 4
                centered_text(10, "ROLL: 2", text_offset)
                draw_piece(.Two, pp(2, 1))
                draw_piece(.Two, pp(1, 0))
                
            case .P1_Killed: draw_piece(.One, pp(1, 0)) // blinks
        }
    }
    
    // draw text
    max_length :: (w4.SCREEN_SIZE - text_offset) / CHAR_SIZE

    lines: [32]Layout_Row
    index := 0
    for at := 0; at < len(text);  {
        prev := at
        at = min(at + max_length, len(text))
        if at < len(text) do for text[at] != ' ' {
            at -= 1
        }
        lines[index] = text[prev:at]
        index += 1
        at += 1
    }

    target := Rect {{text_offset, 30}, {w4.SCREEN_SIZE, w4.SCREEN_SIZE - 30}}
    draw_rows(lines[:index], target, 3)
    
    w4.DRAW_COLORS^ = 0x13
    centered_text(w4.SCREEN_SIZE - 20, "Next: X", text_offset)
    w4.DRAW_COLORS^ = 0x14
    centered_text(w4.SCREEN_SIZE - 10, "Prev: Z", text_offset)
}

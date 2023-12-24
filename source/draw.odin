
package wasm4_ur

import "w4"
import "assets"

CHAR_SIZE :: 8

iVec2 :: [2]i16

Rect :: struct {
    min, max: iVec2,
}

Dice :: [4]int

Layout_Row :: union {string, ^Dice, Pieces_Row, Colored_Text}

Pieces_Row :: struct {
    /* count, padding: i32, */
    /* id: Player_ID, */
}

Colored_Text :: struct {
    text: string,
    color: u16,
}

player_color :: proc(id: Player_ID) -> u16 {
    if id == .One do return 3
    if id == .Two do return 4
    return 2
}

FULL_SCREEN_RECT :: Rect{{0,0}, {w4.SCREEN_SIZE, w4.SCREEN_SIZE}}

// TODO: stop using magic numbers
draw_rows :: proc(rows: []Layout_Row, target := FULL_SCREEN_RECT,
                  maybe_padding: Maybe(i16) = nil, bordered := false)
{
    pieces_count :: 7
    pieces_padding :: 3
    piece_size :: 18
    
    total_width: i16
    total_height: i16
    widths  := make([]i16, len(rows))
    heights := make([]i16, len(rows))
    for row, i in rows {
        w, h: i16
        switch r in row {
            case string:
                w = i16(len(r)) * CHAR_SIZE
                h = CHAR_SIZE
            case Colored_Text:
                w = i16(len(r.text)) * CHAR_SIZE
                h = CHAR_SIZE
            case ^Dice:
                w = 12*4
                h = 12
            case Pieces_Row:
                w = pieces_count * piece_size + (pieces_count-1) * pieces_padding
                h = piece_size
        }
        widths[i] = w
        heights[i] = h
        total_height += h
        total_width = max(total_width, w)
    }

    target_width := target.max.x-target.min.x
    target_height := target.max.y-target.min.y
    
    padding, ok := maybe_padding.?
    if !ok {
        padding = (target_height - total_height) / i16(len(rows)+1)
    }
    
    total_height += i16(len(rows)-1) * padding
    
    center := target.min + iVec2{target_width, target_height}/2
    y := i32(center.y - total_height/2)

    if bordered {
        p := padding
        p2 := p*2
        w4.DRAW_COLORS^ = 0x21
        w4.rect(i32(center.x - total_width/2 - p), y - i32(p),
                u32(total_width + p2), u32(total_height + p2))
    }

    for row, i in rows {
        x := i32(center.x - widths[i]/2)
        switch r in row {
            case string:
                w4.DRAW_COLORS^ = 0x12
                w4.text(r, x, y)
            case Colored_Text:
                w4.DRAW_COLORS^ = r.color
                w4.text(r.text, x, y)
            case ^Dice:
                draw_dice(r^, x, y)
            case Pieces_Row:
                for j in 0..<pieces_count {
                    player := Player_ID(j%2)
                    draw_piece(player, x, y, false)
                    x += 18 + pieces_padding
                }
        }
        y += i32(heights[i] + padding)
    }
}

centered_text :: proc(y: i32, text: string, x_offset := 0) {
    width := len(text) * CHAR_SIZE
    x := x_offset + ((w4.SCREEN_SIZE - x_offset) / 2) - width / 2
    w4.text(text, i32(x), i32(y))
}

player1_info_x :i32 : 1
player2_info_x :i32 : 112

board_x :: 50
board_width :: 3*20 + 2

get_info_piece_positions :: proc(game: Game_State, id: Player_ID) -> [][2]i32 {
    @static positions: [7][2]i32
    player_index := int(id)
    using player := game.players[player_index]
    
    effective_available_pieces := available_pieces

    if (game.state == .Move_Prompt) &&
	id == game.active_player &&
	game.selected_tile == 0
    {
	effective_available_pieces -= 1
    }
    
    piece_counts := [?]u8{effective_available_pieces, finished_pieces}
    y_offsets    := [?]i32{12,              6*20 + 18}

    index := 0
    for piece_count, i in piece_counts {
	x_offset := id == .One ? player1_info_x : player2_info_x
	y_offset := y_offsets[i]
        for j in 0 ..< i32(piece_count) {
            positions[index].x = (j*12 - (j < 4 ? 0 : 12*4-6)) + x_offset + 2
            positions[index].y =         (j < 4 ? 0 : 10)      + y_offset
	    index += 1
	}
    }

    return positions[:index]
}

get_tile_pos :: proc(game: Game_State, id: Player_ID, index: int) -> (i32, i32) {
    tile_tab := [?][2]u8 {
	{0, 4}, {0, 3}, {0, 2}, {0, 1}, {0, 0}, {1, 0}, {1, 1}, {1, 2},
	{1, 3}, {1, 4}, {1, 5}, {1, 6}, {1, 7}, {0, 7}, {0, 6}, {0, 5},
    }

    #assert(len(tile_tab) == len(game.board))

    pos: iVec2
    pos.x = auto_cast tile_tab[index].x
    pos.y = auto_cast tile_tab[index].y
    if id == .Two && pos.x == 0 {
	pos.x = 2
    }
    pos.x *= 20
    pos.y *= 20
    pos.x += i16(board_x)
    return i32(pos.x), i32(pos.y)
}

draw_piece :: proc(id: Player_ID, x, y: i32, is_info: bool = false) {
    if id == .One {
	w4.DRAW_COLORS^ = 0x0230
    } else {
	w4.DRAW_COLORS^ = 0x0140
    }

    if is_info {
	assets.blit_info_piece(x, y)
    } else {
	assets.blit_piece(x, y)
    }
}

draw_dice :: proc(dice: [4]int, x, y: i32) {
    // the way we draw the dice is by masking off the corners that should be black
    Mask_Rect :: struct {
        x, y: i32,
        w, h: u32,
    }
    mask_rects := [?]Mask_Rect {
	{4,5,3,2},
	{5,1,1,2},
	{1,9,2,1},
	{8,9,2,1},
    }
    mask_permutations := [?][2]int {
	{1, 2},
	{1, 3},
	{2, 3},
	{0, 1},
	{0, 2},
	{0, 3},
    }

    x := x
    for die in dice {
	w4.DRAW_COLORS^ = 0x4321

	assets.blit_die(x, y)

	for rect_index in mask_permutations[die] {
	    rect := mask_rects[rect_index]
	    w4.DRAW_COLORS^ = 0x20
	    w4.rect(x + rect.x, y + rect.y, rect.w, rect.h)
	}

        x += 12
    }
}

tile_position :: proc(column, row: int, offset: int) -> (i32, i32) {
    return i32(offset + column*20), i32(row * 20)
}

// also draws pieces on board
draw_board :: proc(game: Game_State, board_x := board_x) {
    board_layout :: [?]u8 {
	1, 2, 1,
	3, 4, 3,
	4, 6, 4,
	3, 1, 3,
	0, 4, 0,
	0, 6, 0,
	1, 3, 1,
	5, 4, 5,
    }

    board_indices := [?]u8 {
	 4,  5,  4,
	 3,  6,  3,
	 2,  7,  2,
 	 1,  8,  1,
	 0,  9,  0,
	15, 10, 15,
	14, 11, 14,
	13, 12, 13,
    }

    // this really needs to be done first!
    // board outline
    w4.DRAW_COLORS^ = 0x20
    w4.rect(   i32(board_x-1),      0, board_width, 4*20+1)
    w4.rect(i32(board_x+20-1),   4*20,   20+2, 2*20)
    w4.rect(   i32(board_x-1), 6*20-1, board_width, 2*20+2)

    for tile_sprite, i in board_layout {
	w4.DRAW_COLORS^ = 0x3421

        column := i%3
        row    := i/3
        x, y := tile_position(column, row, board_x)

        // TODO:
        // all of the DRAW_COLORS^ = ... is to  make up for the tiles
        // being colored differently as assets. should be fixed offline sometime
	switch tile_sprite {
	    case 0: // empty space
	    case 1:
	        w4.DRAW_COLORS^ = 0x3421
	        flags: w4.Blit_Flags = {.FLIPX} if column == 0 else nil
	        assets.blit_rosette(x, y, flags)
	    case 2:
	        w4.DRAW_COLORS^ = 0x4421
	        assets.blit_square_circle_with_crosses(x, y)
	    case 3:
	        w4.DRAW_COLORS^ = 0x1420
	        flags: w4.Blit_Flags = {.ROTATE_CCW_90}
	        if row > 2 {
		    flags += {.FLIPX}
	        }
	        if column != 0 {
		    flags += {.FLIPY}
	        }
	        assets.blit_eyes_crosses(x, y, flags)
	    case 4:
	        w4.DRAW_COLORS^ = 0x4221
	        assets.blit_circles_with_eyes(x, y)
	    case 5:
	        w4.DRAW_COLORS^ = 0x1423
	        assets.blit_zig_zaggy_circles(x, y)

	    case 6:
	        w4.DRAW_COLORS^ = 0x1421
	        assets.blit_last_peace(x, y)
	}

	draw_piece_if_on_tile :: proc(game: Game_State, board_index: u8,
				      id: Player_ID, pieces: Tile_Pieces, x, y: i32)
	{
	    is_selected_piece :=
		game.state == .Move_Prompt &&
		int(board_index) == game.selected_tile &&
		id == game.active_player
	    
	    should_draw: bool
	    if  is_selected_piece {
		oscillation_length :: 10

		n := game.frame_count % (oscillation_length*2)
		
		should_draw = n < oscillation_length
		should_draw = true
	    } else {
		should_draw = id in pieces
	    }

	    if should_draw {
		draw_piece(id, x+1, y+1)
	    }
	}
	
	board_index := board_indices[i]
	tile := game.board[board_index]
	pieces := tile

	if column <= 1 {
	    draw_piece_if_on_tile(game, board_index, .One, pieces, x, y)
	}
	if column >= 1 {
	    draw_piece_if_on_tile(game, board_index, .Two, pieces, x, y)
	}
    }
}

draw_player_digit :: proc(digit: int, id: Player_ID, y: i32, x_offset: i32 = 0) {
    buffer: [1]u8
    buffer[0] = byte(digit) + '0'
    draw_player_text(string(buffer[:]), id, y, x_offset)
}

draw_player_text :: proc(text: string, id: Player_ID, y: i32, x_offset: i32 = 0) {
    x: i32

    if id == .One {
	x = player1_info_x
	w4.DRAW_COLORS^ = 0x03
    } else {
	x = player2_info_x
	w4.DRAW_COLORS^ = 0x04
    }

    x += x_offset
    
    w4.text(text, x, y)
}

draw_game :: proc(game: ^Game_State) {
    state := game.state
    active_player := game.active_player

    if state >= .Roll_Prompt {
	draw_board(game^)

        if state >= .Roll_Prompt {
	    draw_board(game^)

	    player_names := [?]string {"  P1", "  P2"}

            // draw info pieces
	    for i in 0..=1 {
	        id := Player_ID(i)
	        draw_player_text(player_names[i], id, 2, 2)
	        positions := get_info_piece_positions(game^, id)
	        for position in positions {
		    draw_piece(id, position.x, position.y, true)
	        }
	    }
        }
    }

    draw_roll :: proc(roll: int, active_player: Player_ID) {
	draw_player_text("ROLL:", active_player, 60)
	draw_player_digit(roll, active_player, 60, 40)
    }

    info_x := active_player == .One ? player1_info_x : player2_info_x

    switch state {
        case .Menu: fallthrough
        case .Players_Ready_Up: fallthrough
        case .Menu_Rolling:
            selection_color :: proc(game: Game_State, selection: Menu_Selection) -> u16 {
                return game.menu_selection == selection ? 4 : 2
            }

            logo_rows := [?]Layout_Row {
                "The Royal Game of Ur",
                Pieces_Row {},
                &game.dice,
            }
            
            menu_rows := [?]Layout_Row {
                Colored_Text {"Start", selection_color(game^, .Start)},
                Colored_Text {.One in game.ais ? "P1 IS AI" : "P1 IS NOT AI",
                              selection_color(game^, .Player_One_AI_Checkbox)},
                Colored_Text {.Two in game.ais ? "P2 IS AI" : "P2 IS NOT AI",
                              selection_color(game^, .Player_Two_AI_Checkbox)},
                Colored_Text {"How to Play", selection_color(game^, .How_To_Play)},
            }

            ready_up_rows := [?]Layout_Row {
                Colored_Text {game.player_1_ready ? "P1 IS READY" : "P1 IS NOT READY", 3},
                Colored_Text {game.player_2_ready ? "P2 IS READY" : "P2 IS NOT READY", 4},
                "X to toggle READY",
                "Z to quit",
            }

            logo_target := Rect {{0, 0}, {w4.SCREEN_SIZE, w4.SCREEN_SIZE/2}}
            draw_rows(logo_rows[:], logo_target)

            menu_target := Rect {{0, w4.SCREEN_SIZE/2}, {w4.SCREEN_SIZE, w4.SCREEN_SIZE}}
            use_ready_up := state != .Menu && card(game.ais) == 0
            draw_rows(use_ready_up ? ready_up_rows[:] : menu_rows[:], menu_target)

        case .Tutorial:
            draw_tutorial(game^)
            
        case .Roll_Prompt:
	    draw_player_text("ROLL", active_player, 60)
	    draw_player_text("HIT X", active_player, 70)
	    draw_dice(game.dice, info_x, 45)
	    
        case .Rolling:
	    draw_roll(game.roll, active_player)
	    draw_dice(game.dice, info_x, 45)

        case .Move_Prompt:
	    draw_roll(game.roll, active_player)
	    draw_dice(game.dice, info_x, 45)
	    draw_player_text(" MOVE", active_player, 70)

	    x, y := get_tile_pos(game^, active_player, game.selected_tile)

	    if active_player == .One {
	        w4.DRAW_COLORS^ = 0x20
	    } else {
	        w4.DRAW_COLORS^ = 0x20
	    }
	    w4.oval(x+1, y+1, 18, 18)
	    w4.oval(x, y, 20, 20)

	    oscillation_length :: 10
	    n := game.frame_count % (oscillation_length*2)
	    should_draw := n < oscillation_length

	    if should_draw {
	        x, y = get_tile_pos(game^, active_player, game.selected_tile + game.roll)

	        x += 1
	        y += 1

	        draw_piece(active_player, x, y)
	    }
	    
        case .Done:
	    for y in 0..<w4.SCREEN_SIZE {
	        for x in 0..<w4.SCREEN_SIZE {
		    index := u32(x + y*w4.SCREEN_SIZE)
		    if get_bit(&game.end_screen_has_sprite, index) {
		        is_info := get_bit(&game.end_screen_is_info, index)
		        player_id := Player_ID(get_bit(&game.end_screen_player_id, index))
		        draw_piece(player_id, i32(x), i32(y), is_info)
		    }
	        }
	    }

	    frames_to_oscillate_for :: 120

	    should_draw := true
	    if game.state_frame_count < frames_to_oscillate_for {
	        oscillation_length :: 10
	        n := game.state_frame_count % (oscillation_length*2)
	        should_draw = n < oscillation_length
	    }

            if should_draw {
                p := game.player_that_won
                rows := [?]Layout_Row {
                    Colored_Text {p == .One ? "P1 Wins!" : "P2 Wins!", player_color(p)},
                    "X to Restart",
                }
                draw_rows(rows[:], FULL_SCREEN_RECT, 2, true)
            }
    }
}

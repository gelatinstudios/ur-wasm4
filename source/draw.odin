
package wasm4_ur

import "core:strings"

import "w4"
import "assets"

CHAR_SIZE :: 8

centered_text :: proc(y: i32, text: string, x_offset := 0) {
    width := len(text) * CHAR_SIZE
    x := x_offset + ((w4.SCREEN_SIZE - x_offset) / 2) - width / 2
    w4.text(text, i32(x), i32(y))
}

player1_info_x :i32 : 1
player2_info_x :i32 : 112

board_x :: i32(50)
board_width :: 3*20 + 2

get_tile_pos :: proc(game: Game_State, id: Player_ID, index: int) -> (i32, i32) {
    tile_tab := [?][2]i32 {
	{0, 4}, {0, 3}, {0, 2}, {0, 1}, {0, 0}, {1, 0}, {1, 1}, {1, 2},
	{1, 3}, {1, 4}, {1, 5}, {1, 6}, {1, 7}, {0, 7}, {0, 6}, {0, 5},
    }

    #assert(len(tile_tab) == len(game.board))

    pos := tile_tab[index]
    if id == .Two && pos.x == 0 {
	pos.x = 2
    }
    pos.x *= 20
    pos.y *= 20
    pos.x += board_x
    return pos.x, pos.y
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

draw_dice :: proc(dice: [4]int, id: Player_ID, y_pos: Maybe(i32) = nil) {
    // the way we draw the dice is by making off the corners that should be black
    Rect :: struct {
	x, y: i32,
	w, h: u32,
    }
    mask_rects := [?]Rect {
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

    dice := dice

    for die, i in dice {
	w4.DRAW_COLORS^ = 0x4321

	x_offset := id == .One ? player1_info_x : player2_info_x
	
	x := x_offset + i32(i*12)
        y, for_menu := y_pos.(i32)
        if for_menu {
	    x = w4.SCREEN_SIZE/2 - 2*12 + i32(i*12)
        } else {
            y = 45
        }
	
	assets.blit_die(x, y)
	
	//mask := mask_permutations[die]

	for rect_index in mask_permutations[die] {
	    rect := mask_rects[rect_index]
	    w4.DRAW_COLORS^ = 0x20
	    w4.rect(x + rect.x, y + rect.y, rect.w, rect.h)
	}
    }
}

screen_texts := [?]string {
    "Ur is a board game from ancient Mesopotamia",
    "It's at least 4000 years old",
    "Ur is a racing game"
    "So the object of the game is to be the first to get your pieces from start to finish"
}

TUTORIAL_SCREEN_COUNT :: len(screen_texts)

draw_tutorial :: proc(game: Game_State) {
    using strings

    offset :: 3
    draw_board(game, offset)
    text_offset :: (offset + board_width)

    w4.DRAW_COLORS^ = 0x12

    y := i32(10)
    text := screen_texts[game.tutorial_screen] 

    max_length :: (w4.SCREEN_SIZE - text_offset) / CHAR_SIZE
    
    for len(text) > 0 {
        buffer: [256]u8
        builder := builder_from_bytes(buffer[:])

        write_string(&builder, fields_iterator(&text) or_else "")

        prev_text := text
        for word in fields_iterator(&text) {
            if builder_len(builder) + len(word) + 1 >= max_length {
                text = prev_text
                break
            }

            write_byte(&builder, ' ')
            write_string(&builder, word)

            prev_text = text
        }

        centered_text(y, to_string(builder), text_offset)
        
        y += 10
    }

    w4.DRAW_COLORS^ = 0x14
    centered_text(w4.SCREEN_SIZE - 10, "Press X", text_offset)
}
    
// also draws pieces on board
draw_board :: proc(game: Game_State, board_x := board_x) {
    board_layout :: [?]int {
	1, 2, 1,
	3, 4, 3,
	4, 6, 4,
	3, 1, 3,
	0, 4, 0,
	0, 6, 0,
	1, 3, 1,
	5, 4, 5,
    }

    board_indices := [?]int {
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
    w4.rect(   board_x-1,      0, board_width, 4*20+1)
    w4.rect(board_x+20-1,   4*20,   20+2, 2*20+2)
    w4.rect(   board_x-1, 6*20-1, board_width, 2*20+2)

    for tile_sprite, i in board_layout {
	using assets
	
	w4.DRAW_COLORS^ = 0x3421

	column := i%3
	row    := i/3
	
	x := board_x + i32(column*20)
	y := i32(row*20)

        // TODO:
        // all of the DRAW_COLORS^ = ... is to  make up for the tiles
        // being colored differently as assets. should be fixed offline sometime
	switch tile_sprite {
	    case 0: // do nothing
	    case 1:
	        w4.DRAW_COLORS^ = 0x3421
	        flags: w4.Blit_Flags = {.FLIPX} if column == 0 else nil
	        blit_rosette(x, y, flags)
	    case 2:
	        w4.DRAW_COLORS^ = 0x4421
	        blit_square_circle_with_crosses(x, y)
	    case 3:
	        w4.DRAW_COLORS^ = 0x1420
	        flags: w4.Blit_Flags = {.ROTATE_CCW_90}
	        if row > 2 {
		    flags += {.FLIPX}
	        }
	        if column != 0 {
		    flags += {.FLIPY}
	        }
	        blit_eyes_crosses(x, y, flags)
	    case 4:
	        w4.DRAW_COLORS^ = 0x4221
	        blit_circles_with_eyes(x, y)
	    case 5:
	        w4.DRAW_COLORS^ = 0x1423
	        blit_zig_zaggy_circles(x, y)

	    case 6:
	        w4.DRAW_COLORS^ = 0x1421
	        blit_last_peace(x, y)
	}

	draw_piece_if_on_tile :: proc(game: Game_State, board_index: int,
						     id: Player_ID, pieces: Tile_Pieces, x, y: i32)
	{
	    is_selected_piece :=
		game.state == .Move_Prompt &&
		board_index == game.selected_tile &&
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

draw_digit :: proc(digit: int, x, y: i32) {
    buffer: [1]u8
    buffer[0] = byte(digit) + '0'
    w4.text(string(buffer[:]), x, y)
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

get_info_piece_positions :: proc(game: Game_State, id: Player_ID) -> [][2]i32 {
    @static positions: [7][2]i32
    player_index := int(id)
    using player := game.players[player_index]
        
    info_pieces_offsets := [?][2]i32 {
	{ 0,  0},
	{12,  0},
	{24,  0},
	{36,  0},
	{ 6, 10},
	{18, 10},
	{30, 10},
	{42, 10},
    }

    effective_available_pieces := available_pieces

    if (game.state == .Move_Prompt) &&
	id == game.active_player &&
	game.selected_tile == 0
    {
	effective_available_pieces -= 1
    }
    
    piece_counts := [?]int{effective_available_pieces, finished_pieces}
    y_offsets    := [?]i32{12,              6*20 + 18}

    index := 0
    for piece_count, i in piece_counts {
	x_offset := id == .One ? player1_info_x : player2_info_x
	y_offset := y_offsets[i]
	for pos in info_pieces_offsets[:piece_count] {
            pos := pos
	    pos.x += x_offset + 2
	    pos.y += y_offset

	    positions[index] = pos
	    index += 1
	}
    }

    return positions[:index]
}

draw_game :: proc(game: ^Game_State) {
    state := game.state
    active_player := game.active_player
    
    if state >= .Roll_Prompt {
	draw_board(game^)

	player_names := [?]string {"  P1", "  P2"}
	
	for i in 0..=1 {
	    id := Player_ID(i)
	    draw_player_text(player_names[i], id, 2, 2)
	    positions := get_info_piece_positions(game^, id)
	    for position in positions {
		draw_piece(id, position.x, position.y, true)
	    }
	}
    }

    draw_roll :: proc(roll: int, active_player: Player_ID) {
	draw_player_text("ROLL:", active_player, 60)
	draw_player_digit(roll, active_player, 60, 40)
    }

    switch state {
        case .Menu: fallthrough
        case .Players_Ready_Up: fallthrough
        case .Menu_Rolling:
	    w4.DRAW_COLORS^ = 0x12
            
            y := i32(10)
            
	    centered_text(y, "The Royal Game of Ur")
            y += 20
            
	    centered_text(y, "Press X to Start")
            y += 20
            
	    draw_dice(game.dice, active_player, y)
            y += 20

	    for i in 0..<7 {
	        id := Player_ID(i % 2)
	        draw_piece(id, 5 + i32(i*22), y)
	    }
            y += 30

            menu_selections := [Menu_Selection]string {
                    .One_Player_Start = "One Player Start",
                    .Two_Player_Start = "Two Player Start",
                    .How_To_Play = "How To Play",
            }

            if state == .Menu || game.player_2_is_ai {
	        w4.DRAW_COLORS^ = 0x12
                for text, selection in menu_selections {
                    text := text
                    if game.menu_selection == selection {
                        w4.DRAW_COLORS^ = 0x14
                    } else {
                        w4.DRAW_COLORS^ = 0x12
                    }
                    centered_text(y, text)
                    y += 15
                }
            } else {
                if game.player_1_ready {
                    draw_player_text(" P1",   .One, 120, 6)
                    draw_player_text("READY", .One, 130, 2)
                } else {
                    draw_player_text(" P1",   .One, 120, 6)
                    draw_player_text("NOT",   .One, 130, 10)
                    draw_player_text("READY", .One, 140, 2)
                }
                
                if game.player_2_ready {
                    draw_player_text(" P2",   .Two, 120, 6)
                    draw_player_text("READY", .Two, 130, 2)
                } else {
                    draw_player_text(" P2",   .Two, 120, 6)
                    draw_player_text("NOT",   .Two, 130, 10)
                    draw_player_text("READY", .Two, 140, 2)
                }
            }
            
        case .Tutorial:
            draw_tutorial(game^)
            
        case .Roll_Prompt:
	    draw_player_text("ROLL", active_player, 60)
	    draw_player_text("HIT X", active_player, 70)
	    draw_dice(game.dice, active_player)
	    
        case .Rolling:
	    draw_roll(game.roll, active_player)
	    draw_dice(game.dice, active_player)

        case .Move_Prompt:
	    draw_roll(game.roll, active_player)
	    draw_dice(game.dice, active_player)
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

	    // TODO: this is all pretty sloppily hacked together
	    //       could be cleaned up...
	    
	    if should_draw {
	        w4.DRAW_COLORS^ = 0x21
	        width  :u32 = 80
	        height :u32 = 20
	        
	        x := i32(w4.SCREEN_SIZE/2 - width/2)
	        y := i32(w4.SCREEN_SIZE/2 - height/2) - w4.SCREEN_SIZE/4
	        w4.rect(x, y - 5, width, height)

	        y += 1
	        
	        if game.player_that_won == .One {
		    w4.DRAW_COLORS^ = 0x3
		    w4.text(" P1 Wins!", x, y)
	        } else {
		    w4.DRAW_COLORS^ = 0x4
		    w4.text(" P2 Wins!", x, y)
	        }
	    }

	    if game.state_frame_count >= frames_to_oscillate_for {
	        text :: "X to Restart"
	        width :: len(text)*8 + 2
	        
	        w4.DRAW_COLORS^ = 0x21
	        w4.rect(w4.SCREEN_SIZE/2 - width/2, w4.SCREEN_SIZE/2 + 10 - w4.SCREEN_SIZE/4, width, 12)

	        if game.player_that_won == .One {
		    w4.DRAW_COLORS^ = 0x3
	        } else {
		    w4.DRAW_COLORS^ = 0x4
	        }
	        
	        w4.text(text, w4.SCREEN_SIZE/2 - width/2 +2, w4.SCREEN_SIZE/2 + 13 - w4.SCREEN_SIZE/4)
	    }
    }
}

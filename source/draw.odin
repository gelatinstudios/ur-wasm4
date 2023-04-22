
package wasm4_ur

import "w4"
import "assets"

player1_info_x :i32 : 1
player2_info_x :i32 : 112

board_x :: 50

tile_pos :: proc "contextless" (game: Game_State, id: Player_ID, index: int) -> (i32, i32) {
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

draw_piece :: proc "contextless" (id: Player_ID, x, y: i32, is_info: bool = false) {
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

draw_dice :: proc "contextless" (dice: [4]int, id: Player_ID, for_menu := false) {
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
	y := i32(45)

	if for_menu {
	    x = w4.SCREEN_SIZE/2 - 2*12 + i32(i*12)
	    y = 70
	}
	
	assets.blit_die(x, y)
	
	mask := mask_permutations[die]

	for rect_index in mask_permutations[die] {
	    rect := mask_rects[rect_index]
	    w4.DRAW_COLORS^ = 0x20
	    w4.rect(x + rect.x, y + rect.y, rect.w, rect.h)
	}
    }
}

// also draws pieces on board
draw_board :: proc "contextless" (game: Game_State) {
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
    w4.rect(   50-1,      0, 3*20+2, 4*20+1)
    w4.rect(50+20-1,   4*20,   20+2, 2*20+2)
    w4.rect(   50-1, 6*20-1, 3*20+2, 2*20+2)

    for tile_sprite, i in board_layout {
	using assets
	
	w4.DRAW_COLORS^ = 0x3421

	column := i%3
	row    := i/3
	
	x := i32(board_x + column*20)
	y := i32(row*20)

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

	draw_piece_if_on_tile :: proc "contextless" (game: Game_State, board_index: int,
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

draw_digit :: proc "contextless" (digit: int, x, y: i32) {
    buffer: [1]u8
    buffer[0] = byte(digit) + '0'
    w4.text(string(buffer[:]), x, y)
}

draw_player_digit :: proc "contextless" (digit: int, id: Player_ID, y: i32, x_offset: i32 = 0) {
    buffer: [1]u8
    buffer[0] = byte(digit) + '0'
    draw_player_text(string(buffer[:]), id, y, x_offset)
}

draw_player_text :: proc "contextless" (text: string, id: Player_ID, y: i32, x_offset: i32 = 0) {
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

draw_game :: proc "contextless" (game: Game_State) {
    state := game.state
    active_player := game.active_player
    
    if state >= .Roll_Prompt {
	draw_board(game)

	player_names := [?]string {"  P1", "  P2"}
	
	for i in 0..=1 {
	    using player := game.players[i]
	    id := Player_ID(i)
	    
	    draw_player_text(player_names[i], id, 2, 2)
	    
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

	    if (state == .Move_Prompt) &&
		id == active_player &&
		game.selected_tile == 0
	    {
		effective_available_pieces -= 1
	    }
	    
	    piece_counts := [?]int{effective_available_pieces, finished_pieces}
	    y_offsets    := [?]i32{12,              6*20 + 18}

	    for piece_count, i in piece_counts {
		x_offset := id == .One ? player1_info_x : player2_info_x
		y_offset := y_offsets[i]
		for i in 0 ..< piece_count {
		    pos := info_pieces_offsets[i]

		    pos.x += x_offset + 2
		    pos.y += y_offset

		    draw_piece(id, pos.x, pos.y, true)
		}
	    }
	}
    }

    draw_roll :: proc "contextless" (roll: int, active_player: Player_ID) {
	draw_player_text("ROLL:", active_player, 60)
	draw_player_digit(roll, active_player, 60, 40)
    }

    switch state {
    case .Menu: fallthrough
    case .Menu_Rolling:
	
	w4.DRAW_COLORS^ = 0x12
	w4.text("The Royal Game of Ur", 0, 20)
	w4.text("Press X to Start", 15, 50)
	draw_dice(game.dice, active_player, true)

	for i in 0..<7 {
	    id := Player_ID(i % 2)
	    draw_piece(id, 5 + i32(i*22), 90)
	}
	for i in 0..<7 {
	    id := Player_ID(int(!bool(i % 2)))
	    draw_piece(id, 5 + i32(i*22), 120)
	}

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

	x, y := tile_pos(game, active_player, game.selected_tile)

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
	    x, y = tile_pos(game, active_player, game.selected_tile + game.roll)

	    x += 1
	    y += 1

	    draw_piece(active_player, x, y)
	}
	
    case .Done:
    }
}

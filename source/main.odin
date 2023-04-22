
package wasm4_ur

import "w4"
import "assets"

frames_to_roll_for :: 60
frames_to_pause_after_roll_for :: 20
total_rolling_frames :: frames_to_roll_for + frames_to_pause_after_roll_for

board_length :: 16

Player :: struct {
    available_pieces: int,
    finished_pieces: int,
}

Player_ID :: enum {
    One = 0,
    Two = 1,
}

Tile_Pieces :: distinct bit_set[Player_ID]

war_region_min :: 5
war_region_max :: 12

in_war_region :: proc "contextless" (index: int) -> bool {
    return index >= war_region_min && index <= war_region_max
}

State :: enum {
    Menu = 1,
    Menu_Rolling,
    Roll_Prompt,
    Rolling,
    Move_Prompt,
    Done,
}

DICE_PERMUTATION_COUNT :: 6

Move_Type :: enum {
    No_Move = 0,
    Normal,
    Rosette,
    Kill,
    Finish_Line,
}

Game_State :: struct {
    state: State,

    frame_count: u64,
    state_frame_count: i64,

    pads_last_frame: [2]w4.Buttons,
    
    board: [board_length]Tile_Pieces, // one extra tile at beginning and end
    players: [2]Player,
    active_player: Player_ID,

    dice: [4]int,
    roll: int,

    selected_tile: int,
    move_type: Move_Type,
    player_that_moved: Player_ID,
}

is_rosette_tab: [board_length]bool

global_rng_state: u64
global_game_state: Game_State

switch_state :: proc "contextless" (game: ^Game_State, state: State) {
    game.state = state
    game.state_frame_count = -1 // because 1 is always added to it at the end of the update function

    if state == .Menu {
	global_audio_engine = {}
    }
}

other_player :: proc "contextless" (id: Player_ID) -> Player_ID {
    return Player_ID(!bool(id))
}

next_turn :: proc "contextless" (game: ^Game_State) {
    game.active_player = other_player(game.active_player)
    switch_state(game, .Roll_Prompt)
}

pcg32_increment :: 1442695040888963407

pcg32 :: proc "contextless" () -> u32 {
    // https://en.wikipedia.org/wiki/Permuted_congruential_generator
    rotr32 :: proc "contextless" (x: u32, r: u64) -> u32 {
	return x >> r | x << (-r & 31)
    }

    x := global_rng_state
    count := x >> 59
    global_rng_state = x * 6364136223846793005 + pcg32_increment
    x ~= (x >> 18)
    return rotr32(u32(x >> 27), count)
}

pcg32_init :: proc "contextless" (seed: u64) {
    global_rng_state = seed + pcg32_increment
}

roll :: proc "contextless" (game: ^Game_State) {
    sum := 0
    for die in &game.dice {
	n := pcg32() % DICE_PERMUTATION_COUNT
	die = int(n)
	sum += int(n < DICE_PERMUTATION_COUNT/2)
    }
    game.roll = sum
}

has_player_piece :: proc "contextless" (game: Game_State, id: Player_ID, index: int) -> bool {
    if index == 0 {
	return game.players[id].available_pieces > 0
    }
    tile := game.board[index]
    return id in tile
}

is_valid_selection :: proc "contextless" (game: Game_State, id: Player_ID, s: int) -> bool {
    if !has_player_piece(game, id, s) {
	return false
    }
    
    from := s
    to := s + game.roll

    result := false
    if to < board_length && !has_player_piece(game, id, to) {
	result =
	    !(in_war_region(to) &&
	      is_rosette_tab[to] &&
	      other_player(id) in game.board[to])
    }

    return result
}

selection_wrap :: proc "contextless" (game: Game_State, s: ^int, delta: int) {
    mod := len(game.board)
    s^ += delta
    s^ += (1 - s^ / mod) * mod
    s^ %= mod
}

find_valid_selection :: proc "contextless" (game: Game_State, id: Player_ID) -> (int, bool) {
    for i in 0 ..< len(game.board) {
	if is_valid_selection(game, id, i) {
	    return i, true
	}
    }
    return ---, false
}

next_valid_selection :: proc "contextless" (game: ^Game_State, id: Player_ID, delta: int) {
    s := game.selected_tile

    selection_wrap(game^, &s, delta)
    for !is_valid_selection(game^, id, s) {
	selection_wrap(game^, &s, delta)
    }

    game.selected_tile = s
}

@export
start :: proc "c" () {
    w4.PALETTE[0] = 0xE0D9BA
    w4.PALETTE[1] = 0x221100
    w4.PALETTE[2] = 0xFD4102
    w4.PALETTE[3] = 0x4B5A9B

    is_rosette_tab[4] = true
    is_rosette_tab[8] = true
    is_rosette_tab[14] = true

    reset_game(&global_game_state)
}

reset_game :: proc "contextless" (game: ^Game_State) {
    game^ = {}

    switch_state(game, .Menu)
    
    for player in &game.players {
	player.available_pieces = 7
	player.finished_pieces = 0
    }

    game.dice[0] = 4
    game.dice[1] = 0
    game.dice[2] = 1
    game.dice[3] = 5

    global_audio_engine = {}
    global_rng_state = {}
}

update_game :: proc "contextless" (game: ^Game_State) {
    game := game
    state := game.state
    active_player := game.active_player
    
    pad1 := w4.GAMEPAD1^
    pad2 := w4.GAMEPAD2^
        
    active_pad := active_player == .One ? pad1 : pad2
    pressed_this_frame := active_pad - game.pads_last_frame[int(active_player)]

    game.move_type = .No_Move

    switch state {
    case .Menu:
	if .A in pressed_this_frame {
	    switch_state(game, .Menu_Rolling)
	    pcg32_init(game.frame_count)
	}

	using assets
	
	// making the dice at the beginning dance

	tick_die :: proc "contextless" (die: ^int) {
	    die^ = (die^ + 1) % 6
	}

	tracks := [?][]Audio_Block {
	    Ur_Opening_Pulse1[:],
	    Ur_Opening_Pulse2[:],
	    Ur_Opening_Triangle[:],
	}
	song_is_playing := false
	for track, i in tracks {
	    index := global_audio_engine.block_indices[i]
	
	    if index < len(track) {
		song_is_playing = true
		block := track[index]
		tick := game.state_frame_count - menu_music_frame_start
		if tick == block.end_frame {
		    tick_die(&game.dice[i])
		    if i == 0 {
			tick_die(&game.dice[3])
		    }
		}
	    }
	}
	if !song_is_playing {
	    for die, i in &game.dice {
		die = (int(game.frame_count) / 60 + i) % 6
	    }
	}
	
    case .Menu_Rolling:
	if game.state_frame_count < frames_to_roll_for {
	    roll(game)
	} else {
	    switch_state(game, .Roll_Prompt)
	}
		
    case .Roll_Prompt:
	if .A in pressed_this_frame {
	    switch_state(game, .Rolling)
	}
	
    case .Rolling:
	if game.state_frame_count < frames_to_roll_for {
	    roll(game)
	}

	if game.state_frame_count >= total_rolling_frames {
	    game.selected_tile = 0
	    
	    switch_state(game, .Move_Prompt)
	    s, ok := find_valid_selection(game^, active_player)
	    if !ok {
		// TODO: tell the user there's no available moves??
		next_turn(game)
	    } else {
		game.selected_tile = s
	    }
	}

    case .Move_Prompt:
	if .UP in pressed_this_frame {
	    next_valid_selection(game, active_player, 1)
	}
	
	if .DOWN in pressed_this_frame {
	    next_valid_selection(game, active_player, -1)
	}
	
	if .A in pressed_this_frame {
	    game.move_type = .Normal
	    
	    player_id := active_player
	    player := &game.players[player_id]
	    enemy_id := other_player(player_id)
	    enemy := &game.players[enemy_id]
	    
	    game.player_that_moved = player_id
		
	    from := game.selected_tile
	    to := from + game.roll

	    from_tile := &game.board[from]
	    to_tile   := &game.board[to]
	    
	    from_tile^ -= {active_player}
	    if in_war_region(to) && enemy_id in to_tile^ {
		to_tile^ = nil
		enemy.available_pieces += 1
		game.move_type = .Kill
	    }
	    to_tile^ += {active_player}

	    game.board[board_length-1] = nil
	    
	    if from == 0 {
		player.available_pieces -= 1
	    }
	    if to == board_length-1 {
		game.move_type = .Finish_Line
		player.finished_pieces += 1
	    }

	    if player.finished_pieces == 7 {
		switch_state(game, .Done)
	    } else if is_rosette_tab[to] {
		game.move_type = .Rosette
		switch_state(game, .Roll_Prompt)
	    } else {
		next_turn(game)
	    }
	}
	
    case .Done:
	if .A in pressed_this_frame {
	    reset_game(game)
	}
    }
}

@export
update :: proc "c" () {
    game := &global_game_state
    
    update_game(game)
    do_sounds(game^)
    draw_game(game^)

    game.state_frame_count += 1
    game.frame_count += 1
    game.pads_last_frame[0] = w4.GAMEPAD1^
    game.pads_last_frame[1] = w4.GAMEPAD2^
    pcg32() // this makes it matter what frame you roll on
}


package wasm4_ur

import "w4"
import "assets"
import "math"

frames_to_roll_for :: 60
frames_to_pause_after_roll_for :: 20
total_rolling_frames :: frames_to_roll_for + frames_to_pause_after_roll_for

board_length :: 16

Player :: struct {
    available_pieces: int,
    finished_pieces: int,
}

Player_ID :: enum u8 {
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

End_Screen_Sprite :: struct #packed {
    x, y: i16,
    player: Player_ID,
    dx, dy: i16,
    angle: i16,
    angle_delta: i16,
    is_info: b8,
}

SCREEN_BIT_ARRAY :: w4.SCREEN_SIZE*w4.SCREEN_SIZE/8

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

    player_that_won: Player_ID,
    end_screen_sprites: [14]End_Screen_Sprite

    // 160*160 bit arrays
    end_screen_has_sprite: [SCREEN_BIT_ARRAY]byte,
    end_screen_player_id:  [SCREEN_BIT_ARRAY]byte,
    end_screen_is_info:    [SCREEN_BIT_ARRAY]byte,
}

get_bit :: proc "contextless" (arr: ^[SCREEN_BIT_ARRAY]byte, index: u32) -> bool {
    b := arr[index/8]
    b >>= index % 8
    return bool(b & 1)
}

set_bit :: proc "contextless" (arr: ^[SCREEN_BIT_ARRAY]byte, index: u32, n: bool) {
    n := u8(n)
    shift := index % 8
    b := &arr[index/8]
    b^ = (b^ & ~(1<<shift)) | (n << shift)
}

// NOTE: this is for testing the end screen only
fake_end_game :: proc "contextless" (using game: ^Game_State) {
    switch_state(game, .Done)
    players[0].available_pieces = 0
    players[0].finished_pieces = 7
    players[1].available_pieces = 1
    players[1].finished_pieces = 5
    board[len(board)/2] = {.Two}
    active_player = .One
    player_that_won = .One
}

is_rosette_tab: [board_length]bool

global_rng_state: u64
global_game_state: Game_State

get_end_screen_circle_deltas :: proc "contextless" (angle: i16) -> (f32, f32) {
    END_SCREEN_RADIUS :: 10
    using math
    
    return END_SCREEN_RADIUS*cos(angle), END_SCREEN_RADIUS*sin(angle)
}

switch_state :: proc "contextless" (game: ^Game_State, state: State) {
    game.state = state
    game.state_frame_count = -1 // because 1 is always added to it at the end of the update function

    if state == .Menu || state == .Done {
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

initialize_end_screen :: proc "contextless" (game: ^Game_State) {
    using game

    player_that_won = active_player
    
    init_end_screen_sprite :: proc "contextless" (sprite: ^End_Screen_Sprite,
						  x, y: i16, id: Player_ID, is_info: b8) {
	angle := pcg32() % 360
	x := x
	y := y
	
	using math

	if x < w4.SCREEN_SIZE/2 {
	    sprite.dx = 1
	} else {
	    sprite.dx = -1
	}

	if y < w4.SCREEN_SIZE/2 {
	    sprite.dy = 1
	} else {
	    sprite.dy = -1
	}
	
	dx, dy := get_end_screen_circle_deltas(i16((angle + 180) % 360))
	x += i16(dx)
	y += i16(dy)

	sprite.x = x
	sprite.y = y
	sprite.player = id
	sprite.angle = i16(angle)
	sprite.angle_delta = i16(pcg32() % 15 + 5)
	sprite.is_info = is_info
    }

    end_screen_sprite_index := 0
    
    ids := [2]Player_ID { active_player, other_player(active_player) }
    for id in ids {
	for tile, i in board {
	    if id in tile {
		sprite := &game.end_screen_sprites[end_screen_sprite_index]
		end_screen_sprite_index += 1
		
		x, y := get_tile_pos(game^, id, i)
		init_end_screen_sprite(sprite, i16(x), i16(y), id, false)
	    }
	}
	for pos in get_info_piece_positions(game^, id) {
	    sprite := &game.end_screen_sprites[end_screen_sprite_index]
	    end_screen_sprite_index += 1

	    init_end_screen_sprite(sprite, i16(pos.x), i16(pos.y), id, true)
	}
    }

    fisher_yattes_shuffle :: proc "contextless" (sprites: []End_Screen_Sprite) {
	n := len(sprites)
	for i := n-1; i >= 1; i -= 1 {
	    j := uint(pcg32()) % uint(i)
	    tmp := sprites[i]
	    sprites[i] = sprites[j]
	    sprites[j] = tmp
	}
    }

    fisher_yattes_shuffle(game.end_screen_sprites[1:])
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
        using assets
        
        // making the dice at the beginning dance

        tick_die :: proc "contextless" (die: ^int) {
            die^ = (die^ + 1) % 6
        }

        // it's dumb that i have to declare this but whatever
        tracks := [?][]Audio_Block {
            Ur_Opening2_Pulse1[:],
            Ur_Opening2_Pulse2[:],
            Ur_Opening2_Triangle[:],
            Ur_Opening2_Noise[:],
        }
        song_is_playing := false
        for track, i in tracks {
            index := global_audio_engine.block_indices[i]
            
            if index < len(track) {
                song_is_playing = true
                block := track[index]
                tick := game.state_frame_count - menu_music_frame_start
                tick %= get_song_tick_length(tracks[:])
                if tick == i64(block.start_frame) {
                    die_index_tab := [?]int{0, 3, 1, 2}
                    tick_die(&game.dice[die_index_tab[i]])
                }
            }
        }
        if !song_is_playing {
            for die, i in &game.dice {
                die = (int(game.frame_count) / 60 + i) % 6
            }
        }

	if .A in pressed_this_frame {
            switch_state(game, .Menu_Rolling)
            pcg32_init(game.frame_count)

	    //fake_end_game(game) // TODO: remove!!!
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
		game.player_that_won = game.active_player
            } else if is_rosette_tab[to] {
                game.move_type = .Rosette
                switch_state(game, .Roll_Prompt)
            } else {
                next_turn(game)
            }
        }
        
    case .Done:
	if game.state_frame_count == 0 {
	    initialize_end_screen(game)
	} else {
	    tick := game.state_frame_count - 1
	    moving_sprite_count := min(tick/60+1, len(game.end_screen_sprites))
	    moving_sprites := game.end_screen_sprites[:moving_sprite_count]
	    for sprite in &moving_sprites {
		dx, dy := get_end_screen_circle_deltas(sprite.angle)
		x := sprite.x + i16(dx)
		y := sprite.y + i16(dy)
		
		if x >= 0 && x < w4.SCREEN_SIZE && y >= 0 && y < w4.SCREEN_SIZE {
		    index := u32(x) + u32(y)*w4.SCREEN_SIZE
		    set_bit(&game.end_screen_has_sprite, index, true)
		    set_bit(&game.end_screen_is_info, index, bool(sprite.is_info))
		    set_bit(&game.end_screen_player_id, index, bool(sprite.player))
		}
		
		ANGLE_DELTA :: 1
		
		sprite.x += sprite.dx
		sprite.y += sprite.dy
		sprite.angle += sprite.angle_delta
		sprite.angle %= 360
	    }

	    if game.state_frame_count >= 120 && .A in pressed_this_frame {
		reset_game(game)
            }
	}
    }
}

@export
update :: proc "c" () {
    game := &global_game_state
    
    update_game(game)
    do_sounds(game^)
    draw_game(game)

    game.state_frame_count += 1
    game.frame_count += 1
    game.pads_last_frame[0] = w4.GAMEPAD1^
    game.pads_last_frame[1] = w4.GAMEPAD2^
    pcg32() // this makes it matter what frame you roll on
}

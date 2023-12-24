package wasm4_ur

import "core:mem"
import "core:runtime"

import "w4"
import "assets"
import "math"

frames_to_roll_for :: 60
frames_to_pause_after_roll_for :: 20
total_rolling_frames :: frames_to_roll_for + frames_to_pause_after_roll_for

board_length :: 16

TEST_END :: false

Player :: struct {
    available_pieces: u8,
    finished_pieces: u8,
}

Player_ID :: enum u8 {
    One = 0,
    Two = 1,
    None = 2, // really only for setting player_that_moved for sound fx center-pan
}

player_ids := [?]Player_ID { .One, .Two }

Player_Set :: bit_set[Player_ID]
Tile_Pieces :: distinct Player_Set
AIs :: distinct Player_Set

war_region_min :: 5
war_region_max :: 12
 
in_war_region :: proc(index: int) -> bool {
    return index >= war_region_min && index <= war_region_max
}

State :: enum {
    Menu = 1,
    Tutorial,
    Players_Ready_Up,
    Menu_Rolling,
    Roll_Prompt,
    Rolling,
    Move_Prompt,
    Done,
}

DICE_PERMUTATION_COUNT :: 6

SFX_Kind :: enum {
    No_Move = 0,
    Normal,
    Rosette,
    Kill,
    Finish_Line,
}

End_Screen_Sprite :: struct #packed {
    x, y: i16,
    player: Player_ID,
    dx, dy: i8,
    angle: i16,
    angle_delta: i16,
    is_info: b8,
}

SCREEN_BIT_ARRAY :: w4.SCREEN_SIZE*w4.SCREEN_SIZE/8

Menu_Selection :: enum {
    Start,
    Player_One_AI_Checkbox,
    Player_Two_AI_Checkbox,
    How_To_Play,
}

SFX :: struct {
    kind: SFX_Kind,
    pan: w4.Tone_Pan,
}

Game_State :: struct {
    state: State,

    frame_count: u64,
    state_frame_count: i64,

    pads_last_frame: [2]w4.Buttons,
    
    board: [board_length]Tile_Pieces, // one extra tile at beginning and end
    players: [2]Player,
    active_player: Player_ID,

    ais: AIs,
    
    dice: [4]int,
    roll: int,

    menu_selection: Menu_Selection,
    tutorial_screen: int,
    player_1_ready, player_2_ready: bool,
    
    selected_tile: int,
    
    sfx: SFX,

    player_that_won: Player_ID,
    end_screen_sprites: [14]End_Screen_Sprite,

    // 160*160 bit arrays
    end_screen_has_sprite: [SCREEN_BIT_ARRAY]byte,
    end_screen_player_id:  [SCREEN_BIT_ARRAY]byte,
    end_screen_is_info:    [SCREEN_BIT_ARRAY]byte,
}

toggle_ai :: proc(ais: ^AIs, id: Player_ID) {
    if id in ais^ do ais^ -= {id}
    else          do ais^ += {id}
}

get_bit :: proc(arr: ^[SCREEN_BIT_ARRAY]byte, index: u32) -> bool {
    b := arr[index/8]
    b >>= index % 8
    return bool(b & 1)
}

set_bit :: proc(arr: ^[SCREEN_BIT_ARRAY]byte, index: u32, n: bool) {
    n := u8(n)
    shift := index % 8
    b := &arr[index/8]
    b^ = (b^ & ~(1<<shift)) | (n << shift)
}

// NOTE: this is for testing the end screen only
fake_end_game :: proc(using game: ^Game_State) {
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

get_end_screen_circle_deltas :: proc(angle: i16) -> (f32, f32) {
    r :: 10
    return r*math.cos(angle), r*math.sin(angle)
}

switch_state :: proc(game: ^Game_State, state: State) {
    game.state = state
    game.state_frame_count = -1 // because 1 is always added to it at the end of the update function

    if state == .Menu || state == .Done {
        global_audio_engine = {}
    }
}

other_player :: proc(id: Player_ID) -> Player_ID {
    return Player_ID(!bool(id))
}

next_turn :: proc(game: ^Game_State) {
    game.active_player = other_player(game.active_player)
    switch_state(game, .Roll_Prompt)
}

pcg32_increment :: 1442695040888963407

pcg32 :: proc() -> u32 {
    // https://en.wikipedia.org/wiki/Permuted_congruential_generator
    rotr32 :: proc(x: u32, r: u64) -> u32 {
        return x >> r | x << (-r & 31)
    }

    x := global_rng_state
    count := x >> 59
    global_rng_state = x * 6364136223846793005 + pcg32_increment
    x ~= (x >> 18)
    return rotr32(u32(x >> 27), count)
}

pcg32_init :: proc(seed: u64) {
    global_rng_state = seed + pcg32_increment
}

roll :: proc(game: ^Game_State) {
    sum := 0
    for die in &game.dice {
        n := pcg32() % DICE_PERMUTATION_COUNT
        die = int(n)
        sum += int(n < DICE_PERMUTATION_COUNT/2)
    }
    game.roll = sum
}

has_player_piece :: proc(game: Game_State, id: Player_ID, index: int) -> bool {
    if index == 0 {
        return game.players[id].available_pieces > 0
    }
    tile := game.board[index]
    return id in tile
}

is_valid_selection :: proc(game: Game_State, id: Player_ID, s: int) -> bool {
    if !has_player_piece(game, id, s) {
        return false
    }
    
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

selection_wrap :: proc(game: Game_State, s: ^int, delta: int) {
    mod := len(game.board)
    s^ += delta
    s^ += (1 - s^ / mod) * mod
    s^ %= mod
}

find_valid_selection :: proc(game: Game_State, id: Player_ID) -> (int, bool) {
    for i in 0 ..< len(game.board) {
        if is_valid_selection(game, id, i) {
            return i, true
        }
    }
    return 0, false
}

next_valid_selection :: proc(game: ^Game_State, id: Player_ID, delta: int) {
    s := game.selected_tile

    selection_wrap(game^, &s, delta)
    for !is_valid_selection(game^, id, s) {
        selection_wrap(game^, &s, delta)
    }

    game.selected_tile = s
}

@export
start :: proc "c" () {
    context = {}
    
    w4.PALETTE[0] = 0xE0D9BA
    w4.PALETTE[1] = 0x221100
    w4.PALETTE[2] = 0xFD4102
    w4.PALETTE[3] = 0x4B5A9B

    is_rosette_tab[4] = true
    is_rosette_tab[8] = true
    is_rosette_tab[14] = true

    reset_game(&global_game_state)
}

reset_game :: proc(game: ^Game_State) {
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

initialize_end_screen :: proc(using game: ^Game_State) {
    player_that_won = active_player
    
    init_end_screen_sprite :: proc(sprite: ^End_Screen_Sprite,
				   x, y: i16, id: Player_ID, is_info: b8)
    {
	angle := pcg32() % 360
	x := x
	y := y
	
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

    fisher_yattes_shuffle :: proc(sprites: []End_Screen_Sprite) {
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

update_game :: proc(game: ^Game_State) {
    state := game.state
    active_player := game.active_player
    
    is_ai_turn := active_player in game.ais
    
    pad1 := w4.GAMEPAD1^
    pad2 := w4.GAMEPAD2^

    pad1_pressed_this_frame :=  pad1 - game.pads_last_frame[0]
    pad2_pressed_this_frame :=  pad2 - game.pads_last_frame[1]

    pressed_this_frame := active_player == .One ? pad1_pressed_this_frame : pad2_pressed_this_frame
    if game.state < .Roll_Prompt || game.state == .Done {
        pressed_this_frame = pad1_pressed_this_frame + pad2_pressed_this_frame
    } else {
        if is_ai_turn {
            pressed_this_frame = {}
        } else if card(game.ais) == 1 {
            // correcting for player one playing as player 2
            pressed_this_frame = pad1_pressed_this_frame
        }
    }

    game.sfx =  {}
    
    player_id := active_player
    player := &game.players[player_id]
    enemy_id := other_player(player_id)
    enemy := &game.players[enemy_id]
    
    switch state {
        case .Menu:
            pressed_this_frame = pad1_pressed_this_frame // only player one can use the menu
            
            // making the dice at the beginning dance
            {
                tick_die :: proc(die: ^int) {
                    die^ = (die^ + 1) % 6
                }

                // it's dumb that i have to declare this but whatever
                tracks := [?][]assets.Audio_Block {
                    assets.Ur_Opening2_Pulse1[:],
                    assets.Ur_Opening2_Pulse2[:],
                    assets.Ur_Opening2_Triangle[:],
                    assets.Ur_Opening2_Noise[:],
                }
                song_is_playing := false
                for track, i in tracks {
                    index := global_audio_engine.block_indices[i]
                    
                    if index < len(track) {
                        song_is_playing = true
                        block := track[index]
                        tick := game.state_frame_count - menu_music_frame_start
                        tick %= assets.get_song_tick_length(tracks[:])
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
            }

            prev_selection := game.menu_selection
            game.menu_selection += Menu_Selection(.DOWN in pressed_this_frame)
            game.menu_selection -= Menu_Selection(.UP in pressed_this_frame)
            game.menu_selection = clamp(game.menu_selection, min(Menu_Selection), max(Menu_Selection))
            if prev_selection != game.menu_selection {
                game.sfx = {.Normal, .Center}
            }

	    if .A in pressed_this_frame do switch game.menu_selection {
                case .Player_One_AI_Checkbox: {
                    toggle_ai(&game.ais, .One)
                    game.sfx = {.Rosette, .Center}
                }
                
                case .Player_Two_AI_Checkbox: {
                    toggle_ai(&game.ais, .Two)
                    game.sfx = {.Rosette, .Center}
                }

                case .Start:
                    if card(game.ais) > 0 {
                        switch_state(game, .Menu_Rolling)
                        pcg32_init(game.frame_count)
                    } else {
                        switch_state(game, .Players_Ready_Up)
                        game.sfx = {.Rosette, .Center}
                    }
                    when TEST_END {
                        fake_end_game(game)
                    }

                case .How_To_Play:
                    game.tutorial_screen = 0
                    switch_state(game, .Tutorial)
                    game.sfx = {.Rosette, .Center}
            }

        case .Tutorial:
            if .A in pressed_this_frame {
                game.tutorial_screen += 1
                if game.tutorial_screen >= TUTORIAL_SCREEN_COUNT {
                    switch_state(game, .Menu)
                    game.sfx = {.Rosette, .Center}
                } else {
                    game.sfx = {.Normal, .Center}
                }
            }
            if .B in pressed_this_frame {
                game.tutorial_screen -= 1
                if game.tutorial_screen < 0 {
                    switch_state(game, .Menu)
                }
                game.sfx = {.Kill, .Center}
            }
            
        case .Players_Ready_Up:
            do_a_press :: proc(game: ^Game_State, ready: ^bool) {
                ready^ = !ready^
                if ready^ {
                    game.sfx.kind = .Rosette
                } else {
                    game.sfx.kind = .Kill
                }
            }
            if .A in pad1_pressed_this_frame {
                do_a_press(game, &game.player_1_ready)
                game.sfx.pan = .Left
            }
            if .A in pad2_pressed_this_frame {
                do_a_press(game, &game.player_2_ready)
                game.sfx.pan = .Right
            }
            if .B in pressed_this_frame {
                game.player_1_ready = false
                game.player_2_ready = false
                switch_state(game, .Menu)
                game.sfx = {.Kill, .Center}
            }
            if game.player_1_ready && game.player_2_ready {
                switch_state(game, .Menu_Rolling)
                pcg32_init(game.frame_count)
            }
            
        case .Menu_Rolling:
            if game.state_frame_count < frames_to_roll_for {
                roll(game)
            } else {
                switch_state(game, .Roll_Prompt)
            }
            
        case .Roll_Prompt:
            if .A in pressed_this_frame || is_ai_turn {
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
                if ok {
                    game.selected_tile = s
                } else {
                    next_turn(game)
                }
            }

        case .Move_Prompt:
            if is_ai_turn { // here is the AI
                Heuristic :: proc(game: Game_State, selection: int) -> bool
                heuristics := [?]Heuristic {
                    proc(game: Game_State, to: int) -> bool { return is_rosette_tab[to] },
                    proc(game: Game_State, to: int) -> bool { return in_war_region(to) && other_player(game.active_player) in game.board[to] },
                    proc(game: Game_State, to: int) -> bool { return !in_war_region(to) },
                }

                selection: Maybe(int)
                heuristic_loop: for heuristic in heuristics {
                    for i := len(game.board)-1; i >= 0; i -= 1 {
                        if !is_valid_selection(game^, active_player, i) do continue
                        if heuristic(game^, i + game.roll) {
                            selection = i
                            break heuristic_loop
                        }
                    }
                }

                if selection != nil {
                    game.selected_tile, _ = selection.(int)
                } else {
                    for _ in 0 ..< pcg32() % 10 {
                        next_valid_selection(game, active_player, 1)
                    }
                }
            }

            if .UP in pressed_this_frame {
                next_valid_selection(game, active_player, 1)
            }
            
            if .DOWN in pressed_this_frame {
                next_valid_selection(game, active_player, -1)
            }
             
            if .A in pressed_this_frame || is_ai_turn {
                game.sfx = {.Normal, player_id == .One ? .Left : .Right}
                                
                from := game.selected_tile
                to := from + game.roll

                from_tile := &game.board[from]
                to_tile   := &game.board[to]

                from_tile^ -= {active_player}

                // kill enemy
                if in_war_region(to) && enemy_id in to_tile^ {
                    to_tile^ = nil
                    enemy.available_pieces += 1
                    game.sfx.kind = .Kill
                }
                
                to_tile^ += {active_player}

                // force invisible ending space empty
                game.board[board_length-1] = nil

                // adjust player piece counts
                if from == 0 {
                    player.available_pieces -= 1
                }
                if to == board_length-1 {
                    game.sfx.kind = .Finish_Line
                    player.finished_pieces += 1
                }

                // end turn
                if player.finished_pieces == 7 {
                    switch_state(game, .Done)
		    game.player_that_won = game.active_player
                } else if is_rosette_tab[to] {
                    game.sfx.kind = .Rosette
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
		    
		    sprite.x += i16(sprite.dx)
		    sprite.y += i16(sprite.dy)
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
    context = runtime.default_context()
    
    temp_memory: [4096]byte
    arena: mem.Arena
    mem.arena_init(&arena, temp_memory[:])
    
    context.allocator = mem.arena_allocator(&arena)
    
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


package wasm4_ur

import "w4"
import "assets"

global_audio_engine: struct {
    block_indices: [3]int,
}

menu_music_frame_start :: 30

maybe_do_roll_sound :: proc "contextless" (state_frame_count: i64, id: Player_ID, center := false) {
    if state_frame_count < frames_to_roll_for {
	pan: w4.Tone_Pan
	if center {
	    pan = .Center
	} else {
	    pan = id == .One ? .Left : .Right
	}
	frequency := u32(pcg32() % 3 + 4)*10
	w4.tone(frequency, 1, 50, .Pulse1, .Eigth, pan)
    }
}

do_sounds :: proc "contextless" (game: Game_State) {
    using assets

    pad1 := w4.GAMEPAD1^
    pad2 := w4.GAMEPAD2^

    active_player := game.active_player
    
    active_pad := active_player == .One ? pad1 : pad2
    pressed_this_frame := active_pad - game.pads_last_frame[int(active_player)]

    switch game.state {
    case .Menu:
	indices := cast([^]int)(&global_audio_engine.block_indices)
	tick := game.state_frame_count - menu_music_frame_start
	play_Ur_Opening(indices, tick)

    case .Roll_Prompt: // do nothing
	
    case .Menu_Rolling:
	maybe_do_roll_sound(game.state_frame_count, active_player, true)
	
    case .Rolling:
	maybe_do_roll_sound(game.state_frame_count, active_player)
	
    case .Move_Prompt:
    case .Done:
    }

    
    if game.move_type != .No_Move {
	start_frequency: u16
	end_frequency: u16

	switch game.move_type {
	case .No_Move: // <-- this should never happen
	    
	case .Normal:
	    start_frequency = 120
	    end_frequency = 0
	    
	case .Rosette:
	    start_frequency = 120
	    end_frequency = 340

	case .Kill:
	    start_frequency = 340
	    end_frequency = 60

	case .Finish_Line:
	    start_frequency = 340
	    end_frequency = 340*2
	}

	duration := w4.Tone_Duration { sustain = 4 }
	
	volume_percent :: 50
	channel :: w4.Tone_Channel.Pulse1
	duty_cycle :: w4.Tone_Duty_Cycle.Eigth

	pan := game.player_that_moved == .One ? w4.Tone_Pan.Left : w4.Tone_Pan.Right
	
	w4.tone_complex(start_frequency, end_frequency,
			duration, volume_percent, channel, duty_cycle, pan)
    }
}

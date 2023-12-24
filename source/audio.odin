
package wasm4_ur

import "w4"
import "assets"

global_audio_engine: struct {
    block_indices: [4]int,
}

menu_music_frame_start :: 30

maybe_do_roll_sound :: proc(state_frame_count: i64, id: Player_ID, center := false) {
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

do_sounds :: proc(game: Game_State) {
    active_player := game.active_player

    switch game.state {
        case .Menu:
	    indices := global_audio_engine.block_indices[:]
	    params := [4]assets.Audio_Params{}
	    tick := game.state_frame_count - menu_music_frame_start

	    assets.play_Ur_Opening2(indices, params[:], tick, true)

        case .Tutorial:

        case .Players_Ready_Up: // maybe a cool sound when a player ready's up?

        case .Roll_Prompt: // do nothing

        case .Menu_Rolling:
	    maybe_do_roll_sound(game.state_frame_count, active_player, true)

        case .Rolling:
	    maybe_do_roll_sound(game.state_frame_count, active_player)

        case .Move_Prompt:
        case .Done:
	    indices := global_audio_engine.block_indices[:]
	    params := [4]assets.Audio_Params{}
	    assets.play_Ur_Ending(indices, params[:], game.state_frame_count, false)
    }

    if game.sfx.kind != .No_Move {
	start_frequency: u16
	end_frequency: u16

	switch game.sfx.kind {
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

	w4.tone_complex(start_frequency, end_frequency,
			duration, volume_percent, channel, duty_cycle, game.sfx.pan)
    }
}

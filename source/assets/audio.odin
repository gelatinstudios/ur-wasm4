
package assets

import "../w4"

Audio_Block :: struct {
    frequency: u32,
    start_frame, end_frame: i64,
}

play_track :: proc "contextless" (tracks: [][]Audio_Block, indices: [^]int, tick: i64,
					  duty_cycle := w4.Tone_Duty_Cycle.Eigth,
					  duration := w4.Tone_Duration{},
					  pan := w4.Tone_Pan.Center) {
    for track, i in tracks {
        index := &indices[i]

        if index^ < len(track) {
            current_block := track[index^]
            
            if tick >= current_block.end_frame {
                index^ += 1
                if index^ < len(track) {
                    current_block = track[index^]
                }
            }
            
            if tick == current_block.start_frame {
                using current_block
                duration := u32(end_frame - start_frame + 1)
                w4.tone(frequency, duration, 50, w4.Tone_Channel(i), duty_cycle, pan)
                w4.tracef("playing frequency %d on channel %d for %d frames\n", frequency, i, duration)
            }
        }
    }
}

Ur_Opening_Pulse1 := [?]Audio_Block {
    { 440, 0, 40 },
    { 494, 43, 63 },
    { 523, 64, 84 },
    { 587, 85, 126 },
    { 587, 128, 135 },
    { 523, 135, 142 },
    { 494, 142, 149 },
    { 440, 149, 156 },
    { 392, 156, 163 },
    { 349, 163, 170 },
    { 440, 170, 227 },
    { 494, 230, 264 },
    { 523, 266, 309 },
    { 587, 311, 482 },
}
Ur_Opening_Pulse2 := [?]Audio_Block {
    { 330, 0, 40 },
    { 294, 43, 63 },
    { 330, 64, 84 },
    { 370, 85, 126 },
    { 440, 128, 135 },
    { 392, 135, 142 },
    { 370, 142, 149 },
    { 330, 149, 156 },
    { 294, 156, 163 },
    { 262, 163, 170 },
    { 330, 170, 174 },
    { 349, 174, 177 },
    { 392, 178, 181 },
    { 415, 181, 185 },
    { 466, 185, 189 },
    { 494, 189, 192 },
    { 554, 193, 196 },
    { 587, 196, 200 },
    { 659, 200, 204 },
    { 698, 204, 207 },
    { 784, 208, 211 },
    { 831, 211, 215 },
    { 932, 215, 219 },
    { 988, 219, 222 },
    { 1109, 223, 226 },
    { 1175, 226, 230 },
    { 415, 230, 241 },
    { 440, 242, 253 },
    { 415, 254, 265 },
    { 370, 266, 280 },
    { 415, 281, 295 },
    { 370, 296, 310 },
    { 330, 311, 345 },
    { 349, 347, 381 },
    { 330, 383, 482 },
}
Ur_Opening_Triangle := [?]Audio_Block {
    { 110, 0, 20 },
    { 220, 21, 42 },
    { 165, 43, 63 },
    { 131, 64, 84 },
    { 123, 85, 105 },
    { 41, 107, 127 },
    { 73, 128, 135 },
    { 98, 135, 142 },
    { 92, 142, 149 },
    { 131, 149, 156 },
    { 123, 156, 163 },
    { 104, 163, 170 },
    { 82, 170, 198 },
    { 123, 200, 229 },
    { 175, 230, 264 },
    { 156, 266, 309 },
    { 110, 311, 397 },
    { 55, 401, 482 },
}
play_Ur_Opening :: proc "contextless" (indices: [^]int, tick: i64) {
    tracks := [][]Audio_Block {
        Ur_Opening_Pulse1[:],
        Ur_Opening_Pulse2[:],
        Ur_Opening_Triangle[:],
    }
    play_track(tracks, indices, tick)
}

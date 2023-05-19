
package wasm4_ur_rng_test

import "core:math/rand"
import "core:fmt"
import "core:slice"

pcg32_increment :: 1442695040888963407

pcg32 :: proc "contextless" (is_for_roll := false) -> u32 {
    // https://en.wikipedia.org/wiki/Permuted_congruential_generator
    rotr32 :: proc "contextless" (x: u32, r: u64) -> u32 {
        return x >> r | x << (-r & 31)
    }

    index := int(is_for_roll)
    
    x := global_rng_state
    count := x >> 59
    global_rng_state = x * 6364136223846793005 + pcg32_increment
    x ~= (x >> 18)
    return rotr32(u32(x >> 27), count)
}

global_rng_state: u64

pcg32_init :: proc "contextless" (seed: u64) {
    global_rng_state = seed + pcg32_increment
}

// avoid modulo bias https://stackoverflow.com/questions/10984974/why-do-people-say-there-is-modulo-bias-when-using-a-random-number-generator
pcg32_mod :: proc "contextless" (n: u32, is_for_rolling := false) -> u32 {
    x: u32
//    for {
	x = pcg32(is_for_rolling)
//	if x < (max(u32) - max(u32) % n) do break
//    }
    return x % n
}

main :: proc () {
    pcg32_init(1234);

    DICE_PERMUTATIONS :: 6

    players: [2][5]int
    total:   [5]int
    
    n :: 10000000
    for i in 0 ..< n {
	for _ in 0 ..< rand.int_max(3) {
	    sum := 0
	    for _ in 0..<4{
		sum += int(pcg32_mod(DICE_PERMUTATIONS) < (DICE_PERMUTATIONS)/2)

		// throwaway random number
		for _ in 0..<rand.int_max(500) do  pcg32()
	    }
	    players[i%2][sum] += 1
	    total[sum] += 1
	}
    }

    stats :: proc (name: string, counts: [5]int) {
	fmt.println(name)
	fmt.println("~~~~~~~~~~~~~")

	sum := 0
	for count in counts do sum += count

	for count, i in counts {
	    p := f64(count) / f64(sum)
	    fmt.printf("{}: {}\n", i, p)
	}
    }

    stats("player 1", players[0])
    stats("player 2", players[1])
    stats("total", total)
}

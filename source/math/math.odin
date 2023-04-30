
package ur_math

cos :: proc "contextless" (x: i16) -> f32 {

    cos_tab := [?]f32 {
	1.000000,
	0.999848,
	0.999391,
	0.998630,
	0.997564,
	0.996195,
	0.994522,
	0.992546,
	0.990268,
	0.987688,
	0.984808,
	0.981627,
	0.978148,
	0.974370,
	0.970296,
	0.965926,
	0.961262,
	0.956305,
	0.951056,
	0.945519,
	0.939693,
	0.933580,
	0.927184,
	0.920505,
	0.913545,
	0.906308,
	0.898794,
	0.891006,
	0.882947,
	0.874620,
	0.866025,
	0.857167,
	0.848048,
	0.838670,
	0.829037,
	0.819152,
	0.809017,
	0.798635,
	0.788011,
	0.777146,
	0.766044,
	0.754709,
	0.743145,
	0.731353,
	0.719340,
	0.707107,
	0.694658,
	0.681998,
	0.669130,
	0.656059,
	0.642787,
	0.629320,
	0.615661,
	0.601815,
	0.587785,
	0.573576,
	0.559193,
	0.544639,
	0.529919,
	0.515038,
	0.500000,
	0.484809,
	0.469471,
	0.453990,
	0.438371,
	0.422618,
	0.406736,
	0.390731,
	0.374606,
	0.358367,
	0.342020,
	0.325568,
	0.309016,
	0.292371,
	0.275637,
	0.258819,
	0.241921,
	0.224950,
	0.207911,
	0.190808,
	0.173648,
	0.156434,
	0.139172,
	0.121869,
	0.104528,
	0.087155,
	0.069756,
	0.052335,
	0.034899,
	0.017452,
	-0.000001,
	-0.017453,
	-0.034900,
	-0.052337,
	-0.069757,
	-0.087156,
	-0.104529,
	-0.121870,
	-0.139174,
	-0.156435,
	-0.173649,
	-0.190810,
	-0.207912,
	-0.224952,
	-0.241923,
	-0.258820,
	-0.275638,
	-0.292372,
	-0.309018,
	-0.325569,
	-0.342021,
	-0.358369,
	-0.374607,
	-0.390732,
	-0.406737,
	-0.422619,
	-0.438372,
	-0.453991,
	-0.469472,
	-0.484810,
	-0.500001,
	-0.515039,
	-0.529920,
	-0.544640,
	-0.559194,
	-0.573577,
	-0.587786,
	-0.601816,
	-0.615662,
	-0.629321,
	-0.642788,
	-0.656060,
	-0.669131,
	-0.681999,
	-0.694659,
	-0.707107,
	-0.719341,
	-0.731354,
	-0.743146,
	-0.754710,
	-0.766045,
	-0.777147,
	-0.788011,
	-0.798636,
	-0.809018,
	-0.819153,
	-0.829038,
	-0.838671,
	-0.848049,
	-0.857168,
	-0.866026,
	-0.874620,
	-0.882948,
	-0.891007,
	-0.898795,
	-0.906308,
	-0.913546,
	-0.920505,
	-0.927184,
	-0.933581,
	-0.939693,
	-0.945519,
	-0.951057,
	-0.956305,
	-0.961262,
	-0.965926,
	-0.970296,
	-0.974370,
	-0.978148,
	-0.981627,
	-0.984808,
	-0.987689,
	-0.990268,
	-0.992546,
	-0.994522,
	-0.996195,
	-0.997564,
	-0.998630,
	-0.999391,
	-0.999848,
	-1.000000,
	-0.999848,
	-0.999391,
	-0.998629,
	-0.997564,
	-0.996195,
	-0.994522,
	-0.992546,
	-0.990268,
	-0.987688,
	-0.984808,
	-0.981627,
	-0.978147,
	-0.974370,
	-0.970295,
	-0.965925,
	-0.961261,
	-0.956304,
	-0.951056,
	-0.945518,
	-0.939692,
	-0.933580,
	-0.927183,
	-0.920504,
	-0.913545,
	-0.906307,
	-0.898793,
	-0.891006,
	-0.882947,
	-0.874619,
	-0.866025,
	-0.857166,
	-0.848047,
	-0.838670,
	-0.829037,
	-0.819151,
	-0.809016,
	-0.798635,
	-0.788010,
	-0.777145,
	-0.766043,
	-0.754708,
	-0.743144,
	-0.731353,
	-0.719339,
	-0.707106,
	-0.694657,
	-0.681997,
	-0.669129,
	-0.656058,
	-0.642786,
	-0.629319,
	-0.615660,
	-0.601814,
	-0.587784,
	-0.573575,
	-0.559191,
	-0.544638,
	-0.529918,
	-0.515037,
	-0.499998,
	-0.484808,
	-0.469470,
	-0.453989,
	-0.438370,
	-0.422617,
	-0.406735,
	-0.390729,
	-0.374605,
	-0.358366,
	-0.342018,
	-0.325566,
	-0.309015,
	-0.292370,
	-0.275636,
	-0.258817,
	-0.241920,
	-0.224949,
	-0.207910,
	-0.190807,
	-0.173646,
	-0.156433,
	-0.139171,
	-0.121867,
	-0.104526,
	-0.087154,
	-0.069754,
	-0.052334,
	-0.034897,
	-0.017450,
	0.000002,
	0.017454,
	0.034902,
	0.052338,
	0.069759,
	0.087158,
	0.104531,
	0.121871,
	0.139175,
	0.156437,
	0.173650,
	0.190811,
	0.207914,
	0.224953,
	0.241924,
	0.258821,
	0.275639,
	0.292374,
	0.309019,
	0.325570,
	0.342022,
	0.358370,
	0.374609,
	0.390733,
	0.406739,
	0.422620,
	0.438373,
	0.453992,
	0.469474,
	0.484812,
	0.500002,
	0.515040,
	0.529921,
	0.544641,
	0.559195,
	0.573578,
	0.587787,
	0.601817,
	0.615663,
	0.629322,
	0.642789,
	0.656061,
	0.669132,
	0.682000,
	0.694660,
	0.707108,
	0.719341,
	0.731355,
	0.743146,
	0.754711,
	0.766046,
	0.777147,
	0.788012,
	0.798637,
	0.809018,
	0.819153,
	0.829039,
	0.838672,
	0.848049,
	0.857169,
	0.866027,
	0.874621,
	0.882949,
	0.891008,
	0.898795,
	0.906309,
	0.913546,
	0.920506,
	0.927185,
	0.933581,
	0.939693,
	0.945519,
	0.951057,
	0.956306,
	0.961262,
	0.965926,
	0.970296,
	0.974371,
	0.978148,
	0.981628,
	0.984808,
	0.987689,
	0.990268,
	0.992546,
	0.994522,
	0.996195,
	0.997564,
	0.998630,
	0.999391,
	0.999848,
    }

    return cos_tab[x]
}

sin :: proc "contextless" (x: i16) -> f32 {
    sin_tab := [?]f32 {
	0.000000,
	0.017452,
	0.034900,
	0.052336,
	0.069757,
	0.087156,
	0.104529,
	0.121869,
	0.139173,
	0.156435,
	0.173648,
	0.190809,
	0.207912,
	0.224951,
	0.241922,
	0.258819,
	0.275637,
	0.292372,
	0.309017,
	0.325568,
	0.342020,
	0.358368,
	0.374607,
	0.390731,
	0.406737,
	0.422618,
	0.438371,
	0.453991,
	0.469472,
	0.484810,
	0.500000,
	0.515038,
	0.529919,
	0.544639,
	0.559193,
	0.573577,
	0.587785,
	0.601815,
	0.615662,
	0.629321,
	0.642788,
	0.656059,
	0.669131,
	0.681999,
	0.694659,
	0.707107,
	0.719340,
	0.731354,
	0.743145,
	0.754710,
	0.766045,
	0.777146,
	0.788011,
	0.798636,
	0.809017,
	0.819152,
	0.829038,
	0.838671,
	0.848048,
	0.857168,
	0.866026,
	0.874620,
	0.882948,
	0.891007,
	0.898794,
	0.906308,
	0.913546,
	0.920505,
	0.927184,
	0.933581,
	0.939693,
	0.945519,
	0.951057,
	0.956305,
	0.961262,
	0.965926,
	0.970296,
	0.974370,
	0.978148,
	0.981627,
	0.984808,
	0.987688,
	0.990268,
	0.992546,
	0.994522,
	0.996195,
	0.997564,
	0.998630,
	0.999391,
	0.999848,
	1.000000,
	0.999848,
	0.999391,
	0.998629,
	0.997564,
	0.996195,
	0.994522,
	0.992546,
	0.990268,
	0.987688,
	0.984808,
	0.981627,
	0.978147,
	0.974370,
	0.970296,
	0.965926,
	0.961261,
	0.956305,
	0.951056,
	0.945518,
	0.939692,
	0.933580,
	0.927184,
	0.920505,
	0.913545,
	0.906307,
	0.898794,
	0.891006,
	0.882947,
	0.874619,
	0.866025,
	0.857167,
	0.848048,
	0.838670,
	0.829037,
	0.819152,
	0.809016,
	0.798635,
	0.788010,
	0.777145,
	0.766044,
	0.754709,
	0.743144,
	0.731353,
	0.719339,
	0.707106,
	0.694658,
	0.681998,
	0.669130,
	0.656058,
	0.642787,
	0.629320,
	0.615661,
	0.601814,
	0.587784,
	0.573576,
	0.559192,
	0.544638,
	0.529918,
	0.515037,
	0.499999,
	0.484809,
	0.469471,
	0.453989,
	0.438370,
	0.422617,
	0.406736,
	0.390730,
	0.374605,
	0.358367,
	0.342019,
	0.325567,
	0.309016,
	0.292371,
	0.275636,
	0.258818,
	0.241921,
	0.224950,
	0.207910,
	0.190808,
	0.173647,
	0.156433,
	0.139172,
	0.121868,
	0.104527,
	0.087154,
	0.069755,
	0.052335,
	0.034898,
	0.017451,
	-0.000001,
	-0.017454,
	-0.034901,
	-0.052337,
	-0.069758,
	-0.087157,
	-0.104530,
	-0.121871,
	-0.139174,
	-0.156436,
	-0.173650,
	-0.190810,
	-0.207913,
	-0.224952,
	-0.241923,
	-0.258820,
	-0.275639,
	-0.292373,
	-0.309018,
	-0.325570,
	-0.342022,
	-0.358369,
	-0.374608,
	-0.390733,
	-0.406738,
	-0.422620,
	-0.438373,
	-0.453992,
	-0.469473,
	-0.484811,
	-0.500001,
	-0.515039,
	-0.529921,
	-0.544640,
	-0.559194,
	-0.573578,
	-0.587787,
	-0.601816,
	-0.615663,
	-0.629322,
	-0.642789,
	-0.656060,
	-0.669132,
	-0.682000,
	-0.694660,
	-0.707108,
	-0.719341,
	-0.731355,
	-0.743146,
	-0.754711,
	-0.766046,
	-0.777147,
	-0.788012,
	-0.798637,
	-0.809018,
	-0.819153,
	-0.829039,
	-0.838672,
	-0.848049,
	-0.857168,
	-0.866026,
	-0.874621,
	-0.882948,
	-0.891007,
	-0.898795,
	-0.906309,
	-0.913546,
	-0.920506,
	-0.927185,
	-0.933581,
	-0.939693,
	-0.945519,
	-0.951057,
	-0.956305,
	-0.961262,
	-0.965926,
	-0.970296,
	-0.974370,
	-0.978148,
	-0.981628,
	-0.984808,
	-0.987689,
	-0.990268,
	-0.992546,
	-0.994522,
	-0.996195,
	-0.997564,
	-0.998630,
	-0.999391,
	-0.999848,
	-1.000000,
	-0.999848,
	-0.999391,
	-0.998629,
	-0.997564,
	-0.996195,
	-0.994522,
	-0.992546,
	-0.990268,
	-0.987688,
	-0.984807,
	-0.981627,
	-0.978147,
	-0.974370,
	-0.970295,
	-0.965925,
	-0.961261,
	-0.956304,
	-0.951056,
	-0.945518,
	-0.939692,
	-0.933580,
	-0.927183,
	-0.920504,
	-0.913545,
	-0.906307,
	-0.898793,
	-0.891006,
	-0.882947,
	-0.874619,
	-0.866024,
	-0.857166,
	-0.848047,
	-0.838669,
	-0.829036,
	-0.819151,
	-0.809016,
	-0.798634,
	-0.788009,
	-0.777145,
	-0.766043,
	-0.754708,
	-0.743143,
	-0.731352,
	-0.719338,
	-0.707105,
	-0.694657,
	-0.681997,
	-0.669129,
	-0.656057,
	-0.642786,
	-0.629319,
	-0.615660,
	-0.601813,
	-0.587783,
	-0.573574,
	-0.559191,
	-0.544637,
	-0.529917,
	-0.515036,
	-0.499998,
	-0.484807,
	-0.469469,
	-0.453988,
	-0.438369,
	-0.422616,
	-0.406734,
	-0.390729,
	-0.374604,
	-0.358366,
	-0.342018,
	-0.325566,
	-0.309015,
	-0.292369,
	-0.275635,
	-0.258817,
	-0.241919,
	-0.224949,
	-0.207909,
	-0.190806,
	-0.173646,
	-0.156432,
	-0.139170,
	-0.121867,
	-0.104526,
	-0.087153,
	-0.069754,
	-0.052333,
	-0.034897,
	-0.017450,
    }

    return sin_tab[x]
}

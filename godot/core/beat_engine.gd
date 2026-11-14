class_name BeatEngine
## Patterns des boîtes à rythmes : batterie 16 pas (5 instruments) + ligne de 808 sur 16 pas.
## Pattern de batterie : Array[5] de PackedInt32Array(16) ; valeur = 0 (silence) ou 1–4 (1 coup, ou
## roulement de 2, 3 ou 4 coups dans le pas — utile pour les hi-hats).
## Ligne de 808 : PackedInt32Array(16) ; -1 = rien, sinon intervalle en demi-tons au-dessus de la
## fondamentale de l'accord en cours (0–12).

const INSTR := ["KICK", "CLAP", "HAT", "OPEN", "PERC"]
const GM := [36, 39, 42, 46, 37]          # notes General MIDI (canal 10)
const STYLE_BPM := {"RAP": 90, "TRAP": 140, "R&B": 84, "SOUL": 96, "DRILL": 142, "AFRO": 104}
const STYLE_SWING := {"RAP": .58, "TRAP": .5, "R&B": .54, "SOUL": .6, "DRILL": .5, "AFRO": .55}

## Bases par style : pas (1–16) actifs pour chaque instrument.
const BASE := {
	"RAP": {"KICK": [1, 8, 11], "CLAP": [5, 13], "HAT": [1, 3, 5, 7, 9, 11, 13, 15], "OPEN": [], "PERC": []},
	"TRAP": {"KICK": [1, 11], "CLAP": [9], "HAT": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16], "OPEN": [], "PERC": []},
	"R&B": {"KICK": [1, 7, 11], "CLAP": [5, 13], "HAT": [1, 3, 5, 7, 9, 11, 12, 13, 15], "OPEN": [], "PERC": [8, 16]},
	"SOUL": {"KICK": [1, 4, 9, 11], "CLAP": [5, 13], "HAT": [1, 3, 5, 7, 9, 11, 13, 15], "OPEN": [15], "PERC": []},
	"DRILL": {"KICK": [1, 11], "CLAP": [9], "HAT": [1, 3, 4, 7, 9, 11, 12, 15], "OPEN": [], "PERC": [6, 14]},
	"AFRO": {"KICK": [1, 9], "CLAP": [5, 13], "HAT": [1, 3, 5, 7, 9, 11, 13, 15], "OPEN": [], "PERC": [1, 4, 7, 11, 13]},
}
## Variantes ajoutées au hasard : [instrument, pas, probabilité]
const VARIANTS := {
	"RAP": [["KICK", 3, .3], ["KICK", 15, .25], ["CLAP", 16, .15], ["PERC", 12, .2], ["OPEN", 15, .2]],
	"TRAP": [["KICK", 8, .4], ["KICK", 15, .35], ["KICK", 4, .2], ["OPEN", 15, .25], ["CLAP", 16, .15]],
	"R&B": [["KICK", 3, .25], ["KICK", 14, .3], ["CLAP", 16, .2], ["OPEN", 7, .2]],
	"SOUL": [["KICK", 3, .3], ["KICK", 14, .3], ["CLAP", 8, .2], ["PERC", 12, .3]],
	"DRILL": [["KICK", 4, .35], ["KICK", 8, .3], ["KICK", 14, .4], ["CLAP", 12, .25], ["OPEN", 16, .2]],
	"AFRO": [["KICK", 7, .4], ["KICK", 12, .3], ["OPEN", 8, .3], ["CLAP", 16, .2]],
}


static func empty_drums() -> Array:
	var out := []
	for i in INSTR.size():
		var a := PackedInt32Array()
		a.resize(16)
		out.append(a)
	return out


static func empty_bass() -> PackedInt32Array:
	var b := PackedInt32Array()
	b.resize(16)
	b.fill(-1)
	return b


static func generate_drums(style: String, seed: int) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var d := empty_drums()
	var base: Dictionary = BASE[style]
	for i in INSTR.size():
		for s in base[INSTR[i]]:
			d[i][s - 1] = 1
	for v in VARIANTS[style]:
		if r.randf() < v[2]:
			d[INSTR.find(v[0])][v[1] - 1] = 1
	# hi-hats : roulements (trap / drill surtout), quelques pas retirés ailleurs
	var hat := 2
	if style in ["TRAP", "DRILL"]:
		for s in [4, 8, 12, 14, 16]:
			if r.randf() < .35:
				d[hat][s - 1] = [2, 3, 4][r.randi() % 3]
		if style == "DRILL":
			for s in 16:
				if r.randf() < .2:
					d[hat][s] = 0
	elif style in ["R&B", "SOUL", "RAP"] and r.randf() < .4:
		d[hat][15] = 2
	# l'open hat coupe le hat sur le même pas
	for s in 16:
		if d[3][s] > 0:
			d[hat][s] = 0
	return d


## Ligne de 808 : suit le kick (fondamentale), avec quelques octaves / quintes / notes de passage.
static func generate_bass(drums: Array, style: String, seed: int) -> PackedInt32Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed * 31 + 7
	var b := empty_bass()
	for s in 16:
		if drums[0][s] > 0:
			b[s] = 0
	var extras := {"TRAP": [7, 12], "DRILL": [3, 7, 12, 10], "RAP": [7, 12], "R&B": [7, 5], "SOUL": [7, 12], "AFRO": [7, 12, 5]}[style] as Array
	for s in 16:
		if b[s] == 0 and s > 0 and r.randf() < .3:
			b[s] = extras[r.randi() % extras.size()]
		elif b[s] < 0 and s % 2 == 1 and r.randf() < (.12 if style in ["TRAP", "DRILL"] else .06):
			b[s] = extras[r.randi() % extras.size()]
	if b[0] < 0:
		b[0] = 0
	return b


## Fondamentale (classe de hauteur) à la mesure `bar` : celle de la grille du fax si on est calé dessus.
static func root_at(bar: int, key_tonic: int, fax_prog: Array) -> int:
	if fax_prog.is_empty():
		return key_tonic
	var beat := bar * 4
	var root: int = fax_prog[0].root
	for c in fax_prog:
		if c.beat <= beat:
			root = c.root
	return root


## Note MIDI de 808 (entre E0 et F2 environ) pour une fondamentale et un intervalle.
static func bass_note(root_pc: int, interval: int) -> int:
	var n := 24 + posmod(root_pc, 12)
	if n < 28:
		n += 12
	return n + interval


## Export MIDI : batterie (canal 10, notes GM) + 808, sur `bars` mesures (le pattern de 1 mesure boucle,
## la 808 suit la grille du fax si on est calé dessus), swing et roulements compris.
static func to_midi(drums: Array, bass: PackedInt32Array, bpm: float, swing: float, bars: int, key_tonic: int, fax_prog: Array) -> PackedByteArray:
	var ppq := MidiWriter.PPQ
	var step := ppq / 4
	var dnotes := []
	var bnotes := []
	for bar in bars:
		var root := root_at(bar, key_tonic, fax_prog)
		for s in 16:
			var t0 := bar * ppq * 4 + s * step + (int((swing - .5) * 2.0 * step) if s % 2 == 1 else 0)
			for i in INSTR.size():
				var v: int = drums[i][s]
				if v <= 0:
					continue
				for k in v:
					var tk := t0 + k * step / v
					dnotes.append([tk, tk + step / v - 4, GM[i], 100 if k == 0 else 70 + 8 * k])
			if bass[s] >= 0:
				var end := s + 1
				while end < 16 and bass[end] < 0:
					end += 1
				var t1 := bar * ppq * 4 + end * step - 6
				bnotes.append([t0, t1, bass_note(root, bass[s]), 110])
	return MidiWriter.build_tracks([
		{"name": "Batterie", "channel": 9, "program": 0, "notes": dnotes},
		{"name": "808", "channel": 0, "program": 38, "notes": bnotes},
	], bpm, "REEL Drum Machines")

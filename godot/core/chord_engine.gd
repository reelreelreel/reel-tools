class_name ChordEngine
## Générateur de progressions d'accords (module Fax) : style, tonalité, nombre de mesures.
## Chaque style a des grilles types (en demi-tons depuis la tonique) pour le mineur et le majeur,
## puis on colore (7e, 9e, sus) selon le style et on enchaîne les voicings au plus près.
##
## Résultat : Array de Dictionary {name, root, notes: PackedInt32Array (MIDI), beat, beats}.

const STYLES := ["RAP", "TRAP", "R&B", "SOUL", "DRILL", "AFRO"]
const NAMES_SHARP := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
const NAMES_FLAT := ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

## Intervalles de chaque qualité d'accord (14 = 9e, 21 = 13e).
const QUAL := {
	"": [0, 4, 7], "m": [0, 3, 7], "7": [0, 4, 7, 10], "m7": [0, 3, 7, 10], "maj7": [0, 4, 7, 11],
	"m9": [0, 3, 7, 10, 14], "maj9": [0, 4, 7, 11, 14], "9": [0, 4, 7, 10, 14], "13": [0, 4, 10, 14, 21],
	"add9": [0, 4, 7, 14], "madd9": [0, 3, 7, 14], "sus2": [0, 2, 7], "sus4": [0, 5, 7], "dim": [0, 3, 6],
	"m7b5": [0, 3, 6, 10], "6": [0, 4, 7, 9], "m6": [0, 3, 7, 9], "m11": [0, 3, 7, 10, 14, 17],
}

## Grilles types : [demi-tons depuis la tonique, qualité]. 4 accords = 4 mesures.
const GRIDS := {
	"RAP": {
		"min": [[[0, "m7"], [8, "maj7"], [3, "maj7"], [10, "7"]], [[0, "m"], [5, "m"], [8, ""], [7, "m"]],
				[[0, "m9"], [5, "m7"], [10, "7"], [3, "maj7"]], [[0, "m7"], [3, "maj7"], [5, "m7"], [7, "m7"]]],
		"maj": [[[0, "maj7"], [9, "m7"], [2, "m7"], [7, "7"]], [[0, ""], [4, "m"], [9, "m"], [5, ""]],
				[[5, "maj7"], [4, "m7"], [2, "m7"], [0, "maj7"]]],
	},
	"TRAP": {
		"min": [[[0, "m"], [8, ""], [3, ""], [10, ""]], [[0, "m"], [7, "m"], [8, ""], [7, "m"]],
				[[0, "m"], [1, ""], [0, "m"], [8, ""]], [[0, "m"], [8, ""], [5, "m"], [7, ""]],
				[[0, "m"], [3, ""], [8, ""], [7, "m"]]],
		"maj": [[[0, ""], [7, ""], [9, "m"], [5, ""]], [[9, "m"], [5, ""], [0, ""], [7, ""]]],
	},
	"R&B": {
		"min": [[[0, "m9"], [5, "m9"], [10, "13"], [3, "maj9"]], [[8, "maj9"], [7, "m7"], [5, "m9"], [0, "m9"]],
				[[0, "m11"], [8, "maj7"], [5, "m9"], [7, "7"]]],
		"maj": [[[2, "m9"], [7, "13"], [0, "maj9"], [9, "m9"]], [[5, "maj9"], [4, "m7"], [2, "m9"], [0, "maj9"]],
				[[0, "maj9"], [4, "m7"], [5, "maj7"], [7, "13"]]],
	},
	"SOUL": {
		"min": [[[0, "m7"], [5, "7"], [10, "maj7"], [3, "maj7"]], [[0, "m9"], [10, "7"], [8, "maj7"], [7, "7"]]],
		"maj": [[[0, "maj7"], [9, "m7"], [2, "m7"], [7, "9"]], [[0, "6"], [4, "m7"], [9, "7"], [2, "m7"]],
				[[5, "maj7"], [7, "7"], [4, "m7"], [9, "m7"]]],
	},
	"DRILL": {
		"min": [[[0, "m"], [8, ""], [1, ""], [0, "m"]], [[0, "m"], [3, ""], [1, ""], [7, "m"]],
				[[0, "m"], [11, "dim"], [8, ""], [7, ""]], [[0, "m"], [8, ""], [10, ""], [7, "m"]]],
		"maj": [[[0, ""], [8, ""], [10, ""], [0, ""]]],
	},
	"AFRO": {
		"min": [[[0, "m7"], [5, "m7"], [10, "add9"], [3, "maj7"]], [[0, "madd9"], [8, "maj7"], [10, "add9"], [5, "m7"]]],
		"maj": [[[0, "add9"], [7, "sus2"], [9, "m7"], [5, "maj7"]], [[5, "maj7"], [7, "add9"], [4, "m7"], [9, "m7"]],
				[[0, "maj7"], [5, "add9"], [9, "m7"], [7, "sus4"]]],
	},
}

## Probabilité d'enrichir un accord simple (7e / 9e) selon le style.
const COLOR := {"RAP": .35, "TRAP": .1, "R&B": .2, "SOUL": .4, "DRILL": .05, "AFRO": .3}


## Les 24 tonalités dans l'ordre de la molette : Cm, C, C#m, Db, … (mineur d'abord : c'est le cas courant).
static func key_count() -> int:
	return 24


static func key_tonic(k: int) -> int:
	return (k / 2) % 12


static func key_minor(k: int) -> bool:
	return k % 2 == 0


static func key_name(k: int) -> String:
	var t := key_tonic(k)
	if key_minor(k):
		return NAMES_SHARP[t] + "m" if t in [1, 6, 8] else NAMES_FLAT[t] + "m"
	return NAMES_FLAT[t] if t in [1, 3, 8, 10, 6] else NAMES_SHARP[t]


static func _use_flats(k: int) -> bool:
	var t := key_tonic(k)
	if key_minor(k):
		return t in [2, 7, 0, 5, 10, 3]   # Dm Gm Cm Fm Bbm Ebm
	return t in [5, 10, 3, 8, 1, 6]        # F Bb Eb Ab Db Gb


static func note_name(pc: int, k: int) -> String:
	return (NAMES_FLAT if _use_flats(k) else NAMES_SHARP)[posmod(pc, 12)]


## Nouvelle progression. bars = 2, 4 ou 8. seed = pour varier à chaque « froissage ».
static func generate(style: String, k: int, bars: int, seed: int) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var mode := "min" if key_minor(k) else "maj"
	var grids: Array = GRIDS[style][mode]
	var grid: Array = grids[r.randi() % grids.size()].duplicate(true)
	# couleur : 7e / 9e sur les accords simples, parfois une sus
	for c in grid:
		if c[1] in ["", "m"] and r.randf() < COLOR[style]:
			c[1] = ("m7" if c[1] == "m" else ("maj7" if r.randf() < .5 else "add9"))
		elif c[1] == "" and r.randf() < COLOR[style] * .3:
			c[1] = "sus2"
	# déroulé selon le nombre de mesures
	var seq := []   # [demi-tons, qualité, temps]
	match bars:
		2:
			for c in grid:
				seq.append([c[0], c[1], 2])
		4:
			for c in grid:
				seq.append([c[0], c[1], 4])
		_:
			for c in grid:
				seq.append([c[0], c[1], 4])
			# seconde moitié : même grille, fin variée (cadence différente)
			var tail := grid.duplicate(true)
			if r.randf() < .7:
				var alts := [[7, "7" if mode == "min" else "7"], [5, "m7" if mode == "min" else "maj7"], [10, ""], [8, "maj7"]]
				tail[3] = alts[r.randi() % alts.size()]
			for c in tail:
				seq.append([c[0], c[1], 4])
	var tonic := key_tonic(k)
	var out := []
	var beat := 0
	var prev := PackedInt32Array()
	for c in seq:
		var root := posmod(tonic + int(c[0]), 12)
		var q: String = c[1]
		var notes := _voice(root, q, prev)
		prev = notes
		out.append({"name": note_name(root, k) + q, "root": root, "notes": notes, "beat": beat, "beats": c[2]})
		beat += int(c[2])
	return out


## Voicing : basse (fondamentale, octave 2) + accord serré entre ~F3 et ~D5, au plus près du précédent.
static func _voice(root: int, q: String, prev: PackedInt32Array) -> PackedInt32Array:
	var ivs: Array = QUAL[q]
	var pcs := []
	for iv in ivs:
		var pc := posmod(root + int(iv), 12)
		if not pcs.has(pc):
			pcs.append(pc)
	# on retire la fondamentale du haut si l'accord est riche (la basse la joue)
	if pcs.size() >= 5:
		pcs.erase(root)
	var best := PackedInt32Array()
	var best_cost := INF
	for start in pcs.size():
		for base in [53, 55, 57, 59]:
			var v := PackedInt32Array()
			var last: int = base - 1
			for i in pcs.size():
				var pc: int = pcs[(start + i) % pcs.size()]
				var n: int = last + 1 + posmod(pc - (last + 1), 12)
				v.append(n)
				last = n
			if v[v.size() - 1] > 77:
				continue
			var cost := 0.0
			if prev.size() > 1:
				var pa := 0.0
				for i in range(1, prev.size()):
					pa += prev[i]
				pa /= prev.size() - 1
				var va := 0.0
				for n in v:
					va += n
				va /= v.size()
				cost = absf(va - pa)
			else:
				cost = absf(v[0] - 58.0)
			if cost < best_cost:
				best_cost = cost
				best = v
	var bass := 36 + posmod(root - 0, 12)
	if bass > 45:
		bass -= 12
	var out := PackedInt32Array([bass])
	out.append_array(best)
	return out


## Texte de la grille (pour le presse-papiers / la feuille).
static func summary(prog: Array) -> String:
	var parts := []
	for c in prog:
		parts.append(c.name)
	return " | ".join(parts)

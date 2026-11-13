class_name NoteFreq
## Notes ↔ fréquences, avec un diapason réglable (La4 = 440 Hz par défaut).

const NAMES := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


static func hz(midi: int, a4 := 440.0) -> float:
	return a4 * pow(2.0, (midi - 69) / 12.0)


## {midi, note, octave, cents} de la note la plus proche d'une fréquence.
static func describe(f: float, a4 := 440.0) -> Dictionary:
	var m := 69.0 + 12.0 * log(f / a4) / log(2.0)
	var n := int(round(m))
	return {"midi": n, "note": NAMES[posmod(n, 12)], "octave": floori(n / 12.0) - 1, "cents": (m - n) * 100.0}


static func label(midi: int) -> String:
	return NAMES[posmod(midi, 12)] + str(floori(midi / 12.0) - 1)

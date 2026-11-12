class_name TempoEngine
extends RefCounted
## Logique du module Tempo (indépendante du studio / skin) : BPM, tap tempo, valeurs de note en ms.

signal changed

## [libellé, multiplicateur de noire] ; négatif = decay (n temps moins un pré-delay de 1/32)
const NOTES := [
	["1/4", 1.0], ["1/4 DOTTED", 1.5], ["1/4 TRIPLET", 2.0 / 3.0],
	["1/8", 0.5], ["1/8 DOTTED", 0.75], ["1/8 TRIPLET", 1.0 / 3.0],
	["1/16", 0.25], ["1/16 DOTTED", 0.375], ["1/16 TRIPLET", 1.0 / 6.0],
	["1/32", 0.125], ["PRE-DELAY", 0.125], ["DECAY 1/2", -2.0], ["DECAY 1 BAR", -4.0],
]

var bpm: float = 140.0
var note_ix: int = 4
var _taps: Array[float] = []


func _init() -> void:
	bpm = float(Store.get_v("bpm", 140.0))
	note_ix = int(Store.get_v("note", 4))


func set_bpm(v: float) -> void:
	bpm = clampf(round(v * 10.0) / 10.0, 30.0, 300.0)
	Store.set_v("bpm", bpm)
	changed.emit()


func set_note(i: int) -> void:
	note_ix = posmod(i, NOTES.size())
	Store.set_v("note", note_ix)
	changed.emit()


func note_label() -> String:
	return NOTES[note_ix][0]


func note_ms() -> float:
	var beat := 60000.0 / bpm
	var mul: float = NOTES[note_ix][1]
	return beat * -mul - beat / 8.0 if mul < 0 else beat * mul


func note_is_decay() -> bool:
	return NOTES[note_ix][1] < 0


## Renvoie true quand le tempo a été recalculé (au moins 3 frappes).
func tap() -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if not _taps.is_empty() and now - _taps[-1] > 2.0:
		_taps.clear()
	_taps.append(now)
	if _taps.size() > 10:
		_taps.pop_front()
	if _taps.size() >= 3:
		set_bpm(60.0 / ((_taps[-1] - _taps[0]) / (_taps.size() - 1)))
		return true
	return false


func beat_phase(t: float) -> float:
	var beat_len := 60.0 / bpm
	return fmod(t, beat_len) / beat_len

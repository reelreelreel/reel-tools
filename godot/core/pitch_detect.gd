class_name PitchDetect
## Trouve la note d'un sample de 808 / kick (fichier WAV) : lecture du WAV, passage en mono,
## sous-échantillonnage à ~8 kHz, puis algorithme YIN sur la queue du son (après l'attaque).

const NAMES := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
const MIN_HZ := 25.0
const MAX_HZ := 500.0


## Renvoie {ok, hz, note, octave, cents, midi} ou {ok: false, err}.
static func analyze_file(path: String) -> Dictionary:
	var wav := read_wav(path)
	if not wav.ok:
		return wav
	return analyze(wav.samples, wav.rate)


static func analyze(samples: PackedFloat32Array, rate: float) -> Dictionary:
	if samples.size() < rate * .05:
		return {"ok": false, "err": "SAMPLE TROP COURT"}
	# sous-échantillonnage (moyenne par blocs = petit passe-bas)
	var f := maxi(1, int(round(rate / 8000.0)))
	var x := PackedFloat32Array()
	x.resize(samples.size() / f)
	for i in x.size():
		var s := 0.0
		for k in f:
			s += samples[i * f + k]
		x[i] = s / f
	var sr := rate / f
	# fenêtre d'analyse : de 40 ms après le pic jusqu'à 350 ms plus loin (la queue tenue de la 808)
	var peak := 0
	var pv := 0.0
	for i in mini(x.size(), int(sr * .3)):
		if absf(x[i]) > pv:
			pv = absf(x[i])
			peak = i
	if pv < 1e-4:
		return {"ok": false, "err": "SILENCE"}
	var start := peak + int(sr * .04)
	var n := mini(int(sr * .35), x.size() - start)
	var max_lag := int(sr / MIN_HZ)
	var min_lag := int(sr / MAX_HZ)
	if n < max_lag * 2:
		start = 0
		n = mini(x.size(), int(sr * .5))
		if n < max_lag * 2:
			return {"ok": false, "err": "SAMPLE TROP COURT"}
	var w := n - max_lag
	# YIN : fonction de différence + moyenne cumulée normalisée
	var d := PackedFloat32Array()
	d.resize(max_lag + 1)
	for tau in range(1, max_lag + 1):
		var acc := 0.0
		for j in w:
			var diff := x[start + j] - x[start + j + tau]
			acc += diff * diff
		d[tau] = acc
	var cmnd := PackedFloat32Array()
	cmnd.resize(max_lag + 1)
	cmnd[0] = 1.0
	var run := 0.0
	for tau in range(1, max_lag + 1):
		run += d[tau]
		cmnd[tau] = d[tau] * tau / maxf(run, 1e-12)
	var best := -1
	for tau in range(min_lag, max_lag):
		if cmnd[tau] < .15:
			while tau + 1 < max_lag and cmnd[tau + 1] < cmnd[tau]:
				tau += 1
			best = tau
			break
	if best < 0:  # pas sous le seuil : on prend le minimum global
		var mv := 1e9
		for tau in range(min_lag, max_lag):
			if cmnd[tau] < mv:
				mv = cmnd[tau]
				best = tau
	# interpolation parabolique pour la précision
	var t := float(best)
	if best > 1 and best < max_lag:
		var a := cmnd[best - 1]
		var b := cmnd[best]
		var c := cmnd[best + 1]
		var den := a - 2.0 * b + c
		if absf(den) > 1e-9:
			t = best + .5 * (a - c) / den
	return describe(sr / t)


static func describe(hz: float) -> Dictionary:
	var midi_f := 69.0 + 12.0 * log(hz / 440.0) / log(2.0)
	var midi := int(round(midi_f))
	return {"ok": true, "hz": hz, "midi": midi, "note": NAMES[posmod(midi, 12)], "octave": floori(midi / 12.0) - 1, "cents": (midi_f - midi) * 100.0}


# ---------------------------------------------------------------- lecture WAV (PCM 8/16/24/32 bits, flottant 32)
static func read_wav(path: String) -> Dictionary:
	var b := FileAccess.get_file_as_bytes(path)
	if b.size() < 44 or b.slice(0, 4).get_string_from_ascii() != "RIFF" or b.slice(8, 12).get_string_from_ascii() != "WAVE":
		return {"ok": false, "err": "PAS UN WAV"}
	var pos := 12
	var fmt := 0
	var ch := 1
	var rate := 44100
	var bits := 16
	var data_off := -1
	var data_len := 0
	while pos + 8 <= b.size():
		var id := b.slice(pos, pos + 4).get_string_from_ascii()
		var size := b.decode_u32(pos + 4)
		if id == "fmt ":
			fmt = b.decode_u16(pos + 8)
			ch = b.decode_u16(pos + 10)
			rate = b.decode_u32(pos + 12)
			bits = b.decode_u16(pos + 22)
			if fmt == 0xFFFE and size >= 40:
				fmt = b.decode_u16(pos + 32)
		elif id == "data":
			data_off = pos + 8
			data_len = mini(size, b.size() - data_off)
			break
		pos += 8 + size + (size % 2)
	if data_off < 0 or ch < 1:
		return {"ok": false, "err": "WAV ILLISIBLE"}
	if not (fmt == 1 or fmt == 3):
		return {"ok": false, "err": "FORMAT WAV NON GERE"}
	var bps := bits / 8
	var frames := data_len / (bps * ch)
	frames = mini(frames, rate * 4)  # 4 s suffisent
	var out := PackedFloat32Array()
	out.resize(frames)
	for i in frames:
		var s := 0.0
		for c in ch:
			var o := data_off + (i * ch + c) * bps
			var v := 0.0
			if fmt == 3 and bits == 32:
				v = b.decode_float(o)
			elif bits == 16:
				v = b.decode_s16(o) / 32768.0
			elif bits == 24:
				var u := b[o] | (b[o + 1] << 8) | (b[o + 2] << 16)
				if u & 0x800000:
					u -= 0x1000000
				v = u / 8388608.0
			elif bits == 32:
				v = b.decode_s32(o) / 2147483648.0
			elif bits == 8:
				v = (b[o] - 128) / 128.0
			s += v
		out[i] = s / ch
	return {"ok": true, "samples": out, "rate": float(rate)}

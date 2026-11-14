class_name TrackAnalyzer
## Trouve le BPM et la tonalité d'un morceau ou d'une prod (WAV, MP3, AIFF…), avec d'autres possibilités.
## - BPM : enveloppe d'attaques (énergie grave + aiguë, ~11 ms), autocorrélation, peigne sur 4 temps
##   pour la précision, préférence douce autour de 110 BPM ; propose aussi la moitié et le double.
## - Tonalité : chroma (FFT 2048 à ~5,5 kHz, 100 Hz – 2,2 kHz) corrélé aux profils de Krumhansl.
## Pensé pour tourner dans un thread (WorkerThreadPool) : aucune dépendance à la scène.

const NOTES_EN := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
const NOTES_FR := ["Do", "Do#", "Ré", "Ré#", "Mi", "Fa", "Fa#", "Sol", "Sol#", "La", "La#", "Si"]
const MAJOR := [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
const MINOR := [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]
const MAX_SECONDS := 60.0


static func analyze_file(path: String) -> Dictionary:
	var dec := AudioDecode.to_wav(path, 22050)
	if not dec.ok:
		return dec
	var wav := PitchDetect.read_wav(dec.path, 600.0)
	if not wav.ok:
		return wav
	return analyze(wav.samples, wav.rate)


static func analyze(samples: PackedFloat32Array, rate: float) -> Dictionary:
	var dur := samples.size() / rate
	if dur < 4.0:
		return {"ok": false, "err": "TRACK TOO SHORT"}
	# on prend une minute au cœur du morceau (après l'intro)
	var start := 0
	if dur > MAX_SECONDS + 10.0:
		start = int(clampf(dur * .25, 0.0, dur - MAX_SECONDS) * rate)
	var n := mini(samples.size() - start, int(MAX_SECONDS * rate))
	var x11 := _decimate(samples, start, n, rate, 11025.0)
	var bpm := _tempo(x11[0], x11[1])
	var x5 := _decimate(x11[0], 0, x11[0].size(), x11[1], 5512.5)
	var key := _key(x5[0], x5[1])
	return {"ok": true, "bpm": bpm, "key": key, "seconds": dur}


## Sous-échantillonnage par moyenne de blocs (passe-bas grossier). Renvoie [échantillons, fréquence].
static func _decimate(x: PackedFloat32Array, start: int, n: int, rate: float, target: float) -> Array:
	var f := maxi(1, int(round(rate / target)))
	var out := PackedFloat32Array()
	out.resize(n / f)
	for i in out.size():
		var s := 0.0
		var o := start + i * f
		for k in f:
			s += x[o + k]
		out[i] = s / f
	return [out, rate / f]


# ---------------------------------------------------------------- tempo
static func _tempo(x: PackedFloat32Array, sr: float) -> Dictionary:
	var hop := 128
	var frames := x.size() / hop
	var lp := 0.0
	var a_lp := 1.0 - exp(-TAU * 150.0 / sr)
	var prev_lo := 0.0
	var prev_hi := 0.0
	var prev_x := 0.0
	var onset := PackedFloat32Array()
	onset.resize(frames)
	for fi in frames:
		var e_lo := 0.0
		var e_hi := 0.0
		for j in hop:
			var v := x[fi * hop + j]
			lp += a_lp * (v - lp)
			var hp := v - prev_x
			prev_x = v
			e_lo += lp * lp
			e_hi += hp * hp
		var l_lo := log(1e-6 + e_lo)
		var l_hi := log(1e-6 + e_hi)
		onset[fi] = maxf(0.0, l_lo - prev_lo) + .7 * maxf(0.0, l_hi - prev_hi)
		prev_lo = l_lo
		prev_hi = l_hi
	# on retire la moyenne glissante (garde les pics)
	var mean := 0.0
	for v in onset:
		mean += v
	mean /= maxf(1.0, onset.size())
	for i in onset.size():
		onset[i] = maxf(0.0, onset[i] - mean)
	var fps := sr / hop
	var max_lag := int(fps * 60.0 / 40.0 * 4.0) + 2  # 4 temps à 40 BPM
	max_lag = mini(max_lag, onset.size() - 1)
	var ac := PackedFloat32Array()
	ac.resize(max_lag + 1)
	for lag in range(1, max_lag + 1):
		var s := 0.0
		for i in onset.size() - lag:
			s += onset[i] * onset[i + lag]
		ac[lag] = s / (onset.size() - lag)
	var scores := []
	var b := 55.0
	while b <= 210.0:
		var L := fps * 60.0 / b
		var s := 0.0
		for k in [1, 2, 3, 4]:
			s += _interp(ac, L * k) * (1.0 if k != 3 else .6)
		var prior := exp(-.5 * pow(log(b / 110.0) / log(2.0) / .9, 2))
		scores.append([b, s, s * prior])
		b += .1
	scores.sort_custom(func(p, q): return p[2] > q[2])
	var best: float = scores[0][0]
	var cands := [_round_bpm(best)]
	for alt in [best / 2.0, best * 2.0]:
		if alt >= 50.0 and alt <= 220.0:
			cands.append(_round_bpm(alt))
	return {"bpm": cands[0], "alts": cands.slice(1)}


static func _interp(a: PackedFloat32Array, t: float) -> float:
	var i := int(t)
	if i + 1 >= a.size():
		return 0.0
	var f := t - i
	return a[i] * (1.0 - f) + a[i + 1] * f


static func _round_bpm(b: float) -> float:
	var r := roundf(b)
	return r if absf(b - r) < .35 else roundf(b * 2.0) / 2.0


# ---------------------------------------------------------------- tonalité
static func _key(x: PackedFloat32Array, sr: float) -> Dictionary:
	var N := 2048
	var bins := N / 2
	# poids bin -> classe de hauteur (gaussienne sur l'écart en cents)
	var map := []
	for k in range(1, bins):
		var f := k * sr / N
		if f < 100.0 or f > 2200.0:
			continue
		var midi := 69.0 + 12.0 * log(f / 440.0) / log(2.0)
		var m := int(round(midi))
		var d := midi - m
		var w := exp(-d * d / (2.0 * .25 * .25))
		if w > .05:
			map.append([k, posmod(m, 12), w])
	var chroma := PackedFloat32Array()
	chroma.resize(12)
	var win := PackedFloat32Array()
	win.resize(N)
	for i in N:
		win[i] = .5 - .5 * cos(TAU * i / (N - 1))
	var re := PackedFloat32Array()
	var im := PackedFloat32Array()
	re.resize(N)
	im.resize(N)
	var tw := _twiddles(N)
	var pos := 0
	while pos + N <= x.size():
		for i in N:
			re[i] = x[pos + i] * win[i]
			im[i] = 0.0
		_fft(re, im, tw)
		var frame := PackedFloat32Array()
		frame.resize(12)
		for e in map:
			var k: int = e[0]
			frame[e[1]] += sqrt(re[k] * re[k] + im[k] * im[k]) * e[2]
		var mx := 0.0
		for v in frame:
			mx = maxf(mx, v)
		if mx > 1e-6:
			for c in 12:
				chroma[c] += frame[c] / mx
		pos += N
	var ranked := []
	for root in 12:
		for minor in [false, true]:
			var prof: Array = MINOR if minor else MAJOR
			ranked.append([root, minor, _corr(chroma, prof, root)])
	ranked.sort_custom(func(p, q): return p[2] > q[2])
	var out := []
	for i in 4:
		out.append(_key_info(ranked[i][0], ranked[i][1], ranked[i][2]))
	return {"best": out[0], "alts": out.slice(1), "chroma": chroma}


static func _key_info(root: int, minor: bool, score: float) -> Dictionary:
	var short: String = NOTES_EN[root] + ("m" if minor else "")
	var long: String = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"][root] + (" minor" if minor else " major")
	var rel_root := posmod(root + (3 if minor else -3), 12)
	return {"root": root, "minor": minor, "score": score, "short": short, "long": long,
		"relative": NOTES_EN[rel_root] + ("" if minor else "m")}


static func _corr(chroma: PackedFloat32Array, prof: Array, root: int) -> float:
	var mx := 0.0
	var mp := 0.0
	for i in 12:
		mx += chroma[i]
		mp += prof[i]
	mx /= 12.0
	mp /= 12.0
	var num := 0.0
	var dx := 0.0
	var dp := 0.0
	for i in 12:
		var a := chroma[(i + root) % 12] - mx
		var b: float = prof[i] - mp
		num += a * b
		dx += a * a
		dp += b * b
	return num / sqrt(maxf(dx * dp, 1e-12))


# ---------------------------------------------------------------- FFT radix-2 en place
static func _twiddles(n: int) -> Array:
	var c := PackedFloat32Array()
	var s := PackedFloat32Array()
	c.resize(n / 2)
	s.resize(n / 2)
	for i in n / 2:
		c[i] = cos(-TAU * i / n)
		s[i] = sin(-TAU * i / n)
	return [c, s]


static func _fft(re: PackedFloat32Array, im: PackedFloat32Array, tw: Array) -> void:
	var n := re.size()
	var j := 0
	for i in range(1, n):
		var bit := n >> 1
		while j & bit:
			j ^= bit
			bit >>= 1
		j |= bit
		if i < j:
			var t := re[i]
			re[i] = re[j]
			re[j] = t
			t = im[i]
			im[i] = im[j]
			im[j] = t
	var cs: PackedFloat32Array = tw[0]
	var sn: PackedFloat32Array = tw[1]
	var size := 2
	while size <= n:
		var half := size / 2
		var step := n / size
		var start := 0
		while start < n:
			var k := 0
			for m in half:
				var wr := cs[k]
				var wi := sn[k]
				var a := start + m
				var b := a + half
				var tr := re[b] * wr - im[b] * wi
				var ti := re[b] * wi + im[b] * wr
				re[b] = re[a] - tr
				im[b] = im[a] - ti
				re[a] += tr
				im[a] += ti
				k += step
			start += size
		size *= 2

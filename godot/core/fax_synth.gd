class_name FaxSynth
## Sons d'écoute du Fax (en attendant les one shots de Maxime) : la progression est rendue d'avance
## dans un AudioStreamWAV (mono 22 kHz) qui boucle. À lancer dans un thread (≈ 1–3 s pour 8 mesures).
## Sons : Rhodes (FM), nappe de cordes, pad, guitare (Karplus-Strong, gratté), pluck.

const SOUNDS := ["RHODES", "NAPPE", "PAD", "GUIT.", "PLUCK"]
const SR := 22050


static func midi_hz(n: int) -> float:
	return 440.0 * pow(2.0, (n - 69) / 12.0)


static func render(prog: Array, bpm: float, sound: int) -> AudioStreamWAV:
	var spb := 60.0 / bpm
	var total_beats := 0
	for c in prog:
		total_beats = maxi(total_beats, c.beat + c.beats)
	var n_total := int(total_beats * spb * SR)
	var buf := PackedFloat32Array()
	buf.resize(n_total)
	for c in prog:
		var start := int(c.beat * spb * SR)
		var length := int(c.beats * spb * SR)
		for i in c.notes.size():
			var note: int = c.notes[i]
			var is_bass: bool = i == 0
			var delay := 0
			if sound == 3:  # guitare : on gratte de la basse vers l'aigu
				delay = int(i * .018 * SR)
			_voice(buf, start + delay, length - delay, note, sound, is_bass, n_total)
	# normalisation douce + conversion 16 bits
	var peak := 0.001
	for v in buf:
		peak = maxf(peak, absf(v))
	var g := .85 / peak
	var data := PackedByteArray()
	data.resize(n_total * 2)
	for i in n_total:
		var v := tanh(buf[i] * g * 1.1)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n_total
	return w


static func _voice(buf: PackedFloat32Array, start: int, length: int, note: int, sound: int, bass: bool, n_total: int) -> void:
	var f := midi_hz(note)
	var amp := .55 if bass else .32
	var rel := int(.06 * SR)
	var tail := int((.9 if sound in [1, 2] else .35) * SR)  # résonance après la fin de l'accord
	var n := mini(length + tail, n_total - start)
	if n <= 0:
		return
	var w := TAU * f / SR
	match sound:
		0:  # Rhodes : FM 1:1, indice qui décroît (attaque « tine »), corps qui s'éteint lentement
			var ph := 0.0
			for i in n:
				var t := float(i) / SR
				var idx := 2.2 * exp(-t * 7.0) + .25
				var s := sin(ph + idx * sin(ph))
				var env := exp(-t * (1.6 if bass else 1.1)) * minf(1.0, t * 300.0)
				if i > length:
					env *= exp(-float(i - length) / rel)
				buf[start + i] += s * env * amp
				ph += w
		1, 2:  # nappe (cordes, vibrato) / pad (doux, plus filtré) : scies désaccordées filtrées
			var att := .25 if sound == 1 else .45
			var cut := .22 if sound == 1 else .1
			var dets := [-.006, 0.0, .007] if sound == 1 else [-.004, .005]
			var phs := []
			for d in dets:
				phs.append(randf())
			var lp := 0.0
			var lp2 := 0.0
			for i in n:
				var t := float(i) / SR
				var vib := 1.0 + (.003 * sin(TAU * 5.2 * t) if sound == 1 else 0.0)
				var s := 0.0
				for k in dets.size():
					phs[k] = fmod(phs[k] + f * (1.0 + dets[k]) * vib / SR, 1.0)
					s += 2.0 * phs[k] - 1.0
				s /= dets.size()
				lp += cut * (s - lp)
				lp2 += cut * (lp - lp2)
				var env := minf(1.0, t / att)
				if i > length:
					env *= exp(-float(i - length) / (tail * .35))
				buf[start + i] += lp2 * env * amp * (1.3 if bass else 1.0)
		3:  # guitare : Karplus-Strong
			var period := maxi(2, int(SR / f))
			var line := PackedFloat32Array()
			line.resize(period)
			for k in period:
				line[k] = randf_range(-1.0, 1.0)
			var idx := 0
			var damp := .996 if bass else .994
			for i in n:
				var a := line[idx]
				var b := line[(idx + 1) % period]
				var v := (a + b) * .5 * damp
				line[idx] = v
				idx = (idx + 1) % period
				var env := 1.0
				if i > length:
					env = exp(-float(i - length) / rel)
				buf[start + i] += a * env * amp * 1.2
		_:  # pluck : carré filtré, décroissance rapide, filtre qui se ferme
			var ph := 0.0
			var lp := 0.0
			for i in n:
				var t := float(i) / SR
				ph = fmod(ph + f / SR, 1.0)
				var s := 1.0 if ph < .5 else -1.0
				var cut := .03 + .5 * exp(-t * 12.0)
				lp += cut * (s - lp)
				var env := exp(-t * (3.5 if bass else 5.0)) * minf(1.0, t * 500.0)
				buf[start + i] += lp * env * amp

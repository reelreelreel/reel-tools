class_name BeatSounds
## Sons des boîtes à rythmes, synthétisés une fois et gardés en cache (AudioStreamWAV mono 44,1 kHz) :
## kick, clap, hi-hat fermé, open hat, perc (rim), et 808 par note (sinus saturé, chute de hauteur).
## (Maxime pourra plus tard les remplacer par ses propres samples.)

const SR := 44100
static var _cache := {}


static func _to_wav(buf: PackedFloat32Array, gain := 1.0) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i] * gain, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = data
	return w


static func drum(i: int) -> AudioStreamWAV:
	var key := "d%d" % i
	if _cache.has(key):
		return _cache[key]
	var w: AudioStreamWAV
	match i:
		0:
			w = _kick()
		1:
			w = _clap()
		2:
			w = _hat(.045, .9)
		3:
			w = _hat(.32, .8)
		_:
			w = _rim()
	_cache[key] = w
	return w


static func bass(note: int) -> AudioStreamWAV:
	var key := "b%d" % note
	if _cache.has(key):
		return _cache[key]
	var f := 440.0 * pow(2.0, (note - 69) / 12.0)
	var n := int(1.1 * SR)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / SR
		var fr := f * (1.0 + 1.3 * exp(-t * 38.0))
		ph += TAU * fr / SR
		var env := exp(-t * 2.2) * minf(1.0, t * 800.0)
		var s := sin(ph) + .15 * sin(2.0 * ph)
		buf[i] = tanh(s * 2.2) * env * .75
	var w := _to_wav(buf)
	_cache[key] = w
	return w


static func _kick() -> AudioStreamWAV:
	var n := int(.45 * SR)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / SR
		var fr := 48.0 + 110.0 * exp(-t * 30.0)
		ph += TAU * fr / SR
		var env := exp(-t * 7.0)
		var click := exp(-t * 900.0) * randf_range(-1, 1) * .4
		buf[i] = tanh(sin(ph) * env * 1.8) * .9 + click
	return _to_wav(buf)


static func _clap() -> AudioStreamWAV:
	var n := int(.3 * SR)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var bp := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / SR
		var env := 0.0
		for k in 3:  # trois mains décalées puis la queue
			var tk := t - k * .011
			if tk >= 0:
				env = maxf(env, exp(-tk * 140.0))
		env = maxf(env, .55 * exp(-maxf(t - .022, 0) * 18.0) * (1.0 if t > .022 else 0.0))
		var x := randf_range(-1, 1)
		lp += .35 * (x - lp)
		bp = x - lp  # passe-haut
		buf[i] = (lp * .6 + bp * .5) * env * .9
	return _to_wav(buf)


static func _hat(decay: float, bright: float) -> AudioStreamWAV:
	var n := int((decay * 3.0 + .02) * SR)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var prev := 0.0
	var ph := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var fr := [205.3, 304.4, 369.6, 522.7, 540.0, 800.0]
	for i in n:
		var t := float(i) / SR
		var s := 0.0
		for k in 6:  # métal façon 808 : carrés inharmoniques
			ph[k] = fmod(ph[k] + fr[k] * 8.0 / SR, 1.0)
			s += 1.0 if ph[k] < .5 else -1.0
		s = s / 6.0 * .5 + randf_range(-1, 1) * .5
		var hp: float = s - prev
		prev = s
		buf[i] = hp * exp(-t / decay) * bright * .55
	return _to_wav(buf)


static func _rim() -> AudioStreamWAV:
	var n := int(.08 * SR)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t := float(i) / SR
		buf[i] = (sin(TAU * 1700.0 * t) * .6 + sin(TAU * 480.0 * t) * .5 + randf_range(-1, 1) * .3 * exp(-t * 300)) * exp(-t * 60.0) * .7
	return _to_wav(buf)

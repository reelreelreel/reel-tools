class_name MidiWriter
## Écrit un fichier MIDI standard (format 1) : piste tempo + piste d'accords (basse comprise).
## 480 ticks par noire. La progression vient de ChordEngine.generate().

const PPQ := 480


static func _vlq(v: int) -> PackedByteArray:
	var bytes := [v & 0x7F]
	v >>= 7
	while v > 0:
		bytes.push_front((v & 0x7F) | 0x80)
		v >>= 7
	return PackedByteArray(bytes)


static func _u32(v: int) -> PackedByteArray:
	return PackedByteArray([(v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255])


static func _chunk(id: String, data: PackedByteArray) -> PackedByteArray:
	var out := id.to_ascii_buffer()
	out.append_array(_u32(data.size()))
	out.append_array(data)
	return out


static func _text_event(delta: int, kind: int, txt: String) -> PackedByteArray:
	var t := txt.to_utf8_buffer()
	var out := _vlq(delta)
	out.append_array(PackedByteArray([0xFF, kind]))
	out.append_array(_vlq(t.size()))
	out.append_array(t)
	return out


## Octets du fichier .mid.
static func build(prog: Array, bpm: float, title := "REEL'S TOOLS") -> PackedByteArray:
	# piste 0 : tempo, mesure 4/4, nom
	var t0 := PackedByteArray()
	t0.append_array(_text_event(0, 0x03, title))
	var us := int(round(60000000.0 / bpm))
	t0.append_array(PackedByteArray([0, 0xFF, 0x51, 3, (us >> 16) & 255, (us >> 8) & 255, us & 255]))
	t0.append_array(PackedByteArray([0, 0xFF, 0x58, 4, 4, 2, 24, 8]))
	t0.append_array(PackedByteArray([0, 0xFF, 0x2F, 0]))
	# piste 1 : accords (marqueurs avec le nom de l'accord)
	var events := []  # [tick, ordre, octets]
	for c in prog:
		var on: int = c.beat * PPQ
		var off: int = (c.beat + c.beats) * PPQ - 12
		events.append([on, 0, PackedByteArray([0xFF, 0x06]), c.name])
		for i in c.notes.size():
			var n: int = c.notes[i]
			var vel: int = 92 if i == 0 else 78 + (i * 3) % 10
			events.append([on, 2, PackedByteArray([0x90, n, vel]), ""])
			events.append([off, 1, PackedByteArray([0x80, n, 0]), ""])
	events.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var t1 := PackedByteArray()
	t1.append_array(_text_event(0, 0x03, "Accords"))
	t1.append_array(PackedByteArray([0, 0xC0, 4]))  # programme : piano électrique
	var last := 0
	for ev in events:
		var delta: int = ev[0] - last
		last = ev[0]
		if ev[3] != "":
			t1.append_array(_text_event(delta, 0x06, ev[3]))
		else:
			t1.append_array(_vlq(delta))
			t1.append_array(ev[2])
	t1.append_array(PackedByteArray([0, 0xFF, 0x2F, 0]))
	var head := PackedByteArray([0, 1, 0, 2, (PPQ >> 8) & 255, PPQ & 255])
	var out := _chunk("MThd", head)
	out.append_array(_chunk("MTrk", t0))
	out.append_array(_chunk("MTrk", t1))
	return out


static func save(path: String, prog: Array, bpm: float, title := "REEL'S TOOLS") -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(build(prog, bpm, title))
	f.close()
	return true


## Plusieurs pistes de notes : tracks = [{name, channel, program, notes: [[tick_on, tick_off, note, vel], …]}].
static func build_tracks(tracks: Array, bpm: float, title := "REEL'S TOOLS") -> PackedByteArray:
	var t0 := PackedByteArray()
	t0.append_array(_text_event(0, 0x03, title))
	var us := int(round(60000000.0 / bpm))
	t0.append_array(PackedByteArray([0, 0xFF, 0x51, 3, (us >> 16) & 255, (us >> 8) & 255, us & 255]))
	t0.append_array(PackedByteArray([0, 0xFF, 0x58, 4, 4, 2, 24, 8]))
	t0.append_array(PackedByteArray([0, 0xFF, 0x2F, 0]))
	var out := _chunk("MThd", PackedByteArray([0, 1, 0, tracks.size() + 1, (PPQ >> 8) & 255, PPQ & 255]))
	out.append_array(_chunk("MTrk", t0))
	for tr in tracks:
		var ch: int = tr.channel
		var ev := []
		for n in tr.notes:
			ev.append([int(n[0]), 1, PackedByteArray([0x90 | ch, n[2], n[3]])])
			ev.append([int(n[1]), 0, PackedByteArray([0x80 | ch, n[2], 0])])
		ev.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
		var t := PackedByteArray()
		t.append_array(_text_event(0, 0x03, tr.name))
		if ch != 9:
			t.append_array(PackedByteArray([0, 0xC0 | ch, tr.program]))
		var last := 0
		for e in ev:
			t.append_array(_vlq(e[0] - last))
			last = e[0]
			t.append_array(e[2])
		t.append_array(PackedByteArray([0, 0xFF, 0x2F, 0]))
		out.append_array(_chunk("MTrk", t))
	return out


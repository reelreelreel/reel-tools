class_name AudioDecode
## Conversion d'un fichier audio (MP3, AIFF, M4A, FLAC…) en WAV 16 bits pour l'analyser ou l'écouter.
## Sur Mac on utilise afconvert (fourni avec macOS) ; sinon ffmpeg s'il est installé.

const DIRECT := ["wav", "wave"]


## Renvoie {ok, path} (le WAV à lire) ou {ok: false, err}.
static func to_wav(path: String, rate := 0) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "err": "FILE NOT FOUND"}
	if DIRECT.has(path.get_extension().to_lower()):
		return {"ok": true, "path": path}
	var out := OS.get_cache_dir().path_join("reels_tools_decode_%d.wav" % (Time.get_ticks_usec() % 100000))
	var fmt := "LEI16" + ("@%d" % rate if rate > 0 else "")
	for exe in ["/usr/bin/afconvert", "afconvert"]:
		if OS.execute(exe, PackedStringArray(["-f", "WAVE", "-d", fmt, "-c", "1", path, out])) == 0 and FileAccess.file_exists(out):
			return {"ok": true, "path": out}
	var args := PackedStringArray(["-y", "-loglevel", "error", "-i", path, "-ac", "1"])
	if rate > 0:
		args.append_array(["-ar", str(rate)])
	args.append_array(["-c:a", "pcm_s16le", out])
	for exe in ["ffmpeg", "/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"]:
		if OS.execute(exe, args) == 0 and FileAccess.file_exists(out):
			return {"ok": true, "path": out}
	return {"ok": false, "err": "UNSUPPORTED FORMAT"}

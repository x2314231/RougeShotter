extends AudioStreamPlayer
## 背景音樂（BGM）管理器
## 每一關（wave）開始時：由外部呼叫 play_random_bgm()，隨機挑選一首並循環播放。

# 在 Web 匯出時，`DirAccess.open("res://...")` 可能無法列舉資料夾。
# 因此提供「預設路徑清單」確保至少能載入你專案中現有的 BGM。
@export var bgm_paths: Array[String] = [
	"res://audio/bgm/Chrono_Trigger_Genesis_Awakening.wav",
	"res://audio/bgm/Pixelated_Dust_and_Steel.wav",
	"res://audio/bgm/Pixelated_Horizon.wav",
]
@export var bgm_dir: String = "res://audio/bgm" # 若資源打包無法列舉時，僅使用 bgm_paths
@export var bgm_volume_db: float = -6.0

var _streams: Array[AudioStream] = []


func _ready() -> void:
	# Godot：AudioStreamPlayer 不會自動幫你 loop，我們盡可能在載入時把常見格式設成 loop。
	_load_streams()
	autoplay = false
	volume_db = bgm_volume_db


func _load_streams() -> void:
	_streams.clear()

	# 1) 先載入顯式指定的路徑（最穩、最適合打包/匯出）
	for p in bgm_paths:
		var s := load(p) as AudioStream
		if s == null:
			continue
		_try_enable_loop(s)
		_streams.append(s)

	# 2) 進階：嘗試從目錄列舉（若在匯出環境失敗也沒關係）
	var dir := DirAccess.open(bgm_dir)
	if dir == null:
		return

	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir():
			if f.ends_with(".ogg") or f.ends_with(".wav") or f.ends_with(".mp3"):
				var p2 := "%s/%s" % [bgm_dir, f]
				var s2 := load(p2) as AudioStream
				if s2 != null:
					_try_enable_loop(s2)
					_streams.append(s2)
		f = dir.get_next()
	dir.list_dir_end()

	# 若 Web 匯出導致目錄列舉失敗，至少應該用 bgm_paths 載入。
	# 若仍為空，代表目前沒有任何可播放的 BGM 資源。
	if _streams.is_empty():
		push_warning("BackgroundMusic: 找不到可載入的 BGM，請確認 bgm_paths 是否包含有效 res:// 路徑。")


func _try_enable_loop(s: AudioStream) -> void:
	# 常見格式：ogg / wav
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	elif s is AudioStreamWAV:
		# AudioStreamWAV 沒有 bool loop，改用 loop_mode。
		# LOOP_FORWARD = 1：在 loop_begin/loop_end 間循環（若資源導入已設定 loop 點，效果最好）。
		var wav := (s as AudioStreamWAV)
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD

		# 你的 wav 匯入設定目前多半是 loop_end=-1（循環停用狀態）。
		# 為了避免「loop_mode 設了但範圍無效導致播完就停」，在 loop_end 無效時，
		# 用「音長 * mix_rate」估算整段長度並寫回 loop_end。
		var invalid_loop_end := (wav.loop_end < 0) or (wav.loop_end <= wav.loop_begin)
		if invalid_loop_end:
			var len_sec := wav.get_length()
			if len_sec > 0.0:
				var end_samples := int(len_sec * float(wav.mix_rate))
				if end_samples > wav.loop_begin + 1:
					wav.loop_begin = 0
					wav.loop_end = end_samples
	elif s is AudioStreamMP3:
		# MP3 的循環控制使用 loop + loop_offset（以秒為單位）
		(s as AudioStreamMP3).loop = true
		(s as AudioStreamMP3).loop_offset = 0.0


func play_random_bgm() -> void:
	if _streams.is_empty():
		return
	var idx := randi_range(0, _streams.size() - 1)
	stream = _streams[idx]
	play()

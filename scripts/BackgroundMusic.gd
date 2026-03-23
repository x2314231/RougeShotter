extends AudioStreamPlayer
## 背景音樂（BGM）管理器
## 外部在遊戲開始時呼叫 play_random_bgm() 播放第一首；
## 播放完畢後自動播放下一首（不依 wave 換歌）。

# 在 Web 匯出時，`DirAccess.open("res://...")` 可能無法列舉資料夾。
# 因此提供「預設路徑清單」確保至少能載入你專案中現有的 BGM。
@export var bgm_paths: Array[String] = [
	"res://audio/bgm/Chrono_Trigger_Genesis_Awakening.wav",
	"res://audio/bgm/Pixelated_Dust_and_Steel.wav",
	"res://audio/bgm/Pixelated_Horizon.wav",
]
@export var bgm_dir: String = "res://audio/bgm" # 若資源打包無法列舉時，僅使用 bgm_paths
@export var bgm_volume_db: float = -18.0

var _streams: Array[AudioStream] = []

var _current_stream_idx: int = -1

# Web/行動裝置常見狀況：切到背景/離開頁面時音樂還會繼續播放。
# 用 Application 通知暫停/停止，離開就關掉，回來則可選擇恢復。
var _bgm_was_playing_before_suspend := false
var _bgm_saved_playback_pos_sec := 0.0


func _ready() -> void:
	# AudioStreamPlayer 依序播放時需要「不 loop」，否則 finished 不會觸發。
	_load_streams()
	autoplay = false
	volume_db = bgm_volume_db
	finished.connect(_on_bgm_finished)


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
	# 這裡名稱沿用舊版，但在「自動下一首」需求下必須關閉 loop。
	# 常見格式：ogg / wav / mp3
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = false
	elif s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
	elif s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = false


func play_random_bgm() -> void:
	if _streams.is_empty():
		return
	var idx := randi_range(0, _streams.size() - 1)
	_play_index(idx)

func _play_index(idx: int) -> void:
	if idx < 0 or idx >= _streams.size():
		return
	_current_stream_idx = idx
	stream = _streams[idx]
	play()

func _on_bgm_finished() -> void:
	if _streams.is_empty():
		return
	if _streams.size() == 1:
		_play_index(0)
		return

	var next_idx := _current_stream_idx
	var tries := 0
	while next_idx == _current_stream_idx and tries < 10:
		next_idx = randi_range(0, _streams.size() - 1)
		tries += 1
	if next_idx == _current_stream_idx:
		next_idx = (_current_stream_idx + 1) % _streams.size()
	_play_index(next_idx)

func _notification(what: int) -> void:
	# 手機瀏覽器離開/切到背景時可能觸發這些通知
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			if playing:
				_bgm_was_playing_before_suspend = true
				_bgm_saved_playback_pos_sec = get_playback_position()
			else:
				_bgm_was_playing_before_suspend = false
			stop()
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			if _bgm_was_playing_before_suspend and stream != null:
				play(_bgm_saved_playback_pos_sec)
			_bgm_was_playing_before_suspend = false

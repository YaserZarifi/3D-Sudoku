extends Node
## Autoload. Short UI sounds, synthesized at startup so the game ships with
## no audio files and stays fully offline.

const MIX_RATE := 44100
const VOICES := 4
const VOLUME_DB := -8.0

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	_streams["select"] = _tone([1320.0], 0.035, 0.18)
	_streams["place"] = _tone([880.0], 0.06, 0.3)
	_streams["erase"] = _tone([520.0], 0.05, 0.22)
	_streams["conflict"] = _tone([196.0, 185.0], 0.16, 0.35)
	_streams["solved"] = _tone([523.25, 659.25, 783.99, 1046.5], 0.5, 0.35)
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.volume_db = VOLUME_DB
		add_child(player)
		_players.append(player)


func play(sound: String) -> void:
	if not SaveManager.get_setting("sound") or not _streams.has(sound):
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = _streams[sound]
	player.play()


## Plays the frequencies one after another (an arpeggio when there are
## several) with a soft attack and exponential decay.
func _tone(frequencies: Array, seconds: float, gain: float) -> AudioStreamWAV:
	var frames := int(seconds * MIX_RATE)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var segment := maxi(frames / frequencies.size(), 1)
	var phase := 0.0
	for i in frames:
		var part := mini(i / segment, frequencies.size() - 1)
		var local := float(i - part * segment) / MIX_RATE
		phase += TAU * float(frequencies[part]) / MIX_RATE
		var attack := minf(local / 0.004, 1.0)
		var decay := exp(-local * 9.0 / (segment / float(MIX_RATE)))
		var sample := sin(phase) * gain * attack * decay
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream

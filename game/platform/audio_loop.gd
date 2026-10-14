class_name AudioLoop
extends RefCounted
## Presentation-only loops: streamed Vorbis beds, PCM for short responsive voices.

static func prepare(source: AudioStream) -> AudioStream:
	if source is AudioStreamOggVorbis:
		var stream: AudioStreamOggVorbis = source.duplicate() as AudioStreamOggVorbis
		stream.loop = true
		stream.loop_offset = 0.0
		return stream
	return PcmAudioLoop.prepare(source as AudioStreamWAV)

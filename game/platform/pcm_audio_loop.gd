class_name PcmAudioLoop
extends RefCounted
## Prepare a lossless full-file loop with its cyclic interpolation frame.

static func prepare(source: AudioStreamWAV) -> AudioStreamWAV:
	assert(source.format==AudioStreamWAV.FORMAT_16_BITS,"Loop masters must be lossless 16-bit PCM")
	var stream: AudioStreamWAV = source.duplicate() as AudioStreamWAV
	var frame_bytes: int = 4 if stream.stereo else 2
	var pcm: PackedByteArray = stream.data
	assert(pcm.size()>=frame_bytes and pcm.size()%frame_bytes==0,"Complete PCM frames required")
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = pcm.size()/frame_bytes
	# Fractional pitch interpolates into this frame before the cursor wraps.
	# Resource padding is silence and would produce a short click/dip instead.
	pcm.append_array(pcm.slice(0,frame_bytes))
	stream.data = pcm
	return stream

"""Make a seamless distant thunder bed from the existing owner-supplied tail."""
from pathlib import Path
import hashlib
import json
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'game/assets/audio/storm_thunder.wav'
SOURCE_HASH = '66210f9ed33fb60ab325f0ecf3c76450a993bdfef5f2ede8071e4c899256055b'


def main():
    digest = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    if digest != SOURCE_HASH:
        raise ValueError('Accepted strong thunder master changed')
    with wave.open(str(SOURCE)) as handle:
        rate = handle.getframerate()
        source = np.frombuffer(handle.readframes(handle.getnframes()), dtype='<i2').astype(float) / 32768
    # Omit the clap and final fade. Slowly varying, overlapping excerpts of the
    # real rolling body give continuous distant movement without new synthesis.
    tail = source[round(1.2 * rate):round(4.8 * rate)]
    size = 16 * rate
    bed = np.zeros(size)
    weights = np.zeros(size)
    window_size = 4 * rate
    window = np.sin(np.arange(window_size) * np.pi / window_size) ** 2
    for index in range(8):
        pace = [0.82, 0.91, 0.86, 0.96, 0.88, 0.83, 0.94, 0.89][index]
        coordinates = (np.arange(window_size) * pace + index * 0.317 * rate) % len(tail)
        clip = np.interp(coordinates, np.arange(len(tail)), tail, period=len(tail))
        positions = (np.arange(window_size) + index * 2 * rate) % size
        bed[positions] += clip * window
        weights[positions] += window
    bed /= weights
    # Periodic FFT filtering preserves the loop boundary. Keep a muffled rolling
    # bass/body, with no subsonic load or high-frequency crack.
    hz = np.fft.rfftfreq(size, 1 / rate)
    curve = (1 - np.exp(-(hz / 30) ** 4)) / np.sqrt(1 + (hz / 420) ** 8)
    bed = np.fft.irfft(np.fft.rfft(bed) * curve, n=size)
    bed -= bed.mean()
    bed *= min(0.18 / np.sqrt(np.mean(bed ** 2)), 0.65 / np.max(np.abs(bed)))
    pcm = np.rint(bed * 32767).astype('<i2')
    target = SOURCE.with_name('storm_rumble.wav')
    with wave.open(str(target), 'wb') as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(rate)
        handle.writeframes(pcm.tobytes())
    manifest = dict(file=target.name, source=SOURCE.name, source_sha256=digest,
                    provenance='Derivative of existing owner-supplied freesound_community-thunder-big-wav-29190.mp3; original licence metadata not provided',
                    edits='1.2-4.8s rolling tail only; eight periodic 4s Hann overlaps; pace0.82-0.96;30Hz cleanup/420Hz lowpass; mono16-bit PCM; no clap or added synthesis',
                    rate=rate, seconds=len(pcm) / rate, bytes=target.stat().st_size,
                    sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
                    rms=float(np.sqrt(np.mean(bed ** 2))), peak=float(np.max(np.abs(bed))),
                    seam_step=float(abs(int(pcm[0]) - int(pcm[-1])) / 32768))
    target.with_name('storm_rumble_manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(manifest, indent=2))


if __name__ == '__main__':
    main()

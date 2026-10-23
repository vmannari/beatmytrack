"""Encode only the kerb playback derivative and audit its actual decoded audio."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import wave

import numpy as np


ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ffmpeg', default='ffmpeg')
    parser.add_argument('--wsl-ffmpeg', help='Use an existing FFmpeg inside WSL')
    parser.add_argument('--reference', type=Path, help='Prior PCM cue for a matched loudness audit')
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    command = ['wsl.exe', '-e', args.wsl_ffmpeg] if args.wsl_ffmpeg else [args.ffmpeg]

    def audio_path(path):
        value = path.resolve().as_posix()
        return '/mnt/' + value[0].lower() + value[2:] if args.wsl_ffmpeg and value[1:3] == ':/' else value

    def ffmpeg(*arguments):
        return subprocess.run(command + ['-nostdin'] + list(arguments), check=True, capture_output=True)

    def loudness(path):
        result = ffmpeg('-hide_banner', '-i', audio_path(path), '-af',
                        'loudnorm=I=-23:TP=-1:LRA=11:print_format=json', '-f', 'null', '-')
        return float(json.loads(re.search(r'\{.*?\}', result.stderr.decode(), re.S)[0])['input_i'])

    master = ROOT / 'game/assets/audio/vehicles/kerb_roll.wav'
    encoded = master.with_suffix('.ogg')
    with wave.open(str(master)) as recording:
        assert recording.getframerate() == 44100 and recording.getnchannels() == 1 and recording.getsampwidth() == 2
        x = np.frombuffer(recording.readframes(recording.getnframes()), dtype='<i2').astype(float) / 32768
    ffmpeg('-v', 'error', '-y', '-i', audio_path(master), '-map_metadata', '-1',
           '-c:a', 'libvorbis', '-flags:a', '+bitexact', '-q:a', '10', '-fflags', '+bitexact', audio_path(encoded))
    result = ffmpeg('-v', 'error', '-i', audio_path(encoded), '-f', 'f32le', '-acodec', 'pcm_f32le', '-')
    y = np.frombuffer(result.stdout, dtype='<f4').astype(float)
    assert x.shape == y.shape, 'Decoded duration must remain exact'
    hz = np.fft.rfftfreq(len(x), 1 / 44100)
    px, py = abs(np.fft.rfft(x)) ** 2, abs(np.fft.rfft(y)) ** 2
    bands = []
    for low, high in [(0, 200), (200, 1000), (1000, 4000), (4000, 10000), (10000, 20000)]:
        mask = (hz >= low) & (hz < high)
        if px[mask].sum() > px.sum() * 1e-4:
            bands.append(float(10 * np.log10(py[mask].sum() / px[mask].sum())))
    def envelope(values):
        return np.sqrt(np.mean(values.reshape(-1, 2205) ** 2, axis=1))
    stats = {
        'quality': 10,
        'snr_db': float(10 * np.log10(np.mean(x * x) / max(np.mean((x - y) ** 2), 1e-20))),
        'rms_change_db': float(10 * np.log10(np.mean(y * y) / np.mean(x * x))),
        'band_changes_db': bands,
        'envelope_max_change_db': float(np.max(abs(20 * np.log10(envelope(y) / envelope(x))))),
        'peak': float(max(abs(y))), 'seam_step': float(abs(y[0] - y[-1])),
        'seam_reference_step': float(np.quantile(abs(np.diff(x)), .9995)),
        'frames': len(x), 'rate': 44100, 'channels': 1,
    }
    assert stats['snr_db'] >= 30 and abs(stats['rms_change_db']) < .15
    assert max(map(abs, bands)) < .75 and stats['envelope_max_change_db'] < 1
    assert stats['peak'] < 1 and stats['seam_step'] <= max(.008, stats['seam_reference_step'] * 1.5)
    row = dict(stats, master=master.relative_to(ROOT).as_posix(), encoded=encoded.relative_to(ROOT).as_posix(),
               master_sha256=sha(master), encoded_sha256=sha(encoded), master_bytes=master.stat().st_size,
               encoded_bytes=encoded.stat().st_size, duration_seconds=len(x) / 44100, attempts=[stats])
    report = dict(row, master_lufs=loudness(master), decoded_lufs=loudness(encoded))
    if args.reference:
        report['reference_lufs'] = loudness(args.reference)
        assert abs(report['decoded_lufs'] - report['reference_lufs']) <= .5, 'Compare tone at matched loudness'
    manifest_path = ROOT / 'game/assets/audio/compressed/manifest.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    assert sum(item['encoded'] == row['encoded'] for item in manifest['outputs']) == 1
    manifest['outputs'] = [row if item['encoded'] == row['encoded'] else item for item in manifest['outputs']]
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(f"KERB_ENCODE: {len(y)} frames, {stats['snr_db']:.2f} dB SNR, {report['decoded_lufs']:.2f} LUFS, {encoded.stat().st_size} bytes")


if __name__ == '__main__':
    run()

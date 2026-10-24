"""Review the owner's cobblestone reference using a real compact-car recording."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import wave

import numpy as np


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--source-page', type=Path, required=True)
    parser.add_argument('--encoded-source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--wsl-ffmpeg', required=True)
    parser.add_argument('--register-source', action='store_true', help='Register the cleared source for scoped bank rebuilding')
    args = parser.parse_args()
    assert 'creativecommons.org/publicdomain/zero/1.0/' in args.source_page.read_text(encoding='utf-8-sig')
    with wave.open(str(args.source)) as stream:
        rate = stream.getframerate()
        assert rate == 44100 and stream.getnchannels() == 1 and stream.getsampwidth() == 2
        source = np.frombuffer(stream.readframes(stream.getnframes()), '<i2').astype(float)/32768
    # Retain the actual small, uneven tyre/body contacts and their natural timing.
    # Only broad EQ and audition-boundary fades; no gate or transient assembly.
    values = source[8*rate:18*rate].copy()
    hz = np.fft.rfftfreq(len(values), 1/rate)
    eq = (1-np.exp(-(hz/45)**4))*np.exp(-(hz/7500)**4)
    values = np.fft.irfft(np.fft.rfft(values)*eq, n=len(values))
    values -= values.mean()
    fade = round(.012*rate)
    values[:fade] *= np.linspace(0,1,fade)
    values[-fade:] *= np.linspace(1,0,fade)
    args.output.mkdir(parents=True, exist_ok=True)
    target = args.output/'compact-cobblestones.wav'

    def write():
        assert np.isfinite(values).all() and max(abs(values)) < .85
        with wave.open(str(target), 'wb') as stream:
            stream.setnchannels(1)
            stream.setsampwidth(2)
            stream.setframerate(rate)
            stream.writeframes(np.rint(values*32767).astype('<i2').tobytes())

    def measure():
        value = target.resolve().as_posix()
        path = '/mnt/'+value[0].lower()+value[2:] if value[1:3]==':/' else value
        command = ['wsl.exe','-e',args.wsl_ffmpeg,'-nostdin','-hide_banner','-i',path,
                   '-af','loudnorm=I=-23:TP=-1:LRA=11:print_format=json','-f','null','-']
        result = subprocess.run(command, check=True, capture_output=True)
        return float(json.loads(re.search(r'\{.*?\}', result.stderr.decode(), re.S)[0])['input_i'])

    write()
    gain = min(10**((-18.5-measure())/20), .82/max(float(max(abs(values))), 1e-9))
    values *= gain
    write()
    loudness = measure()
    with wave.open(str(target)) as stream:
        assert stream.getnframes() == 10*rate
    sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
    report = {
        'source': 'https://freesound.org/people/orlandorizo/sounds/591078/',
        'author': 'orlandorizo', 'title': 'Car rolling on cobblestone.wav', 'licence': 'CC0-1.0',
        'recordist_description': 'Small compact car on bumpy cobblestones, recorded inside a Suzuki Alto with a Zoom H5',
        'input_quality': 'Public HQ MP3 preview decoded to mono PCM; original 48kHz/24-bit WAV not downloaded',
        'source_cut_s': [8,18], 'seconds': 10, 'rate': rate, 'channels': 1, 'bits': 16,
        'processing': 'Broad 45-7500 Hz EQ, 12ms boundary fades and fixed loudness gain only',
        'integrated_lufs': loudness, 'peak': float(max(abs(values))),
        'encoded_source_sha256': sha(args.encoded_source), 'decoded_source_sha256': sha(args.source),
        'source_page_sha256': sha(args.source_page), 'preview_sha256': sha(target),
        'runtime_changed': False,
    }
    (args.output/'source.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    if args.register_source:
        archive = Path(__file__).resolve().parents[1]/'build/vehicle_audio_sources'
        archive.mkdir(parents=True,exist_ok=True)
        registered = archive/'car_cobblestone_cc0.wav'
        shutil.copy2(args.source,registered)
        record = dict(filename=registered.name, author=report['author'], title=report['title'],
                      source=report['source'], license=report['licence'], quality=report['input_quality'],
                      sha256=sha(registered), encoded_sha256=sha(args.encoded_source),
                      source_page_sha256=sha(args.source_page), rate=rate,
                      download='https://cdn.freesound.org/previews/591/591078_6411813-hq.mp3')
        (archive/'cobblestone_source_manifest.json').write_text(json.dumps([record],indent=2)+'\n',encoding='utf-8')
    print(f'COBBLESTONE_KERB_AUDITION: real compact-car recording; 10 seconds; {loudness:.2f} LUFS; peak {report["peak"]:.4f}; preview only')


if __name__ == '__main__':
    main()

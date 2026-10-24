"""Prepare review-only kerb recordings without changing any game asset."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import wave

import numpy as np


def read(path):
    with wave.open(str(path)) as recording:
        assert recording.getsampwidth() == 2 and recording.getnchannels() == 1
        rate = recording.getframerate()
        values = np.frombuffer(recording.readframes(recording.getnframes()), '<i2').astype(float) / 32768
    return values, rate


def write(path, values, rate):
    assert np.isfinite(values).all() and max(abs(values)) < .85
    with wave.open(str(path), 'wb') as recording:
        recording.setnchannels(1)
        recording.setsampwidth(2)
        recording.setframerate(rate)
        recording.writeframes(np.rint(values * 32767).astype('<i2').tobytes())


def subtract_background(values, rate):
    # Estimate the background floor from the quieter first 2.5 seconds.
    # Retain the phase and changing tyre vibration of the actual recording.
    size, hop = 2048, 512
    window = np.hanning(size)
    padded = np.pad(values, (size, size))
    frames = np.lib.stride_tricks.sliding_window_view(padded, size)[::hop]
    spectrum = np.fft.rfft(frames * window, axis=1)
    magnitude = abs(spectrum)
    profile = np.median(magnitude[round(size/hop):round((2.5*rate+size)/hop)], axis=0)
    gain = np.sqrt(np.maximum(magnitude*magnitude-profile*profile*.8, 0) / np.maximum(magnitude*magnitude, 1e-16))
    gain = np.maximum(gain, .35)
    # Smooth gains to avoid isolated spectral holes and watery gate artifacts.
    gain = sum(np.roll(gain, offset, axis=1) for offset in [-2,-1,0,1,2]) / 5
    output = np.zeros(len(padded))
    weights = np.zeros(len(padded))
    for index, frame in enumerate(np.fft.irfft(spectrum*gain, n=size, axis=1)):
        start = index*hop
        output[start:start+size] += frame*window
        weights[start:start+size] += window*window
    return (output/np.maximum(weights, 1e-10))[size:size+len(values)]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--source-page', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--wsl-ffmpeg', help='Existing offline FFmpeg for matching both auditions to -18.5 LUFS')
    args = parser.parse_args()
    page = args.source_page.read_text(encoding='utf-8-sig')
    assert 'creativecommons.org/publicdomain/zero/1.0/' in page
    values, rate = read(args.source)
    assert rate == 44100
    clean = subtract_background(values, rate)[round(4.0*rate):round(10.0*rate)]
    args.output.mkdir(parents=True, exist_ok=True)
    report = {'source': 'https://freesound.org/people/bsumusictech/sounds/62652/',
              'author': 'bsumusictech', 'title': 'rumble strip exit 41.wav',
              'licence': 'CC0-1.0', 'input': 'Public HQ MP3 preview decoded to mono PCM; original WAV requires sign-in',
              'decoded_source_sha256': hashlib.sha256(args.source.read_bytes()).hexdigest(),
              'source_cut_seconds': [4.0, 10.0], 'runtime_changed': False, 'options': []}
    for label, low, high, emphasis in [('A-natural', 55, 6500, 0), ('B-close', 120, 5800, .8)]:
        hz = np.fft.rfftfreq(len(clean), 1/rate)
        eq = (1-np.exp(-(hz/low)**4))*np.exp(-(hz/high)**4)
        eq *= 1+emphasis*np.exp(-((hz-800)/600)**2)
        result = np.fft.irfft(np.fft.rfft(clean)*eq, n=len(clean))
        result -= result.mean()
        result *= min(.13/np.sqrt(np.mean(result*result)), .78/max(abs(result)))
        fade = round(.012*rate)
        result[:fade] *= np.linspace(0,1,fade)
        result[-fade:] *= np.linspace(1,0,fade)
        target = args.output / (label+'.wav')
        write(target, result, rate)
        lufs = None
        if args.wsl_ffmpeg:
            value = target.resolve().as_posix()
            source_path = '/mnt/'+value[0].lower()+value[2:] if value[1:3]==':/' else value
            command = ['wsl.exe','-e',args.wsl_ffmpeg,'-nostdin','-hide_banner','-i',source_path,
                       '-af','loudnorm=I=-23:TP=-1:LRA=11:print_format=json','-f','null','-']
            measured = subprocess.run(command, check=True, capture_output=True)
            lufs = float(json.loads(re.search(r'\{.*?\}', measured.stderr.decode(), re.S)[0])['input_i'])
            result *= 10**((-18.5-lufs)/20)
            write(target, result, rate)
            measured = subprocess.run(command, check=True, capture_output=True)
            lufs = float(json.loads(re.search(r'\{.*?\}', measured.stderr.decode(), re.S)[0])['input_i'])
            assert abs(lufs+18.5)<.1
        report['options'].append({'file': target.name, 'seconds': len(result)/rate,
            'peak': float(max(abs(result))), 'rms': float(np.sqrt(np.mean(result*result))),
            'integrated_lufs': lufs,
            'sha256': hashlib.sha256(target.read_bytes()).hexdigest()})
    (args.output/'source.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print('RECORDED_KERB_AUDITION: two 6-second recorded options; no game assets changed')


if __name__ == '__main__':
    main()

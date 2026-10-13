"""Build synchronized English narration, bilingual captions, and an original music bed.
Uses only Python's standard library, macOS say, and FFmpeg.
"""
from pathlib import Path
import array
import json
import math
import subprocess
import wave

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'media/intro-en'
WORK = OUT / 'working'
FFMPEG = '/usr/local/Cellar/ffmpeg/9.0.2/bin/ffmpeg'
RATE = 44100
spoken = {
    'hook': ['When your app breaks,', 'your logs should tell the story.'],
    'brand': ['Meet M X Logger.', 'Cross-platform logging for i O S, Android, and Flutter.'],
    'core': ['A native C plus plus core uses memory-mapped files', 'and FlatBuffers to write compact logs.'],
    'storage': ['Encrypt log files with A E S.', 'And control rotation, retention, and disk usage.'],
    'search': ['Import dot M X files into the analyzer.', 'Search by keyword, level, time, name, or tag.'],
    'detail': ['Expand structured J SON.', 'And inspect nearby records to understand what happened.'],
    'embed': ['Analyze on your desktop.', 'Or inspect logs right inside your Flutter app.'],
    'code': ['Add M X Logger to your project.', 'And start capturing useful context.'],
    'cta': ['M X Logger. Write fast. Debug smarter.', 'Explore the project on GitHub.'],
}


def read_wav(path):
    with wave.open(str(path)) as stream:
        assert stream.getnchannels() == 1 and stream.getsampwidth() == 2
        assert stream.getframerate() == RATE
        result = array.array('h', stream.readframes(stream.getnframes()))
    return result


def write_wav(path, samples, channels=1):
    with wave.open(str(path), 'wb') as stream:
        stream.setnchannels(channels)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(samples.tobytes())


def timestamp(seconds):
    ms = round(seconds * 1000)
    return f'{ms//3600000:02d}:{ms//60000%60:02d}:{ms//1000%60:02d},{ms%1000:03d}'


def main():
    WORK.mkdir(parents=True, exist_ok=True)
    board = json.loads((OUT / 'source/storyboard.json').read_text())
    speech = array.array('h')
    cues = []
    silence = lambda seconds: array.array('h', [0]) * round(seconds * RATE)
    for scene in board['scenes']:
        start_sample = len(speech)
        scene['start'] = len(speech) / RATE
        speech.extend(silence(0.38))
        scene_cues = []
        for index, phrase in enumerate(spoken[scene['id']]):
            aiff = WORK / f"{scene['id']}-{index}.aiff"
            wav = aiff.with_suffix('.wav')
            if not wav.exists():
                subprocess.run(['say', '-v', board['voice'], '-r', str(board['voice_rate']), '-o', str(aiff), phrase], check=True)
                subprocess.run([FFMPEG, '-v', 'error', '-y', '-i', str(aiff), '-ac', '1', '-ar', str(RATE), '-c:a', 'pcm_s16le', str(wav)], check=True)
            samples = read_wav(wav)
            cue = {'start': len(speech) / RATE, 'end': (len(speech) + len(samples)) / RATE,
                   'en': scene['captions'][index][0], 'zh': scene['captions'][index][1]}
            cues.append(cue)
            scene_cues.append(cue)
            speech.extend(samples)
            if index == 0:
                speech.extend(silence(0.06))
        speech.extend(silence(0.32 if scene['id'] != 'cta' else 1.2))
        # Round scene boundaries to whole video frames.
        target_frames = math.ceil(len(speech) / RATE * board['fps'])
        speech.extend(array.array('h', [0]) * (round(target_frames / board['fps'] * RATE) - len(speech)))
        scene['duration'] = (len(speech) - start_sample) / RATE
        scene['cues'] = scene_cues
        print(f"{scene['id']}: {scene['duration']:.2f}s", flush=True)
    board['duration'] = len(speech) / RATE
    board['cues'] = cues
    (WORK / 'timeline.json').write_text(json.dumps(board, ensure_ascii=False, indent=2))
    (OUT / 'MXLogger_intro_bilingual.srt').write_text('\n\n'.join(
        f"{i+1}\n{timestamp(c['start'])} --> {timestamp(c['end'])}\n{c['en']}\n{c['zh']}"
        for i, c in enumerate(cues)) + '\n')
    (OUT / 'MXLogger_intro_english.srt').write_text('\n\n'.join(
        f"{i+1}\n{timestamp(c['start'])} --> {timestamp(c['end'])}\n{c['en']}"
        for i, c in enumerate(cues)) + '\n')
    write_wav(WORK / 'narration.wav', speech)
    # Original electronic underscore: gentle pads and a light arpeggio, no sampled audio.
    chords = [(130.8128, 155.5635, 195.9977), (103.8262, 130.8128, 155.5635),
              (155.5635, 195.9977, 233.0819), (116.5409, 146.8324, 174.6141)]
    beat = 60 / 104
    stereo = array.array('h')
    for i, voice in enumerate(speech):
        t = i / RATE
        chord = chords[int(t / (beat * 8)) % len(chords)]
        fade = min(1.0, t / 1.5, max(0.0, (board['duration'] - t) / 2))
        pulse_time = t % beat
        arp_frequency = chord[int(t / beat) % 3] * 4
        arp = math.sin(2 * math.pi * arp_frequency * t) * math.exp(-pulse_time * 10) * 0.005
        left_pad = sum(math.sin(2 * math.pi * f * t) for f in chord) * 0.0035
        right_pad = sum(math.sin(2 * math.pi * (f * 1.0012) * t) for f in chord) * 0.0035
        for pad in (left_pad, right_pad):
            value = voice + round((pad + arp) * fade * 32767)
            stereo.append(max(-32768, min(32767, value)))
    write_wav(WORK / 'mix.wav', stereo, channels=2)
    print(f"Complete: {board['duration']:.2f}s / {len(cues)} bilingual cues", flush=True)


if __name__ == '__main__':
    main()

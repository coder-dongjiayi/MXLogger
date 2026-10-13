"""Verify playback streams and subtitle synchronization, then fully decode the MP4."""
import json
from pathlib import Path
import subprocess

OUT = Path(__file__).resolve().parents[1]
BIN = Path('/usr/local/Cellar/ffmpeg/9.0.2/bin')
video = OUT / 'MXLogger_intro_EN_ZH_vertical.mp4'
info = json.loads(subprocess.check_output([
    str(BIN / 'ffprobe'), '-v', 'error', '-show_format', '-show_streams', '-of', 'json', str(video)]))
v = next(s for s in info['streams'] if s['codec_type'] == 'video')
a = next(s for s in info['streams'] if s['codec_type'] == 'audio')
assert (v['width'], v['height']) == (1080, 1920)
assert v['codec_name'] == 'h264' and v['pix_fmt'] == 'yuv420p'
assert v['avg_frame_rate'] == '30/1'
assert a['codec_name'] == 'aac' and a['channels'] == 2
assert a['sample_rate'] == '48000'
timeline = json.loads((OUT / 'working/timeline.json').read_text())
duration = float(info['format']['duration'])
assert abs(duration - timeline['duration']) < 0.1
assert abs(float(v['duration']) - float(a['duration'])) < 0.1
previous_end = 0
for cue in timeline['cues']:
    assert previous_end <= cue['start'] < cue['end'] <= duration
    assert cue['en'] and cue['zh']
    previous_end = cue['end']
subprocess.run([str(BIN / 'ffmpeg'), '-v', 'error', '-xerror', '-i', str(video), '-f', 'null', '-'], check=True)
summary = {'duration_seconds': duration, 'resolution': '1080x1920', 'aspect_ratio': '9:16',
    'fps': 30, 'video_codec': 'H.264', 'audio_codec': 'AAC', 'audio_sample_rate': 48000,
    'size_bytes': int(info['format']['size']), 'subtitle_cues': len(timeline['cues']),
    'narration': 'English / synthesized Samantha voice', 'burned_subtitles': ['English', 'Simplified Chinese'],
    'full_decode': 'passed'}
(OUT / 'working/validation.json').write_text(json.dumps(summary, indent=2))
print(json.dumps(summary, ensure_ascii=False, indent=2))

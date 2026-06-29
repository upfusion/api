# UPFUSION Audio API

Private audio streaming API for [upfusion.net](https://upfusion.net). Serves MP3 streams and SVG waveforms via nginx with anti-hotlinking, rate limiting, and CORS restrictions.

## Architecture

```
upfusion.net → proxy (i.upfusion.net) → upfusion-api (nginx:8080) → /music/{band}/{album}/{file}
```

## Music Library

```
music/
└── upfusion/
    ├── alternative/          # Alternative / experimental tracks
    │   ├── 01-Orthopraxy.mp3
    │   ├── 02-Genome.mp3
    │   ├── 03-Extinction.mp3
    │   ├── 04-Axiom.mp3
    │   ├── 05-Noir.mp3
    │   └── waveforms/        # SVG waveform visualizations
    └── jazz/                 # Jazz compositions
        ├── 01-Spring-Vibes.mp3
        ├── 02-D-Flat-Jazz.mp3
        ├── 03-Cronus-Fall.mp3
        ├── 04-Hypnos-Prelude.mp3
        ├── 05-Poseidon-Ocean.mp3
        ├── 06-Axiom.mp3
        ├── 07-Noir.mp3
        ├── 08-Sigma.mp3
        └── waveforms/
```

## Endpoints

| Method | URL | Description |
|--------|-----|-------------|
| `GET` | `/health` | Health check |
| `GET` | `/stream/{band}/{album}/{slug}` | Stream audio (MP3) |
| `GET` | `/waveform/{band}/{album}/{slug}` | Waveform image (SVG) |

**Examples:**
```
GET /stream/upfusion/jazz/cronus-fall     → 03-Cronus-Fall.mp3
GET /waveform/upfusion/jazz/cronus-fall   → waveforms/03-Cronus-Fall.svg
GET /stream/upfusion/alternative/genome   → 02-Genome.mp3
```

## Security

- **Anti-hotlinking**: Only requests with `Referer: *upfusion.net*` are accepted (403 otherwise)
- **Rate limiting**: 10 req/s per IP with burst allowance
- **CORS**: Restricted to `https://upfusion.net`
- **No directory listing**: `autoindex off`
- **Content-Type enforcement**: Forces `audio/mpeg` / `image/svg+xml`, prevents MIME sniffing

## Generating Waveforms

SVG waveforms are 200-bar visualizations (800×100px, white fill) generated from MP3 files using ffmpeg + Python.

**Requirements:** `ffmpeg`, `python3`

```bash
# Generate waveform for a single track
python3 -c "
import subprocess, struct, math, sys

mp3, svg = sys.argv[1], sys.argv[2]
raw = subprocess.run(['ffmpeg', '-i', mp3, '-f', 's16le', '-acodec', 'pcm_s16le', '-ar', '44100', '-ac', '1', '-'], capture_output=True).stdout
samples = struct.unpack(f'<{len(raw)//2}h', raw)
bars = [math.sqrt(sum(s*s for s in samples[i*len(samples)//200:(i+1)*len(samples)//200]) / (len(samples)//200)) for i in range(200)]
mx = max(bars)
bars = [b/mx for b in bars]
lines = ['<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 799 100\" preserveAspectRatio=\"none\">', '  <style>rect{fill:white}</style>']
lines += [f'  <rect x=\"{i*4}\" y=\"{(100-max(4,int(a*96)))//2}\" width=\"3\" height=\"{max(4,int(a*96))}\" rx=\"1\"/>' for i, a in enumerate(bars)]
lines.append('</svg>')
open(svg, 'w').write('\n'.join(lines) + '\n')
print(f'Generated: {svg}')
" input.mp3 output.svg

# Generate waveforms for all tracks in a folder
for f in music/upfusion/jazz/*.mp3; do
    name=$(basename "${f%.mp3}")
    python3 gen_waveform.py "$f" "music/upfusion/jazz/waveforms/${name}.svg"
done
```

## Usage

```bash
make help           # Show all commands
make local          # Start locally on port 8080
make deploy         # Deploy to production
make test           # Run endpoint tests
make reload         # Reload nginx config (zero downtime)
make logs           # Follow container logs
```

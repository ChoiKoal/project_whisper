#!/usr/bin/env python3
"""v0.4.0-C procedural audio synthesizer for Project Whisper.

Deterministic (fixed RNG seed), stdlib-only. Generates 22050 Hz 16-bit mono WAVs
into assets/audio/. No external assets — every sound is synthesized from oscillators,
noise, and simple envelopes so the whole soundscape ships in the repo and stays small.

Run:  python3 tools_gen_audio.py
Output: assets/audio/<name>.wav for every entry in SPECS.

Design notes:
  - SFX are short (< 1s) one-shots. Ambience/BGM are seamless loops (first and last
    samples matched, whole-cycle melodies) so Godot's loop_mode=forward is gapless.
  - A gentle master limiter + fade guards clipping and click-free edges.
  - The palette is melancholic/warm per the art guide: Am-F-C-G pad chords, music-box
    pentatonic melody, sparse night crickets, soft day wind.
"""

import math
import os
import struct
import random
import wave

SR = 22050            # sample rate (Hz)
AUDIO_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets", "audio")

rng = random.Random(20400703)   # fixed seed → deterministic output

# ---- note frequencies (equal temperament, A4=440) -------------------------
def note(n):
    """MIDI-ish note name -> Hz. e.g. note('A4'), note('C5')."""
    names = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6,
             "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
    name = n[:-1]
    octave = int(n[-1])
    midi = 12 * (octave + 1) + names[name]
    return 440.0 * (2 ** ((midi - 69) / 12.0))


# ---- primitive buffers ----------------------------------------------------
def buf(seconds):
    return [0.0] * int(SR * seconds)


def sine(freq, t):
    return math.sin(2 * math.pi * freq * t)


def triangle(freq, t):
    x = (freq * t) % 1.0
    return 4 * abs(x - 0.5) - 1.0


def add_tone(b, freq, start, dur, amp, wave_fn=sine, attack=0.005, decay=None,
             vibrato=0.0, vib_rate=5.0):
    """Add a tone with a simple AD/ADSR-ish envelope into buffer b."""
    n0 = int(start * SR)
    n1 = min(len(b), int((start + dur) * SR))
    if decay is None:
        decay = dur * 0.7
    for i in range(n0, n1):
        t = (i - n0) / SR
        # envelope: linear attack, exp-ish decay tail
        if t < attack:
            env = t / attack
        else:
            env = math.exp(-(t - attack) / max(1e-4, decay))
        f = freq * (1.0 + vibrato * math.sin(2 * math.pi * vib_rate * t))
        b[i] += amp * env * wave_fn(f, (i / SR))


def add_noise(b, start, dur, amp, decay=None, lp=1.0):
    """Add a short noise burst (optionally low-passed via 1-pole)."""
    n0 = int(start * SR)
    n1 = min(len(b), int((start + dur) * SR))
    if decay is None:
        decay = dur * 0.5
    prev = 0.0
    for i in range(n0, n1):
        t = (i - n0) / SR
        env = math.exp(-t / max(1e-4, decay))
        w = rng.uniform(-1, 1)
        prev = prev + lp * (w - prev)   # 1-pole lowpass
        b[i] += amp * env * prev


def fade_edges(b, ms=8):
    n = int(SR * ms / 1000.0)
    n = min(n, len(b) // 2)
    for i in range(n):
        g = i / n
        b[i] *= g
        b[-1 - i] *= g


def normalize(b, peak=0.85):
    m = max((abs(x) for x in b), default=0.0)
    if m < 1e-9:
        return
    g = peak / m
    for i in range(len(b)):
        b[i] *= g


def soft_limit(b, thr=0.9):
    for i in range(len(b)):
        x = b[i]
        if x > thr:
            b[i] = thr + (1 - thr) * math.tanh((x - thr) / (1 - thr))
        elif x < -thr:
            b[i] = -thr + (1 - thr) * math.tanh((x + thr) / (1 - thr))


def write_wav(name, b, loop=False):
    os.makedirs(AUDIO_DIR, exist_ok=True)
    soft_limit(b)
    path = os.path.join(AUDIO_DIR, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for x in b:
            v = int(max(-1.0, min(1.0, x)) * 32767)
            frames += struct.pack("<h", v)
        w.writeframes(bytes(frames))
    size = os.path.getsize(path)
    print("  %-18s %6.1f KB  %5.2fs%s" % (name, size / 1024.0, len(b) / SR,
                                          "  [loop]" if loop else ""))
    return size


# ==== individual sounds ====================================================

def gather_pop():
    b = buf(0.18)
    add_tone(b, note("C6"), 0.0, 0.12, 0.6, vibrato=0.0, attack=0.002, decay=0.05)
    add_tone(b, note("G6"), 0.02, 0.12, 0.35, attack=0.002, decay=0.04)
    add_noise(b, 0.0, 0.03, 0.25, decay=0.01, lp=0.5)
    normalize(b, 0.8); fade_edges(b); return b, False


def place_thud():
    b = buf(0.28)
    add_tone(b, note("C3"), 0.0, 0.2, 0.9, wave_fn=sine, attack=0.002, decay=0.06)
    add_tone(b, note("C2"), 0.0, 0.22, 0.6, attack=0.002, decay=0.08)
    add_noise(b, 0.0, 0.09, 0.5, decay=0.03, lp=0.25)
    normalize(b, 0.9); fade_edges(b); return b, False


def fuse_bubble():
    # ~1s loop of gentle rising bubbles
    dur = 1.0
    b = buf(dur)
    t = 0.0
    while t < dur - 0.06:
        f = note("A4") * (1.0 + 0.5 * rng.random())
        add_tone(b, f, t, 0.08, 0.22, attack=0.005, decay=0.03,
                 vibrato=0.04, vib_rate=18)
        t += rng.uniform(0.06, 0.14)
    normalize(b, 0.6); fade_edges(b, 20); return b, True


def fuse_success():
    # ascending arpeggio chime C-E-G-C
    b = buf(0.7)
    for i, nm in enumerate(["C5", "E5", "G5", "C6"]):
        add_tone(b, note(nm), i * 0.09, 0.4, 0.5, wave_fn=triangle,
                 attack=0.004, decay=0.28)
    normalize(b, 0.8); fade_edges(b); return b, False


def fuse_discovery():
    # sparkle sting: high shimmering cluster + rising tail
    b = buf(0.8)
    for i, nm in enumerate(["G5", "B5", "D6", "G6", "B6"]):
        add_tone(b, note(nm), i * 0.05, 0.5, 0.32, wave_fn=triangle,
                 attack=0.003, decay=0.3, vibrato=0.02, vib_rate=9)
    add_noise(b, 0.0, 0.4, 0.06, decay=0.25, lp=0.9)
    normalize(b, 0.8); fade_edges(b); return b, False


def fuse_fail():
    # dull puff — low muffled thud + noise
    b = buf(0.3)
    add_tone(b, note("F3"), 0.0, 0.15, 0.4, attack=0.004, decay=0.06)
    add_tone(b, note("D3"), 0.01, 0.16, 0.3, attack=0.004, decay=0.06)
    add_noise(b, 0.0, 0.12, 0.4, decay=0.04, lp=0.2)
    normalize(b, 0.6); fade_edges(b); return b, False


def ui_click():
    b = buf(0.08)
    add_tone(b, note("A5"), 0.0, 0.05, 0.5, attack=0.001, decay=0.02)
    add_noise(b, 0.0, 0.015, 0.2, decay=0.006, lp=0.6)
    normalize(b, 0.7); fade_edges(b, 4); return b, False


def ui_open():
    b = buf(0.22)
    add_tone(b, note("E5"), 0.0, 0.14, 0.4, wave_fn=triangle, attack=0.003, decay=0.09)
    add_tone(b, note("B5"), 0.04, 0.14, 0.3, wave_fn=triangle, attack=0.003, decay=0.09)
    normalize(b, 0.7); fade_edges(b); return b, False


def ui_close():
    b = buf(0.22)
    add_tone(b, note("B5"), 0.0, 0.13, 0.4, wave_fn=triangle, attack=0.003, decay=0.08)
    add_tone(b, note("E5"), 0.04, 0.13, 0.3, wave_fn=triangle, attack=0.003, decay=0.08)
    normalize(b, 0.7); fade_edges(b); return b, False


def quest_advance():
    # soft two-note chime, warm
    b = buf(0.6)
    add_tone(b, note("D5"), 0.0, 0.4, 0.45, wave_fn=triangle, attack=0.006, decay=0.3)
    add_tone(b, note("A5"), 0.12, 0.4, 0.4, wave_fn=triangle, attack=0.006, decay=0.3)
    normalize(b, 0.75); fade_edges(b); return b, False


def footstep(variant):
    b = buf(0.12)
    lp = 0.18 if variant == 0 else 0.28
    add_noise(b, 0.0, 0.07, 0.5, decay=0.02, lp=lp)
    add_tone(b, note("A2") if variant == 0 else note("C3"), 0.0, 0.05, 0.18,
             attack=0.002, decay=0.02)
    normalize(b, 0.45); fade_edges(b, 4); return b, False


def bush_bloom():
    # bloom swell: rising soft pad + shimmer
    b = buf(1.2)
    for i, nm in enumerate(["C4", "E4", "G4", "C5"]):
        add_tone(b, note(nm), 0.0, 1.1, 0.22, wave_fn=triangle,
                 attack=0.25 + i * 0.05, decay=0.6, vibrato=0.02, vib_rate=4)
    for i, nm in enumerate(["G5", "C6", "E6"]):
        add_tone(b, note(nm), 0.5 + i * 0.08, 0.5, 0.14, wave_fn=triangle,
                 attack=0.02, decay=0.3)
    normalize(b, 0.7); fade_edges(b, 20); return b, False


def clear_fanfare():
    # warm 3-chord resolution F - C - (Am->) G  ... ending on C major
    b = buf(2.4)
    chords = [
        (["F3", "A3", "C4"], 0.0),
        (["C3", "E3", "G3"], 0.7),
        (["C4", "E4", "G4", "C5"], 1.4),
    ]
    for names, start in chords:
        for nm in names:
            add_tone(b, note(nm), start, 1.0, 0.28, wave_fn=triangle,
                     attack=0.02, decay=0.7, vibrato=0.015, vib_rate=4.5)
    # gentle melody topline
    for i, nm in enumerate(["C5", "D5", "E5", "G5"]):
        add_tone(b, note(nm), 1.4 + i * 0.12, 0.5, 0.2, wave_fn=triangle,
                 attack=0.01, decay=0.3)
    normalize(b, 0.8); fade_edges(b, 30); return b, False


def night_amb():
    # sparse crickets-ish loop, 8s
    dur = 8.0
    b = buf(dur)
    t = 0.2
    while t < dur - 0.3:
        # cricket chirp: fast amplitude-modulated high tone
        f = note("A7") * (0.96 + 0.08 * rng.random())
        chirp = 0.10 + 0.04 * rng.random()
        n0 = int(t * SR); n1 = min(len(b), int((t + chirp) * SR))
        for i in range(n0, n1):
            tt = (i - n0) / SR
            am = 0.5 + 0.5 * math.sin(2 * math.pi * 40 * tt)
            env = math.exp(-tt / (chirp * 0.4))
            b[i] += 0.12 * am * env * math.sin(2 * math.pi * f * (i / SR))
        t += rng.uniform(0.35, 0.9)
    # low drone bed
    add_tone(b, note("A2"), 0.0, dur, 0.05, attack=1.0, decay=dur,
             vibrato=0.01, vib_rate=0.2)
    normalize(b, 0.5); fade_edges(b, 40); return b, True


def day_amb():
    # soft wind loop, 8s — filtered noise slowly panned in amplitude
    dur = 8.0
    b = buf(dur)
    prev = 0.0
    for i in range(len(b)):
        tt = i / SR
        gust = 0.5 + 0.5 * math.sin(2 * math.pi * 0.12 * tt) \
                   + 0.25 * math.sin(2 * math.pi * 0.37 * tt + 1.3)
        gust = max(0.0, gust) * 0.5
        w = rng.uniform(-1, 1)
        prev = prev + 0.04 * (w - prev)   # heavy lowpass → wind
        b[i] += 0.6 * gust * prev
    # faint tonal bed
    add_tone(b, note("C3"), 0.0, dur, 0.03, attack=1.5, decay=dur)
    normalize(b, 0.45); fade_edges(b, 60); return b, True


def _bgm(dark=False):
    # ~48s gentle melancholic loop: Am-F-C-G pad + sparse music-box pentatonic melody.
    dur = 48.0
    b = buf(dur)
    prog = [("A", ["A3", "C4", "E4"]), ("F", ["F3", "A3", "C4"]),
            ("C", ["C4", "E4", "G4"]), ("G", ["G3", "B3", "D4"])]
    bar = dur / 8.0   # 8 bars over the loop (two trips through the 4-chord cycle)
    oct_shift = -1 if dark else 0
    for barn in range(8):
        _, names = prog[barn % 4]
        start = barn * bar
        for nm in names:
            n2 = nm[:-1] + str(int(nm[-1]) + oct_shift)
            add_tone(b, note(n2), start, bar * 1.02, 0.14, wave_fn=triangle,
                     attack=0.4, decay=bar * 0.9, vibrato=0.012, vib_rate=3.0)
    # sparse pentatonic music-box melody (A minor pentatonic: A C D E G)
    penta = ["A4", "C5", "D5", "E5", "G5", "E5", "D5", "C5"]
    if dark:
        penta = ["A4", "C5", "D5", "E5", "D5", "C5", "A4", "G4"]
    mt = 1.0
    idx = 0
    while mt < dur - 1.0:
        nm = penta[idx % len(penta)]
        n2 = nm[:-1] + str(int(nm[-1]) + oct_shift)
        amp = 0.16 if not dark else 0.13
        add_tone(b, note(n2), mt, 0.9, amp, wave_fn=triangle,
                 attack=0.006, decay=0.6)
        mt += rng.choice([1.5, 2.0, 2.0, 3.0])
        idx += 1
    normalize(b, 0.62 if not dark else 0.55)
    fade_edges(b, 60)
    return b, True


def bgm_day():
    return _bgm(dark=False)


def bgm_night():
    return _bgm(dark=True)


# ==== v0.5.0 phase C: portal SFX ==========================================

def portal_hum():
    # A short (~1.2s) low violet drone with a slow beat — the flickering-portal hum.
    dur = 1.2
    b = buf(dur)
    add_tone(b, note("D3"), 0.0, dur, 0.30, wave_fn=sine, attack=0.2, decay=dur,
             vibrato=0.03, vib_rate=2.2)
    add_tone(b, note("A3"), 0.0, dur, 0.16, wave_fn=sine, attack=0.3, decay=dur,
             vibrato=0.04, vib_rate=3.1)
    add_tone(b, note("D4") * 1.005, 0.0, dur, 0.10, wave_fn=sine, attack=0.4, decay=dur)
    normalize(b, 0.5); fade_edges(b, 40); return b, False


def travel_whoosh():
    # Rising filtered-noise swell + an upward tone glide — entering the portal.
    dur = 1.1
    b = buf(dur)
    prev = 0.0
    for i in range(len(b)):
        tt = i / SR
        swell = (tt / dur)              # rise 0→1
        w = rng.uniform(-1, 1)
        prev = prev + 0.10 * (w - prev)  # lowpass noise
        b[i] += 0.5 * swell * swell * prev
    # upward glide (pitch bend) using vibrato-free tones stepping up
    for i, nm in enumerate(["D4", "F4", "A4", "D5", "A5"]):
        add_tone(b, note(nm), 0.15 + i * 0.16, 0.5, 0.20, wave_fn=triangle,
                 attack=0.02, decay=0.28)
    normalize(b, 0.7); fade_edges(b, 20); return b, False


def portal_ignite():
    # A bright ignition chime — the portal opens (CS-05). Rising sparkle + warm swell.
    dur = 1.4
    b = buf(dur)
    for i, nm in enumerate(["D5", "A5", "D6", "F#6", "A6"]):
        add_tone(b, note(nm), i * 0.06, 0.7, 0.30, wave_fn=triangle,
                 attack=0.004, decay=0.4, vibrato=0.02, vib_rate=8)
    for i, nm in enumerate(["D3", "A3", "D4"]):
        add_tone(b, note(nm), 0.0, dur, 0.16, wave_fn=sine, attack=0.15, decay=dur)
    add_noise(b, 0.0, 0.5, 0.06, decay=0.3, lp=0.9)
    normalize(b, 0.8); fade_edges(b, 24); return b, False


# ==== L2-3: power / gate SFX ==============================================

def power_hum():
    # (L2-3) A machine coming to life: a low electric 60Hz-ish hum with a rising
    # harmonic swell — plays when a 배전반/발전기 energizes (시안 발광 점등의 소리).
    dur = 1.3
    b = buf(dur)
    # low mains hum (steady) + its octave, both with a slow tremolo (AM) beat.
    for i in range(len(b)):
        tt = i / SR
        env = min(1.0, tt / 0.25)              # 0.25s power-up ramp
        trem = 0.85 + 0.15 * math.sin(2 * math.pi * 5.0 * tt)  # 5Hz AM flicker
        val = 0.30 * math.sin(2 * math.pi * 60.0 * tt)
        val += 0.16 * math.sin(2 * math.pi * 120.0 * tt)
        val += 0.10 * math.sin(2 * math.pi * 180.0 * tt)
        b[i] += env * trem * val
    # a rising cyan "power settles" tone glide at the end.
    for i, nm in enumerate(["A3", "E4", "A4"]):
        add_tone(b, note(nm), 0.5 + i * 0.14, 0.5, 0.14, wave_fn=triangle,
                 attack=0.02, decay=0.4)
    normalize(b, 0.6); fade_edges(b, 30); return b, False


def power_spark():
    # (L2-3) A short electric spark/zap — the socket sparks as the item is mounted
    # (전지/퓨즈/코어 장착 순간). Bright crackle noise + a quick high ping.
    dur = 0.35
    b = buf(dur)
    add_noise(b, 0.0, 0.12, 0.5, decay=0.06, lp=0.6)   # sharp crackle
    add_noise(b, 0.02, 0.18, 0.22, decay=0.12, lp=0.9)  # airy tail
    add_tone(b, note("E6"), 0.0, 0.14, 0.28, wave_fn=triangle, attack=0.002, decay=0.1)
    add_tone(b, note("B6"), 0.01, 0.10, 0.18, wave_fn=triangle, attack=0.002, decay=0.07)
    normalize(b, 0.85); fade_edges(b, 6); return b, False


# ==== driver ===============================================================

SPECS = [
    ("gather_pop", gather_pop),
    ("place_thud", place_thud),
    ("fuse_bubble", fuse_bubble),
    ("fuse_success", fuse_success),
    ("fuse_discovery", fuse_discovery),
    ("fuse_fail", fuse_fail),
    ("ui_click", ui_click),
    ("ui_open", ui_open),
    ("ui_close", ui_close),
    ("quest_advance", quest_advance),
    ("footstep_grass1", lambda: footstep(0)),
    ("footstep_grass2", lambda: footstep(1)),
    ("bush_bloom", bush_bloom),
    ("clear_fanfare", clear_fanfare),
    ("night_amb", night_amb),
    ("day_amb", day_amb),
    ("bgm_day", bgm_day),
    ("bgm_night", bgm_night),
    # v0.5.0 phase C portal SFX.
    ("portal_hum", portal_hum),
    ("travel_whoosh", travel_whoosh),
    ("portal_ignite", portal_ignite),
    # L2-3 power / gate SFX.
    ("power_hum", power_hum),
    ("power_spark", power_spark),
]


def main():
    # Optional args = generate ONLY those names (v0.5.0: add the portal SFX without
    # clobbering the CC0 BGM / retired synth ambience). No args = regenerate everything.
    import sys
    wanted = set(sys.argv[1:])
    print("=== Project Whisper audio synth (22050Hz 16-bit mono) ===")
    total = 0
    count = 0
    for name, fn in SPECS:
        if wanted and name not in wanted:
            continue
        b, loop = fn()
        total += write_wav(name, b, loop)
        count += 1
    print("--- %d files, %.2f MB total ---" % (count, total / (1024.0 * 1024.0)))


if __name__ == "__main__":
    main()

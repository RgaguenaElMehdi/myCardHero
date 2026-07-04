#!/usr/bin/env python3
"""Procedural audio v2: layered SFX (sub + transient + shaped noise + echo)
and multi-voice music (pads, bass, plucked arpeggios, synthesized drums).
Pure stdlib. 44.1 kHz 16-bit mono WAV into assets/audio/.

Usage: python tools/gen_sfx.py [--force]
"""

import math
import random
import struct
import sys
import wave
from pathlib import Path

SR = 44100
ROOT = Path(__file__).resolve().parent.parent
SFX_DIR = ROOT / "assets" / "audio" / "sfx"
MUSIC_DIR = ROOT / "assets" / "audio" / "music"

# --- rendering helpers -------------------------------------------------


def save(path: Path, samples: list[float], peak_target: float = 0.88) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    peak = max(1e-6, max(abs(s) for s in samples))
    norm = peak_target / peak
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s * norm)) * 32767))
            for s in samples))
    print(f"OK {path.relative_to(ROOT)} ({len(samples) / SR:.1f}s)")


def silence(dur: float) -> list[float]:
    return [0.0] * int(dur * SR)


def mix_into(buf: list[float], src: list[float], at: float = 0.0, gain: float = 1.0) -> None:
    off = int(at * SR)
    for i, s in enumerate(src):
        j = off + i
        if 0 <= j < len(buf):
            buf[j] += s * gain


def mix(*layers: list[float]) -> list[float]:
    buf = silence(max(len(l) for l in layers) / SR)
    for l in layers:
        mix_into(buf, l)
    return buf


def echo(samples: list[float], delay: float = 0.16, feedback: float = 0.35,
         taps: int = 3) -> list[float]:
    d = int(delay * SR)
    out = samples + [0.0] * d * taps
    for i in range(d, len(out)):
        out[i] += out[i - d] * feedback
    return out


def env_exp(i: int, n: int, attack: float = 0.005, k: float = 5.0) -> float:
    t = i / n
    a = min(1.0, (i / SR) / max(attack, 1e-4))
    return a * math.exp(-t * k)


def env_ar(i: int, n: int, attack: float, release: float) -> float:
    t = i / n
    return min(1.0, t / max(attack, 1e-4)) * min(1.0, (1.0 - t) / max(release, 1e-4))


def tone(dur: float, f0: float, f1: float | None = None,
         partials: list[tuple[float, float]] | None = None, amp: float = 1.0,
         attack: float = 0.004, k: float = 5.0, vib_hz: float = 0.0,
         vib_amt: float = 0.0, exp_sweep: bool = True) -> list[float]:
    """Additive tone with exponential decay envelope and pitch sweep."""
    n = int(dur * SR)
    f1 = f0 if f1 is None else f1
    partials = partials or [(1.0, 1.0)]
    out = []
    phase = 0.0
    for i in range(n):
        t = i / n
        f = f0 * (f1 / f0) ** t if exp_sweep and f0 > 0 and f1 > 0 else f0 + (f1 - f0) * t
        if vib_amt > 0:
            f *= 1.0 + vib_amt * math.sin(2 * math.pi * vib_hz * i / SR)
        phase += 2 * math.pi * f / SR
        s = sum(a * math.sin(phase * m) for m, a in partials)
        out.append(s * amp * env_exp(i, n, attack, k))
    return out


def pluck(dur: float, freq: float, amp: float = 1.0, bright: float = 1.0) -> list[float]:
    return tone(dur, freq, freq * 0.995,
                [(1.0, 1.0), (2.0, 0.45 * bright), (3.0, 0.22 * bright), (4.0, 0.1 * bright)],
                amp, 0.002, 6.5)


def pad(dur: float, freqs: list[float], amp: float = 1.0) -> list[float]:
    n = int(dur * SR)
    out = [0.0] * n
    for f in freqs:
        for det in (0.9965, 1.0, 1.004):
            phase = random.random() * math.tau
            fd = f * det
            step = 2 * math.pi * fd / SR
            for i in range(n):
                phase += step
                out[i] += (math.sin(phase) + 0.3 * math.sin(phase * 2)) \
                    * env_ar(i, n, 0.3, 0.35)
    g = amp / (len(freqs) * 3)
    return [s * g for s in out]


def noise(dur: float, amp: float = 1.0, lp: float = 0.25, hp: bool = False,
          attack: float = 0.003, k: float = 6.0, sweep: float = 1.0) -> list[float]:
    """Filtered noise; sweep>1 opens the filter over time, <1 closes it."""
    n = int(dur * SR)
    out = []
    low = 0.0
    for i in range(n):
        t = i / n
        cut = lp * (sweep ** t if sweep != 1.0 else 1.0)
        cut = max(0.01, min(0.99, cut))
        white = random.uniform(-1, 1)
        low += cut * (white - low)
        s = (white - low) if hp else low
        out.append(s * amp * env_exp(i, n, attack, k))
    return out


def kick(amp: float = 1.0) -> list[float]:
    return tone(0.22, 160, 42, [(1.0, 1.0)], amp, 0.001, 7.0)


def hat(amp: float = 0.5) -> list[float]:
    return noise(0.05, amp, 0.7, hp=True, k=14.0)


def fm_shimmer(dur: float, f0: float, f1: float, amp: float = 0.6) -> list[float]:
    n = int(dur * SR)
    out = []
    phase = 0.0
    mod_phase = 0.0
    for i in range(n):
        t = i / n
        f = f0 * (f1 / f0) ** t
        mod_phase += 2 * math.pi * f * 2.01 / SR
        phase += 2 * math.pi * f / SR
        out.append(math.sin(phase + 2.2 * math.sin(mod_phase))
                   * amp * env_ar(i, n, 0.05, 0.4))
    return out


def hz(name: str) -> float:
    names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    key, octave = name[:-1], int(name[-1])
    semitone = names.index(key) + (octave - 4) * 12 - 9  # A4 = 440
    return 440.0 * 2 ** (semitone / 12)


# --- SFX ---------------------------------------------------------------


def build_sfx() -> dict[str, list[float]]:
    random.seed(7)
    s = {}
    s["click"] = mix(tone(0.05, 900, 700, [(1, 1)], 0.5, 0.001, 9),
                     noise(0.02, 0.25, 0.6, hp=True))
    s["move"] = mix(tone(0.1, 220, 150, [(1, 1), (2, 0.2)], 0.6, 0.002, 7),
                    noise(0.06, 0.3, 0.2))
    s["attack"] = noise(0.22, 1.0, 0.12, sweep=6.0, k=5.0)
    s["hit"] = echo(mix(kick(1.0), noise(0.08, 0.8, 0.5, hp=True, k=10),
                        tone(0.12, 300, 90, [(1, 0.6)], 0.5, 0.001, 8)), 0.09, 0.2, 2)
    s["master_hit"] = echo(mix(tone(0.5, 90, 36, [(1, 1), (2, 0.4)], 1.0, 0.001, 5),
                               noise(0.3, 0.7, 0.25, k=6),
                               kick(0.8)), 0.14, 0.3, 3)
    s["summon"] = mix(fm_shimmer(0.45, 300, 900, 0.5),
                      pluck(0.4, hz("C4"), 0.4), pluck(0.4, hz("G4"), 0.3))
    s["heal"] = echo(mix(pluck(0.35, hz("A5"), 0.5, 0.6), pluck(0.4, hz("E5"), 0.4, 0.6),
                         fm_shimmer(0.5, 1200, 1900, 0.25)), 0.13, 0.3, 2)
    s["death"] = echo(mix(tone(0.5, 260, 60, [(1, 1), (2.9, 0.3)], 0.8, 0.002, 5),
                          noise(0.4, 0.5, 0.2, k=5)), 0.12, 0.25, 2)
    s["shield"] = echo(tone(0.3, 950, 940,
                            [(1, 1), (2.76, 0.6), (5.4, 0.35), (8.9, 0.15)],
                            0.7, 0.001, 8), 0.1, 0.25, 2)
    s["levelup"] = echo(mix(pluck(0.2, hz("C5"), 0.6),
                            *(mix_delay(pluck(0.2, hz(n), 0.6), d)
                              for n, d in [("E5", 0.09), ("G5", 0.18), ("C6", 0.27)])),
                        0.14, 0.3, 2)
    s["evolve"] = echo(mix(noise(0.7, 0.5, 0.06, sweep=14.0, k=2.5),
                           fm_shimmer(0.8, 220, 1500, 0.5),
                           mix_delay(mix(kick(0.9), tone(0.4, 500, 480,
                                     [(1, 0.7), (2.5, 0.4)], 0.6, 0.001, 6)), 0.62)),
                       0.16, 0.3, 2)
    s["cast"] = mix(fm_shimmer(0.35, 700, 1800, 0.5), noise(0.2, 0.35, 0.1, sweep=8.0))
    s["turn"] = echo(tone(0.5, 660, 658, [(1, 1), (2.0, 0.4), (3.01, 0.2)],
                          0.5, 0.002, 6), 0.18, 0.3, 2)
    s["win"] = echo(mix(*(mix_delay(mix(pluck(0.5, hz(a), 0.55), pluck(0.5, hz(b), 0.4)), d)
                          for (a, b), d in [(("C4", "E4"), 0.0), (("E4", "G4"), 0.18),
                                            (("G4", "C5"), 0.36), (("C5", "E5"), 0.54)]),
                        mix_delay(pad(1.2, [hz("C4"), hz("E4"), hz("G4")], 0.5), 0.5)),
                    0.2, 0.3, 3)
    s["lose"] = echo(mix(*(mix_delay(pluck(0.7, hz(n), 0.5, 0.5), d)
                           for n, d in [("A3", 0.0), ("G3", 0.35), ("F3", 0.7), ("E3", 1.05)]),
                         mix_delay(pad(1.5, [hz("A2"), hz("E3"), hz("A3")], 0.5), 0.9)),
                     0.22, 0.3, 2)
    return s


def mix_delay(src: list[float], at: float) -> list[float]:
    out = silence(at + len(src) / SR)
    mix_into(out, src, at)
    return out


# --- Music -------------------------------------------------------------

CHORDS = {
    "C": ["C3", "G3", "C4", "E4", "G4"], "G": ["G2", "D3", "G3", "B3", "D4"],
    "Am": ["A2", "E3", "A3", "C4", "E4"], "F": ["F2", "C3", "F3", "A3", "C4"],
    "Em": ["E2", "B2", "E3", "G3", "B3"], "Dm": ["D3", "A3", "D4", "F4", "A4"],
}


def track(chords: list[str], bar: float, bass: bool, drums: bool, arp_speed: int,
          lead_seed: int, amp_pad: float = 0.5) -> list[float]:
    random.seed(lead_seed)
    total = bar * len(chords)
    buf = silence(total + 1.5)
    for ci, name in enumerate(chords):
        t0 = ci * bar
        notes = CHORDS[name]
        mix_into(buf, pad(bar * 1.05, [hz(n) for n in notes[1:]], amp_pad), t0)
        if bass:
            for b in range(4):
                mix_into(buf, tone(bar / 4 * 0.9, hz(notes[0]), None,
                                   [(1, 1), (2, 0.3)], 0.55, 0.004, 4), t0 + b * bar / 4)
        # plucked arpeggio
        seq_notes = (notes[2:] + notes[2:][::-1])
        step = bar / arp_speed
        for i in range(arp_speed):
            n = seq_notes[i % len(seq_notes)]
            mix_into(buf, pluck(step * 1.6, hz(n) * 2, 0.28, 0.7), t0 + i * step)
        # sparse lead
        if random.random() < 0.75:
            n = random.choice(notes[2:])
            mix_into(buf, pluck(bar / 2, hz(n) * 2, 0.3), t0 + bar * random.choice([0.5, 0.25]))
        if drums:
            for b in range(4):
                mix_into(buf, kick(0.8), t0 + b * bar / 4)
                mix_into(buf, hat(0.35), t0 + (b + 0.5) * bar / 4)
    return echo(buf, 0.22, 0.22, 2)


def build_music() -> dict[str, list[float]]:
    return {
        "menu": track(["C", "G", "Am", "F"] * 2, 3.4, bass=True, drums=False,
                      arp_speed=8, lead_seed=3, amp_pad=0.6),
        "battle": track(["Am", "F", "Am", "G", "Am", "F", "C", "G"], 2.0, bass=True,
                        drums=True, arp_speed=8, lead_seed=9, amp_pad=0.4),
        "story": track(["F", "C", "Am", "G"] * 2, 4.0, bass=False, drums=False,
                       arp_speed=4, lead_seed=5, amp_pad=0.65),
    }


def main() -> int:
    force = "--force" in sys.argv
    for name, samples in build_sfx().items():
        path = SFX_DIR / f"{name}.wav"
        if force or not path.exists():
            save(path, samples)
    for name, samples in build_music().items():
        path = MUSIC_DIR / f"{name}.wav"
        if force or not path.exists():
            save(path, samples, 0.55)
    print("Audio complet.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

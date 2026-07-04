#!/usr/bin/env python3
"""Procedural audio: synthesizes every SFX and music loop into assets/audio/.

Pure stdlib (wave + math + random) — no dependencies. Idempotent: existing
files are kept unless --force. 44.1 kHz, 16-bit mono WAV.
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


def save(path: Path, samples: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    peak = max(1e-6, max(abs(s) for s in samples))
    norm = min(1.0, 0.9 / peak)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s * norm)) * 32767))
            for s in samples))
    print(f"OK {path.relative_to(ROOT)} ({len(samples) / SR:.2f}s)")


def env(i: int, n: int, attack: float = 0.01, release: float = 0.5) -> float:
    t = i / n
    a = min(1.0, t / max(attack, 1e-4))
    r = min(1.0, (1.0 - t) / max(release, 1e-4))
    return min(a, r)


def tone(dur: float, f0: float, f1: float | None = None, vol: float = 1.0,
         harmonics: tuple = (1.0,), attack: float = 0.02, release: float = 0.6,
         vibrato: float = 0.0) -> list[float]:
    n = int(dur * SR)
    out = []
    phase = 0.0
    f1 = f0 if f1 is None else f1
    for i in range(n):
        t = i / n
        f = f0 + (f1 - f0) * t
        if vibrato > 0:
            f *= 1.0 + 0.01 * vibrato * math.sin(2 * math.pi * 6 * i / SR)
        phase += 2 * math.pi * f / SR
        s = sum(a * math.sin(phase * (k + 1)) for k, a in enumerate(harmonics))
        out.append(s * vol * env(i, n, attack, release))
    return out


def noise(dur: float, vol: float = 1.0, lp: float = 0.2, attack: float = 0.005,
          release: float = 0.5) -> list[float]:
    n = int(dur * SR)
    out = []
    prev = 0.0
    for i in range(n):
        prev += lp * (random.uniform(-1, 1) - prev)  # cheap low-pass
        out.append(prev * vol * env(i, n, attack, release))
    return out


def mix(*layers: list[float]) -> list[float]:
    n = max(len(l) for l in layers)
    out = [0.0] * n
    for l in layers:
        for i, s in enumerate(l):
            out[i] += s
    return out


def seq(*parts: list[float]) -> list[float]:
    out = []
    for p in parts:
        out.extend(p)
    return out


def delay(samples: list[float], seconds: float) -> list[float]:
    return [0.0] * int(seconds * SR) + samples


def sfx() -> dict[str, list[float]]:
    random.seed(7)
    return {
        "move": tone(0.09, 320, 210, 0.5, (1.0, 0.3), release=0.8),
        "summon": mix(tone(0.3, 220, 440, 0.6, (1.0, 0.4, 0.2)),
                      delay(tone(0.2, 660, 880, 0.3), 0.1)),
        "attack": noise(0.16, 0.9, 0.45, release=0.9),
        "hit": mix(tone(0.16, 130, 70, 1.0, (1.0, 0.5), release=0.9),
                   noise(0.1, 0.5, 0.6, release=0.9)),
        "master_hit": mix(tone(0.35, 90, 45, 1.0, (1.0, 0.6, 0.3), release=0.9),
                          noise(0.2, 0.6, 0.3, release=0.9)),
        "heal": mix(tone(0.3, 620, 930, 0.5, (1.0, 0.3), vibrato=1.5),
                    delay(tone(0.25, 930, 1240, 0.3), 0.08)),
        "death": mix(tone(0.4, 300, 90, 0.8, (1.0, 0.4), release=0.7),
                     noise(0.35, 0.4, 0.25, release=0.7)),
        "shield": tone(0.22, 1150, 1100, 0.6, (1.0, 0.6, 0.4, 0.25), attack=0.002, release=0.9),
        "levelup": seq(tone(0.12, 523, None, 0.6), tone(0.12, 659, None, 0.6),
                       tone(0.22, 784, None, 0.7, (1.0, 0.4))),
        "evolve": mix(tone(0.6, 392, 784, 0.6, (1.0, 0.5, 0.3), vibrato=1.0),
                      delay(tone(0.4, 988, 1319, 0.35), 0.2)),
        "cast": mix(tone(0.22, 880, 1320, 0.4, (1.0, 0.3), attack=0.002),
                    delay(tone(0.18, 1320, 1760, 0.3), 0.07)),
        "turn": tone(0.28, 660, None, 0.5, (1.0, 0.0, 0.3), attack=0.002, release=0.85),
        "win": seq(tone(0.14, 523, None, 0.6), tone(0.14, 659, None, 0.6),
                   tone(0.14, 784, None, 0.6), tone(0.4, 1047, None, 0.75, (1.0, 0.4))),
        "lose": seq(tone(0.25, 440, 415, 0.6), tone(0.25, 392, 370, 0.6),
                    tone(0.5, 330, 262, 0.7)),
    }


NOTES = {"C3": 130.81, "D3": 146.83, "E3": 164.81, "F3": 174.61, "G3": 196.0,
         "A3": 220.0, "B3": 246.94, "C4": 261.63, "D4": 293.66, "E4": 329.63,
         "F4": 349.23, "G4": 392.0, "A4": 440.0, "B4": 493.88, "C5": 523.25,
         "E5": 659.26, "G5": 783.99}


def pad_chord(dur: float, freqs: list[float], vol: float) -> list[float]:
    layers = []
    for f in freqs:
        layers.append(tone(dur, f * 0.998, f * 1.002, vol, (1.0, 0.25, 0.1),
                           attack=0.25, release=0.3))
    return mix(*layers)


def arp(dur_note: float, names: list[str], vol: float, harmonics=(1.0, 0.3)) -> list[float]:
    return seq(*[tone(dur_note, NOTES[n], None, vol, harmonics,
                      attack=0.01, release=0.5) for n in names])


def music() -> dict[str, list[float]]:
    random.seed(11)
    chords = {
        "I": ["C3", "E4", "G4", "C4"], "vi": ["A3", "C4", "E4", "A3"],
        "IV": ["F3", "A3", "C4", "F4"], "V": ["G3", "B3", "D4", "G4"],
        "i": ["A3", "C4", "E4"], "VI": ["F3", "A3", "C4"], "III": ["C3", "E4", "G3"],
        "VII": ["G3", "B3", "D4"],
    }
    menu = seq(*[pad_chord(3.0, [NOTES[n] for n in chords[c]], 0.35)
                 for c in ["I", "vi", "IV", "V", "I", "IV", "vi", "V"]])
    battle_bar = lambda c: mix(
        arp(0.22, [chords[c][0], chords[c][1], chords[c][2], chords[c][1]] * 2, 0.30),
        pad_chord(3.52, [NOTES[chords[c][0]] / 2], 0.4))
    battle = seq(*[battle_bar(c) for c in ["i", "VI", "III", "VII"]])
    story = seq(*[mix(pad_chord(4.0, [NOTES[n] for n in chords[c]], 0.3),
                      delay(arp(0.5, [chords[c][1], chords[c][2]], 0.15), 1.0))
                  for c in ["IV", "I", "vi", "V"]])
    return {"menu": menu, "battle": battle, "story": story}


def main() -> int:
    force = "--force" in sys.argv
    for name, samples in sfx().items():
        path = SFX_DIR / f"{name}.wav"
        if force or not path.exists():
            save(path, samples)
    for name, samples in music().items():
        path = MUSIC_DIR / f"{name}.wav"
        if force or not path.exists():
            save(path, samples)
    print("Audio complet.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

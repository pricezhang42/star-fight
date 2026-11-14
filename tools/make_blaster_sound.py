#!/usr/bin/env python3
"""Synthesizes the ships' blaster sounds (assets/generated/blaster_1.wav ...).

Original, made-from-scratch "pew" sounds: a tone that drops quickly from a
high pitch to a low one (like a struck steel cable), with a sharp click at
the start and a fast fade. Several variants are made, each tuned a bit
differently; the game picks one at random per shot. Run from the project root:

    python3 tools/make_blaster_sound.py
"""
import math
import random
import struct
import wave

RATE = 44100

# One row per variant:
#   start_hz, end_hz : the pitch falls from start to end
#   sweep            : how quickly the pitch falls (seconds; smaller = snappier)
#   decay            : how quickly the volume falls (seconds)
#   length           : total length in seconds
#   detune           : how far the upper layers are out of tune (more = more metallic)
# The first row is the base sound; the others stay close to it so every shot
# is recognisably the same blaster.
VARIANTS = [
    dict(start_hz=3400.0, end_hz=320.0, sweep=0.060, decay=0.100, length=0.36, detune=1.000),
    dict(start_hz=3520.0, end_hz=330.0, sweep=0.058, decay=0.097, length=0.36, detune=1.008),
    dict(start_hz=3280.0, end_hz=312.0, sweep=0.062, decay=0.103, length=0.36, detune=0.993),
    dict(start_hz=3460.0, end_hz=316.0, sweep=0.057, decay=0.100, length=0.36, detune=1.012),
    dict(start_hz=3340.0, end_hz=326.0, sweep=0.063, decay=0.098, length=0.36, detune=0.996),
]


def make(path, start_hz, end_hz, sweep, decay, length, detune, seed):
    # (frequency multiple, loudness, seconds it lasts) of each layer. The main
    # tone lasts the whole shot. The out-of-tune upper layers give the metallic
    # start and the layer an octave below gives it body, but both die away
    # early so the end of the shot is one clean tone instead of a murky mix.
    partials = [(1.0, 1.0, None), (1.51 * detune, 0.45, 0.09), (2.03 * detune, 0.3, 0.09), (0.5, 0.35, 0.05)]
    rng = random.Random(seed)
    phases = [0.0] * len(partials)
    samples = []
    for i in range(int(RATE * length)):
        t = i / RATE
        freq = end_hz + (start_hz - end_hz) * math.exp(-t / sweep)
        value = 0.0
        for k, (mult, amp, lasts) in enumerate(partials):
            phases[k] += 2.0 * math.pi * freq * mult / RATE
            if lasts is not None:
                amp *= math.exp(-t / lasts)
            value += amp * math.sin(phases[k])
        value += rng.uniform(-1.0, 1.0) * 1.5 * math.exp(-t / 0.004)  # click
        attack = min(1.0, t / 0.002)
        fade_out = min(1.0, (length - t) / 0.06)
        value *= attack * fade_out * math.exp(-t / decay)
        samples.append(math.tanh(value * 1.3))  # a little grit
    peak = max(abs(s) for s in samples)
    with wave.open(path, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(b"".join(struct.pack("<h", int(s / peak * 0.85 * 32767)) for s in samples))


for n, settings in enumerate(VARIANTS, start=1):
    make("assets/generated/blaster_%d.wav" % n, seed=n, **settings)

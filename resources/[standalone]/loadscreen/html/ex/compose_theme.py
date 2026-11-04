# EX_Tii loading theme: an original dark, cinematic night-drive loop (A minor, 84 bpm).
# Everything is synthesized here, so the track belongs to the server.
import numpy as np
from scipy.signal import butter, sosfilt, fftconvolve
from scipy.io import wavfile

SR = 44100
BPM = 84
BEAT = 60 / BPM
BAR = BEAT * 4
rng = np.random.default_rng(7)

def hz(n): return 440.0 * 2 ** ((n - 69) / 12)   # midi -> Hz
def lp(x, f, o=2): return sosfilt(butter(o, f, 'low', fs=SR, output='sos'), x)
def hp(x, f, o=2): return sosfilt(butter(o, f, 'high', fs=SR, output='sos'), x)
def bp(x, a, b): return sosfilt(butter(2, [a, b], 'band', fs=SR, output='sos'), x)

def saw(f, n, ph=0.0):
    t = np.arange(n) / SR
    out = np.zeros(n)
    for k in range(1, 24):   # band-limited
        if f * k > SR / 2.5: break
        out += np.sin(2 * np.pi * f * k * t + ph * k) / k
    return out * 0.6

def env(n, a, r, s=1.0):
    e = np.ones(n) * s
    A, R = int(a * SR), int(r * SR)
    e[:A] = np.linspace(0, s, A)
    if R > 0: e[-R:] *= np.linspace(1, 0, R)
    return e

# the progression: Am - F - C - E (2 bars each), voicings in midi
CHORDS = [
    ([57, 60, 64, 69], 45),   # Am  (root A2 bass 45)
    ([53, 57, 60, 65], 41),   # F
    ([55, 60, 64, 67], 48),   # C
    ([56, 59, 64, 68], 40),   # E (G# for the minor-key pull)
]
CYCLE = 8 * BAR
CYCLES = 5
N = int(CYCLE * CYCLES * SR) + SR * 3
L = np.zeros(N); Rr = np.zeros(N)

def add(sig, at, gain=1.0, pan=0.0):
    i = int(at * SR)
    j = min(N, i + len(sig))
    s = sig[:j - i] * gain
    L[i:j] += s * np.sqrt(0.5 * (1 - pan)); Rr[i:j] += s * np.sqrt(0.5 * (1 + pan))

# sections: 0 pad only, 1 + bass/kick, 2-3 full, 4 breaks down to pad (loops back to the start)
for c in range(CYCLES):
    base = c * CYCLE
    full = c in (2, 3)
    for k, (notes, root) in enumerate(CHORDS):
        t0 = base + k * 2 * BAR
        dur = 2 * BAR
        n = int((dur + 1.2) * SR)
        # pad: three detuned saws per note, dark low-pass, slow swell
        pad = np.zeros(n)
        for m in notes:
            for d in (-0.07, 0.0, 0.07):
                pad += saw(hz(m + d), n, ph=rng.random() * 6)
        pad = lp(pad, 750 if c in (0, 4) else 1100, 3) * env(n, 1.4, 1.4) * 0.05
        add(pad, t0, 1.0, -0.15)
        add(np.roll(pad, int(0.013 * SR)), t0, 0.9, 0.25)
        # sub bass: 8ths, ducked under the kick
        if c in (1, 2, 3):
            for b8 in range(16):
                tb = t0 + b8 * BEAT / 2
                nb = int(BEAT / 2 * SR)
                tt = np.arange(nb) / SR
                s = np.sin(2 * np.pi * hz(root - 12) * tt) + 0.25 * np.sin(2 * np.pi * hz(root) * tt)
                s = np.tanh(s * 1.6) * np.exp(-tt * 3.0) * env(nb, 0.01, 0.03)
                add(s, tb, 0.22 if b8 % 2 == 0 else 0.13)
        # arp: plucked chord tones, 16ths, with a dotted-8th echo
        if full:
            seq = [notes[0] + 12, notes[1] + 12, notes[2] + 12, notes[3] + 12, notes[2] + 12, notes[1] + 12, notes[2] + 24, notes[1] + 12]
            for s16 in range(32):
                ts = t0 + s16 * BEAT / 4
                m = seq[s16 % len(seq)]
                nn = int(0.45 * SR)
                tt = np.arange(nn) / SR
                p = (np.sin(2 * np.pi * hz(m) * tt) + 0.3 * np.sin(2 * np.pi * hz(m) * 2 * tt)) * np.exp(-tt * 9)
                p = lp(p, 3200)
                pan = 0.35 if s16 % 2 else -0.35
                add(p, ts, 0.045, pan)
                add(p, ts + BEAT * 0.75, 0.02, -pan)
    # drums (half-time): kick on 1, clap on 3, soft hats on 8ths
    if c in (1, 2, 3):
        for bar in range(8):
            tb = base + bar * BAR
            for kb in ([0, 2.5] if full else [0]):
                nk = int(0.5 * SR); tt = np.arange(nk) / SR
                f = 42 + 95 * np.exp(-tt * 28)
                kick = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 6.5)
                add(np.tanh(kick * 2.2), tb + kb * BEAT, 0.42)
            if full:
                nc = int(0.35 * SR); tt = np.arange(nc) / SR
                clap = bp(rng.standard_normal(nc), 900, 2600) * np.exp(-tt * 14)
                add(clap, tb + 2 * BEAT, 0.16, 0.05)
            for h in range(8):
                nh = int(0.06 * SR); tt = np.arange(nh) / SR
                hat = hp(rng.standard_normal(nh), 7500) * np.exp(-tt * 70)
                add(hat, tb + h * BEAT / 2, (0.05 if h % 2 else 0.028) * (1 if full else 0.6), 0.3 if h % 2 else -0.2)
    # a riser into the full part
    if c == 1:
        nr = int(4 * BAR * SR); tt = np.arange(nr) / SR
        rise = hp(rng.standard_normal(nr), 2000) * (tt / tt[-1]) ** 3 * 0.018
        add(rise, base + 4 * BAR, 1.0, 0.0)

# night air: a quiet filtered noise bed and distant city rumble
bed = lp(rng.standard_normal(N), 300) * 0.018
L += bed; Rr += np.roll(bed, 3000)

# reverb: a 3 s dark hall
ir_n = int(3.0 * SR); tt = np.arange(ir_n) / SR
irL = lp(rng.standard_normal(ir_n), 4000) * np.exp(-tt * 2.1)
irR = lp(rng.standard_normal(ir_n), 4000) * np.exp(-tt * 2.1)
wetL = fftconvolve(L, irL)[:N]; wetR = fftconvolve(Rr, irR)[:N]
mixL = L + wetL * 0.022; mixR = Rr + wetR * 0.022

# master: gentle glue, limit, fade the very end into the start (it loops)
out = np.stack([mixL, mixR], 1)
out = hp(out.T, 28).T
out = np.tanh(out * 1.4) / np.tanh(1.4)
end = int(CYCLE * CYCLES * SR)
out = out[:end]
fade = int(2.5 * SR)
out[-fade:] *= np.linspace(1, 0, fade)[:, None]
out[:int(1.5 * SR)] *= np.linspace(0, 1, int(1.5 * SR))[:, None]
out = out / np.max(np.abs(out)) * 0.89
wavfile.write('theme.wav', SR, (out * 32767).astype(np.int16))
print('seconds', end / SR)

# EX_Tii minigame sounds, made from physics-style synthesis (modal metal, filtered noise), written as small .ogg
import numpy as np, subprocess, os
from scipy.signal import butter, sosfilt
SR = 44100
rng = np.random.default_rng(7)
def t(d): return np.arange(int(SR * d)) / SR
def bp(x, lo, hi, o=4): return sosfilt(butter(o, [lo, hi], 'band', fs=SR, output='sos'), x)
def lp(x, f, o=4): return sosfilt(butter(o, f, 'low', fs=SR, output='sos'), x)
def hp(x, f, o=4): return sosfilt(butter(o, f, 'high', fs=SR, output='sos'), x)
def env(n, a=0.001, d=0.05):
    tt = np.arange(n) / SR
    return np.minimum(1, tt / max(a, 1e-5)) * np.exp(-tt / d)
def modal(freqs, decays, amps, dur, jitter=0.0):
    x = t(dur); y = np.zeros_like(x)
    for f, d, a in zip(freqs, decays, amps):
        f = f * (1 + rng.uniform(-jitter, jitter))
        y += a * np.sin(2 * np.pi * f * x + rng.uniform(0, 6)) * np.exp(-x / d)
    return y
def place(dst, src, at):
    i = int(at * SR); n = min(len(src), len(dst) - i)
    if n > 0: dst[i:i + n] += src[:n]
def norm(x, peak=0.8):
    x = x - np.mean(x); m = np.max(np.abs(x)) or 1; return x / m * peak
def fade(x, ms=6):
    n = int(SR * ms / 1000); x[:n] *= np.linspace(0, 1, n); x[-n:] *= np.linspace(1, 0, n); return x
def save(name, x, peak=0.8):
    x = fade(norm(x, peak))
    raw = (x * 32767).astype('<i2').tobytes()
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-f', 's16le', '-ar', str(SR), '-ac', '1', '-i', '-', '-c:a', 'libvorbis', '-q:a', '4', f'sfx/{name}.ogg'], input=raw, check=True)

def tick(f0=1.0):
    n = rng.standard_normal(int(SR * 0.004))
    c = bp(np.pad(n, (0, int(SR * 0.03))), 2500 * f0, 7500 * f0) * 0.6
    c[:len(n)] *= 1
    return c * env(len(c), 0.0003, 0.006) + modal([3100 * f0, 5200 * f0, 8100 * f0], [0.008, 0.006, 0.004], [0.4, 0.3, 0.2], 0.034, 0.05)

# ratchet: 6 clicks, the pawl skipping teeth
r = np.zeros(int(SR * 0.42))
for i in range(6): place(r, tick(rng.uniform(0.93, 1.07)) * rng.uniform(0.7, 1.0), 0.02 + i * 0.062 + rng.uniform(-0.005, 0.005))
save('ratchet', r)

def clink(base=1.0, dur=0.6):
    return modal([1830 * base, 4170 * base, 6690 * base, 9420 * base], [0.16, 0.09, 0.05, 0.03], [1, 0.6, 0.35, 0.2], dur, 0.02)
# a bolt coming out and dropping on the bracket (3 bounces)
b = np.zeros(int(SR * 0.9))
for i, (at, a) in enumerate(((0.0, 1.0), (0.16, 0.45), (0.27, 0.2), (0.33, 0.1))):
    place(b, clink(1.0 + i * 0.01, 0.5) * a, at)
save('bolt_out', b, 0.7)

# impact wrench: motor whine + hammer blows at ~22 Hz, then the nut spins free
d = 0.55; x = t(d)
motor = np.sin(2 * np.pi * (620 + 40 * x) * x) * 0.25 + bp(rng.standard_normal(len(x)), 500, 2500) * 0.25
ham = np.zeros_like(x)
for i in range(int(d * 22)):
    place(ham, modal([900, 2300, 4100], [0.012, 0.008, 0.005], [1, 0.6, 0.4], 0.03) + bp(rng.standard_normal(int(SR * 0.03)), 800, 6000) * env(int(SR * 0.03), 0.0002, 0.004), i / 22)
imp = (motor + ham * 0.9) * np.minimum(1, x / 0.02) * np.where(x > d - 0.08, np.linspace(1, 0, len(x)) ** 0.2, 1)
save('impact', imp, 0.75)

# a lug nut dropping on concrete (duller)
n = np.zeros(int(SR * 0.5))
for at, a in ((0, 1), (0.11, 0.35), (0.18, 0.12)):
    place(n, (modal([1400, 3300, 5600], [0.06, 0.035, 0.02], [1, 0.5, 0.3], 0.3) + bp(rng.standard_normal(int(SR * 0.3)), 1500, 8000) * env(int(SR * 0.3), 0.0002, 0.004)) * a, at)
save('nut_drop', n, 0.7)

# pry: steel strain creak (rubbed noise through resonances), then the latch pops
d = 0.7; x = t(d)
fr = 180 + 90 * np.sin(2 * np.pi * 3 * x)
creak = np.sin(2 * np.pi * np.cumsum(fr) / SR) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 37 * x))) * 0.3
creak = bp(creak + bp(rng.standard_normal(len(x)), 300, 1800) * 0.15, 150, 2500) * np.minimum(1, x / 0.1) * np.exp(-x / 0.6)
save('strain', creak, 0.55)
p = np.zeros(int(SR * 0.6))
place(p, lp(rng.standard_normal(int(SR * 0.12)), 900) * env(int(SR * 0.12), 0.0005, 0.03) * 1.2, 0)
place(p, modal([95, 210, 480], [0.12, 0.08, 0.05], [1, 0.5, 0.3], 0.4), 0)
place(p, modal([2600, 5300], [0.04, 0.02], [0.4, 0.2], 0.2), 0.004)
save('pop', p, 0.85)
# a missed lever: the bar slips with a scrape
d = 0.3; x = t(d)
sl = bp(rng.standard_normal(len(x)), 2000, 7000) * env(len(x), 0.01, 0.08) + modal([1250, 2800], [0.05, 0.03], [0.6, 0.3], d)
save('slip', sl, 0.6)

# torch: a hiss that loops (2 s), with the soft roar of the flame
d = 2.0; x = t(d)
h = hp(rng.standard_normal(len(x)), 3000) * 0.35 + lp(rng.standard_normal(len(x)), 300) * 0.5 + bp(rng.standard_normal(len(x)), 800, 2500) * 0.2
h = h * (1 + 0.08 * np.sin(2 * np.pi * 7 * x))
xf = int(SR * 0.15); h[:xf] = h[:xf] * np.linspace(0, 1, xf) + h[-xf:] * np.linspace(1, 0, xf); h = h[:-xf]
x16 = (norm(h, 0.5) * 32767).astype('<i2').tobytes()
subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-f', 's16le', '-ar', str(SR), '-ac', '1', '-i', '-', '-c:a', 'libvorbis', '-q:a', '4', 'sfx/torch_loop.ogg'], input=x16, check=True)
# metal crackle while cutting (spits of molten steel)
c = np.zeros(int(SR * 1.0))
for i in range(40): place(c, bp(rng.standard_normal(int(SR * 0.01)), 2000, 9000) * env(int(SR * 0.01), 0.0001, 0.002) * rng.uniform(0.2, 1), rng.uniform(0, 0.98))
save('crackle', c, 0.5)
# the cut piece drops: heavy sheet metal
s = np.zeros(int(SR * 1.2))
place(s, modal([140, 380, 720, 1350, 2400], [0.4, 0.3, 0.2, 0.12, 0.07], [1, 0.7, 0.5, 0.3, 0.2], 1.0), 0)
place(s, lp(rng.standard_normal(int(SR * 0.1)), 1200) * env(int(SR * 0.1), 0.0005, 0.02), 0)
save('sheet_drop', s, 0.8)
print('done', sorted(os.listdir('sfx')))

# ---------------------------------------------------------------- money wash
def paper(d=0.09, lo=1500, hi=9000, k=1.0):
    n = rng.standard_normal(int(SR * d))
    e = env(len(n), 0.002, d / 3.5) * (1 + 0.6 * np.sin(np.linspace(0, 9, len(n))) ** 2)
    return bp(n, lo, hi) * e * k
f = np.zeros(int(SR * 0.18)); place(f, paper(0.1), 0); place(f, paper(0.05, 3000, 12000, 0.5), 0.03)
save('note_flick', f, 0.55)
f = np.zeros(int(SR * 0.3)); place(f, paper(0.16, 600, 6000), 0); place(f, lp(rng.standard_normal(int(SR * 0.04)), 500) * env(int(SR * 0.04), 0.001, 0.01), 0.12)
save('note_drop', f, 0.6)
# washer drum: motor hum + water slosh, loop 3 s (speed is the page's playbackRate)
d = 3.0; x = t(d)
hum = 0.4 * np.sin(2 * np.pi * 50 * x) + 0.2 * np.sin(2 * np.pi * 100 * x) + 0.1 * np.sin(2 * np.pi * 150 * x)
slosh = lp(rng.standard_normal(len(x)), 400) * (0.5 + 0.5 * np.sin(2 * np.pi * 1.0 * x) ** 4) * 1.4
whine = 0.05 * np.sin(2 * np.pi * 820 * x)
w = hum * 0.5 + slosh + whine
xf = int(SR * 0.2); w[:xf] = w[:xf] * np.linspace(0, 1, xf) + w[-xf:] * np.linspace(1, 0, xf); w = w[:-xf]
subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-f', 's16le', '-ar', str(SR), '-ac', '1', '-i', '-', '-c:a', 'libvorbis', '-q:a', '4', 'sfx/drum_loop.ogg'], input=(norm(w, 0.6) * 32767).astype('<i2').tobytes(), check=True)
# cash counter: the fast flutter of notes through the rollers (loop 1 s)
d = 1.0; x = t(d)
fl = np.zeros_like(x)
for i in range(int(d * 26)): place(fl, paper(0.022, 2500, 10000, rng.uniform(0.6, 1)), i / 26)
mot = 0.12 * np.sin(2 * np.pi * 240 * x) + bp(rng.standard_normal(len(x)), 150, 900) * 0.25
c = fl + mot
xf = int(SR * 0.1); c[:xf] = c[:xf] * np.linspace(0, 1, xf) + c[-xf:] * np.linspace(1, 0, xf); c = c[:-xf]
subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-f', 's16le', '-ar', str(SR), '-ac', '1', '-i', '-', '-c:a', 'libvorbis', '-q:a', '4', 'sfx/counter_loop.ogg'], input=(norm(c, 0.6) * 32767).astype('<i2').tobytes(), check=True)
# the counter's beep (piezo, 2.7 kHz) and an error double beep
def beep(f=2700, d=0.09): x = t(d); return np.sign(np.sin(2 * np.pi * f * x)) * 0.3 * np.minimum(1, x / 0.003) * np.minimum(1, (d - x) / 0.005)
save('beep', lp(beep(), 6000), 0.45)
e = np.zeros(int(SR * 0.3)); place(e, lp(beep(1900, 0.08), 6000), 0); place(e, lp(beep(1900, 0.08), 6000), 0.13); save('beep_err', e, 0.45)
# the paper strap snapping round the stack
s = np.zeros(int(SR * 0.25)); place(s, paper(0.06, 800, 7000, 1), 0); place(s, bp(rng.standard_normal(int(SR * 0.02)), 1000, 5000) * env(int(SR * 0.02), 0.0005, 0.004) * 1.5, 0.07)
save('strap', s, 0.6)
print('wash sfx ok')

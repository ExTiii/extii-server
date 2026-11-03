# EX_Tii heist minigame sounds, set 2 (M3): C4 wiring, alarm panel, keypad. Same physics-style synthesis.
import sys; sys.argv = ['x']
exec(open('/home/claude/mgstudio/h_sfx.py').read().split('# ---- the lock')[0])
rng = np.random.default_rng(23)

# ---- C4: a lead clamped under a screw post (two metal clicks + a little thread squeak), arming beeps, an error
x = np.zeros(int(SR * 0.3)); place(x, click([2600, 4100, 6300], 0.015, 1.0, 0.1), 0.0)
place(x, bp(noise(0.12), 2500, 7000) * env(int(SR * 0.12), 0.01, 0.04) * 0.25, 0.03); place(x, click([3300, 5200], 0.01, 0.7, 0.08), 0.12)
enc('c4_clip', fade(norm(x, 0.7)))
x = np.zeros(int(SR * 1.3))
for i in range(4): place(x, np.sin(2 * np.pi * (2400 + i * 300) * t(0.09)) * np.exp(-t(0.09) / 0.05) * 0.5, i * 0.22)
place(x, np.sin(2 * np.pi * 3600 * t(0.4)) * np.minimum(1, t(0.4) / 0.01) * np.exp(-t(0.4) / 0.25) * 0.6, 0.9)
enc('c4_arm', fade(norm(x, 0.55)))
tt = t(0.5); x = (np.sign(np.sin(2 * np.pi * 180 * tt)) * 0.5 + np.sin(2 * np.pi * 360 * tt) * 0.3) * np.exp(-tt / 0.35); x = lp(x, 2200)
enc('c4_err', fade(norm(x, 0.5)))
# a wire pulled across (soft plastic rub)
d = 0.6; x = bp(noise(d), 700, 3000) * env(int(SR * d), 0.05, 0.25) * 0.4
enc('c4_drag', fade(norm(x, 0.25), 30))

# ---- the alarm panel: snips cutting copper (crunch + snap), a spark with the siren starting
x = np.zeros(int(SR * 0.35)); place(x, bp(noise(0.05), 1500, 6000) * env(int(SR * 0.05), 0.002, 0.02) * 0.7, 0.0)
place(x, click([4200, 6600, 9100], 0.012, 1.0, 0.08, ntime=0.0015), 0.035); place(x, thump(260, 0.02, 0.06, 0.5), 0.035)
enc('wc_snip', fade(norm(x, 0.8)))
x = np.zeros(int(SR * 2.2)); place(x, hp(noise(0.25), 3000) * env(int(SR * 0.25), 0.001, 0.05) * 0.8, 0.0)
tt = t(1.9); f = 900 + 500 * (0.5 + 0.5 * np.sin(2 * np.pi * 2.2 * tt)); ph = 2 * np.pi * np.cumsum(f) / SR
place(x, (np.sign(np.sin(ph)) * 0.35 + np.sin(ph) * 0.3) * np.minimum(1, tt / 0.05), 0.2)
enc('wc_alarm', fade(norm(lp(x, 5000), 0.6), 40))
# all loops cut: a relay drops out (the panel goes quiet)
x = np.zeros(int(SR * 0.4)); place(x, click([1400, 2300, 3700], 0.03, 1.0, 0.12), 0.0); place(x, thump(140, 0.04, 0.12, 0.6), 0.0)
place(x, np.sin(2 * np.pi * 50 * t(0.3)) * np.exp(-t(0.3) / 0.08) * 0.25, 0.01)
enc('wc_done', fade(norm(x, 0.75)))

# ---- the keypad: a rubber key with a piezo beep, wrong code, the lock opens (beep + solenoid clunk), lockout
x = np.zeros(int(SR * 0.16)); place(x, click([900, 1600], 0.006, 0.5, 0.04, nlo=800, nhi=4000, ntime=0.002), 0.0)
place(x, np.sin(2 * np.pi * 2730 * t(0.08)) * np.minimum(1, t(0.08) / 0.002) * np.exp(-t(0.08) / 0.06) * 0.45, 0.01)
enc('kp_key', fade(norm(x, 0.45)))
x = np.zeros(int(SR * 0.6))
for i in range(3): place(x, np.sin(2 * np.pi * 1400 * t(0.1)) * np.minimum(1, t(0.1) / 0.003) * 0.4, i * 0.15)
enc('kp_bad', fade(norm(x, 0.45)))
x = np.zeros(int(SR * 0.9)); place(x, np.sin(2 * np.pi * 2730 * t(0.35)) * np.minimum(1, t(0.35) / 0.003) * np.exp(-t(0.35) / 0.3) * 0.4, 0.0)
place(x, modal([95, 160, 270], [0.08, 0.06, 0.04], [1, 0.6, 0.3], 0.3) + lp(noise(0.3), 1200) * env(int(SR * 0.3), 0.001, 0.03) * 0.5, 0.38)
enc('kp_ok', fade(norm(x, 0.85)))
tt = t(1.2); x = np.sin(2 * np.pi * 1400 * tt) * (np.sin(2 * np.pi * 4 * tt) > 0) * 0.4
enc('kp_lock', fade(norm(x, 0.45), 20))
print('ok')

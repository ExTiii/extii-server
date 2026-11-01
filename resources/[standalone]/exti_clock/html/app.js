// EX_Tii clock — in-game time, day / night ring, weather word
(() => {
    const $ = (id) => document.getElementById(id);
    const clock = $('clock');
    const CIRC = 2 * Math.PI * 21;
    const DAY_START = 6;   // 06:00
    const NIGHT_START = 21; // 21:00 (same as the server's night)

    const SUN = '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="4.2" fill="currentColor" fill-opacity="0.25"/><g class="sun-rays"><path d="M12 2.5v2.2M12 19.3v2.2M2.5 12h2.2M19.3 12h2.2M5.3 5.3l1.6 1.6M17.1 17.1l1.6 1.6M5.3 18.7l1.6-1.6M17.1 6.9l1.6-1.6"/></g></svg>';
    const CLOUD_SUN = '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><g class="sun-rays"><path d="M9 2.8v1.6M3.2 8.6h1.6M4.9 4.5l1.1 1.1M13.1 4.5 12 5.6"/></g><path d="M6.4 11.2a3.6 3.6 0 0 1 6.5-2.6"/><path d="M8 19.5h9.5a3.5 3.5 0 0 0 .4-7 5 5 0 0 0-9.5 1.4A2.9 2.9 0 0 0 8 19.5Z" fill="currentColor" fill-opacity="0.18"/></svg>';
    const MOON = '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M19.5 14.6A8 8 0 0 1 9.4 4.5a8 8 0 1 0 10.1 10.1Z" fill="currentColor" fill-opacity="0.22"/><path class="star" d="M17 3.5v2M16 4.5h2"/><path class="star b" d="M20.5 8.5v1.4M19.8 9.2h1.4"/></svg>';

    const WEATHER_DAY = { EXTRASUNNY: 'مشمس', CLEAR: 'صافٍ', CLOUDS: 'غائم جزئيًا', OVERCAST: 'غائم' };
    const WEATHER_NIGHT = { EXTRASUNNY: 'صافٍ', CLEAR: 'صافٍ', CLOUDS: 'غائم جزئيًا', OVERCAST: 'غائم' };

    function partOfDay(h) {
        if (h >= 21 || h < 5) return 'ليلًا';
        if (h < 6) return 'فجرًا';
        if (h < 12) return 'صباحًا';
        if (h < 15) return 'ظهرًا';
        if (h < 18) return 'عصرًا';
        return 'مساءً';
    }

    function scale() {
        document.documentElement.style.setProperty('--s', Math.max(0.75, Math.min(1.6, window.innerHeight / 1080)));
    }
    scale();
    window.addEventListener('resize', scale);

    let skyKind = null;
    function render(hour, minute, weather) {
        const night = hour >= NIGHT_START || hour < DAY_START;
        clock.classList.toggle('night', night);

        const pad = (n) => String(n).padStart(2, '0');
        $('hh').textContent = pad(hour);
        $('mm').textContent = pad(minute);

        // ring: how far through the day (06-21) or the night (21-06)
        const mins = hour * 60 + minute;
        let done, length;
        if (night) {
            length = (24 - NIGHT_START + DAY_START) * 60;
            done = (mins - NIGHT_START * 60 + 1440) % 1440;
        } else {
            length = (NIGHT_START - DAY_START) * 60;
            done = mins - DAY_START * 60;
        }
        const p = Math.max(0, Math.min(1, done / length));
        $('ring').style.strokeDasharray = `${Math.max(0.5, CIRC * p)} ${CIRC}`;

        const cloudy = weather === 'CLOUDS' || weather === 'OVERCAST';
        const kind = night ? 'moon' : (cloudy ? 'cloud' : 'sun');
        if (kind !== skyKind) {
            skyKind = kind;
            $('sky').innerHTML = kind === 'moon' ? MOON : (kind === 'cloud' ? CLOUD_SUN : SUN);
        }

        const word = (night ? WEATHER_NIGHT : WEATHER_DAY)[weather];
        $('label').textContent = word ? `${partOfDay(hour)} · ${word}` : partOfDay(hour);
    }

    window.addEventListener('message', (e) => {
        const msg = e.data || {};
        if (msg.action === 'show') clock.classList.toggle('hidden', !msg.value);
        else if (msg.action === 'time') render(Number(msg.hour) || 0, Number(msg.minute) || 0, msg.weather);
    });

    // preview outside the game (for checking the design in a browser)
    if (typeof GetParentResourceName !== 'function') {
        const q = new URLSearchParams(location.search);
        document.body.style.background = q.get('bg') === 'dark' ? '#0b0e16' : 'linear-gradient(135deg,#7f93ad,#3b4656)';
        render(Number(q.get('h') ?? 14), Number(q.get('m') ?? 35), q.get('w') || 'EXTRASUNNY');
        clock.classList.remove('hidden');
    }
})();

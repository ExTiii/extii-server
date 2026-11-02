// EX_Tii Roleplay — identity card.
// The page only shows and hides the card. It never asks for NUI focus:
// closing (timer / Backspace) is handled in main/client.lua.
(function () {
    'use strict';

    var $ = function (id) { return document.getElementById(id); };
    var card = $('card');
    var timer = $('timer');

    var setText = function (id, value) {
        var el = $(id);
        if (!el) return;
        var text = value === undefined || value === null ? '' : String(value);
        el.textContent = text;
        el.title = text;
    };

    var setBadge = function (badge) {
        var box = $('badge');
        if (!badge || badge === 'none' || typeof badge !== 'object' || !badge.img) {
            box.classList.remove('on');
            $('badgeimg').src = '';
            setText('badgegrade', '');
            return;
        }
        $('badgeimg').src = 'badges/' + badge.img + '.png';
        setText('badgegrade', badge.grade || '');
        box.classList.add('on');
    };

    var restartTimer = function (ms) {
        timer.classList.remove('run');
        timer.style.animationDuration = '';
        void timer.offsetWidth; // restart the animation
        if (ms > 0) {
            timer.style.animationDuration = ms + 'ms';
            timer.classList.add('run');
        }
    };

    var show = function (data, showTime) {
        if (!data) return;

        var first = data.firstname || '';
        var last = data.lastname || '';

        setText('cardtype', data.header || 'بطاقة الهوية');
        setText('firstname', first);
        setText('lastname', last);
        setText('dob', data.birthdate);
        setText('sex', data.sex);
        setText('nationality', data.nationality);
        setText('citizenid', data.citizenid);
        setText('sign', (first + ' ' + last).trim());

        $('mugshot').src = typeof data.mugShot === 'string' ? data.mugShot : '';
        card.style.setProperty('--card-accent', data.accent || 'var(--accent)');
        setBadge(data.badge);
        // EX_Tii: the owner's level
        var lv = Number(data.level) || 0;
        setText('levelnum', lv > 0 ? String(lv) : '');
        $('level').classList.toggle('on', lv > 0);

        card.classList.add('show');
        card.setAttribute('aria-hidden', 'false');
        restartTimer(Number(showTime) || 0);
    };

    var hide = function () {
        card.classList.remove('show');
        card.setAttribute('aria-hidden', 'true');
        restartTimer(0);
    };

    window.addEventListener('message', function (event) {
        var msg = event.data || {};
        if (msg.type === 'show') show(msg.playerData, msg.showTime);
        else if (msg.type === 'close') hide();
    });
})();

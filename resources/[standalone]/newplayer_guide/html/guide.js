/* EX_Tii city guide (/guide). The text comes from config.lua (Config.guide). */
'use strict';
const IN_GAME = typeof window.GetParentResourceName === 'function';
const RES = IN_GAME ? window.GetParentResourceName() : 'newplayer_guide';
const $ = (s) => document.querySelector(s);

function post(name, data) {
    if (!IN_GAME) return Promise.resolve();
    return fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data || {}) }).catch(() => {});
}
const esc = (t) => String(t == null ? '' : t).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

// line icons (24x24)
const P = {
    start: '<path d="M5 21V4"/><path d="M5 4h11l-2 4 2 4H5"/>',
    briefcase: '<rect x="3" y="7" width="18" height="13" rx="2"/><path d="M9 7V5a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v2"/><path d="M3 13h18"/>',
    key: '<rect x="2.5" y="6" width="19" height="12" rx="2.5"/><path d="M6 10h.01M10 10h.01M14 10h.01M18 10h.01M7 14h10"/>',
    scale: '<path d="M12 4v16M7 20h10"/><path d="M5 8h14"/><path d="M5 8l-3 6a3 3 0 0 0 6 0z"/><path d="M19 8l-3 6a3 3 0 0 0 6 0z"/>',
    help: '<circle cx="12" cy="12" r="9"/><path d="M9.5 9.5a2.5 2.5 0 1 1 3.5 2.3c-.6.3-1 .9-1 1.6v.6"/><path d="M12 17h.01"/>',
    bag: '<path d="M5 8h14l-1 12H6z"/><path d="M9 8V6a3 3 0 0 1 6 0v2"/>',
    cash: '<rect x="2.5" y="6" width="19" height="12" rx="2"/><circle cx="12" cy="12" r="2.6"/><path d="M6 9.5v5M18 9.5v5"/>',
    car: '<path d="M5 16l1.5-5a2 2 0 0 1 1.9-1.4h7.2a2 2 0 0 1 1.9 1.4L19 16"/><rect x="3" y="16" width="18" height="4" rx="1.5"/><path d="M7 20v1.5M17 20v1.5"/>',
    id: '<rect x="3" y="5" width="18" height="14" rx="2"/><circle cx="9" cy="11" r="2.2"/><path d="M5.8 16a3.4 3.4 0 0 1 6.4 0M14 10h4M14 13.5h3"/>',
    level: '<path d="M4 20h4v-6H4zM10 20h4v-10h-4zM16 20h4V5h-4z"/>',
    shop: '<path d="M4 9h16l-1-4H5z"/><path d="M5 9v11h14V9"/><path d="M10 20v-5h4v5"/>',
    chicken: '<path d="M14 6a4 4 0 0 0-4 4c-3 0-5 2.5-5 5.5S7.5 20 11 20h3a5 5 0 0 0 5-5c0-2-1-3-2-3.6V10a4 4 0 0 0-3-4z"/><path d="M17 8.5l2.5-.5M12 20v2M15 20v2"/>',
    grape: '<circle cx="9" cy="10" r="2.3"/><circle cx="15" cy="10" r="2.3"/><circle cx="12" cy="14" r="2.3"/><circle cx="8.5" cy="15" r="2"/><circle cx="15.5" cy="15" r="2"/><circle cx="12" cy="18.6" r="2"/><path d="M12 7.5V4l3-1"/>',
    bread: '<path d="M4 12a5 4 0 0 1 5-4h6a5 4 0 0 1 5 4c0 1-.8 1.6-1.5 1.8V19a1 1 0 0 1-1 1h-11a1 1 0 0 1-1-1v-5.2C4.8 13.6 4 13 4 12z"/><path d="M9 12l1.5 2M13 12l1.5 2"/>',
    fish: '<path d="M3 12c3-4.5 8-5.5 12-3.5L20 5v14l-5-3.5C11 17.5 6 16.5 3 12z"/><path d="M8 11.5h.01"/>',
    pick: '<path d="M4 20l9-9"/><path d="M8.5 5.5C11 3.5 16 3 20 4c1 4 .5 9-1.5 11.5"/><path d="M12 8l4 4"/>',
    thread: '<path d="M7 4h10M7 20h10"/><path d="M8 4v16M16 4v16"/><path d="M8 8l8 3M8 12l8 3M8 16l8 2"/>',
    trash: '<path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13"/>',
    box: '<path d="M3 7.5L12 3l9 4.5v9L12 21l-9-4.5z"/><path d="M3 7.5L12 12l9-4.5M12 12v9"/>',
    truck: '<path d="M2 6h11v10H2zM13 9h4l4 4v3h-8"/><circle cx="6.5" cy="17.5" r="1.8"/><circle cx="17" cy="17.5" r="1.8"/>',
    cross: '<path d="M9 3h6v6h6v6h-6v6H9v-6H3V9h6z"/>',
    badge: '<path d="M12 3l7 3v5c0 5-3.5 8.5-7 10-3.5-1.5-7-5-7-10V6z"/><path d="M9 12l2 2 4-4"/>',
    wrench: '<path d="M14.5 6.5a4 4 0 0 0 5 5L12 19a2.1 2.1 0 0 1-3-3l7.5-7.5a4 4 0 0 1-2-2z"/>',
    map: '<path d="M9 4L3 6v14l6-2 6 2 6-2V4l-6 2z"/><path d="M9 4v14M15 6v14"/>',
};
const ic = (n, cls) => `<svg viewBox="0 0 24 24" class="${cls || ''}" aria-hidden="true">${P[n] || P.help}</svg>`;

let G = null, page = 0, opened = false, welcomeMode = false;

function renderNav() {
    const nav = $('#nav'); nav.innerHTML = '';
    G.pages.forEach((p, i) => {
        const b = document.createElement('button'); b.type = 'button';
        b.className = i === page ? 'on' : '';
        b.innerHTML = `${ic(p.icon)}<span>${esc(p.title)}</span>`;
        b.onclick = () => { page = i; render(); };
        nav.appendChild(b);
    });
}

function tagHtml(t) {
    if (!t) return '';
    return `<span class="tag${t === 'بالتوظيف' ? ' team' : ''}">${esc(t)}</span>`;
}

function renderBody() {
    const p = G.pages[page], b = $('#body');
    $('#welcome').classList.toggle('hidden', !(welcomeMode && page === 0));
    $('#p-title').textContent = p.title;
    $('#p-intro').textContent = p.intro || '';
    let html = '';
    if (p.steps) {
        html = '<ol class="steps">' + p.cards.map((c, i) => `<li><span class="n">${i + 1}</span><div><h3>${esc(c.title)}</h3><p>${esc(c.text)}</p></div>${tagHtml(c.tag)}</li>`).join('') + '</ol>';
    } else if (p.keys) {
        html = '<div class="keys">' + p.cards.map((c) => `<div class="key"><span class="cap">${esc(c.key)}</span><div><h3>${esc(c.title)}</h3><p>${esc(c.text)}</p></div></div>`).join('') + '</div>';
    } else {
        html = '<div class="cards">' + p.cards.map((c) => c.icon
            ? `<div class="card">${ic(c.icon, 'ic')}<div class="top"><h3>${esc(c.title)}</h3>${tagHtml(c.tag)}</div><p>${esc(c.text)}</p></div>`
            : `<div class="card no-ic"><div class="top"><h3>${esc(c.title)}</h3>${tagHtml(c.tag)}</div><p>${esc(c.text)}</p></div>`).join('') + '</div>';
    }
    b.innerHTML = html; b.scrollTop = 0;
}

function render() { renderNav(); renderBody(); }

function open(data) {
    G = data.guide; page = 0;
    $('#g-title').textContent = G.title;
    const w = $('#welcome');
    welcomeMode = data.welcome === true;
    w.innerHTML = `<b>${esc(G.welcomeTitle)}</b><span>${esc(G.welcomeLine)}</span>`;
    render();
    $('#shade').classList.remove('hidden');
    const g = $('#guide'); g.classList.remove('hidden', 'enter'); void g.offsetWidth; g.classList.add('enter');
    opened = true;
    fit();
    setTimeout(() => $('#done').focus(), 50);
}
function close() {
    if (!opened) return;
    opened = false;
    $('#guide').classList.add('hidden'); $('#shade').classList.add('hidden');
    post('close');
}
function fit() { document.documentElement.style.zoom = String(Math.max(0.6, Math.min(1.5, Math.min(window.innerHeight / 900, window.innerWidth / 1500)))); }
window.addEventListener('resize', fit);

$('#close').onclick = close;
$('#done').onclick = close;
$('#gps').onclick = () => { post('gps'); close(); };
window.addEventListener('keydown', (e) => {
    if (!opened) return;
    if (e.key === 'Escape') close();
    else if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
        page = (page + (e.key === 'ArrowDown' ? 1 : -1) + G.pages.length) % G.pages.length; render(); e.preventDefault();
    }
});
window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.action === 'open') open(m);
    else if (m.action === 'close') close();
    else if (m.action === 'safe') {
        const el = document.getElementById('safe');
        if (!el) return;
        if (m.text) document.getElementById('safe-text').textContent = m.text.split(' — ')[0];
        el.classList.toggle('hidden', !m.on);
    }
});

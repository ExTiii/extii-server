// EX_Tii Police tablet — Chat (Staff Network, like the video): one-to-one lines and groups,
// photos from your gallery, emoji, read / unread.
(() => {
    const { S, I, esc, call, render, after, toast, fail, ask, initials, safeUrl, ago, fmtTime } = PT;

    S.chat = {
        list: [], cur: null, draft: '', image: '', emoji: false, menu: false, loaded: false,
        modal: null,   // { tab: 'members' | 'group', q, sel: [cid], name, photo }
        dir: [], stick: false,
    };
    const C = () => S.chat;

    const EMOJI = ['👍', '👌', '🙏', '😂', '😅', '😎', '🤔', '😡', '😢', '👀', '🚓', '🚨', '👮', '🚑', '📍', '✅', '❌', '⚠️', '📷', '🕐'];

    function avatar(item, size = '') {
        const photo = safeUrl(item.photo);
        const inner = photo ? `<img src="${esc(photo)}" alt="">` : esc(initials(item.name));
        const dot = item.kind !== 'group' && item.online != null ? `<em class="${item.online ? 'on' : ''}"></em>` : '';
        return `<i class="pt-av ${size}">${inner}${dot}</i>`;
    }

    // ------------------------------------------------------------------
    // drawing
    // ------------------------------------------------------------------
    function listView() {
        const items = PT.list(C().list);
        if (!items.length) return `<p class="pt-mute pad">${C().loaded ? 'لا توجد محادثات مفتوحة بعد.' : 'جارٍ التحميل…'}</p>`;
        return items.map((c) => `<button class="pt-crow ${C().cur && C().cur.id === c.id ? 'on' : ''}" data-act="chatOpen" data-id="${c.id}">
            ${avatar(c)}
            <span class="pt-crow-main"><b>${esc(c.name || '—')}</b><small>${c.kind === 'group' ? `مجموعة · ${c.count || 0} أعضاء` : esc(c.rank ? `الشرطة · ${c.rank}` : 'الشرطة')}</small>
            ${c.preview ? `<small class="pt-prev">${esc(c.preview)}</small>` : ''}</span>
            ${c.unread ? `<em class="pt-count">${c.unread > 99 ? '99+' : c.unread}</em>` : ''}
        </button>`).join('');
    }

    function readState(m, cur) {
        const others = PT.list(cur.people).filter((p) => !p.me);
        if (!others.length) return '';
        const read = others.every((p) => (p.lastRead || 0) >= m.id);
        return `<i class="pt-read ${read ? 'yes' : ''}">${read ? 'مقروءة' : 'غير مقروءة'}</i>`;
    }

    function messagesView(cur) {
        const msgs = PT.list(cur.messages);
        if (!msgs.length) {
            return `<div class="pt-cempty"><b>${cur.kind === 'group' ? 'لا توجد رسائل في المجموعة بعد' : 'لا توجد رسائل خاصة بعد'}</b>
                <small>${cur.kind === 'group' ? 'ابدأ الحديث في هذه المجموعة.' : 'ابدأ خطًا مباشرًا مع هذا الزميل.'}</small></div>`;
        }
        let lastDay = '';
        return msgs.map((m) => {
            const day = PT.fmtDate(m.at);
            const sep = day !== lastDay ? `<div class="pt-dsep"><span class="ltr">${esc(day)}</span></div>` : '';
            lastDay = day;
            const img = safeUrl(m.image);
            return `${sep}<div class="pt-msg ${m.mine ? 'mine' : ''}">
                ${m.mine ? '' : `<i class="pt-av xs">${esc(initials(m.name))}</i>`}
                <div class="pt-bubble">
                    <div class="pt-bhead"><b>${esc(m.name)}</b><span class="ltr">${esc(fmtTime(m.at))}</span>${m.mine ? readState(m, cur) : ''}</div>
                    ${img ? `<button class="pt-bimg" data-act="view" data-url="${esc(img)}"><img src="${esc(img)}" alt=""><span>اضغط للتكبير</span></button>` : ''}
                    ${m.text ? `<p>${esc(m.text)}</p>` : ''}
                </div>
            </div>`;
        }).join('');
    }

    function convoView() {
        const c = C();
        const cur = c.cur;
        if (!cur) {
            return `<div class="pt-chead"><div class="pt-titles"><small>اختر محادثة</small><h1>شبكة الأفراد</h1></div></div>
                <div class="pt-cempty center"><b>اختر محادثة أو ابدأ واحدة جديدة.</b><small>زر (+) فوق قائمة المحادثات.</small></div>`;
        }
        after(() => {
            const el = document.querySelector('[data-scroll="msgs"]');
            if (el && c.stick) {
                el.scrollTop = el.scrollHeight;
                S.scrolls.msgs = el.scrollTop;
                c.stick = false;
            }
        });
        const people = PT.list(cur.people);
        const menu = c.menu && cur.kind === 'group' ? `<div class="pt-cmenu">
            <h4>أعضاء المجموعة (${people.length})</h4>
            <div class="pt-cmembers">${people.map((p) => `<div>${avatar({ name: p.name, online: p.online })}<span><b>${esc(p.name)}${p.me ? ' <i class="pt-me">أنت</i>' : ''}</b><small>${esc(p.rank || '')}</small></span></div>`).join('')}</div>
            <button class="pt-btn danger sm wide" data-act="chatLeave">${I('x', 14, 2.2)} مغادرة المجموعة</button>
        </div>` : '';
        const image = safeUrl(c.image);
        return `<div class="pt-chead">
                ${avatar({ name: cur.name, photo: cur.photo, kind: cur.kind, online: cur.kind === 'dm' ? (people.find((p) => !p.me) || {}).online : null }, 'md')}
                <div class="pt-titles"><small>${cur.kind === 'group' ? 'محادثة جماعية' : 'خط خاص'}</small><h1>${esc(cur.name || '—')}</h1></div>
                ${cur.kind === 'group' ? `<button class="pt-iconbtn ${c.menu ? 'on' : ''}" data-act="chatMenu" title="الأعضاء">${I('menu', 18, 2)}</button>`
                    : `<button class="pt-iconbtn" data-act="chatLeave" title="إغلاق المحادثة">${I('x', 16, 2)}</button>`}
            </div>
            ${menu}
            <div class="pt-msgs" data-scroll="msgs">${messagesView(cur)}</div>
            ${c.emoji ? `<div class="pt-emoji">${EMOJI.map((e) => `<button data-act="chatEmoji" data-e="${e}">${e}</button>`).join('')}</div>` : ''}
            ${image ? `<div class="pt-attach"><img src="${esc(image)}" alt=""><span>صورة مرفقة</span><button class="pt-x" data-act="chatNoImage">${I('x', 14, 2.2)}</button></div>` : ''}
            <div class="pt-composer">
                <button class="pt-iconbtn" data-act="chatImage" title="صورة من المعرض">${I('image', 18, 2)}</button>
                <input class="pt-in" data-model="chat.draft" data-enter="chatSend" maxlength="${S.cfg.maxText || 500}" value="${esc(c.draft)}" placeholder="${esc(cur.kind === 'group' ? 'اكتب رسالة للمجموعة…' : `اكتب رسالة إلى ${cur.name || ''}…`)}">
                <button class="pt-iconbtn ${c.emoji ? 'on' : ''}" data-act="chatEmojiToggle" title="رموز">${I('smile', 18, 2)}</button>
                <button class="pt-btn primary sm" data-act="chatSend">${I('send', 15, 2)} إرسال</button>
            </div>`;
    }

    function modalView() {
        const m = C().modal;
        if (!m) return '';
        const q = (m.q || '').trim().toLowerCase();
        const dir = PT.list(C().dir).filter((p) => !q || p.name.toLowerCase().includes(q) || (p.rank || '').toLowerCase().includes(q));
        // grouped by rank, the highest first (like the departments in the video)
        const groups = [];
        const seen = new Map();
        dir.slice().sort((a, b) => (b.grade - a.grade) || a.name.localeCompare(b.name)).forEach((p) => {
            if (!seen.has(p.rank)) { seen.set(p.rank, []); groups.push([p.rank, seen.get(p.rank)]); }
            seen.get(p.rank).push(p);
        });
        const isGroup = m.tab === 'group';
        const sel = m.sel || [];
        const all = PT.list(C().dir);
        const rows = groups.length ? groups.map(([rank, people]) => `<h5>${esc(rank)}</h5>${people.map((p) => {
            const on = sel.includes(p.cid);
            return `<button class="pt-prow ${on ? 'on' : ''}" data-act="${isGroup ? 'chatToggle' : 'chatStart'}" data-cid="${esc(p.cid)}">
                ${avatar({ name: p.name, online: p.online })}<span><b>${esc(p.name)}</b><small>${esc(p.rank)}${p.online ? ' · متصل' : ''}</small></span>
                ${isGroup ? `<em class="pt-added">${on ? `${I('check', 13, 2.4)} أُضيف` : 'إضافة'}</em>` : `<em class="pt-added go">${I('chat', 13, 2)} مراسلة</em>`}
            </button>`;
        }).join('')}`).join('') : `<p class="pt-mute pad">${all.length ? 'لا أحد بهذا الاسم.' : 'لا يوجد زملاء آخرون في الشرطة بعد.'}</p>`;
        const chips = isGroup && sel.length ? `<div class="pt-chips"><small>الأعضاء المختارون</small><div>${sel.map((cid) => {
            const p = all.find((x) => x.cid === cid);
            return `<button class="pt-schip" data-act="chatToggle" data-cid="${esc(cid)}">${esc(p ? p.name : cid)} ${I('x', 11, 2.4)}</button>`;
        }).join('')}</div></div>` : '';
        const photo = safeUrl(m.photo);
        const groupHead = isGroup ? `<div class="pt-ghead">
            <button class="pt-gphoto" data-act="chatGroupPhoto" title="صورة المجموعة">${photo ? `<img src="${esc(photo)}" alt="">` : I('camera', 20, 1.9)}<i>${I('edit', 11, 2.2)}</i></button>
            <label class="pt-field grow"><span>اسم المجموعة</span><input class="pt-in" data-model="chat.modal.name" maxlength="40" value="${esc(m.name || '')}" placeholder="مثلًا: دورية الليل"></label>
        </div>` : '';
        return `<div class="pt-layer"><div class="pt-backdrop" data-act="chatModalClose"></div>
            <div class="pt-modal tall">
                <div class="pt-mhead"><div><small>دليل الأفراد</small><h2>بدء محادثة</h2></div><button class="pt-x" data-act="chatModalClose">${I('x', 16, 2.2)}</button></div>
                <div class="pt-tabs2"><button class="${!isGroup ? 'on' : ''}" data-act="chatTab" data-t="members">الأعضاء</button><button class="${isGroup ? 'on' : ''}" data-act="chatTab" data-t="group">إنشاء مجموعة</button></div>
                ${groupHead}
                <div class="pt-search">${I('search', 15, 2)}<input class="pt-in bare" data-model="chat.modal.q" data-live="1" value="${esc(m.q || '')}" placeholder="ابحث بالاسم أو الرتبة"></div>
                ${chips}
                <div class="pt-plist" data-scroll="dir">${rows}</div>
                ${isGroup ? `<div class="pt-mfoot"><button class="pt-btn ghost" data-act="chatModalClose">إلغاء</button><button class="pt-btn primary" data-act="chatCreate" ${sel.length ? '' : 'disabled'}>${I('plus', 15, 2.2)} إنشاء المجموعة (${sel.length + 1})</button></div>` : ''}
            </div></div>`;
    }

    function view() {
        return `<div class="pt-appwin pt-chatapp">
            <aside class="pt-cside">
                <div class="pt-chead side">
                    <button class="pt-back" data-act="home" title="رجوع">${I('back', 20, 2.2)}</button>
                    <div class="pt-titles"><small>الاتصالات</small><h1>شبكة الأفراد</h1></div>
                </div>
                <div class="pt-sidehead"><small>المحادثات المفتوحة</small><button class="pt-iconbtn sm" data-act="chatNew" title="محادثة جديدة">${I('newchat', 17, 2)}</button></div>
                <div class="pt-clist" data-scroll="clist">${listView()}</div>
            </aside>
            <section class="pt-cmain">${convoView()}</section>
            ${modalView()}${PT.pickerView()}
        </div>`;
    }

    // ------------------------------------------------------------------
    // talking to the server
    // ------------------------------------------------------------------
    function loadList() {
        return call('chats').then((res) => {
            if (res.ok) { C().list = PT.list(res.r); C().loaded = true; }
            return res;
        });
    }
    function openChat(id, quiet) {
        return call('chatOpen', id).then((res) => {
            if (!res.ok) { if (!quiet) fail(res); return res; }
            const prevCount = C().cur && C().cur.id === id ? PT.list(C().cur.messages).length : -1;
            C().cur = res.r;
            if (PT.list(res.r.messages).length !== prevCount) C().stick = true;
            const row = PT.list(C().list).find((x) => x.id === id);
            if (row) row.unread = 0;
            return res;
        });
    }
    function badges() {
        call('badges').then((res) => { if (res.ok) { S.badges = res.r; render(); } });
    }

    function send() {
        const c = C();
        if (!c.cur) return;
        const text = (c.draft || '').trim();
        const image = safeUrl(c.image);
        if (!text && !image) return;
        const id = c.cur.id;
        c.draft = '';
        c.image = '';
        c.emoji = false;
        render();
        call('chatSend', id, text, image).then((res) => {
            if (!res.ok) {
                c.draft = text;
                c.image = image;
                return fail(res);
            }
            if (c.cur && c.cur.id === id) { c.cur = res.r; c.stick = true; }
            loadList().then(() => render());
        });
    }

    PT.onPick.msg = (url) => { C().image = url; render(); };
    PT.onPick.group = (url) => { if (C().modal) C().modal.photo = url; render(); };

    PT.app('chat', {
        view,
        enter() {
            const c = C();
            c.cur = null; c.menu = false; c.emoji = false; c.modal = null; c.draft = ''; c.image = '';
            loadList().then(() => render());
        },
        // a new message somewhere (pushed by the server)
        push(chatId) {
            const c = C();
            loadList().then(() => {
                if (c.cur && c.cur.id === chatId) openChat(chatId, true).then(() => { render(); badges(); });
                else { render(); badges(); }
            });
        },
        read(chatId) {
            const c = C();
            if (c.cur && c.cur.id === chatId) openChat(chatId, true).then(() => render());
        },
        back() {
            const c = C();
            if (S.pick) { S.pick = null; render(); return true; }
            if (c.modal) { c.modal = null; render(); return true; }
            if (c.emoji || c.menu) { c.emoji = false; c.menu = false; render(); return true; }
            return false;
        },
        act: {
            chatOpen: (el) => {
                const id = Number(el.dataset.id);
                const c = C();
                c.menu = false; c.emoji = false; c.draft = ''; c.image = '';
                openChat(id).then(() => { render(); badges(); });
            },
            chatSend: send,
            chatEmojiToggle: () => { C().emoji = !C().emoji; render(); },
            chatEmoji: (el) => { const c = C(); if ((c.draft || '').length < (S.cfg.maxText || 500)) c.draft = (c.draft || '') + el.dataset.e; render(); },
            chatImage: () => PT.pick('msg'),
            chatNoImage: () => { C().image = ''; render(); },
            chatMenu: () => { C().menu = !C().menu; render(); },
            chatLeave: () => {
                const cur = C().cur;
                if (!cur) return;
                const group = cur.kind === 'group';
                ask({
                    title: group ? 'مغادرة المجموعة؟' : 'إغلاق هذه المحادثة؟',
                    text: group ? 'لن تصلك رسائل هذه المجموعة بعد الآن.' : 'تختفي من قائمتك، وترجع بكل رسائلها إذا وصلت رسالة جديدة.',
                    ok: group ? 'مغادرة' : 'إغلاق', danger: true,
                }, () => {
                    call('chatLeave', cur.id).then((res) => {
                        if (!res.ok) return fail(res);
                        C().list = PT.list(res.r);
                        C().cur = null;
                        C().menu = false;
                        render();
                    });
                });
            },
            chatNew: () => {
                C().modal = { tab: 'members', q: '', sel: [], name: '', photo: '' };
                render();
                call('chatDirectory').then((res) => { if (res.ok) { C().dir = PT.list(res.r); render(); } });
            },
            chatModalClose: () => { C().modal = null; render(); },
            chatTab: (el) => { if (C().modal) { C().modal.tab = el.dataset.t === 'group' ? 'group' : 'members'; render(); } },
            chatToggle: (el) => {
                const m = C().modal;
                if (!m) return;
                const cid = el.dataset.cid;
                m.sel = m.sel.includes(cid) ? m.sel.filter((x) => x !== cid) : [...m.sel, cid].slice(0, 39);
                render();
            },
            chatGroupPhoto: () => PT.pick('group'),
            chatStart: (el) => {
                call('chatStart', el.dataset.cid).then((res) => {
                    if (!res.ok) return fail(res);
                    const c = C();
                    c.modal = null;
                    c.list = PT.list(res.r.list);
                    c.cur = res.r.chat;
                    c.stick = true;
                    render();
                });
            },
            chatCreate: () => {
                const m = C().modal;
                if (!m) return;
                if ((m.name || '').trim().length < 2) return toast('اكتب اسمًا للمجموعة', 'error');
                call('chatGroup', { name: m.name.trim(), photo: safeUrl(m.photo), members: m.sel }).then((res) => {
                    if (!res.ok) return fail(res);
                    const c = C();
                    c.modal = null;
                    c.list = PT.list(res.r.list);
                    c.cur = res.r.chat;
                    c.stick = true;
                    toast('أُنشئت المجموعة');
                });
            },
        },
    });
})();

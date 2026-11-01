// =====================================================================
// EX_Tii Police (server): the tablet camera's photos are kept on this server, the same way the
// phone's are: saved in exti_police/photos and shown at
// https://<the server's address>/exti_police/photos/<file>. No outside picture service or token.
// server/tablet.lua takes the picture (screencapture) and gives it here to save.
// =====================================================================
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const RES = GetCurrentResourceName();
// FiveM only lets a resource write files inside its own folder
const DIR = path.join(GetResourcePath(RES), 'photos');
const FILE_RE = /^[a-f0-9]{32}\.(webp|jpg|png)$/;
const TYPES = { webp: 'image/webp', jpg: 'image/jpeg', png: 'image/png' };
const MAX_BYTES = 8 * 1024 * 1024;

// the public address of the photos, without a trailing slash (null = the server has none yet)
function baseUrl() {
    const custom = GetConvar('exti_police:photoBaseUrl', '').trim().replace(/\/+$/, '');
    if (custom) return custom;
    const web = GetConvar('web_baseUrl', '').trim().replace(/\/+$/, '');
    if (!web) return null;
    const origin = /^https?:\/\//.test(web) ? web : `https://${web}`;
    return `${origin}/${RES}/photos`;
}

exports('photoBase', () => baseUrl() || false);

// a "data:image/...;base64,..." picture -> its public link (false if it can't be saved)
exports('savePhoto', (dataUri) => {
    try {
        const base = baseUrl();
        if (!base) return false;
        const match = /^data:image\/(webp|jpeg|jpg|png);base64,([A-Za-z0-9+/=\s]+)$/.exec(typeof dataUri === 'string' ? dataUri : '');
        if (!match) return false;
        const ext = match[1] === 'jpeg' ? 'jpg' : match[1];
        const buffer = Buffer.from(match[2], 'base64');
        if (!buffer.length || buffer.length > MAX_BYTES) return false;
        fs.mkdirSync(DIR, { recursive: true });
        const fileName = `${crypto.randomBytes(16).toString('hex')}.${ext}`;
        fs.writeFileSync(path.join(DIR, fileName), buffer);
        return `${base}/${fileName}`;
    } catch (e) {
        console.log(`^1[exti_police] could not save a tablet photo: ${e && e.message ? e.message : e}^0`);
        return false;
    }
});

// Replies the same way Cfx.re's own http-wrapper does (and the phone's photos): headers as plain
// strings, the body as a fresh ArrayBuffer, then send() with no arguments.
// (Passing a Node Buffer straight to res.send() can crash the whole server.)
function reply(res, status, headers, body) {
    res.writeHead(status, headers);
    if (body.byteLength > 0) {
        res.write(body.buffer.slice(body.byteOffset, body.byteOffset + body.byteLength));
    }
    res.send();
}

const TEXT = { 'Content-Type': 'text/plain; charset=utf-8' };

// https://<server>/exti_police/photos/<file>  (everything here is synchronous, so the reply
// always happens inside the request itself)
SetHttpHandler((req, res) => {
    try {
        const urlPath = String(req.path || '').split('?')[0];
        const match = /^\/photos\/([^/]+)$/.exec(urlPath);
        if (req.method !== 'GET' || !match || !FILE_RE.test(match[1])) {
            return reply(res, 404, TEXT, Buffer.from('Not found'));
        }
        const fileName = match[1];
        const filePath = path.join(DIR, fileName);
        let data;
        try {
            const stat = fs.statSync(filePath);
            if (!stat.isFile() || stat.size <= 0 || stat.size > MAX_BYTES) return reply(res, 404, TEXT, Buffer.from('Not found'));
            data = fs.readFileSync(filePath);
        } catch (_) {
            return reply(res, 404, TEXT, Buffer.from('Not found'));
        }
        return reply(res, 200, {
            'Content-Type': TYPES[fileName.split('.').pop()] || 'application/octet-stream',
            'Cache-Control': 'public, max-age=31536000, immutable',
            'Access-Control-Allow-Origin': '*',
        }, data);
    } catch (e) {
        try { reply(res, 500, TEXT, Buffer.from('Error')); } catch (_) { /* nothing more to do */ }
    }
});

setTimeout(() => {
    const base = baseUrl();
    if (base) console.log(`[exti_police] tablet photos are saved in ${DIR}`);
    else console.log('^3[exti_police] tablet camera: this server has no public web address yet (web_baseUrl is empty). The camera starts working once it has one.^0');
}, 15000);

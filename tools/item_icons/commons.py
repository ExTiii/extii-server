# public-domain / CC0 photos from Wikimedia Commons
import json, urllib.request, urllib.parse, os, sys, re
UA = {'User-Agent': 'EXTii-icons/1.0 (FiveM server item icons; contact mecheri)'}
API = 'https://commons.wikimedia.org/w/api.php?'
OK = re.compile(r'^(cc0|public domain|pd|cc-zero)', re.I)
def q(params):
    return json.load(urllib.request.urlopen(urllib.request.Request(API + urllib.parse.urlencode(params), headers=UA)))
def search(term, n=40):
    r = q({'action': 'query', 'generator': 'search', 'gsrsearch': f'filetype:bitmap {term}', 'gsrnamespace': 6, 'gsrlimit': n,
           'prop': 'imageinfo', 'iiprop': 'url|extmetadata|size', 'iiurlwidth': 1024, 'format': 'json'})
    out = []
    for p in (r.get('query', {}).get('pages', {}) or {}).values():
        ii = p['imageinfo'][0]; md = ii.get('extmetadata', {})
        lic = md.get('LicenseShortName', {}).get('value', '')
        if OK.match(lic.strip()):
            out.append({'title': p['title'], 'lic': lic, 'thumb': ii.get('thumburl'), 'url': ii['descriptionurl']})
    return out
def get(c, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, 'wb').write(urllib.request.urlopen(urllib.request.Request(c['thumb'], headers=UA)).read())
if __name__ == '__main__':
    tag = sys.argv[1]; term = ' '.join(sys.argv[2:])
    res = search(term)
    os.makedirs(f'photos/cand/{tag}', exist_ok=True)
    json.dump(res, open(f'photos/cand/{tag}/list.json', 'w'), indent=1)
    for i, c in enumerate(res[:16]):
        try: get(c, f'photos/cand/{tag}/{i:02d}.jpg')
        except Exception as e: print('x', e)
    print(tag, len(res))

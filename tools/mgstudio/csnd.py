import json, urllib.request, urllib.parse, re, sys
UA = {'User-Agent': 'EXTii-sfx/1.0 (FiveM server minigame sounds)'}
API = 'https://commons.wikimedia.org/w/api.php?'
OK = re.compile(r'^(cc0|public domain|pd|cc-zero|cc by 4\.0|cc by 3\.0|cc by-sa)', re.I)
def q(p): return json.load(urllib.request.urlopen(urllib.request.Request(API + urllib.parse.urlencode(p), headers=UA), timeout=20))
term = ' '.join(sys.argv[1:])
r = q({'action': 'query', 'generator': 'search', 'gsrsearch': f'filetype:audio {term}', 'gsrnamespace': 6, 'gsrlimit': 25,
       'prop': 'imageinfo', 'iiprop': 'url|extmetadata|size|mediatype', 'format': 'json'})
for p in (r.get('query', {}).get('pages', {}) or {}).values():
    ii = p['imageinfo'][0]; md = ii.get('extmetadata', {})
    lic = md.get('LicenseShortName', {}).get('value', '')
    dur = ii.get('duration')
    print(f"{lic[:14]:14} {round(ii.get('size',0)/1024):6}k  {p['title'][:90]}")

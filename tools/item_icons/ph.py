import json,urllib.request,os,sys
H={'User-Agent':'EXTii-icon-studio/1.0'}
def op(u): return urllib.request.urlopen(urllib.request.Request(u,headers=H))
def get(u): return json.load(op(u))
def dl(u,p):
    os.makedirs(os.path.dirname(p) or '.',exist_ok=True)
    if not os.path.exists(p): open(p,'wb').write(op(u).read())
def model(mid,res='1k'):
    f=get(f'https://api.polyhaven.com/files/{mid}')
    g=f['gltf'].get(res) or f['gltf']['2k']; g=g['gltf']
    d=f'assets/{mid}'
    dl(g['url'],f"{d}/{mid}.gltf")
    for rel,inc in g['include'].items(): dl(inc['url'],f"{d}/{rel}")
    return f"{d}/{mid}.gltf"
def tex(tid,res='1k'):
    f=get(f'https://api.polyhaven.com/files/{tid}'); out={}
    for k in ('Diffuse','nor_gl','Rough','AO','Displacement','arm'):
        if k in f and res in f[k]:
            e=f[k][res].get('jpg') or f[k][res].get('png'); p=f'assets/tex/{tid}/{k}.'+e['url'].rsplit('.',1)[1]; dl(e['url'],p); out[k]=p
    return out
def hdri(hid,res='1k'):
    f=get(f'https://api.polyhaven.com/files/{hid}'); p=f'hdri/{hid}.hdr'; dl(f['hdri'][res]['hdr']['url'],p); return p
if __name__=='__main__':
    for a in sys.argv[1:]:
        k,n=a.split(':'); print({'m':model,'t':tex,'h':hdri}[k](n))

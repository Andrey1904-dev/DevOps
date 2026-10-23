"""Allowlist-only static build. Never reads SQLite, instructions, auth or audits."""
from pathlib import Path
import hashlib
import json
import sys

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from content import public_catalog

def build():
    dest=ROOT/'dist'
    if dest.is_symlink():raise SystemExit('Unsafe dist symlink')
    dest.mkdir(exist_ok=True)
    allowed={'index.html','style.css','app.js','client.js','config.js','catalog.json','.nojekyll','build.json'}
    if any(p.name not in allowed or p.is_symlink() for p in dest.iterdir()):
        raise SystemExit('Unexpected dist contents; inspect manually, nothing deleted')
    html=(ROOT/'web/index.html').read_text().replace('href="/style.css"','href="./style.css"').replace('src="/app.js"','src="./app.js"')
    html=html.replace('<script src="./app.js"', '<script src="./config.js" defer></script><script src="./client.js" defer></script><script src="./app.js"')
    csp="default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self' https://bkufrpbjgtpwtvutsvnh.supabase.co; img-src 'self'; base-uri 'none'; form-action 'self'"
    html=html.replace('<meta name="color-scheme"',f'<meta http-equiv="Content-Security-Policy" content="{csp}"><meta name="referrer" content="no-referrer"><meta name="color-scheme"')
    html=html.replace('Локальный MVP','Онлайн-кабинет').replace('Локальная среда','Supabase Auth')
    # Keep the original local application unchanged; remove the local-only
    # settings body from this generated app to avoid loopback references.
    app=(ROOT/'web/app.js').read_text()
    start=app.index(" return heading('Данные остаются локально'")
    end=app.index('\nfunction render()',start)
    app=app[:start]+" return ''; }\n"+app[end:]
    files={'index.html':html,'app.js':app,'style.css':(ROOT/'web/style.css').read_text(),
           'client.js':(ROOT/'cloud/client.js').read_text(),'config.js':(ROOT/'cloud/config.js').read_text(),
           'catalog.json':json.dumps(public_catalog(),ensure_ascii=False,indent=2),'.nojekyll':''}
    for name,body in files.items():
        if any(x in body for x in ('127.0.0.1','localhost','service_role','sb_secret_','/Users/')):
            raise SystemExit('Forbidden deployment content in '+name)
        (dest/name).write_text(body)
    manifest={name:hashlib.sha256((dest/name).read_bytes()).hexdigest() for name in files}
    (dest/'build.json').write_text(json.dumps({'format':1,'files':manifest},indent=2)+'\n')
    print('Static build:',len(files)+1,'allowlisted files; no learner data')

if __name__=='__main__':build()

"""Static artifact privacy and project-site path checks."""
from pathlib import Path
import json,re

root=Path(__file__).resolve().parents[1];dist=root/'dist'
expected={'index.html','app.js','style.css','client.js','config.js','catalog.json','.nojekyll','build.json'}
assert {p.name for p in dist.iterdir()}==expected
for p in dist.iterdir():
    assert p.is_file() and not p.is_symlink()
    s=p.read_text()
    for forbidden in ('127.0.0.1','localhost','/Users/','sb_secret_','service_role','gho_','sbp_','BEGIN PRIVATE KEY'):
        assert forbidden not in s,(p.name,forbidden)
html=(dist/'index.html').read_text()
assert 'href="./style.css"' in html and 'src="./app.js"' in html
assert not re.search(r'(?:src|href)="/(?!/)',html)
catalog=json.loads((dist/'catalog.json').read_text())
assert len(catalog['lessons'])==10 and len(catalog['diagnostics'])==9 and len(catalog['program'])==30
assert len({x['id'] for x in catalog['lessons']})==10
assert len(catalog['mentors'])==9
assert all('expected' not in x for x in catalog['lessons'])
print('PASS: 8 allowlisted files, project-relative assets, public key only, stable materials; no learner data')

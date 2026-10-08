"""Assemble the unchanged 1.0.0 deliverables, source and QA evidence."""
from pathlib import Path
import hashlib,json,shutil,zipfile,struct
root=Path.cwd();release=root/'downloads/1.0.0'
manifest_path=root/'_upload/manifest.json';manifest=json.loads(manifest_path.read_text());cleanup=[];verified=[]
for item in manifest['outputs']:
    destination=Path(item['path']);assert destination.parent==Path('downloads/1.0.0')
    data=bytearray()
    for part in item['parts']:
        path=Path(part['path']);assert path.parent==Path('_upload') and path.name.startswith(destination.name+'.part')
        block=path.read_bytes();assert len(block)==part['bytes'] and hashlib.sha256(block).hexdigest()==part['sha256']
        data.extend(block);cleanup.append(path)
    assert len(data)==item['bytes'] and hashlib.sha256(data).hexdigest()==item['sha256']
    destination.write_bytes(data)
    verified.append({'file':destination.name,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'result':'PASS'})
    print('Verified original release:',destination.name,len(data),'bytes')
def extract(archive,prefix,target):
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None
        for name in z.namelist():
            if name.endswith('/'):continue
            relative=Path(name);assert not relative.is_absolute() and '..' not in relative.parts and name.startswith(prefix)
            dest=target/name[len(prefix):];dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(z.read(name))
extract(release/'BlackoutSector13-Source-1.0.0.zip','game/',root/'game')
extract(release/'BlackoutSector13-QA-Evidence-1.0.0.zip','BlackoutSector13-QA/',root/'docs/qa')
for name in ['Player-Guide-FA.html','QA-Report.md']:shutil.copyfile(root/'game/docs'/name,release/name)
shutil.copyfile(root/'docs/qa/screenshots/05-reactor.png',release/'BlackoutSector13-Gameplay.png')
for line in (release/'SHA256SUMS.txt').read_text().splitlines():
    digest,name=line.split('  ',1);assert Path(name).name==name
    assert hashlib.sha256((release/name).read_bytes()).hexdigest()==digest,name
package=json.loads((release/'Release-Manifest.json').read_text())
with zipfile.ZipFile(release/'BlackoutSector13-Windows-x64-Portable-1.0.0.zip') as z:
    assert z.testzip() is None
    for item in package['payload']:
        data=z.read('BlackoutSector13/'+item['file']);assert len(data)==item['bytes'] and hashlib.sha256(data).hexdigest()==item['sha256']
    exe=z.read('BlackoutSector13/BlackoutSector13.exe');pe=struct.unpack_from('<I',exe,0x3c)[0]
    assert exe[:2]==b'MZ' and exe[pe:pe+4]==b'PE\0\0' and struct.unpack_from('<H',exe,pe+4)[0]==0x8664
report={'scope':'GitHub delivery verification only; not Windows execution','version':'1.0.0','files':verified,'all_eight_release_checksums':'PASS','portable_crc_and_payload_hashes':'PASS','game_pe_architecture':'AMD64','windows_gameplay':'NOT TESTED'}
(root/'docs/qa/GitHub-Upload-Verification.json').write_text(json.dumps(report,indent=2)+'\n')
for path in cleanup:path.unlink()
manifest_path.unlink();(root/'_upload/assemble.py').unlink();(root/'_upload').rmdir()
print('All release checksums, source archive and portable payload passed; temporary parts removed.')

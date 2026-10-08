"""Build and inspect the final NSIS installer and portable ZIP.

Prerequisites: exported and metadata-patched Windows runtime; completed QA;
QA-Report.md, Persian guide and notices in artifacts/release. Run from anywhere.
The extracted NSIS payload and ZIP bytes are checked; Windows is NOT executed.
"""
from pathlib import Path
import os, subprocess, zipfile, hashlib, json, shutil, pefile

root=Path(__file__).resolve().parents[2]
artifacts=root/'artifacts';release=artifacts/'release'
setup=artifacts/'BlackoutSector13-Setup-1.0.0.exe'
portable=artifacts/'BlackoutSector13-Windows-x64-Portable-1.0.0.zip'
source=artifacts/'BlackoutSector13-Source-1.0.0.zip'
expected=['BlackoutSector13.exe','BlackoutSector13.pck','Player-Guide-FA.html','QA-Report.md','THIRD-PARTY-NOTICES.txt']
assert all((release/name).is_file() for name in expected)
binary=pefile.PE(str(release/expected[0]))
assert binary.FILE_HEADER.Machine==0x8664 and binary.OPTIONAL_HEADER.Magic==0x20b
assert binary.OPTIONAL_HEADER.DATA_DIRECTORY[4].Size==0, 'Report assumes unsigned binary'
env=os.environ.copy();env['NSISDIR']=str(root/'tools/prefix/usr/share/nsis')
with open(root/'logs/installer.log','w') as log:
    subprocess.run([str(root/'tools/prefix/usr/bin/makensis'),str(root/'game/build/installer.nsi')],env=env,stdout=log,stderr=subprocess.STDOUT,check=True)
compiler=(root/'logs/installer.log').read_text()
assert 'warning' not in compiler.lower(),compiler
print('NSIS compilation PASS: no warnings',flush=True)
with zipfile.ZipFile(portable,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
    for name in expected:z.write(release/name,'BlackoutSector13/'+name)
unpacked=root/'tools/final-installer-unpacked'
if unpacked.exists():shutil.rmtree(unpacked)
with open(root/'logs/installer-extract.log','w') as log:
    subprocess.run([str(root/'tools/prefix/usr/lib/7zip/7z'),'x','-y','-o'+str(unpacked),str(setup)],stdout=log,stderr=subprocess.STDOUT,check=True)
payload=[]
with zipfile.ZipFile(portable) as z:
    assert z.testzip() is None
    assert sorted(z.namelist())==sorted('BlackoutSector13/'+name for name in expected)
    for name in expected:
        installed=list(unpacked.rglob(name));assert len(installed)==1,(name,installed)
        data=(release/name).read_bytes()
        assert installed[0].read_bytes()==data and z.read('BlackoutSector13/'+name)==data,name
        payload.append({'file':name,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'installer_matches':True,'portable_matches':True})
print('Installer extraction and portable CRC / all five payload files PASS',flush=True)
uninstallers=list(unpacked.rglob('*ninstall.exe'))
assert uninstallers and all(pefile.PE(str(f)).FILE_HEADER.Machine==0x14c for f in uninstallers)
verification={'version':'1.0.0','runtime_architecture':'PE32+ AMD64','installer_architecture':'NSIS x86 Unicode, installs x64 runtime','unsigned':True,'installer_compilation_warnings':0,'payload':payload,'windows_execution':'NOT TESTED'}
(artifacts/'Package-Verification.json').write_text(json.dumps(verification,indent=2)+'\n')
with zipfile.ZipFile(source,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
    for p in sorted((root/'game').rglob('*')):
        if p.is_file() and '.godot' not in p.parts and '__pycache__' not in p.parts:
            z.write(p,p.relative_to(root))
print('Final primary files prepared:',setup.name,portable.name,flush=True)

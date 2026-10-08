from pathlib import Path
import concurrent.futures, urllib.request, hashlib, zipfile, lzma, subprocess, os

root=Path(__file__).resolve().parents[2]/'tools'
root.mkdir(exist_ok=True)
def fetch(url, path):
    path=Path(path)
    if not path.exists():
        print('Downloading', path.name, flush=True)
        with urllib.request.urlopen(url, timeout=180) as r, open(str(path)+'.part','wb') as f:
            while b:=r.read(1024*1024): f.write(b)
        Path(str(path)+'.part').rename(path)
    return path

def godot():
    base='https://github.com/godotengine/godot/releases/download/4.5.1-stable/'
    sums=fetch(base+'SHA512-SUMS.txt',root/'SHA512-SUMS.txt').read_text()
    names=['Godot_v4.5.1-stable_linux.x86_64.zip','Godot_v4.5.1-stable_export_templates.tpz']
    def one(name):
        path=fetch(base+name,root/name)
        expected=next(line.split()[0] for line in sums.splitlines() if line.split()[-1].lstrip('*')==name)
        actual=hashlib.file_digest(open(path,'rb'),'sha512').hexdigest()
        assert actual==expected, name+' SHA512 mismatch'
        print('Verified SHA512',name,flush=True)
        with zipfile.ZipFile(path) as z:
            if name.endswith('.zip'):
                z.extractall(root)
                (root/'Godot_v4.5.1-stable_linux.x86_64').chmod(0o755)
            else:
                target=Path.home()/'.local/share/godot/export_templates/4.5.1.stable'
                target.mkdir(parents=True,exist_ok=True)
                wanted={'version.txt','windows_release_x86_64.exe','windows_release_x86_64_console.exe','linux_release.x86_64'}
                for member in z.namelist():
                    if Path(member).name in wanted:
                        output=target/Path(member).name
                        output.write_bytes(z.read(member));output.chmod(0o755)
                        print('Extracted',output.name,flush=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        list(pool.map(one,names))

def packages():
    catalog={}
    for component in ['main','universe']:
        p=fetch(f'https://archive.ubuntu.com/ubuntu/dists/noble/{component}/binary-amd64/Packages.xz',root/f'{component}-Packages.xz')
        for stanza in lzma.decompress(p.read_bytes()).decode().split('\n\n'):
            fields={}
            for line in stanza.splitlines():
                if line and not line.startswith(' ') and ': ' in line:
                    k,v=line.split(': ',1);fields[k]=v
            if 'Package' in fields:catalog[fields['Package']]=fields
    names=['nsis','nsis-common','xvfb','xauth','xserver-common','libxfont2','x11-xkb-utils','libxkbfile1','7zip']
    prefix=root/'prefix';prefix.mkdir(exist_ok=True)
    for name in names:
        meta=catalog[name]
        p=fetch('https://archive.ubuntu.com/ubuntu/'+meta['Filename'],root/Path(meta['Filename']).name)
        assert hashlib.sha256(p.read_bytes()).hexdigest()==meta['SHA256']
        subprocess.run(['dpkg-deb','-x',str(p),str(prefix)],check=True)
        print('Extracted package',name,meta['Version'],flush=True)
    xkb=Path('/usr/bin/xkbcomp')
    if not xkb.exists():xkb.symlink_to(prefix/'usr/bin/xkbcomp')

with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    for f in [pool.submit(godot),pool.submit(packages)]:f.result()
print('BOOTSTRAP COMPLETE',flush=True)

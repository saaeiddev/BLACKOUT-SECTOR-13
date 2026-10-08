"""Validate exported Linux runtime using the Windows export's identical PCK.

Run from the parent of game/, after both export presets. This tests Linux only.
Required: tools/prefix/usr/bin/Xvfb and a working OpenGL software renderer.
"""
from pathlib import Path
import subprocess, os, socket, time, shutil, concurrent.futures, json

root=Path(__file__).resolve().parents[2]
artifacts=root/'artifacts'
profile=root/'tools/qa-graphical-user'
qa=artifacts/'qa-graphical'
runtime=artifacts/'Portable QA با فاصله'
runtime.mkdir(exist_ok=True);qa.mkdir(exist_ok=True)
exe=runtime/'BlackoutSector13.x86_64'
shutil.copy2(artifacts/'linux-qa/BlackoutSector13.x86_64',exe)
shutil.copy2(artifacts/'release/BlackoutSector13.pck',runtime/'BlackoutSector13.pck')
exe.chmod(0o755)
assert (artifacts/'release/BlackoutSector13.pck').read_bytes()==(artifacts/'linux-qa/BlackoutSector13.pck').read_bytes()

def run(mode,out,user,graphical=False):
    out.mkdir(exist_ok=True,parents=True);user.mkdir(exist_ok=True,parents=True)
    env=os.environ.copy()
    env.update({'XDG_DATA_HOME':str(user),'BLACKOUT_QA_DIR':str(out),'LIBGL_ALWAYS_SOFTWARE':'1','GODOT_SILENCE_ROOT_WARNING':'1'})
    if graphical:env['DISPLAY']='127.0.0.1:88'
    cmd=[str(exe)]+([] if graphical else ['--headless'])+['--audio-driver','Dummy','--fixed-fps','60','--',mode]
    started=time.monotonic()
    with open(out/(mode[2:]+'.log'),'w') as log:
        result=subprocess.run(cmd,env=env,cwd='/tmp',stdout=log,stderr=subprocess.STDOUT,timeout=300)
    data=json.loads((out/(mode[2:]+'.json')).read_text())
    print(mode,'exit=',result.returncode,'failures=',data['failures'],'checks=',len(data['checks']),'wall_seconds=',round(time.monotonic()-started,2),flush=True)
    assert result.returncode==0 and data['failures']==0

env=os.environ.copy();env['LD_LIBRARY_PATH']=str(root/'tools/prefix/usr/lib/x86_64-linux-gnu')
with open(qa/'xvfb.log','w') as xlog:
    server=subprocess.Popen([str(root/'tools/prefix/usr/bin/Xvfb'),':88','-screen','0','1280x720x24','-ac','-nolisten','unix','-nolisten','local','-listen','tcp'],env=env,stdout=xlog,stderr=subprocess.STDOUT)
    try:
        for i in range(80):
            if server.poll() is not None:raise RuntimeError('Xvfb stopped: '+(qa/'xvfb.log').read_text())
            try:
                with socket.create_connection(('127.0.0.1',6088),timeout=.2):break
            except OSError:time.sleep(.1)
        else:raise RuntimeError('Xvfb did not start')
        run('--qa-smoke',qa,profile,True)
    finally:
        server.terminate();server.wait(timeout=10)
run('--qa-reload',qa,profile)
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    futures=[pool.submit(run,'--qa-campaign',artifacts/'qa-normal',root/'tools/qa-normal-user'),pool.submit(run,'--qa-campaign-easy',artifacts/'qa-easy',root/'tools/qa-easy-user')]
    for future in futures:future.result()
print('ALL EXPORTED LINUX QA PASSED',flush=True)

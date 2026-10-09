"""Offline Linux integration: harmless sleep process stands in for the game.
Use a copy of native module with only winsqlite3.dll renamed to libsqlite3.so.0.
This does not test Windows, WPF, game modes or real Assetto Corsa Rally.
"""
import subprocess,os,json,time,pathlib,shutil,sqlite3,argparse
parser=argparse.ArgumentParser()
for name in ['root','workdir','pwsh','baseline','new']:
 parser.add_argument('--'+name,required=True)
args=parser.parse_args()
root=pathlib.Path(args.root);work=pathlib.Path(args.workdir);work.mkdir()
source=work/'source.sav';shutil.copy2(args.baseline,source)
new=args.new
exe=work/'acr-game-test';shutil.copy2('/bin/sleep',exe);exe.chmod(0o755)
env=os.environ.copy();env.update(XDG_CACHE_HOME='/tmp/acr-db-cache',XDG_CONFIG_HOME='/tmp/acr-db-config',XDG_DATA_HOME='/tmp/acr-db-data',LOCALAPPDATA=str(work/'local'))
workers=[];games=[];owners=[]
def launch(name,owner=None):
 d=work/name;d.mkdir();request=dict(SavePath=str(source),StageId='AlsaceS4SaverneShort1Forward',CarId='SkodaFabiaRSRally2',Profile='test',DatabasePath=str(work/'data.sqlite3'),Minutes=0,Once=False,TTConfirmed=True,OwnerId=0,OwnerTicks=0,GameProcessNames=['acr-game-test'])

 if owner is not None:
  ticks=int(subprocess.check_output([args.pwsh,'-NoProfile','-Command',f'(Get-Process -Id {owner.pid}).StartTime.ToUniversalTime().Ticks'],env=env,text=True).strip())
  # Linux .NET process start timestamps vary across queries. Windows GUI supplies exact ticks.
  request.update(OwnerId=owner.pid,OwnerTicks=0)
 (d/'session.json').write_text(json.dumps(request));log=(d/'output.log').open('w');p=subprocess.Popen([args.pwsh,'-NoProfile','-File',str(root/'collecteur-windows/CollectorWorker.ps1'),'-RequestPath',str(d/'session.json')],env=env,stdout=log,stderr=log);workers.append((p,d));return p,d
def wait(d,fn):
 deadline=time.monotonic()+20
 while time.monotonic()<deadline:
  try:
   state=json.loads((d/'status.json').read_text(encoding='utf-8-sig'))
   if fn(state):return state
  except (FileNotFoundError,json.JSONDecodeError):pass
  time.sleep(.15)
 raise AssertionError('state timeout '+str(d)+' '+(d/'output.log').read_text())
def game():
 p=subprocess.Popen([str(exe),'120']);games.append(p);return p
try:
 p,d=launch('first');wait(d,lambda s:s['State']=='EnAttenteDuJeu' and s['Attempts']==7)
 g=game();s=wait(d,lambda s:s['State']=='CollecteActive');sig=s['GameSignature']
 p2,d2=launch('duplicate');assert p2.wait(timeout=20)==1;wait(d2,lambda s:s['State']=='Erreur')
 shutil.copy2(new,source);s=wait(d,lambda s:s['Attempts']==8 and s['LastAttempt'] is not None);assert s['Eligible']==0 and s['Conflicts']==0
 g.terminate();g.wait();wait(d,lambda s:s['State']=='EnAttenteDuJeu')
 g=game();wait(d,lambda s:s['State']=='CollecteActive' and s['GameSignature']!=sig)
 (d/'stop').write_text('stop');assert p.wait(timeout=20)==0
 p3,d3=launch('restart');wait(d3,lambda s:s['Attempts']==8 and s['State']=='CollecteActive')
 (d3/'stop').write_text('stop');assert p3.wait(timeout=20)==0
 owner=subprocess.Popen([args.pwsh,'-NoProfile','-Command','Start-Sleep -Seconds 120'],env=env);owners.append(owner)
 p4,d4=launch('owner-close',owner);wait(d4,lambda s:s['Attempts']==8 and s['State']=='CollecteActive')
 owner.terminate();owner.wait();assert p4.wait(timeout=20)==0
 wait(d4,lambda s:s['State']=='Arrete')
 con=sqlite3.connect(work/'data.sqlite3');assert con.execute('select count(*) from attempts').fetchone()[0]==8;assert con.execute('select count(*) from eligible_attempts').fetchone()[0]==0;assert con.execute('pragma integrity_check').fetchone()[0]=='ok'
 print('PASS worker reel hors jeu : attente, processus simule, nouvelle capture, fermeture/reprise, double collecteur refuse, arret, redemarrage, 8 uniques non admissibles')
finally:
 for p,d in workers:
  (d/'stop').write_text('stop')
  if p.poll() is None:p.wait(timeout=20)
 for p in games+owners:
  if p.poll() is None:p.terminate();p.wait()

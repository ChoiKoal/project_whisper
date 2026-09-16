"""Portable serial CURRENT15 safety runner. Synthetic fixtures only, no existing saves.
Requires imported Godot 4.5 project; use --godot for the engine path. No process kills.
"""
from pathlib import Path
import argparse,hashlib,json,os,subprocess,sys,time
GAME=Path(__file__).resolve().parents[1]
CASES={
 'future_save_safety_harness':'FUTURE_SAVE_SAFETY_DONE failures=0',
 'pending_lock_safety_harness':'PENDING_LOCK_SAFETY_DONE failures=0',
 'night_flower_art_harness':'NIGHT_FLOWER_ART_DONE failures=0',
 'cutscene_harness':'=== RESULT: PASS (0 failures) ===',
 'm5_test_harness':'=== RESULT: PASS (0 failures) ===',
 'v051_test_harness':'=== RESULT: PASS (0 failures) ===',
 'v052_travel_stress':'=== RESULT: PASS (0 failures) ===',
}
def hashes():
 return {str(p.relative_to(GAME)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(GAME.rglob('*')) if p.is_file() and '.godot' not in p.parts and '__pycache__' not in p.parts}
def main():
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--godot',required=True,type=Path)
 parser.add_argument('--evidence',required=True,type=Path,help='New, not-yet-existing directory. All synthetic HOME files stay inside it.')
 parser.add_argument('--case',action='append',choices=list(CASES))
 args=parser.parse_args()
 engine=args.godot.expanduser().resolve();out=args.evidence.expanduser().resolve()
 if not engine.is_file():parser.error('Godot executable missing')
 if out.exists():parser.error('Evidence directory already exists; choose a new path, never overwrite')
 live=subprocess.check_output(['ps','-axo','pid,state,comm'],text=True)
 if any(line.rstrip().endswith('/Godot') and ' Z ' not in line for line in live.splitlines()):parser.error('Another Godot is live; serial-only runner refuses')
 selected=list(dict.fromkeys(args.case or CASES))
 out.mkdir(parents=True)
 baseline=hashes();(out/'source-hashes.json').write_text(json.dumps(baseline,indent=2))
 results=[]
 for name in selected:
  home=out/'homes'/name;home.mkdir(parents=True)
  env=os.environ.copy();env.update(HOME=str(home),WHISPER_TEST_HOME=str(home),XDG_DATA_HOME=str(home/'.local/share'),XDG_CONFIG_HOME=str(home/'.config'),XDG_CACHE_HOME=str(home/'.cache'))
  command=[str(engine),'--path',str(GAME),'--headless','--max-fps','60','--quit-after','18000',str(GAME/'scenes/dev'/(name+'.tscn'))]
  log=out/(name+'.log');start=time.monotonic()
  with log.open('w') as stream:result=subprocess.run(command,env=env,stdout=stream,stderr=subprocess.STDOUT)
  text=log.read_text();lines=text.splitlines()
  row={'scene':name,'exit':result.returncode,'seconds':round(time.monotonic()-start,2),'assertions':sum('[PASS]' in line for line in lines),'failures':sum('[FAIL]' in line for line in lines),'script_errors':text.count('SCRIPT ERROR'),'engine_errors':[line for line in lines if line.startswith('ERROR:')],'completion_verified':CASES[name] in text,'command':command,'log':str(log),'home':str(home)}
  row['passed']=row['exit']==0 and row['failures']==0 and row['script_errors']==0 and row['completion_verified'] and row['assertions']>0
  results.append(row);(out/'results.json').write_text(json.dumps(results,indent=2));print(json.dumps(row),flush=True)
 after=hashes();delta=[key for key in baseline.keys()|after.keys() if baseline.get(key)!=after.get(key)]
 summary={'expected_scenes':selected,'executed_scenes':[r['scene'] for r in results],'exact_set':set(selected)=={r['scene'] for r in results},'passed_scenes':sum(r['passed'] for r in results),'failed_scenes':sum(not r['passed'] for r in results),'assertions':sum(r['assertions'] for r in results),'source_changed':delta,'engine_error_lines':sum(len(r['engine_errors']) for r in results),'scope':'CURRENT15 selected synthetic safety gates only; not normal gameplay, full regression, art approval or mobile acceptance'}
 (out/'summary.json').write_text(json.dumps(summary,indent=2));print(json.dumps(summary,indent=2))
 return int(bool(summary['failed_scenes'] or delta or not summary['exact_set']))
if __name__=='__main__':raise SystemExit(main())

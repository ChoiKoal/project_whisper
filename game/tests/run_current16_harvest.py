"""Portable CURRENT16 focused harvest/safety runner; fresh isolated HOME, serial engines.
No lock/control changes, no process termination, no historical fixtures required.
"""
from pathlib import Path
from typing import Any
import argparse, hashlib, json, os, subprocess, time
GAME = Path(__file__).resolve().parents[1]
CASES = {
    'harvest_action_state_harness': 'RESULT: ALL GREEN',
    'harvest_reward_harness': 'HARVEST_REWARD_DONE failures=0',
    'harvest_integration_harness': 'HARVEST_INTEGRATION_DONE failures=0',
    'harvest_save_harness': 'HARVEST_SAVE_DONE failures=0',
    'terrain_object_physics_harness': 'OBJECT_PHYSICS_RESULT failures=0',
    'rock_collision_harness': 'ROCK_COLLISION_RESULT failures=0',
    'pending_lock_safety_harness': 'PENDING_LOCK_SAFETY_DONE failures=0',
    'future_save_safety_harness': 'FUTURE_SAVE_SAFETY_DONE failures=0',
    'night_flower_art_harness': 'NIGHT_FLOWER_ART_DONE failures=0',
}
def hashes():
    return {str(p.relative_to(GAME)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(GAME.rglob('*')) if p.is_file() and '.godot' not in p.parts and '__pycache__' not in p.parts}
def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True, type=Path)
    parser.add_argument('--evidence', required=True, type=Path)
    parser.add_argument('--case', action='append', choices=list(CASES))
    args = parser.parse_args()
    engine = args.godot.expanduser().resolve()
    out = args.evidence.expanduser().resolve()
    if not engine.is_file(): parser.error('Godot executable missing')
    if out.exists(): parser.error('Evidence must be a NEW directory; no overwriting')
    live = subprocess.check_output(['ps', '-axo', 'pid,state,comm'], text=True)
    if any(Path(line.rsplit(None, 1)[-1]).name.lower() in ('godot', 'godot4') and ' Z ' not in line for line in live.splitlines() if line.strip()):
        parser.error('A Godot is already live; no concurrent engine allowed')
    selected = list(dict.fromkeys(args.case or CASES))
    out.mkdir(parents=True)
    home = out/'home'; home.mkdir()
    env = os.environ.copy()
    env.update(HOME=str(home), WHISPER_TEST_HOME=str(home), XDG_DATA_HOME=str(home/'.local/share'), XDG_CONFIG_HOME=str(home/'.config'), XDG_CACHE_HOME=str(home/'.cache'))
    command = [str(engine), '--headless', '--editor', '--import', '--path', str(GAME), '--quit']
    with (out/'import.log').open('w') as stream:
        result = subprocess.run(command, env=env, stdout=stream, stderr=subprocess.STDOUT)
    text = (out/'import.log').read_text()
    if result.returncode or 'SCRIPT ERROR' in text:
        print('IMPORT_FAILED: see', out/'import.log'); return 1
    # Godot may generate .uid/.import metadata on a fresh checkout; the tested
    # source baseline starts AFTER import. No metadata is hand-invented.
    baseline = hashes(); (out/'source-hashes.json').write_text(json.dumps(baseline, indent=2))
    rows = []
    for name in selected:
        case_home = out/'homes'/name; case_home.mkdir(parents=True)
        case_env = env.copy()
        case_env.update(HOME=str(case_home), WHISPER_TEST_HOME=str(case_home), XDG_DATA_HOME=str(case_home/'.local/share'), XDG_CONFIG_HOME=str(case_home/'.config'), XDG_CACHE_HOME=str(case_home/'.cache'))
        command = [str(engine), '--path', str(GAME), '--headless', '--max-fps', '60', '--quit-after', '5400', str(GAME/'scenes/dev'/(name+'.tscn'))]
        start = time.monotonic(); log = out/(name+'.log')
        with log.open('w') as stream:
            result = subprocess.run(command, env=case_env, stdout=stream, stderr=subprocess.STDOUT)
        text = log.read_text(); lines = text.splitlines()
        row: dict[str, Any] = dict(scene=name, exit=result.returncode, seconds=round(time.monotonic()-start, 2), assertions=sum('[PASS]' in l or l.startswith('PASS ') for l in lines), failures=sum('[FAIL]' in l or l.startswith('FAIL ') for l in lines), script_errors=text.count('SCRIPT ERROR'), engine_errors=[l for l in lines if l.startswith('ERROR:')], completion_verified=CASES[name] in text, log=str(log), home=str(case_home), command=command)
        row['passed'] = row['exit']==0 and row['failures']==0 and row['script_errors']==0 and row['completion_verified'] and row['assertions']>0
        rows.append(row); (out/'results.json').write_text(json.dumps(rows, indent=2)); print(json.dumps(row), flush=True)
    after = hashes()
    summary = dict(expected_scenes=selected, executed_scenes=[r['scene'] for r in rows], exact_set=selected==[r['scene'] for r in rows], passed_scenes=sum(r['passed'] for r in rows), failed_scenes=sum(not r['passed'] for r in rows), assertions=sum(r['assertions'] for r in rows), source_changed=sorted(k for k in baseline.keys()|after.keys() if baseline.get(k)!=after.get(k)), engine_error_lines=sum(len(r['engine_errors']) for r in rows), scope='Focused synthetic harvest/safety/physics, NOT normal route, full regression, art/fun/device acceptance')
    (out/'summary.json').write_text(json.dumps(summary, indent=2)); print(json.dumps(summary, indent=2))
    return int(bool(summary['failed_scenes'] or summary['source_changed'] or not summary['exact_set']))
if __name__ == '__main__': raise SystemExit(main())

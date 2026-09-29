"""Verify preserved game bytes before opening Godot/importing assets."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PUBLICATION_SHA = 'e21028eaade8a66aed850d4b649db6818ec73412001bf3702ed681fa0ef0afb2'

def verify():
    publication = ROOT / 'PUBLICATION-MANIFEST.json'
    assert hashlib.sha256(publication.read_bytes()).hexdigest() == PUBLICATION_SHA, 'publication manifest hash mismatch'
    spec = json.loads(publication.read_text())
    original = ROOT / spec['original_manifest']
    assert hashlib.sha256(original.read_bytes()).hexdigest() == spec['original_manifest_sha256'], 'original manifest hash mismatch'
    all_files = json.loads(original.read_text())['source_sha256']
    manifest, excluded = spec['source_sha256'], spec['excluded']
    assert not set(manifest) & set(excluded)
    assert set(manifest) | set(excluded) == set(all_files)
    assert len(manifest) == spec['included_count'] == 2536
    assert len(excluded) == spec['excluded_count'] == 17
    assert all(p.endswith('.pyc') and info['sha256'] == all_files[p] and info['reason'] == 'regenerable (.pyc)' for p, info in excluded.items())
    missing, changed = [], []
    for name, expected in manifest.items():
        assert expected == all_files[name], name
        path = ROOT / name
        if not path.is_file():
            missing.append(name)
        elif hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            changed.append(name)
    actual = {p.relative_to(ROOT).as_posix() for p in (ROOT / 'game').rglob('*') if p.is_file()}
    extra = sorted(actual - set(manifest) - set(excluded))
    result = {'original': len(all_files), 'expected': len(manifest), 'excluded_regenerable': len(excluded), 'matched': len(manifest)-len(missing)-len(changed), 'missing': missing, 'changed': changed, 'extra': extra}
    print(json.dumps(result, ensure_ascii=False, indent=2))
    assert not missing and not changed and not extra, 'snapshot mismatch'

if __name__ == '__main__':
    verify()

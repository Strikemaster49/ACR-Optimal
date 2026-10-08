"""Developer checks on the six supplied copies; no player saves are stored in Git.

Run: python tests/verify_block_keys.py --pwsh /path/to/pwsh --copies <six paths>
Python is a development test dependency, not a Windows diagnostic dependency.
"""
import argparse
import csv
import json
import os
from pathlib import Path
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--pwsh', required=True)
    parser.add_argument('--copies', nargs=6, required=True)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    reader = repo / 'diagnostic-windows/Lire-Sauvegarde-Secteurs.ps1'
    comparer = repo / 'diagnostic-windows/Comparer-Cles-Tentatives.ps1'
    with tempfile.TemporaryDirectory(prefix='acr-key-test-') as temp:
        base = Path(temp)
        env = os.environ.copy()
        for name, folder in [('XDG_CACHE_HOME', 'cache'), ('XDG_CONFIG_HOME', 'config'), ('XDG_DATA_HOME', 'data')]:
            env[name] = str(base / folder)

        def decode(path, name):
            out = base / name
            result = subprocess.run([args.pwsh, '-NoProfile', '-File', str(reader),
                                     '-SavePath', str(path), '-OutputRoot', str(out)],
                                    env=env, capture_output=True, text=True)
            assert result.returncode == 0, result.stdout + result.stderr
            run = next(out.iterdir())
            with (run / 'secteurs.csv').open(encoding='utf-8-sig', newline='') as stream:
                rows = list(csv.DictReader(stream))
            return rows, run / 'secteurs.csv'

        all_rows, evidence = [], []
        for i, path in enumerate(args.copies):
            rows, exported = decode(Path(path), f'sample-{i}')
            all_rows.extend(rows)
            evidence.append(str(exported))
        assert len(all_rows) == 54, 'Expected 27 observed attempts / 54 sectors across six known copies'
        identities = {}
        for row in all_rows:
            key = row['AttemptKeyCandidate']
            previous = identities.setdefault(key, row['RawAttemptSHA256'])
            assert previous == row['RawAttemptSHA256'], 'Existing key changed content'
        assert len(identities) == 7, 'Expected five retained and two new attempts'
        by_token = {}
        for row in all_rows:
            by_token.setdefault(row['BlockToken'], set()).add(row['RunIndex'])
        assert sorted(map(len, by_token.values())) == [2, 5], 'Reset must occupy a distinct block token'
        offsets = {}
        for row in all_rows:
            offsets.setdefault(row['AttemptKeyCandidate'], set()).add(row['BlockOffset'])
        assert any(len(v) > 1 for v in offsets.values()), 'No real moved-block check executed'

        original = Path(args.copies[-1]).read_bytes()
        shifted = base / 'shifted.sav'
        shifted.write_bytes(original[:256] + bytes(16) + original[256:])
        before, _ = decode(Path(args.copies[-1]), 'before-shift')
        after, _ = decode(shifted, 'after-shift')
        fields = lambda rows: {(r['AttemptKeyCandidate'], r['RawAttemptSHA256']) for r in rows}
        assert fields(before) == fields(after), 'Offset shift changed identity or content'
        assert {int(r['BlockOffset']) + 16 for r in before} == {int(r['BlockOffset']) for r in after}

        # Equal timing/content under a different token must not be merged as the same run.
        token_changed = bytearray(original)
        first_offset = int(before[0]['BlockOffset'])
        token_changed[first_offset - 12] ^= 1
        other_token = base / 'other-token.sav'
        other_token.write_bytes(token_changed)
        changed_rows, _ = decode(other_token, 'other-token')
        old_block = [r for r in before if int(r['BlockOffset']) == first_offset]
        new_block = [r for r in changed_rows if int(r['BlockOffset']) == first_offset]
        assert {r['RawAttemptSHA256'] for r in old_block} == {r['RawAttemptSHA256'] for r in new_block}
        assert not ({r['AttemptKeyCandidate'] for r in old_block} &
                    {r['AttemptKeyCandidate'] for r in new_block}), 'Equal timings merged across tokens'

        request = base / 'request.json'
        request.write_text(json.dumps(evidence), encoding='utf-8')
        # File arguments are passed through JSON, never interpolated into PowerShell source.
        wrapper = base / 'compare.ps1'
        wrapper.write_text('param($Reader,$Request,$Out)\n'
                           '$paths=@(Get-Content -LiteralPath $Request -Raw | ConvertFrom-Json)\n'
                           '& $Reader -EvidenceCsv $paths -OutputRoot $Out\n', encoding='utf-8')

        def compare(name):
            return subprocess.run([args.pwsh, '-NoProfile', '-File', str(wrapper),
                                   '-Reader', str(comparer), '-Request', str(request),
                                   '-Out', str(base / name)], env=env, capture_output=True, text=True)

        result = compare('consistent')
        assert result.returncode == 0, result.stdout + result.stderr
        run = next((base / 'consistent').iterdir())
        with (run / 'cles.csv').open(encoding='utf-8-sig', newline='') as stream:
            report = list(csv.DictReader(stream))
        assert len(report) == 7 and all(r['ContentVariants'] == '1' for r in report)
        # Artificial conflicting evidence must be reported, not silently deduplicated.
        conflict = dict(all_rows[0])
        conflict['RawAttemptSHA256'] = 'f' * 64
        bad = base / 'conflict.csv'
        with bad.open('w', encoding='utf-8', newline='') as stream:
            writer = csv.DictWriter(stream, fieldnames=list(conflict))
            writer.writeheader()
            writer.writerow(conflict)
        request.write_text(json.dumps(evidence + [str(bad)]), encoding='utf-8')
        result = compare('conflicting')
        assert result.returncode != 0, 'Conflicting content accepted'
        run = next((base / 'conflicting').iterdir())
        assert 'content-conflict' in (run / 'cles.csv').read_text(encoding='utf-8-sig')
    print('PASS: six real copies, seven keys, reset separation, moved offsets, rereads, explicit conflict reporting')


if __name__ == '__main__':
    main()

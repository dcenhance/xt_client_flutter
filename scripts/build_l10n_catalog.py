#!/usr/bin/env python3
"""Extract visible source messages, translate offline and build a checked Dart catalog.

Run extract after updating tr()/trCurrent() call sites; translate each target tag;
then check and generate. Keys are English templates, {named} placeholders are
kept byte-for-byte. Translators never receive the unprotected placeholder text.
"""
import ast
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DIR = ROOT / 'lib/l10n'
BRIDGE = Path('/srv/apps/tooling/dexcore/scripts/archive_translate_argos.py')
PYTHON = Path('/srv/apps/tooling/dexcore/state/venvs/argos/bin/python')
TAGS = 'en de es fr it pt nl pl cs ru uk tr ar hi id ja ko zh sv el zh-Hant'.split()
PLACEHOLDER = re.compile(r'(\{[a-zA-Z][a-zA-Z0-9_]*\})')
LITERAL = r'''((?:'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*"))'''
CALL = re.compile(r'\b(?:tr\(\s*[a-zA-Z_]\w*\s*,\s*|trCurrent\(\s*)' + LITERAL)
DYNAMIC = (
    'tr(context, onContent ?', 'tr(context, label)',
    'tr(context, appState.tabLabel)', 'tr(context, detail)',
    'tr(context, note.substring(', 'tr(context, note)',
    'tr(context, probe.note)', 'tr(context, palette.blurb)',
)


def source_keys():
    result = {'Language', 'System default', 'Live TV', 'Movies', 'Series', 'Account'}
    total = 0
    for path in (ROOT / 'lib').rglob('*.dart'):
        if path.name in ('l10n.dart', 'l10n_catalog.dart'):
            continue
        text = path.read_text()
        calls = list(re.finditer(r'\b(?:tr|trCurrent)\s*\(', text))
        found = list(CALL.finditer(text))
        static_starts = {hit.start() for hit in found}
        dynamic = [hit for hit in calls if hit.start() not in static_starts]
        # These values originate in fixed tab/theme/verdict catalogs or are
        # provider-supplied text; any new dynamic key requires deliberate review.
        for hit in dynamic:
            snippet = text[hit.start():].replace('\n', ' ')
            if not any(snippet.startswith(prefix) for prefix in DYNAMIC):
                raise RuntimeError(f'{path}: unreviewed dynamic translation: {snippet[:100]}')
        total += len(found)
        for hit in found:
            value = ast.literal_eval(hit.group(1))
            if not isinstance(value, str) or not value.strip():
                raise RuntimeError(f'{path}: empty/non-text key at {hit.start()}')
            result.add(value)
    print(f'{total} localized calls / {len(result)} distinct English keys', file=sys.stderr)
    return sorted(result)


def source_template():
    return {key: key for key in source_keys()}


def translate(tag):
    template = source_template()
    old = json.loads((DIR / f'{tag}.json').read_text()) if (DIR / f'{tag}.json').exists() else {}
    missing = [k for k in template if k not in old]
    fragments = sorted(set(
        part for key in missing for part in PLACEHOLDER.split(key)
        if part and not PLACEHOLDER.fullmatch(part) and part.strip()
    ))
    print(f'{tag}: {len(missing)} missing messages, {len(fragments)} translatable fragments', file=sys.stderr)
    translations = {}
    if fragments:
        request = json.dumps({'language': tag, 'texts': fragments}, ensure_ascii=False)
        process = subprocess.run([str(PYTHON), str(BRIDGE)], input=request, text=True,
                                 capture_output=True, timeout=1200, check=True)
        response = json.loads(process.stdout)
        values = response['texts']
        if len(values) != len(fragments) or any(not isinstance(v, str) or not v.strip() for v in values):
            raise RuntimeError(f'{tag}: translation bridge returned incomplete output')
        translations = {
            fragment: (fragment[:len(fragment)-len(fragment.lstrip())] + value.strip() +
                       fragment[len(fragment.rstrip()):])
            for fragment, value in zip(fragments, values)
        }
    for key in missing:
        parts = PLACEHOLDER.split(key)
        converted = ''.join(part if PLACEHOLDER.fullmatch(part) else translations.get(part, part)
                            for part in parts)
        if sorted(PLACEHOLDER.findall(converted)) != sorted(PLACEHOLDER.findall(key)):
            raise RuntimeError(f'{tag}: broken placeholders in {key!r}')
        if not converted.strip():
            raise RuntimeError(f'{tag}: blank translation for {key!r}')
        old[key] = converted
    DIR.mkdir(parents=True, exist_ok=True)
    (DIR / f'{tag}.json').write_text(json.dumps({k: old[k] for k in template}, ensure_ascii=False,
                                             indent=2) + '\n')
    print(f'{tag}: saved {len(template)} keys')


def verify():
    source = source_template()
    if not (DIR / 'en.json').exists():
        raise RuntimeError('Missing English catalog; run extract first')
    for tag in TAGS:
        path = DIR / f'{tag}.json'
        data = json.loads(path.read_text())
        if set(data) != set(source):
            raise RuntimeError(f'{tag}: missing {sorted(set(source)-set(data))[:5]}; extra {sorted(set(data)-set(source))[:5]}')
        for key, value in data.items():
            if not isinstance(value, str) or not value.strip() or sorted(PLACEHOLDER.findall(value)) != sorted(PLACEHOLDER.findall(key)):
                raise RuntimeError(f'{tag}: invalid translation/placeholder for {key!r}')
    return source


def quote(s):
    return json.dumps(s, ensure_ascii=False).replace('$', r'\$')


def generate():
    verify()
    chunks = ['// Generated from lib/l10n/*.json by scripts/build_l10n_catalog.py.\n',
              '// Keep locale JSON files as the source of truth.\n',
              'const Map<String, Map<String, String>> localizedCatalog = {\n']
    for tag in TAGS[1:]:
        data = json.loads((DIR / f'{tag}.json').read_text())
        chunks.append(f'  {quote(tag)}: {{\n')
        for key, value in data.items():
            chunks.append(f'    {quote(key)}: {quote(value)},\n')
        chunks.append('  },\n')
    chunks.append('};\n')
    (ROOT / 'lib/l10n_catalog.dart').write_text(''.join(chunks))
    print(f'Generated 20 translations into {ROOT / "lib/l10n_catalog.dart"}')


if __name__ == '__main__':
    command = sys.argv[1] if len(sys.argv) > 1 else ''
    if command == 'extract':
        DIR.mkdir(parents=True, exist_ok=True)
        data = source_template()
        (DIR / 'en.json').write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    elif command == 'translate' and len(sys.argv) == 3 and sys.argv[2] in TAGS[1:]:
        translate(sys.argv[2])
    elif command == 'check':
        verify()
    elif command == 'generate':
        generate()
    else:
        raise SystemExit('Usage: build_l10n_catalog.py extract|translate <tag>|check|generate')

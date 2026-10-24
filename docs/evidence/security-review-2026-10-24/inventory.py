"""Read-only source inventory; writes only this review's sanitized evidence."""
import collections
import hashlib
import importlib.metadata
import json
from pathlib import Path
import re
import ssl
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'backend'))


def main():
    names = subprocess.check_output(['git', 'ls-files', '-z'], cwd=ROOT).decode().split('\0')
    sources = []
    for folder in ('backend/bmt_backend', 'backend/deploy', 'backend/schemas', 'game/backend',
                   'game/platform', 'game/persistence', 'game/addons', 'native', 'scripts'):
        sources += [p for p in (ROOT / folder).rglob('*') if p.is_file()
                    and not any(x in p.parts for x in ('__pycache__', '.gradle', 'build'))
                    and p.suffix in ('.py', '.gd', '.java', '.cpp', '.h', '.hpp', '.js',
                                     '.html', '.json', '.sh', '.yaml', '.xml', '.gradle', '.ps1')]
    sources += [ROOT / p for p in ('backend/requirements.lock', 'backend/Dockerfile',
        'game/project.godot', 'game/export_presets.cfg', 'godot-version.txt')]
    manifest = [{'path': p.relative_to(ROOT).as_posix(), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest(),
                 'bytes': p.stat().st_size} for p in sorted(set(sources))]
    (OUT / 'source-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    # Do not emit matched values or copy any credential into review artifacts.
    patterns = {
        'private_key_header': re.compile(r'-----BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----'),
        'google_api_key': re.compile(r'\bAIza[0-9A-Za-z_-]{35}\b'),
        'aws_access_key': re.compile(r'\b(?:AKIA|ASIA)[A-Z0-9]{16}\b'),
        'github_token': re.compile(r'\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})\b'),
        'google_oauth_secret': re.compile(r'GOCSPX-[A-Za-z0-9_-]{20,}'),
        'google_service_account_key': re.compile(r'"private_key"\s*:\s*"-----BEGIN'),
    }
    candidates, scanned, scan_bytes = [], 0, 0
    binary = {'.png', '.jpg', '.jpeg', '.webp', '.wav', '.ogg', '.mp3', '.mp4', '.zip', '.dll', '.so', '.a', '.pck'}
    for name in names:
        p = ROOT / name
        if not name or not p.is_file() or p.suffix.lower() in binary or p.stat().st_size > 2_000_000:
            continue
        raw = p.read_bytes()
        if b'\0' in raw:
            continue
        scanned += 1
        scan_bytes += len(raw)
        for number, line in enumerate(raw.decode('utf-8', errors='replace').splitlines(), 1):
            for kind, pattern in patterns.items():
                if pattern.search(line):
                    candidates.append({'path': name, 'line': number, 'kind': kind})
    secret_scan = {'scope': 'current Git-tracked text files <=2MB, known credential formats; no ignored files/history',
                   'files': scanned, 'bytes': scan_bytes, 'candidates': candidates}
    (OUT / 'credential-scan.json').write_text(json.dumps(secret_scan, indent=2) + '\n')
    from bmt_backend.app import create_app
    from bmt_backend.config import Settings
    from fastapi.routing import APIRoute, iter_route_contexts
    scratch = ROOT / 'build/security-review-20261024/inventory-objects'
    app = create_app(Settings(database_url='sqlite://', object_dir=str(scratch)))

    def dependencies(d):
        result = set()
        if d.call is not None:
            result.add(getattr(d.call, '__module__', '') + '.' + getattr(d.call, '__name__', str(type(d.call))))
        for child in d.dependencies:
            result.update(dependencies(child))
        return sorted(result)

    routes = []
    for context in iter_route_contexts(app.router.routes):
        r = context.original_route
        if isinstance(r, APIRoute):
            routes.append({'path': context.path, 'methods': sorted(r.methods),
                'endpoint': r.endpoint.__module__ + '.' + r.endpoint.__name__,
                'dependencies': dependencies(r.dependant), 'body': bool(r.body_field)})
    (OUT / 'routes.json').write_text(json.dumps(routes, indent=2) + '\n')
    locked = dict(re.findall(r'^([A-Za-z0-9_.-]+)==([^\s]+)', (ROOT / 'backend/requirements.lock').read_text(), re.M))
    installed = {}
    for package in locked:
        try:
            installed[package] = importlib.metadata.version(package)
        except importlib.metadata.PackageNotFoundError:
            installed[package] = None
    runtime = {'python': sys.version, 'openssl': ssl.OPENSSL_VERSION, 'locked': locked, 'installed': installed}
    (OUT / 'dependencies.json').write_text(json.dumps(runtime, indent=2) + '\n')
    app.state.engine.dispose()
    print(json.dumps({'source_files': len(manifest), 'routes': len(routes), 'secret_scan_files': scanned,
        'credential_candidates': candidates, 'locked_packages': len(locked),
        'unauthenticated_admin_routes': [r['path'] for r in routes if '/v1/admin/' in r['path']
            and 'bmt_backend.admin.access' not in r['dependencies']]}))


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
import json
from datetime import datetime, timezone
from pathlib import Path

SPEC_PATH = Path('/home/hermes/dotfiles/hosts/hermesbox/hermes-cron-jobs.json')
JOBS_PATH = Path('/var/lib/hermes/.hermes/cron/jobs.json')


def parse_schedule(s: str):
    s = s.strip()
    if s.startswith('every '):
        body = s[len('every '):].strip().lower()
        if body.endswith('h'):
            minutes = int(body[:-1]) * 60
        elif body.endswith('m'):
            minutes = int(body[:-1])
        else:
            raise ValueError(f'Unsupported interval format: {s}')
        return {
            'kind': 'interval',
            'minutes': minutes,
            'display': f'every {minutes}m',
        }, f'every {minutes}m'
    return {
        'kind': 'cron',
        'expr': s,
        'display': s,
    }, s


def now_iso():
    return datetime.now(timezone.utc).astimezone().isoformat()


def load_json(path: Path, default):
    if not path.exists():
        return default
    return json.loads(path.read_text())


def main():
    spec = load_json(SPEC_PATH, {'jobs': []})
    current = load_json(JOBS_PATH, {'jobs': []})

    current_jobs = {j.get('id'): j for j in current.get('jobs', []) if isinstance(j, dict) and j.get('id')}
    out_jobs = []

    for desired in spec.get('jobs', []):
        jid = desired['id']
        existing = current_jobs.get(jid, {})
        schedule_obj, schedule_display = parse_schedule(desired['schedule'])

        base = {
            'id': jid,
            'name': desired['name'],
            'prompt': desired.get('prompt') or '',
            'skills': desired.get('skills', []),
            'skill': None,
            'model': desired.get('model'),
            'provider': desired.get('provider'),
            'base_url': None,
            'script': desired.get('script'),
            'no_agent': bool(desired.get('no_agent', False)),
            'context_from': None,
            'schedule': schedule_obj,
            'schedule_display': schedule_display,
            'repeat': {'times': None, 'completed': existing.get('repeat', {}).get('completed', 0)},
            'enabled': desired.get('enabled', True),
            'state': 'scheduled',
            'paused_at': None,
            'paused_reason': None,
            'created_at': existing.get('created_at') or now_iso(),
            'next_run_at': existing.get('next_run_at') or now_iso(),
            'last_run_at': existing.get('last_run_at'),
            'last_status': existing.get('last_status'),
            'last_error': existing.get('last_error'),
            'last_delivery_error': existing.get('last_delivery_error'),
            'deliver': desired.get('deliver', 'local'),
            'origin': None,
            'enabled_toolsets': desired.get('enabled_toolsets', ['terminal']),
            'workdir': desired.get('workdir'),
        }
        out_jobs.append(base)

    out = {'jobs': out_jobs, 'updated_at': now_iso()}
    JOBS_PATH.parent.mkdir(parents=True, exist_ok=True)
    tmp = JOBS_PATH.with_suffix('.json.tmp')
    tmp.write_text(json.dumps(out, indent=2) + '\n')
    tmp.replace(JOBS_PATH)
    print(f'synced {len(out_jobs)} cron jobs from {SPEC_PATH}')


if __name__ == '__main__':
    main()

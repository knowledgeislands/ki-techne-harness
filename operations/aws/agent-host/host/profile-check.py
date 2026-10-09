#!/usr/bin/env python3
"""Validate a binding owner's techne/host-profile/v1 payload (TECHNE-TOOLS-OPS-015).

usage: profile-check.py [--os linux|macos] [--hostname <name>] [--shell bash|zsh]
                        [--workspace <path>] [--recipe-rig <rig.toml>] <payload>

setup.sh runs it on the operator's workstation before anything is sent, and
host/converge.sh again on the host before anything is written. It prints each
problem and exits 1 when there is one, 0 when the payload is valid.

The payload is a directory holding manifest.json and, under home/, each file
the manifest lists at its path relative to the operator's home. --os refuses a
payload rendered for another OS; --hostname refuses one whose target_host
names another host; --shell and --workspace add the chosen shell's
recipe-managed start-up file and the workspace root to the reserved
destinations; --recipe-rig refuses a Rig fragment that redeclares an identity
of the recipe's own Rig configuration.
"""

import json
import re
import sys
import tomllib
from pathlib import Path

SCHEMA = 'techne/host-profile/v1'
OSES = {'linux', 'macos'}
MODES = {'0600', '0644', '0700', '0755'}
FRAGMENT_DIR = '.config/rig/conf.d/'

# Destinations the recipe manages, refused in any payload; a trailing / is a
# directory and everything under it.
RESERVED = [
    '.config/rig/rig.toml', '.config/mise/', '.config/ki-agent-host/', '.config/ki/host-marker',
    '.config/husky/init.sh', '.claude/rules/ki-agent-host.md', '.claude/settings.json', '.claude/skills/',
    '.agents/', '.local/share/rig/providers/', '.local/state/ki-agent-host/', '.cache/ki-agent-host/',
    '.ssh/', '.gitconfig', '.profile', '.bashrc',
]
# The start-up file the recipe manages for each chosen shell.
SHELL_STARTUP = {'bash': '.bashrc', 'zsh': '.zshenv'}

# Content invalid on the target OS. A Linux file may name pbcopy or pbpaste
# only when it also guards for them.
INVALID_CONTENT = {
    'linux': ['/Users/', '/opt/homebrew', '/usr/local/Cellar', 'brew shellenv'],
    'macos': ['/home/'],
}
GUARDED = ['pbcopy', 'pbpaste']
GUARD = re.compile(r'command -v (pbcopy|pbpaste)|\$\+commands\[(pbcopy|pbpaste)\]|darwin|Darwin')

# The secret patterns of the paired renderer, Cheztoi's scripts/cheztoi-render,
# and a Tailscale key.
SECRETS = [
    ('private key', re.compile(r'-----BEGIN [A-Z ]*PRIVATE KEY-----')),
    ('AWS access key', re.compile(r'\bA(KIA|SIA)[0-9A-Z]{16}\b')),
    ('GitHub token', re.compile(r'\bgh[pousr]_[A-Za-z0-9]{36,}|\bgithub_pat_[A-Za-z0-9_]{22,}')),
    ('Anthropic or OpenAI key', re.compile(r'\bsk-(ant-|proj-)?[A-Za-z0-9_-]{32,}')),
    ('Slack token', re.compile(r'\bxox[abprs]-[A-Za-z0-9-]{10,}')),
    ('Google API key', re.compile(r'\bAIza[0-9A-Za-z_-]{35}\b')),
    ('Tailscale key', re.compile(r'\btskey-[A-Za-z0-9-]{10,}')),
    ('1Password reference', re.compile(r'\bop://[^\s"\'`]+')),
]

# A fragment reaches Rig's built-in providers only, and declares tools,
# categories and its one profile: no [rig] or [provider] table, no managed
# resource and no custom adapter.
BUILTIN_PROVIDERS = {'homebrew', 'uv', 'mise', 'npm', 'chezmoi', 'direct-download'}
FRAGMENT_TABLES = {'category', 'profile', 'tool'}
MANAGED_KEYS = {'services', 'resources'}


def path_problem(path, reserved):
    if not isinstance(path, str) or not path:
        return 'is empty'
    if path.startswith('/'):
        return 'is absolute'
    if any(part in ('', '.', '..') for part in path.split('/')):
        return 'has an empty, . or .. component'
    if re.search(r'[\x00-\x1f]', path):
        return 'has a control character'
    for entry in reserved:
        if (f'{path}/'.startswith(entry) if entry.endswith('/') else path == entry):
            return f'is the reserved destination ~/{entry}'
    return None


def recipe_identities(path):
    if path is None:
        return set()
    recipe = tomllib.loads(path.read_text(encoding='utf-8'))
    return {(table, name) for table in ('tool', 'category', 'profile', 'provider') for name in recipe.get(table, {})}


def check_fragment(text, rig, recipe, problems):
    try:
        fragment = tomllib.loads(text)
    except tomllib.TOMLDecodeError:
        problems.append(f'rig fragment ~/{rig["fragment"]} is not valid TOML')
        return
    for table in sorted(fragment.keys() - FRAGMENT_TABLES):
        problems.append(f'rig fragment declares a [{table}] table; only tools, categories and its profile are allowed')
    profiles = list(fragment.get('profile', {}))
    if profiles != [rig['profile']]:
        problems.append(f'rig fragment must declare exactly its profile {rig["profile"]}, not {profiles}')
    for table in sorted(FRAGMENT_TABLES):
        for name in fragment.get(table, {}):
            if (table, name) in recipe:
                problems.append(f'rig fragment redeclares the recipe\'s {table} {name}')
    for name, tool in fragment.get('tool', {}).items():
        if not isinstance(tool, dict):
            continue
        installs = [tool.get('install')] + [variant.get('install') for variant in tool.get('variant', {}).values()]
        for install in filter(None, installs):
            if install.get('provider') not in BUILTIN_PROVIDERS:
                problems.append(f'rig tool {name} uses provider {install.get("provider")!r}, which is not built in')
        for key in sorted(tool.keys() & MANAGED_KEYS):
            problems.append(f'rig tool {name} declares a managed resource ({key})')


def validate(payload, os=None, hostname=None, shell=None, workspace=None, recipe_rig=None):
    problems = []
    manifest_path = payload / 'manifest.json'
    if not manifest_path.is_file() or manifest_path.is_symlink():
        return ['manifest.json is missing']
    try:
        manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    except (ValueError, UnicodeDecodeError):
        return ['manifest.json is not valid JSON']
    if not isinstance(manifest, dict):
        return ['manifest.json must be an object']

    if manifest.get('schema') != SCHEMA:
        problems.append(f'schema must be {SCHEMA}')
    if not isinstance(manifest.get('revision'), str) or not manifest['revision']:
        problems.append('revision is missing')
    target_os = manifest.get('target_os')
    if target_os not in OSES:
        problems.append('target_os must be linux or macos')
    elif os is not None and target_os != os:
        problems.append(f'the payload is for {target_os}, not this {os} host')
    if 'target_host' in manifest:
        target_host = manifest['target_host']
        if not isinstance(target_host, str) or not target_host:
            problems.append('target_host, when present, must be a host name')
        elif hostname is not None and target_host != hostname:
            problems.append(f'the payload is for host {target_host}, not {hostname}')
    files = manifest.get('files')
    if not isinstance(files, list):
        return problems + ['files must be a list']
    removed = manifest.get('removed')
    if not isinstance(removed, list):
        problems.append('removed must be a list')
        removed = []

    reserved = list(RESERVED)
    if shell in SHELL_STARTUP:
        reserved.append(SHELL_STARTUP[shell])
    if workspace:
        root = workspace.rstrip('/')
        if root.startswith('~/'):
            root = root[2:]
        if root and not root.startswith('/'):
            reserved.append(f'{root}/')

    home = payload / 'home'
    listed = set()
    for entry in files:
        path = entry.get('path') if isinstance(entry, dict) else None
        problem = path_problem(path, reserved)
        if problem:
            problems.append(f'file {path!r} {problem}')
            if isinstance(path, str):
                listed.add(path)  # refused once, not again as unlisted
            continue
        if path in listed:
            problems.append(f'file ~/{path} is listed twice')
        listed.add(path)
        if entry.get('mode') not in MODES:
            problems.append(f'file ~/{path} has mode {entry.get("mode")!r}, not one of {", ".join(sorted(MODES))}')
        target = home / path
        if target.is_symlink():
            continue  # reported by the walk below
        if not target.exists():
            problems.append(f'listed file ~/{path} is absent')
            continue
        if not target.is_file():
            problems.append(f'listed file ~/{path} is not a regular file')
            continue
        try:
            text = target.read_text(encoding='utf-8')
        except UnicodeDecodeError:
            problems.append(f'file ~/{path} is not UTF-8 text')
            continue
        for needle in INVALID_CONTENT.get(target_os, []):
            if needle in text:
                problems.append(f'file ~/{path} contains {needle!r}, invalid on {target_os}')
        if target_os == 'linux' and not GUARD.search(text):
            for needle in GUARDED:
                if needle in text:
                    problems.append(f'file ~/{path} uses {needle} without a guard, invalid on linux')
        for number, line in enumerate(text.splitlines(), 1):
            for name, pattern in SECRETS:
                if pattern.search(line):
                    problems.append(f'file ~/{path} line {number} matches the {name} pattern')

    for path in removed:
        problem = path_problem(path, reserved)
        if problem:
            problems.append(f'removed path {path!r} {problem}')
        elif path in listed:
            problems.append(f'~/{path} is both delivered and removed')

    if home.is_symlink():
        problems.append('home is a symbolic link')
    elif home.is_dir():
        for found in sorted(home.rglob('*')):
            name = found.relative_to(home).as_posix()
            if found.is_symlink():
                problems.append(f'~/{name} is a symbolic link')
            elif found.is_file() and name not in listed:
                problems.append(f'~/{name} is not listed in the manifest')
            elif not found.is_file() and not found.is_dir():
                problems.append(f'~/{name} is not a regular file')

    fragments = sorted(path for path in listed if path.startswith(FRAGMENT_DIR))
    rig = manifest.get('rig')
    if rig is not None:
        fragment = rig.get('fragment') if isinstance(rig, dict) else None
        profile = rig.get('profile') if isinstance(rig, dict) else None
        if not isinstance(fragment, str) or not fragment.startswith(FRAGMENT_DIR) or fragment not in listed:
            problems.append(f'rig.fragment must name one listed file under ~/{FRAGMENT_DIR}')
        elif not isinstance(profile, str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]*', profile):
            problems.append('rig.profile must name the profile the fragment declares')
        elif (home / fragment).is_file() and not (home / fragment).is_symlink():
            check_fragment((home / fragment).read_text(encoding='utf-8'), rig, recipe_identities(recipe_rig), problems)
        if len(fragments) > 1:
            problems.append('a payload may carry one Rig fragment only')
    elif fragments:
        problems.append('a Rig fragment is delivered but manifest.json names no rig object')
    return problems


def main(argv):
    options = {'os': None, 'hostname': None, 'shell': None, 'workspace': None, 'recipe_rig': None}
    usage = ('usage: profile-check.py [--os linux|macos] [--hostname <name>] [--shell bash|zsh] '
             '[--workspace <path>] [--recipe-rig <rig.toml>] <payload>')
    payload = None
    while argv:
        flag = argv.pop(0)
        key = flag[2:].replace('-', '_')
        if flag.startswith('--') and key in options and argv:
            options[key] = argv.pop(0)
        elif payload is None and not flag.startswith('--'):
            payload = flag
        else:
            print(usage, file=sys.stderr)
            return 2
    if payload is None:
        print(usage, file=sys.stderr)
        return 2
    if options['recipe_rig'] is not None:
        options['recipe_rig'] = Path(options['recipe_rig'])
    problems = validate(Path(payload), **options)
    for problem in problems:
        print(f'profile-check: {problem}', file=sys.stderr)
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))

#!/usr/bin/env python3
"""Offline check of the agent-host recipe's pin file (TECHNE-TOOLS-OPS-014).

usage: recipe-pins.py <rig.toml>

The pin file is Rig's agent-host profile. Every tool needs Rig's required
fields and a variant for each target OS, Linux and macOS, observed through the
observe-only agent-host-pins provider with an exact or minimum version
locator. Rig itself stays out of the check, which needs no network.
"""

import re
import sys
import tomllib

OSES = ('linux', 'macos')
PROVIDER = 'agent-host-pins'
TOOLS = {'rig', 'ki', 'mise', 'bun', 'node', 'codex', 'claude'}
VERSION = re.compile(r'^[0-9]+(\.[0-9]+)+$')

errors = []


def fail(message):
    errors.append(message)


def main():
    if len(sys.argv) != 2:
        print(__doc__.strip().splitlines()[2], file=sys.stderr)
        return 2
    with open(sys.argv[1], 'rb') as handle:
        pins = tomllib.load(handle)

    if pins.get('rig', {}).get('default-profile') != 'agent-host':
        fail('rig.default-profile must be agent-host')
    if 'agent-host' not in pins.get('profile', {}):
        fail('[profile.agent-host] is required')
    provider = pins.get('provider', {}).get(PROVIDER, {})
    if provider.get('adapter') != 'custom' or provider.get('capabilities') != ['observe']:
        fail(f'[provider.{PROVIDER}] must be a custom adapter that only observes')

    tools = pins.get('tool', {})
    if tools.keys() != TOOLS:
        fail(f'the pins must declare exactly {", ".join(sorted(TOOLS))}')
    categories = pins.get('category', {})
    for name, tool in tools.items():
        for field in ('name', 'category', 'purpose', 'rationale'):
            if not isinstance(tool.get(field), str) or not tool[field]:
                fail(f'tool.{name}.{field} is required')
        if tool.get('category') not in categories:
            fail(f'tool.{name} names an undeclared category')
        if tool.get('platforms') != list(OSES):
            fail(f'tool.{name}.platforms must be {list(OSES)}')
        variants = tool.get('variant', {})
        if variants.keys() != set(OSES):
            fail(f'tool.{name} needs exactly a linux and a macos variant')
        for os in OSES:
            variant = variants.get(os, {})
            install = variant.get('install', {})
            if variant.get('platforms') != [os]:
                fail(f'tool.{name}.variant.{os}.platforms must be ["{os}"]')
            if install.get('provider') != PROVIDER:
                fail(f'tool.{name}.variant.{os} must use the {PROVIDER} provider')
            if install.get('kind') not in ('exact', 'minimum'):
                fail(f'tool.{name}.variant.{os}.install.kind must be exact or minimum')
            if not VERSION.match(str(install.get('locator', ''))):
                fail(f'tool.{name}.variant.{os}.install.locator must be a version')

    for message in errors:
        print(f'recipe-pins: {message}', file=sys.stderr)
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main())

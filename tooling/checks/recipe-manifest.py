#!/usr/bin/env python3
"""Offline checks for techne/recipe/v1 manifests (TECHNE-TOOLS-OPS-012).

usage: recipe-manifest.py [--binding <binding.toml>] <recipe.toml>...

Each binding field of techne/host-binding/v1 must be declared exactly once:
provider-neutral fields under [parameters], provider fields under
[providers.<provider>.parameters]. No provider-neutral entry may name an AWS
concept; harness paths are locations, not concepts, and are exempt. Every
script a parameter names must read its environment variable. The [status]
table declares the host-workspace report schema and an exit status for each
outcome; each [operations.<name>] entry names an operation of a declared
script. The [patching] table declares the OS patching intent once, and each
supported provider must give its mechanism under [providers.<provider>.patching]
(TECHNE-TOOLS-OPS-022). A parameter is required, has a default or is optional;
a reboot window is a daily 24-hour HH:MM with no weekday. With --binding,
each script's default for that variable must equal the binding's resolved
value, so running a script with no binding behaves as that binding would.
"""

import re
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = 'techne/recipe/v1'
BINDING_SCHEMA = 'techne/host-binding/v1'
RUNTIMES = {'direct'}
NEUTRAL_FIELDS = {
    'host_name', 'tailscale_name', 'tailscale_tag', 'repositories', 'workspace', 'reboot_window', 'livepatch',
    'profile', 'shell',
}
# The interactive shells the direct-host recipe supports (TECHNE-TOOLS-OPS-015).
SHELLS = {'bash', 'zsh'}
PROVIDER_FIELDS = {
    'aws': {
        'account', 'region', 'admin_profile', 'operator_profile', 'tag', 'stack_name',
        'parameter_prefix', 'operator_role', 'instance_type', 'volume_size',
    },
}
STATUS_SCHEMA = 'techne/host-workspace/v1'
STATUS_EXITS = {'clean', 'failed', 'at-risk', 'unknown', 'unreachable'}
OPERATIONS = {'rebuild', 'withdraw'}
TOP_KEYS = {
    'schema', 'name', 'summary', 'runtime', 'paths', 'status', 'operations', 'patching', 'parameters', 'footprint',
    'providers',
}
PROVIDER_KEYS = {'summary', 'paths', 'parameters', 'selectors', 'tags', 'footprint', 'patching'}
PARAMETER_KEYS = {'summary', 'required', 'default', 'optional', 'env', 'scripts'}
# The patching intent (TECHNE-TOOLS-OPS-022): the value each key may declare.
PATCHING_INTENT = {'unattended': {'security'}, 'livepatch': {'opt-in'}, 'reboot': {'window'}}
PATCHING_KEYS = set(PATCHING_INTENT) | {'report'}
REBOOT_WINDOW = re.compile(r'^([01][0-9]|2[0-3]):[0-5][0-9]$')
AWS_CONCEPT = re.compile(
    r'\b(aws|amazon|ec2|cloudformation|ssm|iam|vpc|ebs|ami|s3|arn|stack|account|region|profile)\b',
    re.IGNORECASE,
)
PLACEHOLDER = re.compile(r'\{([^{}]+)\}')
ENV_NAME = re.compile(r'^[A-Z][A-Z0-9_]*$')


def field_form_problem(field, value):
    """The problem with a binding or default value of a field that has a fixed form, else None."""
    if field == 'reboot_window' and not (isinstance(value, str) and REBOOT_WINDOW.match(value)):
        return f'reboot_window must be a daily 24-hour HH:MM with no weekday, not {value!r}'
    if field == 'livepatch' and not isinstance(value, bool):
        return f'livepatch must be true or false, not {value!r}'
    if field == 'shell' and value not in SHELLS:
        return f'shell must be one of {", ".join(sorted(SHELLS))}, not {value!r}'
    return None


def is_harness_path(value):
    return isinstance(value, str) and '/' in value and '{' not in value and (ROOT / value).exists()


def neutral_strings(manifest):
    """Yield (location, text) for every key and string value outside [providers].

    A binding field's own name is the binding schema's, not a concept: the
    neutral field `profile` is the owner's payload, not an AWS profile.
    """
    def walk(location, value):
        if isinstance(value, dict):
            for key, item in value.items():
                if not (location == 'parameters' and key in NEUTRAL_FIELDS):
                    yield f'{location}.{key}', key
                yield from walk(f'{location}.{key}', item)
        elif isinstance(value, list):
            for index, item in enumerate(value):
                yield from walk(f'{location}[{index}]', item)
        elif isinstance(value, str) and not is_harness_path(value):
            yield location, value

    for key, value in manifest.items():
        if key not in ('providers', 'schema'):
            yield key, key
            yield from walk(key, value)


def placeholders_for(provider):
    names = {'name'} | NEUTRAL_FIELDS
    return names | {f'{provider}.{field}' for field in PROVIDER_FIELDS.get(provider, ())} if provider else names


def check_manifest(path):
    failures = []

    def fail(message):
        failures.append(f'{path}: {message}')

    def check_template(where, template, provider):
        for name in PLACEHOLDER.findall(template):
            if name not in placeholders_for(provider):
                fail(f'{where}: unknown placeholder {{{name}}}')

    try:
        manifest = tomllib.loads(path.read_text(encoding='utf-8'))
    except tomllib.TOMLDecodeError as error:
        return [f'{path}: not valid TOML (a key declared twice in one table is invalid): {error}'], None

    for key in sorted(manifest.keys() - TOP_KEYS):
        fail(f'unknown top-level key {key}')
    if manifest.get('schema') != SCHEMA:
        fail(f'schema must be {SCHEMA}')
    if path.name == 'recipe.toml' and manifest.get('name') != path.parent.name:
        fail(f'name must equal its directory name {path.parent.name}')
    for key in ('name', 'summary'):
        if not isinstance(manifest.get(key), str) or not manifest[key]:
            fail(f'{key} is required')
    if manifest.get('runtime') not in RUNTIMES:
        fail(f'runtime must be one of {", ".join(sorted(RUNTIMES))}')

    # A recipe supports exactly the providers it has a [providers.<provider>] table for.
    providers = manifest.get('providers', {})
    if not isinstance(providers, dict) or not providers:
        fail('providers must hold at least one [providers.<provider>] table')
        providers = {}
    for provider, table in providers.items():
        if provider not in PROVIDER_FIELDS:
            fail(f'provider {provider} has no binding schema')
        elif not isinstance(table, dict):
            fail(f'providers.{provider} must be a table')
        else:
            for key in sorted(table.keys() - PROVIDER_KEYS):
                fail(f'unknown key providers.{provider}.{key}')
    providers = {name: table for name, table in providers.items() if name in PROVIDER_FIELDS and isinstance(table, dict)}

    sections = [('', 'parameters', manifest.get('parameters', {}))]
    sections += [(name, f'providers.{name}.parameters', table.get('parameters', {})) for name, table in providers.items()]

    declarations = {}
    for _, section, parameters in sections:
        for field in parameters:
            declarations.setdefault(field, []).append(f'[{section}]')
    known = NEUTRAL_FIELDS.union(*(PROVIDER_FIELDS[name] for name in providers))
    for field, where in sorted(declarations.items()):
        if field not in known:
            fail(f'{field} is not a binding field')
        elif len(where) > 1:
            fail(f'{field} is declared more than once: {", ".join(where)}')
        elif field in NEUTRAL_FIELDS and where[0] != '[parameters]':
            fail(f'{field} is provider-neutral and must be declared under [parameters], not {where[0]}')
        elif field not in NEUTRAL_FIELDS and where[0] == '[parameters]':
            fail(f'{field} is a provider field and must be declared under [providers.<provider>.parameters]')
    for field in sorted(known - declarations.keys()):
        fail(f'binding field {field} is not declared')

    for location, value in neutral_strings(manifest):
        if AWS_CONCEPT.search(value) or value.startswith('AWS_'):
            fail(f'provider-neutral entry {location} names an AWS concept: {value!r}')

    scripts = {key: ('', relative) for key, relative in manifest.get('paths', {}).items()}
    for name, table in providers.items():
        for key, relative in table.get('paths', {}).items():
            if key in scripts:
                fail(f'script {key} is declared more than once')
            scripts[key] = (name, relative)
    for key, (_, relative) in scripts.items():
        if not (ROOT / relative).is_file():
            fail(f'script {key} does not exist: {relative}')

    status = manifest.get('status')
    if not isinstance(status, dict):
        fail('[status] is required')
    else:
        for key in sorted(status.keys() - {'schema', 'exit'}):
            fail(f'unknown key status.{key}')
        if status.get('schema') != STATUS_SCHEMA:
            fail(f'status.schema must be {STATUS_SCHEMA}')
        exits = status.get('exit')
        if not isinstance(exits, dict) or exits.keys() != STATUS_EXITS:
            fail(f'status.exit must give exactly {", ".join(sorted(STATUS_EXITS))}')
        elif not all(isinstance(code, int) and 0 <= code <= 255 for code in exits.values()) or len(set(exits.values())) != len(exits):
            fail('status.exit must give each outcome its own exit status from 0 to 255')

    patching = manifest.get('patching')
    if not isinstance(patching, dict):
        fail('[patching] is required')
    else:
        for key in sorted(patching.keys() ^ PATCHING_KEYS):
            fail(f'unknown key patching.{key}' if key in patching else f'patching.{key} is required')
        for key, allowed in PATCHING_INTENT.items():
            if key in patching and patching[key] not in allowed:
                fail(f'patching.{key} must be one of {", ".join(sorted(allowed))}')
        report = patching.get('report')
        if 'report' in patching and (not isinstance(report, list) or not report
                                     or not all(isinstance(item, str) and item for item in report)
                                     or len(set(report)) != len(report)):
            fail('patching.report must list distinct field names')
    for name, table in providers.items():
        mechanism = table.get('patching')
        if not isinstance(mechanism, dict):
            fail(f'[providers.{name}.patching] is required')
            continue
        for key in sorted(mechanism.keys() ^ PATCHING_KEYS):
            fail(f'unknown key providers.{name}.patching.{key}' if key in mechanism
                 else f'providers.{name}.patching.{key} is required')
        for key, value in mechanism.items():
            if not isinstance(value, str) or not value:
                fail(f'providers.{name}.patching.{key} must name the mechanism')
            else:
                check_template(f'providers.{name}.patching.{key}', value, name)

    operations = manifest.get('operations')
    if not isinstance(operations, dict) or operations.keys() != OPERATIONS:
        fail(f'[operations] must declare exactly {", ".join(sorted(OPERATIONS))}')
        operations = operations if isinstance(operations, dict) else {}
    for name, operation in operations.items():
        if not isinstance(operation, dict):
            fail(f'operations.{name} must be a table')
            continue
        for key in sorted(operation.keys() - {'summary', 'script'}):
            fail(f'unknown key operations.{name}.{key}')
        if not isinstance(operation.get('summary'), str) or not operation['summary']:
            fail(f'operations.{name}.summary is required')
        if operation.get('script') not in scripts:
            fail(f'operations.{name} names unknown script {operation.get("script")}')

    readers = {}
    for provider, section, parameters in sections:
        for field, parameter in parameters.items():
            where = f'{section}.{field}'
            if not isinstance(parameter, dict):
                fail(f'{where} must be a table')
                continue
            for key in sorted(parameter.keys() - PARAMETER_KEYS):
                fail(f'unknown key {where}.{key}')
            kinds = [parameter.get('required') is True, 'default' in parameter, parameter.get('optional') is True]
            if kinds.count(True) != 1:
                fail(f'{where} must be exactly one of required = true, a default or optional = true')
            if 'default' in parameter and field_form_problem(field, parameter['default']):
                fail(f'{where}.default: {field_form_problem(field, parameter["default"])}')
            if isinstance(parameter.get('default'), str):
                check_template(f'{where}.default', parameter['default'], provider)
            env, listed = parameter.get('env'), parameter.get('scripts', [])
            if env is None:
                if listed:
                    fail(f'{where} names scripts but no env')
                continue
            if not isinstance(env, str) or not ENV_NAME.match(env):
                fail(f'{where}.env must be an environment variable name')
                continue
            if not listed:
                fail(f'{where} declares env {env} but no script that reads it')
            for script in listed:
                if script not in scripts:
                    fail(f'{where} names unknown script {script}')
                    continue
                owner, relative = scripts[script]
                if provider and owner != provider:
                    fail(f'{where} is a {provider} field but script {script} is not a {provider} script')
                if not provider and env.startswith('AWS_'):
                    fail(f'provider-neutral entry {where}.env names an AWS concept: {env}')
                body = (ROOT / relative).read_text(encoding='utf-8') if (ROOT / relative).is_file() else ''
                if f'${{{env}' not in body and f'${env}' not in body:
                    fail(f'{where}: {relative} does not read {env}')
                readers.setdefault((env, script), []).append(where)
    for (env, script), wheres in sorted(readers.items()):
        if len(wheres) > 1:
            fail(f'script {script} reads {env} for more than one field: {", ".join(wheres)}')

    footprints = [('', 'footprint', manifest.get('footprint', []))]
    footprints += [(name, f'providers.{name}.footprint', table.get('footprint', [])) for name, table in providers.items()]
    for provider, where, entries in footprints:
        if not isinstance(entries, list) or not all(isinstance(entry, str) for entry in entries):
            fail(f'{where} must be a list of strings')
            continue
        for index, entry in enumerate(entries):
            check_template(f'{where}[{index}]', entry, provider)
    for name, table in providers.items():
        for key, value in table.get('selectors', {}).items():
            if not isinstance(value, str):
                fail(f'providers.{name}.selectors.{key} must be a string')
            else:
                check_template(f'providers.{name}.selectors.{key}', value, name)
        for key, value in table.get('tags', {}).items():
            if not isinstance(value, str) or PLACEHOLDER.search(value):
                fail(f'providers.{name}.tags.{key} must be a literal recipe-owned value')

    return failures, (manifest, providers, scripts)


def resolve(binding, provider, manifest, providers):
    """Resolve every field as the CLI does: the binding's value, else the recipe default."""
    neutral = manifest.get('parameters', {})
    own = providers[provider].get('parameters', {})
    values = {'name': binding['name']}

    def lookup(key):
        if key not in values:
            if key.startswith(f'{provider}.'):
                field = key.split('.', 1)[1]
                raw, parameter = binding[provider].get(field), own[field]
            else:
                raw, parameter = binding.get(key), neutral[key]
            if raw is None:
                raw = parameter.get('default')
                if isinstance(raw, str):
                    raw = PLACEHOLDER.sub(lambda match: str(lookup(match.group(1))), raw)
            values[key] = raw
        return values[key]

    for field in neutral:
        lookup(field)
    for field in own:
        lookup(f'{provider}.{field}')
    return values


def check_binding_defaults(binding_path, manifest, providers, scripts):
    binding = tomllib.loads(binding_path.read_text(encoding='utf-8'))
    if binding.get('schema') != BINDING_SCHEMA or binding.get('recipe') != manifest['name']:
        return [f'{binding_path}: not a {BINDING_SCHEMA} binding of {manifest["name"]}']
    chosen = [name for name in PROVIDER_FIELDS if isinstance(binding.get(name), dict)]
    if len(chosen) != 1 or chosen[0] not in providers:
        return [f'{binding_path}: a binding needs exactly one provider table that the recipe supports']
    provider = chosen[0]
    failures = []
    for field in NEUTRAL_FIELDS:
        if field in binding and field_form_problem(field, binding[field]):
            failures.append(f'{binding_path}: {field_form_problem(field, binding[field])}')
    if failures:
        return failures
    values = resolve(binding, provider, manifest, providers)

    sections = [('', manifest.get('parameters', {})), (provider, providers[provider].get('parameters', {}))]
    for owner, parameters in sections:
        for field, parameter in parameters.items():
            env, value = parameter.get('env'), values[f'{owner}.{field}' if owner else field]
            if env is None or value is None:
                continue
            if isinstance(value, bool):
                value = 'true' if value else 'false'
            for script in parameter.get('scripts', []):
                relative = scripts[script][1]
                body = (ROOT / relative).read_text(encoding='utf-8')
                accepted = [f'${{{env}:-{value}}}']
                if is_harness_path(value):
                    local = Path(value).relative_to(Path(relative).parent)
                    accepted.append(f'${{{env}:-${{here}}/{local}}}')
                if 'default' in parameter and value == parameter['default']:
                    # Empty defers to the same recipe default, applied on the host.
                    accepted.append(f'${{{env}:-}}')
                if not any(form in body for form in accepted):
                    failures.append(f'{relative}: the default of {env} must be the binding value {value!r}')
    return failures


def main(argv):
    binding = None
    if len(argv) >= 2 and argv[0] == '--binding':
        binding, argv = Path(argv[1]), argv[2:]
    if not argv:
        print('usage: recipe-manifest.py [--binding <binding.toml>] <recipe.toml>...', file=sys.stderr)
        return 2
    failures = []
    for argument in argv:
        found, parsed = check_manifest(Path(argument))
        failures += found
        if binding is not None and parsed and not found:
            failures += check_binding_defaults(binding, *parsed)
    for failure in failures:
        print(failure, file=sys.stderr)
    if failures:
        return 1
    for argument in argv:
        print(f'validated {argument}')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))

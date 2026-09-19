import { AwsClient, type ControllerStatus } from './aws.ts'
import { type Environment, type Invocation, parseInvocation } from './config.ts'
import { TechneError } from './errors.ts'
import type { CommandRunner } from './process.ts'

export interface CliIo {
  stdout(value: string): void
  stderr(value: string): void
}

export interface CliDependencies {
  runner: CommandRunner
  environment: Environment
  io: CliIo
}

interface DoctorCheck {
  name: string
  ok: boolean
  detail: string
}

const HELP = `techne — operate the Techne controller and execution fabric

Usage:
  techne [global options] doctor
  techne [global options] controller status
  techne [global options] controller bootstrap

Global options:
  --profile <name>            AWS profile
  --region <region>           AWS region
  --account <id>              expected AWS account
  --controller-stack <name>   controller CloudFormation stack
  --json                      machine-readable output where supported
  -h, --help                  show help
`

function commandName(invocation: Invocation): string {
  return invocation.command.join(' ')
}

function cleanVersion(result: { stdout: string; stderr: string }): string {
  return (result.stdout.trim() || result.stderr.trim()).split('\n', 1)[0] ?? 'available'
}

async function doctor(invocation: Invocation, dependencies: CliDependencies): Promise<number> {
  const checks: DoctorCheck[] = []
  const awsVersion = await dependencies.runner.run('aws', ['--version'])
  checks.push({
    name: 'aws',
    ok: awsVersion.exitCode === 0,
    detail: awsVersion.exitCode === 0 ? cleanVersion(awsVersion) : 'AWS CLI is unavailable'
  })

  const pluginVersion = await dependencies.runner.run('session-manager-plugin', ['--version'])
  checks.push({
    name: 'session-manager-plugin',
    ok: pluginVersion.exitCode === 0,
    detail: pluginVersion.exitCode === 0 ? cleanVersion(pluginVersion) : 'AWS Session Manager plugin is unavailable'
  })

  if (awsVersion.exitCode === 0) {
    try {
      const account = await new AwsClient(dependencies.runner, invocation.config).account()
      checks.push({ name: 'aws-account', ok: true, detail: account })
    } catch (error) {
      checks.push({
        name: 'aws-account',
        ok: false,
        detail: error instanceof Error ? error.message : String(error)
      })
    }
  }

  const ok = checks.every((check) => check.ok)
  if (invocation.json) {
    dependencies.io.stdout(`${JSON.stringify({ ok, checks })}\n`)
  } else {
    for (const check of checks) {
      dependencies.io.stdout(`${check.ok ? 'ok' : 'fail'}  ${check.name}: ${check.detail}\n`)
    }
  }
  return ok ? 0 : 1
}

function printControllerStatus(status: ControllerStatus, invocation: Invocation, io: CliIo): void {
  if (invocation.json) {
    io.stdout(`${JSON.stringify(status)}\n`)
    return
  }
  io.stdout(`controller stack: ${status.stackName}\n`)
  io.stdout(`state: ${status.exists ? (status.stackStatus ?? 'unknown') : 'absent'}\n`)
  if (status.instanceId !== null) {
    io.stdout(`instance: ${status.instanceId}\n`)
  }
}

async function controllerStatus(invocation: Invocation, dependencies: CliDependencies): Promise<number> {
  const status = await new AwsClient(dependencies.runner, invocation.config).controllerStatus()
  printControllerStatus(status, invocation, dependencies.io)
  return 0
}

async function controllerBootstrap(invocation: Invocation, dependencies: CliDependencies): Promise<number> {
  if (invocation.json) {
    throw new TechneError('--json is not supported for an interactive bootstrap', 2)
  }
  const plugin = await dependencies.runner.run('session-manager-plugin', ['--version'])
  if (plugin.exitCode !== 0) {
    throw new TechneError('AWS Session Manager plugin is unavailable')
  }

  const aws = new AwsClient(dependencies.runner, invocation.config)
  const status = await aws.controllerStatus()
  if (!status.exists) {
    throw new TechneError(`controller stack does not exist: ${status.stackName}`)
  }
  if (status.instanceId === null || !status.instanceId.startsWith('i-')) {
    throw new TechneError('controller instance output is missing')
  }

  dependencies.io.stdout(`Opening a private interactive bootstrap session on ${status.instanceId}.\n`)
  dependencies.io.stdout('Credential values are read by the remote process and are not sent as command parameters.\n')
  await aws.startBootstrap(status.instanceId)
  return 0
}

export async function runCli(argv: readonly string[], dependencies: CliDependencies): Promise<number> {
  try {
    const invocation = parseInvocation(argv, dependencies.environment)
    if (invocation.help || invocation.command.length === 0) {
      dependencies.io.stdout(HELP)
      return 0
    }

    switch (commandName(invocation)) {
      case 'doctor':
        return await doctor(invocation, dependencies)
      case 'controller status':
        return await controllerStatus(invocation, dependencies)
      case 'controller bootstrap':
        return await controllerBootstrap(invocation, dependencies)
      default:
        throw new TechneError(`unknown command: ${commandName(invocation)}`, 2)
    }
  } catch (error) {
    if (error instanceof TechneError) {
      dependencies.io.stderr(`error: ${error.message}\n`)
      return error.exitCode
    }
    dependencies.io.stderr(`error: ${error instanceof Error ? error.message : String(error)}\n`)
    return 1
  }
}

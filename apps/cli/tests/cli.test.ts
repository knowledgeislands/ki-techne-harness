import { describe, expect, test } from 'bun:test'
import { type CliIo, runCli } from '../src/cli.ts'
import type { CommandCall, CommandResult, CommandRunner, RunOptions } from '../src/process.ts'

const ACCOUNT = '655383751458'
const INSTANCE = 'i-0123456789abcdef0'

class FakeRunner implements CommandRunner {
  readonly calls: CommandCall[] = []

  constructor(private readonly responses: CommandResult[]) {}

  async run(command: string, args: readonly string[], options: RunOptions = {}): Promise<CommandResult> {
    this.calls.push({ command, args: [...args], mode: options.mode ?? 'capture' })
    return this.responses.shift() ?? { exitCode: 0, stdout: '', stderr: '' }
  }
}

function response(stdout = '', stderr = '', exitCode = 0): CommandResult {
  return { exitCode, stdout, stderr }
}

function identity(account = ACCOUNT): CommandResult {
  return response(JSON.stringify({ Account: account }))
}

function stack(instanceId: string | null = INSTANCE): CommandResult {
  const Outputs = instanceId === null ? [] : [{ OutputKey: 'ControllerInstanceId', OutputValue: instanceId }]
  return response(JSON.stringify({ Stacks: [{ StackStatus: 'CREATE_COMPLETE', Outputs }] }))
}

function harness(runner: FakeRunner, environment: Record<string, string | undefined> = {}) {
  let stdout = ''
  let stderr = ''
  const io: CliIo = {
    stdout: (value) => {
      stdout += value
    },
    stderr: (value) => {
      stderr += value
    }
  }
  return {
    run: (argv: readonly string[]) => runCli(argv, { runner, environment, io }),
    output: () => ({ stdout, stderr })
  }
}

describe('techne CLI', () => {
  test('shows help without running a subprocess', async () => {
    const runner = new FakeRunner([])
    const cli = harness(runner)

    expect(await cli.run(['--help'])).toBe(0)
    expect(cli.output().stdout).toContain('controller bootstrap')
    expect(runner.calls).toHaveLength(0)
  })

  test('rejects unknown commands', async () => {
    const cli = harness(new FakeRunner([]))

    expect(await cli.run(['controller', 'explode'])).toBe(2)
    expect(cli.output().stderr).toContain('unknown command')
  })

  test('reports local tools and expected AWS identity', async () => {
    const runner = new FakeRunner([response('', 'aws-cli/2.36.49'), response('1.2.835.0\n'), identity()])
    const cli = harness(runner)

    expect(await cli.run(['doctor', '--json'])).toBe(0)
    expect(JSON.parse(cli.output().stdout)).toMatchObject({ ok: true })
    expect(runner.calls.map((call) => call.command)).toEqual(['aws', 'session-manager-plugin', 'aws'])
  })

  test('reports a controller stack using flag precedence', async () => {
    const runner = new FakeRunner([identity('222222222222'), stack()])
    const cli = harness(runner, {
      AWS_PROFILE: 'environment-profile',
      AWS_REGION: 'environment-region',
      EXPECTED_AWS_ACCOUNT: ACCOUNT
    })

    expect(
      await cli.run([
        'controller',
        'status',
        '--profile',
        'flag-profile',
        '--region',
        'flag-region',
        '--account',
        '222222222222',
        '--json'
      ])
    ).toBe(0)
    expect(JSON.parse(cli.output().stdout)).toMatchObject({
      exists: true,
      stackStatus: 'CREATE_COMPLETE',
      instanceId: INSTANCE
    })
    expect(runner.calls[0]?.args).toContain('flag-profile')
    expect(runner.calls[1]?.args).toContain('flag-region')
  })

  test('reports an absent controller stack without masking identity checks', async () => {
    const runner = new FakeRunner([
      identity(),
      response('', 'Stack with id ki-techne-ops-007-controller does not exist', 255)
    ])
    const cli = harness(runner)

    expect(await cli.run(['controller', 'status'])).toBe(0)
    expect(cli.output().stdout).toContain('state: absent')
  })

  test('refuses an unexpected AWS account before inspecting the stack', async () => {
    const runner = new FakeRunner([identity('999999999999')])
    const cli = harness(runner)

    expect(await cli.run(['controller', 'status'])).toBe(1)
    expect(cli.output().stderr).toContain('refusing AWS account')
    expect(runner.calls).toHaveLength(1)
  })

  test('opens bootstrap through an interactive SSM session', async () => {
    const runner = new FakeRunner([response('1.2.835.0\n'), identity(), stack(), response()])
    const cli = harness(runner, { TELEGRAM_BOT_TOKEN: 'must-not-leak' })

    expect(await cli.run(['controller', 'bootstrap'])).toBe(0)
    const session = runner.calls.at(-1)
    expect(session).toMatchObject({ command: 'aws', mode: 'interactive' })
    expect(session?.args.join(' ')).toContain('AWS-StartInteractiveCommand')
    expect(session?.args.join(' ')).not.toContain('must-not-leak')
    expect(cli.output().stdout).toContain('private interactive bootstrap session')
  })

  test('rejects JSON output for interactive bootstrap', async () => {
    const runner = new FakeRunner([])
    const cli = harness(runner)

    expect(await cli.run(['controller', 'bootstrap', '--json'])).toBe(2)
    expect(runner.calls).toHaveLength(0)
  })
})

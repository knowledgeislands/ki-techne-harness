export type RunMode = 'capture' | 'interactive'

export interface RunOptions {
  mode?: RunMode
}

export interface CommandResult {
  exitCode: number
  stdout: string
  stderr: string
}

export interface CommandCall {
  command: string
  args: readonly string[]
  mode: RunMode
}

export interface CommandRunner {
  run(command: string, args: readonly string[], options?: RunOptions): Promise<CommandResult>
}

function commandError(error: unknown): CommandResult {
  const message = error instanceof Error ? error.message : String(error)
  return { exitCode: 127, stdout: '', stderr: message }
}

export class BunCommandRunner implements CommandRunner {
  async run(command: string, args: readonly string[], options: RunOptions = {}): Promise<CommandResult> {
    const mode = options.mode ?? 'capture'

    try {
      if (mode === 'interactive') {
        const child = Bun.spawn([command, ...args], {
          stdin: 'inherit',
          stdout: 'inherit',
          stderr: 'inherit'
        })
        const exitCode = await child.exited
        return { exitCode, stdout: '', stderr: '' }
      }

      const child = Bun.spawn([command, ...args], {
        stdin: 'ignore',
        stdout: 'pipe',
        stderr: 'pipe'
      })
      const [stdout, stderr, exitCode] = await Promise.all([
        new Response(child.stdout).text(),
        new Response(child.stderr).text(),
        child.exited
      ])
      return { exitCode, stdout, stderr }
    } catch (error) {
      return commandError(error)
    }
  }
}

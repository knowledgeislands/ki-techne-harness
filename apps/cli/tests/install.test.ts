import { afterEach, describe, expect, test } from 'bun:test'
import { mkdtemp, readFile, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'

const repository = resolve(import.meta.dir, '../../..')
const temporaryDirectories: string[] = []

afterEach(async () => {
  await Promise.all(temporaryDirectories.splice(0).map((directory) => rm(directory, { recursive: true, force: true })))
})

async function run(
  command: readonly string[],
  environment: Record<string, string>
): Promise<{
  exitCode: number
  stdout: string
  stderr: string
}> {
  const child = Bun.spawn([...command], {
    cwd: repository,
    env: { ...process.env, ...environment },
    stdout: 'pipe',
    stderr: 'pipe'
  })
  const [stdout, stderr, exitCode] = await Promise.all([
    new Response(child.stdout).text(),
    new Response(child.stderr).text(),
    child.exited
  ])
  return { exitCode, stdout, stderr }
}

describe('local installer', () => {
  test('installs a launcher bound to the checkout source', async () => {
    const root = await mkdtemp(join(tmpdir(), 'techne-install-'))
    temporaryDirectories.push(root)
    const installDirectory = join(root, 'bin')

    const installation = await run(['bash', 'install.sh', '--link'], { TECHNE_INSTALL_DIR: installDirectory })
    expect(installation).toMatchObject({ exitCode: 0, stderr: '' })
    expect(installation.stdout).toContain('linked')

    const launcher = join(installDirectory, 'techne')
    expect(await readFile(launcher, 'utf8')).toContain(resolve(repository, 'apps/cli/src/main.ts'))

    const diagnostic = await run([launcher, 'diag', '--json'], {})
    expect(diagnostic.exitCode).toBe(0)
    expect(JSON.parse(diagnostic.stdout)).toMatchObject({ version: '0.1.0', installation: 'local' })
  })

  test('rejects an implicit installation mode', async () => {
    const root = await mkdtemp(join(tmpdir(), 'techne-install-'))
    temporaryDirectories.push(root)

    const result = await run(['bash', 'install.sh'], { TECHNE_INSTALL_DIR: join(root, 'bin') })
    expect(result.exitCode).toBe(1)
    expect(result.stderr).toContain('expected --link')
  })
})

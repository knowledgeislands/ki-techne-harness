#!/usr/bin/env bun

import { runCli } from './cli.ts'
import { BunCommandRunner } from './process.ts'

const exitCode = await runCli(process.argv.slice(2), {
  runner: new BunCommandRunner(),
  environment: process.env,
  io: {
    stdout: (value) => process.stdout.write(value),
    stderr: (value) => process.stderr.write(value)
  }
})

process.exitCode = exitCode

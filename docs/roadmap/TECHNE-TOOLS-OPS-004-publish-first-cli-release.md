---
id: TECHNE-TOOLS-OPS-004
area: OPS
title: Publish first CLI release
theme: operations
horizon: triage
status: done
intake_disposition: rejected
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-20T08:01:34Z
updated_at: 2026-09-22T00:04:47Z
---

## Goal

Publish the first immutable Techne CLI release from the accepted packaging workflow and prove its three supported platform archives, checksums, and installation provenance are usable downstream.

## Context

`TECHNE-TOOLS-OPS-002` delivered local-link installation, mode-aware diagnostics, native archive packaging, guarded release workflows, and offline current-platform smoke evidence. It deliberately stopped before creating a tag or GitHub release. Homebrew packaging cannot begin honestly until immutable release assets and observed checksums exist.

## Boundary

Do not publish, tag, push, deploy infrastructure, or mutate Homebrew Tap under the authority of this Triage capture. Release execution requires explicit reviewed authority and must preserve the accepted version, tag-ancestry, native-runner, checksum, and installed-binary smoke gates.

## Intake disposition

Rejected because Techne Harness no longer owns CLI source or release lifecycle. Retaining this proposal as executable harness work would assert an implementation boundary that the accepted extraction has superseded.

## Done

Rejected on 22 September 2026 with explicit owner approval. The record is retained as the canonical terminal disposition of the obsolete intake.

## Discussion

### Source ownership

Techne Harness owns the source tag, GitHub release workflow, archives, checksums, and release evidence. Homebrew Tap consumes those immutable outputs under its own later work item and does not own source publication.

### Completion evidence

A future adopted item should require the exact accepted commit, semantic-version tag, successful native packaging jobs for macOS ARM64, macOS x64, and Linux x64, published checksums, and an installation smoke result without AWS access.

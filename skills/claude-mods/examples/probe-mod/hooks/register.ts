// Throwaway probe mod: proves which hook events fire and which $ nouns reach on this box.
import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { ProbeHealth } from '../types'

const health = atom({ plugin: 'lf-probe', key: 'health' } as const, null as ProbeHealth | null)

const COLLECTOR = 'http://127.0.0.1:7311/health'

let seq = 0
let calls = 0
const lines: string[] = []
// ponytail: $.fs.write replaces the whole file, so keep the lines in memory and rewrite; fine for a probe.
let writing: Promise<void> = Promise.resolve()

function out($: EngineInterface, name: string) {
  return `${$.plugin.root}/out/${name}`
}

function log($: EngineInterface, row: Record<string, unknown>) {
  lines.push(JSON.stringify({ seq: ++seq, ...row }))
  writing = writing.then(() => $.fs.write(out($, 'calls.jsonl'), lines.join('\n') + '\n')).catch(() => {})
  return writing
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const started = await next(e)
    const report: Record<string, unknown> = { at: await $.clock.now(), version: await $.session.version() }

    report.command = await $.command.register({ name: 'lfprobe', description: 'lf-probe: report what the probe saw.' })
      .catch((err: Error) => ({ error: String(err) }))

    const t0 = await $.clock.now()
    try {
      const r = await $.http.fetch(COLLECTOR)
      report.http = { status: r.status, ok: r.ok, ms: (await $.clock.now()) - t0, body: r.text.slice(0, 120) }
    } catch (err) {
      report.http = { refused: String(err), ms: (await $.clock.now()) - t0 }
    }

    try {
      const p = await $.process.run(['git', '-C', '/home/justin/ops', 'rev-parse', '--short', 'HEAD'])
      report.process = { exitCode: p.exitCode, stdout: p.stdout.trim(), stderr: p.stderr.slice(0, 120) }
    } catch (err) {
      report.process = { refused: String(err) }
    }

    const http = report.http as { status?: number; ms?: number; refused?: string }
    const text = http.refused ? `collector: refused (${http.refused.slice(0, 60)})` : `collector: ${http.status} in ${http.ms}ms`
    await update($, health, () => ({ text })).catch((err: Error) => { report.stateError = String(err) })
    $.ui.status(`lf-probe ${text}`)

    await $.store.set('marker', report.at)
    report.storeMarker = await $.store.get('marker')
    await $.fs.write(out($, 'session.json'), JSON.stringify(report, null, 2))
    return started
  })

  on('command.run', { command: 'lfprobe' }, async $ => {
    const cur = await read($, health)
    return { text: `lf-probe: ${calls} tool calls observed; ${cur?.text ?? 'no health yet'}; marker=${String(await $.store.get('marker'))}` }
  })

  on('tool.call', async ($, e, next) => {
    calls += 1
    const t0 = await $.clock.now()
    await log($, { ev: 'tool.call:enter', tool: String(e.tool), id: e.tool_use_id })
    const result = await next(e)
    const ms = (await $.clock.now()) - t0
    await log($, { ev: 'tool.call:exit', tool: String(e.tool), id: e.tool_use_id, ms, isError: result.isError ?? false, denied: result.deny ?? null })
    return result
  })

  on('classic.PreToolUse', async ($, e, next) => {
    await log($, { ev: 'classic.PreToolUse:enter', tool: String(e.tool), id: e.tool_use_id })
    const result = await next(e)
    await log($, { ev: 'classic.PreToolUse:exit', tool: String(e.tool), result })
    return result
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const cur = await read($, health)
    if (e.props.hasSurvey || cur === null) return next(e)
    const { Box, Text } = $.ui.resolve(e)
    return h(Box, null, h(Text, { dimColor: true }, `lf-probe ${cur.text}`))
  })
}

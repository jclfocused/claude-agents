import { expect, test } from 'claude-code/testing'

// The test's `on` hooks stand for the engine: every $ noun the plugin calls is answered here as { value }.
test('tool.call passes the result through unchanged and logs enter/PreToolUse/exit in order', async ($, on) => {
  let now = 1000
  let written = ''
  on('clock.now', () => ({ value: (now += 7) }))
  on('fs.write', ($, e) => {
    if (e.path.endsWith('/out/calls.jsonl')) written = e.text
    return { value: undefined }
  })
  on('tool.call', { tool: 'Bash' }, () => ({ result: { stdout: 'probe-ok', stderr: '', interrupted: false } }))

  const ran = await $.tool.call({ tool: 'Bash', command: 'echo probe-ok' })
  expect(ran.result).toMatchObject({ stdout: 'probe-ok' })

  const rows = written.trim().split('\n').map(l => JSON.parse(l) as { ev: string; ms?: number })
  const evs = rows.map(r => r.ev)
  expect(evs).toEqual(['tool.call:enter', 'classic.PreToolUse:enter', 'classic.PreToolUse:exit', 'tool.call:exit'])
  expect(rows[3].ms).toBe(7)
})

test('/lfprobe answers with the observed call count', async ($, on) => {
  on('store.get', () => ({ value: 42 }))
  const { text } = await $.command.run({ command: 'lfprobe' })
  expect(text).toMatch(/^lf-probe: \d+ tool calls observed; .*marker=42$/)
})

export type ProbeHealth = { text: string }

declare module 'claude-code' {
  interface PluginState {
    'lf-probe': { health: ProbeHealth | null }
  }
}

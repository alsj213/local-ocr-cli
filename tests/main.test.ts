import { describe, expect, it } from 'vitest'
import { analyze, doctor, ENGINE_PATH } from '../src/main.js'
import { existsSync } from 'node:fs'
import { join } from 'node:path'

// A tiny PNG (1x1 red pixel) — valid image bytes for file checks.
const TINY_PNG = join(import.meta.dirname, 'fixtures', 'tiny.png')

describe('engine resolution', () => {
  it('engine script exists', () => {
    expect(existsSync(ENGINE_PATH)).toBe(true)
  })
})

describe('doctor', () => {
  it('prints diagnostics without throwing', () => {
    const out = doctor()
    expect(out).toContain('local-ocr doctor')
    expect(out).toContain('Python')
    expect(out).toContain('Engine')
  })
})

describe('analyze', () => {
  it('rejects missing input', async () => {
    await expect(analyze({ input: '/nonexistent/nope.png' })).rejects.toThrow(/not found/)
  })

  it('rejects non-file input', async () => {
    await expect(analyze({ input: import.meta.dirname })).rejects.toThrow(/not a file/)
  })

  it('returns a well-shaped result for a file, success or error', async () => {
    // tiny.png exists; the engine either recognizes it (text) or reports
    // error (no tesseract/paddle in CI). We assert the shape, not success.
    const result = await analyze({ input: TINY_PNG, engine: 'tesseract', timeoutMs: 30_000 })
    expect(result).toHaveProperty('engine', 'tesseract')
    expect(typeof result.durationSeconds).toBe('number')
    expect(result.text !== undefined || result.error !== undefined).toBe(true)
  })
})

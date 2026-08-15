/**
 * LocalOCR CLI entry.
 *
 * `local-ocr <image>` — recognize a local image with PaddleOCR-VL (default)
 * or tesseract, entirely on this machine. The engine is the bundled Python
 * script (`engine/engine.py`), spawned as a subprocess: no PATH lookup, no
 * npx, CLI and engine version-lock together.
 *
 * Subcommands: analyze (default), doctor, engine-path.
 */
import { spawn } from 'node:child_process'
import { existsSync, statSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join, resolve } from 'node:path'
import { Command } from 'commander'

const __dirname = dirname(fileURLToPath(import.meta.url))
export const ENGINE_PATH = join(__dirname, '..', 'engine', 'engine.py')
const ENGINE_TIMEOUT_MS = 300_000

export interface AnalyzeOptions {
  input: string
  engine?: 'paddleocr' | 'tesseract'
  version?: string
  language?: string
  psm?: number
  saveDir?: string
  pythonBin?: string
  timeoutMs?: number
}

export interface AnalyzeResult {
  text: string
  engine: string
  version?: string
  saved_to?: string
  json_to?: string
  blocks?: unknown[]
  error?: string
  durationSeconds?: number
}

function findPython(): string {
  // Explicit override first, then common venv/system names.
  if (process.env.LOCAL_OCR_PYTHON) return process.env.LOCAL_OCR_PYTHON
  const candidates = [
    process.env.LOCAL_OCR_VENV ? join(process.env.LOCAL_OCR_VENV, 'bin', 'python') : '',
    join(__dirname, '..', '.venv', 'bin', 'python'),
    'python3',
    'python',
  ].filter(Boolean)
  for (const c of candidates) {
    if (c.includes('/') && !existsSync(c)) continue
    return c
  }
  return 'python3'
}

export function analyze(options: AnalyzeOptions): Promise<AnalyzeResult> {
  return new Promise((resolvePromise, rejectPromise) => {
    if (!existsSync(options.input)) {
      rejectPromise(new Error(`input not found: ${options.input}`))
      return
    }
    const stat = statSync(options.input)
    if (!stat.isFile()) {
      rejectPromise(new Error(`input is not a file: ${options.input}`))
      return
    }

    const argv = [
      findPython(),
      ENGINE_PATH,
      resolve(options.input),
      '--engine', options.engine ?? 'paddleocr',
      '--version', options.version ?? 'v1.6',
      '--json',
    ]
    if (options.language) argv.push('--language', options.language)
    if (options.psm !== undefined) argv.push('--psm', String(options.psm))
    if (options.saveDir) argv.push('--save-dir', resolve(options.saveDir))

    const start = Date.now()
    const child = spawn(argv[0], argv.slice(1), {
      stdio: ['ignore', 'pipe', 'pipe'],
      env: { ...process.env, NO_PROXY: '127.0.0.1,localhost', no_proxy: '127.0.0.1,localhost' },
    })
    let stdout = ''
    let stderr = ''
    child.stdout.on('data', (chunk: Buffer) => { stdout += chunk.toString() })
    child.stderr.on('data', (chunk: Buffer) => { stderr += chunk.toString() })
    const timer = setTimeout(() => {
      child.kill('SIGTERM')
      rejectPromise(new Error(`engine timed out after ${ENGINE_TIMEOUT_MS}ms`))
    }, options.timeoutMs ?? ENGINE_TIMEOUT_MS)

    child.on('error', (err) => {
      clearTimeout(timer)
      rejectPromise(err)
    })
    child.on('close', (code) => {
      clearTimeout(timer)
      const durationSeconds = (Date.now() - start) / 1000
      const lines = stdout.trim().split('\n').filter(Boolean)
      const last = lines.at(-1) ?? ''
      let parsed: AnalyzeResult
      try {
        parsed = JSON.parse(last) as AnalyzeResult
      } catch {
        parsed = { text: '', engine: options.engine ?? 'paddleocr', error: stdout.slice(0, 500) || stderr.slice(0, 500) }
      }
      if (parsed.engine === undefined) parsed.engine = options.engine ?? 'paddleocr'
      parsed.durationSeconds = Number(durationSeconds.toFixed(2))
      if (code !== 0 && !parsed.error) {
        parsed.error = `engine exited ${code}: ${stderr.slice(0, 500)}`
      }
      resolvePromise(parsed)
    })
  })
}

export function doctor(): string {
  const lines: string[] = []
  lines.push('local-ocr doctor (local diagnostics only, no network)')
  lines.push('')
  lines.push('Python')
  const py = findPython()
  lines.push(`  ${py} ${existsSync(py) ? '' : '(not found, will fall back to python3)'}`)
  lines.push('')
  lines.push('Engine')
  lines.push(`  ${ENGINE_PATH} ${existsSync(ENGINE_PATH) ? '[ok]' : '[missing]'}`)
  lines.push('')
  lines.push('Engines available (best-effort probe)')
  lines.push('  paddleocr: requires Python venv with paddlepaddle-gpu>=3.2.1 + paddleocr>=3.7.0')
  lines.push('  tesseract:  requires tesseract binary on PATH')
  lines.push('')
  lines.push('Save dir')
  lines.push(`  ${process.env.LOCAL_OCR_SAVE_DIR ?? 'ocr_output/'} (set LOCAL_OCR_SAVE_DIR to change)`)
  return lines.join('\n')
}

const program = new Command()
program
  .name('local-ocr')
  .description('Fully-local OCR CLI: PaddleOCR-VL (first-tier) with tesseract fallback')
  .version('0.1.0')

program
  .command('analyze')
  .description('recognize text in an image (default)')
  .argument('<input>', 'local image path')
  .option('-e, --engine <name>', 'engine: paddleocr (default) | tesseract', 'paddleocr')
  .option('-v, --version <ver>', 'PaddleOCR-VL pipeline version: v1 | v1.5 | v1.6', 'v1.6')
  .option('-l, --language <lang>', 'tesseract language (tesseract only)', 'chi_sim+eng')
  .option('--psm <n>', 'tesseract PSM (tesseract only)', '3')
  .option('-s, --save-dir <dir>', 'directory for .md/.json outputs')
  .option('-j, --json', 'emit structured JSON', true)
  .action(async (input: string, opts: Record<string, string>) => {
    try {
      const result = await analyze({
        input,
        engine: opts.engine as AnalyzeOptions['engine'],
        version: opts.version,
        language: opts.language,
        psm: opts.psm !== undefined ? Number(opts.psm) : undefined,
        saveDir: opts.saveDir,
      })
      if (opts.json || true) {
        process.stdout.write(`${JSON.stringify(result, null, 2)}\n`)
      } else {
        process.stdout.write(`${result.text ?? result.error ?? ''}\n`)
      }
      if (result.error) process.exitCode = 2
    } catch (err) {
      process.stderr.write(`local-ocr: ${(err as Error).message}\n`)
      process.exitCode = 1
    }
  })

program
  .command('doctor')
  .description('offline diagnostics')
  .action(() => {
    process.stdout.write(`${doctor()}\n`)
  })

program
  .command('engine-path')
  .description('print the resolved engine script path')
  .action(() => {
    process.stdout.write(`${ENGINE_PATH}\n`)
  })

program.parseAsync(process.argv).catch((err: unknown) => {
  process.stderr.write(`local-ocr: ${(err as Error).message}\n`)
  process.exitCode = 1
})

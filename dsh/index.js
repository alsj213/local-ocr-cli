// DeepSeek Harness (dsh) plugin for LocalOCR: registers an `ocr` tool backed
// by the bundled Python engine. The engine is spawned from engine/engine.py
// inside this package: no PATH lookup, no npx, plugin and engine version-lock
// together. Everything runs locally — no network, no cloud, images never
// leave the machine.
//
// Loaded via the cordis.patch.yml row `local-ocr-cli` (see package.json
// `dsh.bundle` manifest).
import { spawn } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import { dirname, join, resolve } from 'node:path'
import { existsSync, statSync } from 'node:fs'

const __dirname = dirname(fileURLToPath(import.meta.url))
const ENGINE_PATH = join(__dirname, '..', 'engine', 'engine.py')
const ENGINE_TIMEOUT_MS = 300_000

export const name = 'local-ocr'
export const inject = ['tools']

function findPython(): string {
  if (process.env.LOCAL_OCR_PYTHON) return process.env.LOCAL_OCR_PYTHON
  const candidates = [
    process.env.LOCAL_OCR_VENV ? join(process.env.LOCAL_OCR_VENV, 'bin', 'python') : '',
    join(__dirname, '..', '..', '..', '..', '..', 'ocr-venv', 'bin', 'python'),
    'python3',
    'python',
  ].filter(Boolean)
  for (const c of candidates) {
    if (c.includes('/') && !existsSync(c)) continue
    return c
  }
  return 'python3'
}

export function apply(ctx) {
  const tools = ctx.get('tools')
  if (tools === undefined) return

  const tool = {
    name: 'ocr',
    description:
      '识别图片中的文字（OCR），完全本地运行。默认使用 PaddleOCR-VL 第一梯队模型（版面分析+VLM，'
      + '支持中英文/表格/公式），可回退 tesseract。结果自动保存 markdown + 结构化 JSON 到工作区 ocr_output/。',
    parameters: {
      type: 'object',
      properties: {
        image_path: { type: 'string', description: '图片文件路径（绝对路径或相对当前工作区）' },
        engine: { type: 'string', enum: ['paddleocr', 'tesseract'], description: '识别引擎，默认 paddleocr' },
        version: { type: 'string', enum: ['v1', 'v1.5', 'v1.6'], description: 'PaddleOCR-VL 版本，默认 v1.6' },
        save: { type: 'boolean', description: '是否保存结果文件（默认 true）' },
        language: { type: 'string', description: 'tesseract 语言（仅 tesseract），默认 chi_sim+eng' },
        psm: { type: 'number', description: 'tesseract 页面分割模式（仅 tesseract），默认 3' },
      },
      required: ['image_path'],
    },
    async execute(args, exec) {
      const imagePath = String(args.image_path)
      const engine = args.engine === 'tesseract' ? 'tesseract' : 'paddleocr'
      const version = typeof args.version === 'string' ? args.version : 'v1.6'
      const save = args.save !== false
      const language = typeof args.language === 'string' && args.language.length > 0 ? args.language : 'chi_sim+eng'
      const psm = typeof args.psm === 'number' && Number.isFinite(args.psm) ? args.psm : 3

      const abs = resolve(imagePath)
      if (!existsSync(abs)) throw new Error(`图片文件不存在: ${imagePath}`)
      const st = statSync(abs)
      if (!st.isFile()) throw new Error(`不是文件: ${imagePath}`)

      const argv = [
        findPython(), ENGINE_PATH, abs,
        '--engine', engine,
        '--version', version,
        '--language', language,
        '--psm', String(psm),
        '--json',
      ]
      if (save) argv.push('--save-dir', join(process.cwd(), 'ocr_output'))

      const result = await runEngine(argv, exec.signal)
      if (result.error) {
        return { text: '', engine, version, error: result.error }
      }
      const blocks = Array.isArray(result.blocks) ? result.blocks : []
      return {
        text: result.text ?? '',
        engine,
        version: result.version ?? version,
        saved_to: result.saved_to,
        json_to: result.json_to,
        block_count: blocks.length,
      }
    },
  }

  // Keep the exact same shape as other dynamic tools: register through the
  // tools registry so the model sees `ocr` on the next step.
  return ctx.effect(() => tools.register(tool))
}

function runEngine(argv, signal) {
  return new Promise((resolvePromise, rejectPromise) => {
    const child = spawn(argv[0], argv.slice(1), {
      stdio: ['ignore', 'pipe', 'pipe'],
      env: { ...process.env, NO_PROXY: '127.0.0.1,localhost', no_proxy: '127.0.0.1,localhost' },
    })
    let stdout = ''
    let stderr = ''
    child.stdout.on('data', (c) => { stdout += c.toString() })
    child.stderr.on('data', (c) => { stderr += c.toString() })
    const timer = setTimeout(() => { child.kill('SIGTERM') }, ENGINE_TIMEOUT_MS)
    if (signal) {
      signal.addEventListener('abort', () => { child.kill('SIGTERM') }, { once: true })
    }
    child.on('error', (err) => { clearTimeout(timer); rejectPromise(err) })
    child.on('close', (code) => {
      clearTimeout(timer)
      const lines = stdout.trim().split('\n').filter(Boolean)
      const last = lines.at(-1) ?? ''
      let parsed
      try {
        parsed = JSON.parse(last)
      } catch {
        parsed = { error: stdout.slice(0, 500) || stderr.slice(0, 500) }
      }
      if (code !== 0 && !parsed.error) parsed.error = `engine exited ${code}: ${stderr.slice(0, 500)}`
      resolvePromise(parsed)
    })
  })
}

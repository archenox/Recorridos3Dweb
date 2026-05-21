import Fastify from 'fastify'
import multipart from '@fastify/multipart'
import staticFiles from '@fastify/static'
import { pipeline } from 'stream/promises'
import { createWriteStream, mkdirSync } from 'fs'
import { randomUUID } from 'crypto'
import sharp from 'sharp'
import { resolve } from 'path'

const app = Fastify({ logger: true })

const DATA_DIR = resolve(process.env.DATA_DIR ?? './data/tours')

app.register(multipart, {
  limits: { fileSize: 500 * 1024 * 1024 }
})

// Sirve los assets desde disco
app.register(staticFiles, {
  root: DATA_DIR,
  prefix: '/assets/tours/',
})

app.get('/health', async () => ({ status: 'ok' }))

app.post('/api/upload', async (req, reply) => {
  const data    = await req.file()
  const tourId  = randomUUID()
  const sceneId = randomUUID()
  const dir     = `${DATA_DIR}/${tourId}/${sceneId}`

  mkdirSync(dir, { recursive: true })

  const originalPath = `${dir}/original.jpg`
  await pipeline(data.file, createWriteStream(originalPath))

  await sharp(originalPath, { limitInputPixels: false })
    .resize(512, 256)
    .webp({ quality: 80 })
    .toFile(`${dir}/preview.webp`)

  await sharp(originalPath, { limitInputPixels: false })
    .resize(4096, 2048)
    .webp({ quality: 85 })
    .toFile(`${dir}/full.webp`)

  return {
    tourId,
    sceneId,
    previewUrl: `/assets/tours/${tourId}/${sceneId}/preview.webp`,
    fullUrl:    `/assets/tours/${tourId}/${sceneId}/full.webp`,
  }
})

const port = Number(process.env.PORT ?? 3001)
try {
  await app.listen({ port, host: '0.0.0.0' })
} catch (err) {
  app.log.error(err)
  process.exit(1)
}
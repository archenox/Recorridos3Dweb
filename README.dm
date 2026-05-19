# tours3d

Self-hosted platform for 360° virtual tours. Upload panoramic photos, build navigable tours with hotspots, and share them with a single URL.

> Functional MVP in 4 weeks. No unnecessary infrastructure.

---

## Stack

| Layer | Technology | Notes |
|---|---|---|
| Frontend | React + Vite | Static SPA served by Nginx |
| Viewer | Photo Sphere Viewer | Virtual Tour Plugin for multi-scene support |
| API | Fastify (Node.js) | REST + inline Sharp processing |
| Database | PostgreSQL 16 | Dedicated `tours3d` schema |
| Cache | Valkey 7.2 | Tour cache with 5 min TTL |
| Object Storage | MinIO | S3-compatible, self-hosted |
| CDN | Cloudflare | Edge cache for assets via MinIO presigned URLs |
| Containers | Docker + Nginx | 2 new services on top of existing infra |

---

## Project Structure

```
tours3d/
├── apps/
│   ├── web/                    # React SPA
│   └── api/                    # Fastify API
├── infra/
│   ├── docker-compose.yml
│   ├── nginx/
│   │   └── tours3d.conf
│   └── db/
│       └── schema.sql
└── pnpm-workspace.yaml
```

---

## Requirements

- Node.js 22+
- pnpm 9+
- Docker + Docker Compose
- PostgreSQL 16 (can reuse an existing instance)
- Valkey 7.2 (can reuse an existing instance)
- Nginx on the host

---

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/your-username/tours3d.git
cd tours3d
```

### 2. Install dependencies

```bash
# ignore-scripts due to active npm ecosystem vulnerability
pnpm config set ignore-scripts true
pnpm install
# Sharp requires native binaries — rebuild separately
pnpm rebuild sharp
```

### 3. Create the database

```bash
psql -U postgres -c "CREATE DATABASE tours3d;"
psql -U postgres -d tours3d -f infra/db/schema.sql
```

### 4. Environment variables

```bash
cp apps/api/.env.example apps/api/.env
```

```env
# apps/api/.env
PORT=3001
DATABASE_URL=postgresql://user:password@localhost:5432/tours3d
VALKEY_URL=redis://localhost:6379
JWT_SECRET=replace_with_a_secure_random_string

# MinIO
MINIO_ENDPOINT=minio
MINIO_PORT=9000
MINIO_ACCESS_KEY=your_access_key
MINIO_SECRET_KEY=your_secret_key
MINIO_BUCKET=tours3d
MINIO_USE_SSL=false
```

### 5. Start with Docker

```bash
cd infra
docker compose up -d
```

This starts two new containers: `tour-api` and `minio`. PostgreSQL and Valkey are referenced from your existing stack.

### 6. Create the MinIO bucket

On first run, open the MinIO console at `http://your-server:9001` and create a bucket named `tours3d`. Alternatively, use the CLI:

```bash
docker exec -it minio mc alias set local http://localhost:9000 $MINIO_ACCESS_KEY $MINIO_SECRET_KEY
docker exec -it minio mc mb local/tours3d
docker exec -it minio mc anonymous set download local/tours3d
```

### 7. Configure Nginx

```bash
sudo cp infra/nginx/tours3d.conf /etc/nginx/sites-available/tours3d
sudo ln -s /etc/nginx/sites-available/tours3d /etc/nginx/sites-enabled/
sudo nginx -t && sudo nginx -s reload
```

### 8. Build the frontend

```bash
cd apps/web
pnpm build
sudo cp -r dist/* /var/www/tours3d/
```

---

## Local Development

```bash
# Terminal 1 — API
cd apps/api
pnpm dev

# Terminal 2 — Frontend
cd apps/web
pnpm dev
```

API runs at `http://localhost:3001`, frontend at `http://localhost:5173`.

---

## Basic Usage

### Upload a 360° photo (weeks 1–2, no auth yet)

```bash
# Create a tour
curl -X POST http://localhost:3001/api/tours \
  -H "Content-Type: application/json" \
  -d '{"title": "My House"}'

# Upload a panorama
curl -X POST http://localhost:3001/api/upload \
  -F "file=@photo360.jpg" \
  -F "tourId=<tour_id>" \
  -F "sceneId=<scene_id>"
```

### View the tour

```
https://tours3d.adsr64.qzz.io/tour/<tour_id>
```

---

## API Reference

```
POST   /api/auth/register          Register a new user
POST   /api/auth/login             Login → JWT

GET    /api/tours                  List your tours (JWT required)
POST   /api/tours                  Create a tour
GET    /api/tours/:id              Full tour with scenes and hotspots
PATCH  /api/tours/:id              Update title or default scene

POST   /api/tours/:id/scenes       Add a scene to a tour
POST   /api/upload                 Upload panorama (Sharp processes inline)

POST   /api/scenes/:id/hotspots    Create a hotspot
PATCH  /api/hotspots/:id           Update a hotspot
DELETE /api/hotspots/:id           Delete a hotspot

GET    /api/public/:id             Published tour (no auth, Valkey cached)
```

---

## Image Processing

Sharp runs **synchronously inside the API process**. For the MVP with low traffic this is fine. An async BullMQ worker will be added in V2.

For each uploaded panorama, three files are generated and stored in MinIO:

```
tours3d/              ← MinIO bucket
└── {tour_id}/
    └── {scene_id}/
        ├── original.jpg     ← original upload
        ├── preview.webp     ← 512 × 256 px  (immediate blur-up in viewer)
        └── full.webp        ← 4096 × 2048 px (high quality)
```

Assets are served via **MinIO presigned URLs** proxied through Nginx. Cloudflare caches them at the edge on first access.

---

## Storage — Why MinIO

MinIO is included from the start for a few practical reasons:

- **S3-compatible API** — swapping to any S3-compatible provider later (Backblaze, Cloudflare R2, AWS) requires zero code changes, only env vars
- **Built-in bucket management** — easier to browse, delete, and manage assets than raw filesystem
- **Presigned URLs** — assets are served with time-limited URLs, no direct filesystem exposure
- **Separation of concerns** — the API doesn't need to know where files live on disk

RAM overhead is ~300 MB idle, which fits comfortably in the available headroom.

---

## Database

```sql
users       → id, email, password_hash, created_at
tours       → id, owner_id, title, published, default_scene_id
scenes      → id, tour_id, title, status, preview_path, full_path, order_index
hotspots    → id, scene_id, yaw, pitch, label, target_scene_id
```

Full schema in `infra/db/schema.sql`.

---

## Infrastructure

| Service | RAM idle | Notes |
|---|---|---|
| tour-api | ~150 MB | Peaks ~600 MB during Sharp processing |
| minio | ~300 MB | Object storage |
| PostgreSQL | already running | Shared with existing stack |
| Valkey | already running | Shared with existing stack |
| **Total new** | **~450 MB** | Comfortable within available headroom |

---

## Docker Compose — New Services

```yaml
services:

  tour-api:
    build: ../apps/api
    environment:
      DATABASE_URL: postgresql://...
      VALKEY_URL: redis://valkey:6379
      MINIO_ENDPOINT: minio
    networks:
      - darsy_network
    deploy:
      resources:
        limits:
          memory: 512M

  minio:
    image: minio/minio:latest
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: ${MINIO_ACCESS_KEY}
      MINIO_ROOT_PASSWORD: ${MINIO_SECRET_KEY}
    volumes:
      - minio_data:/data
    ports:
      - "9000:9000"   # API
      - "9001:9001"   # Console (close this port in production)
    networks:
      - darsy_network
    deploy:
      resources:
        limits:
          memory: 512M

volumes:
  minio_data:
```

---

## Roadmap

The MVP covers the first 4 weeks. Everything below comes later, only if users ask for it:

- [ ] Async worker with BullMQ (unblock the API during processing)
- [ ] 3D model support (.glb) with React Three Fiber
- [ ] Info hotspots (text, image)
- [ ] `<iframe>` embed
- [ ] Per-scene visit analytics
- [ ] Real-time collaboration (WebSocket + Valkey pub/sub)
- [ ] OAuth (Google, GitHub)

---

## License

MIT
import { useState, useRef } from 'react'
import { ReactPhotoSphereViewer } from 'react-photo-sphere-viewer'

export default function App() {
  const [uploading, setUploading]   = useState(false)
  const [progress,  setProgress]    = useState(0)
  const [scene,     setScene]       = useState(null)
  const [error,     setError]       = useState(null)
  const inputRef = useRef(null)

  async function handleUpload(e) {
    const file = e.target.files?.[0]
    if (!file) return

    setUploading(true)
    setProgress(0)
    setError(null)

    const formData = new FormData()
    formData.append('file', file)

    const xhr = new XMLHttpRequest()

    xhr.upload.onprogress = (ev) => {
      if (ev.lengthComputable)
        setProgress(Math.round((ev.loaded / ev.total) * 100))
    }

    xhr.onload = () => {
      if (xhr.status === 200) {
        const data = JSON.parse(xhr.responseText)
        setScene(data)
      } else {
        setError('Upload failed — check the API logs')
      }
      setUploading(false)
    }

    xhr.onerror = () => {
      setError('Network error')
      setUploading(false)
    }

    xhr.open('POST', '/api/upload')
    xhr.send(formData)
  }

  // ── Viewer ─────────────────────────────────────────────────
  if (scene) {
    return (
      <div style={{ width: '100vw', height: '100vh' }}>
        <ReactPhotoSphereViewer
          src={scene.fullUrl}
          smallPanorama={scene.previewUrl}
          height="100vh"
          width="100%"
        />
        <button
          onClick={() => { setScene(null); setProgress(0) }}
          style={styles.backBtn}
        >
          ← Upload another
        </button>
      </div>
    )
  }

  // ── Upload form ────────────────────────────────────────────
  return (
    <div style={styles.page}>
      <div style={styles.card}>
        <div style={styles.title}>tours3d</div>
        <div style={styles.sub}>Upload a 360° panorama to get started</div>

        <div
          style={styles.dropzone}
          onClick={() => inputRef.current?.click()}
          onDragOver={e => e.preventDefault()}
          onDrop={e => {
            e.preventDefault()
            const file = e.dataTransfer.files?.[0]
            if (file) handleUpload({ target: { files: [file] } })
          }}
        >
          {uploading ? (
            <div>
              <div style={styles.progressBar}>
                <div style={{ ...styles.progressFill, width: `${progress}%` }} />
              </div>
              <div style={styles.progressLabel}>{progress}% — processing with Sharp...</div>
            </div>
          ) : (
            <>
              <div style={styles.icon}>⊕</div>
              <div style={styles.dropLabel}>Click or drag a .jpg / .png panorama here</div>
              <div style={styles.dropSub}>Equirectangular 2:1 recommended</div>
            </>
          )}
        </div>

        <input
          ref={inputRef}
          type="file"
          accept="image/*"
          style={{ display: 'none' }}
          onChange={handleUpload}
        />

        {error && <div style={styles.error}>{error}</div>}
      </div>
    </div>
  )
}

const styles = {
  page: {
    minHeight: '100vh',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    background: '#07090e',
    fontFamily: "'IBM Plex Mono', monospace",
    padding: 24,
  },
  card: {
    width: '100%',
    maxWidth: 480,
    display: 'flex',
    flexDirection: 'column',
    gap: 16,
  },
  title: {
    fontSize: 28,
    fontWeight: 800,
    color: '#dde4f0',
    letterSpacing: -1,
    fontFamily: 'sans-serif',
  },
  sub: {
    fontSize: 12,
    color: '#3d4a60',
    marginBottom: 8,
  },
  dropzone: {
    border: '1px dashed #1c2230',
    borderRadius: 10,
    padding: '48px 24px',
    textAlign: 'center',
    cursor: 'pointer',
    background: '#0c0f18',
    transition: 'border-color 0.15s',
  },
  icon: {
    fontSize: 32,
    color: '#22d3ee',
    marginBottom: 12,
  },
  dropLabel: {
    fontSize: 13,
    color: '#8a98b4',
    marginBottom: 6,
  },
  dropSub: {
    fontSize: 11,
    color: '#3d4a60',
  },
  progressBar: {
    height: 4,
    background: '#1c2230',
    borderRadius: 4,
    overflow: 'hidden',
    marginBottom: 12,
  },
  progressFill: {
    height: '100%',
    background: '#22d3ee',
    borderRadius: 4,
    transition: 'width 0.2s',
  },
  progressLabel: {
    fontSize: 11,
    color: '#3d4a60',
  },
  error: {
    fontSize: 11,
    color: '#ef4444',
    padding: '8px 12px',
    background: '#ef444411',
    border: '1px solid #ef444422',
    borderRadius: 6,
  },
  backBtn: {
    position: 'fixed',
    top: 16,
    left: 16,
    zIndex: 100,
    background: '#07090ecc',
    border: '1px solid #1c2230',
    borderRadius: 6,
    color: '#8a98b4',
    fontSize: 12,
    padding: '8px 14px',
    cursor: 'pointer',
    fontFamily: "'IBM Plex Mono', monospace",
    backdropFilter: 'blur(8px)',
  },
}

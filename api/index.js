const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { exec } = require('child_process');

const app = express();
app.use(cors());
app.use(express.json({ limit: '10mb' })); // allow reasonably large JSON payloads

// Simple request logger
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
  next();
});

// Path to JSON data
const DATA_PATH = path.join(__dirname, '..', 'assets', 'data', 'pbm_materi.json');
const DATA_DIR = path.dirname(DATA_PATH);
if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });

// Optional secrets to protect dev endpoints
const RELOAD_SECRET = process.env.RELOAD_SECRET || null;
const UPLOAD_SECRET = process.env.UPLOAD_SECRET || null;

let db = { judul_materi: '', rangkuman_topik: [] };

function loadData() {
  try {
    if (!fs.existsSync(DATA_PATH)) {
      console.warn('Data file not found, creating empty JSON at', DATA_PATH);
      fs.writeFileSync(DATA_PATH, JSON.stringify(db, null, 2));
    }
    const raw = fs.readFileSync(DATA_PATH, 'utf8');
    db = JSON.parse(raw);
    console.log('Loaded topics:', db.rangkuman_topik?.length ?? 0);
  } catch (err) {
    console.error('Failed to load JSON:', err);
    db = { judul_materi: 'empty', rangkuman_topik: [] };
  }
}

loadData();

// GET /materi - return full JSON
app.get('/materi', (req, res) => res.json(db));

// GET /pretty - HTML view
app.get('/pretty', (req, res) => {
  const pretty = JSON.stringify(db, null, 2);
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(`<html><body><pre style="white-space:pre-wrap;">${pretty.replace(/</g, '&lt;')}</pre></body></html>`);
});

// GET /topics - list id + title
app.get('/topics', (req, res) => {
  const list = (db.rangkuman_topik || []).map(t => ({ topik_id: t.topik_id, judul_topik: t.judul_topik }));
  res.json(list);
});

// GET /topics_index - lightweight paginated index (id + title)
// Query params: page (1-based), per_page (default 20)
app.get('/topics_index', (req, res) => {
  const page = Math.max(1, parseInt(req.query.page || '1'));
  const perPage = Math.max(1, Math.min(100, parseInt(req.query.per_page || '20')));
  const all = (db.rangkuman_topik || []).map(t => ({ topik_id: t.topik_id, judul_topik: t.judul_topik }));
  const total = all.length;
  const totalPages = Math.max(1, Math.ceil(total / perPage));
  const start = (page - 1) * perPage;
  const items = all.slice(start, start + perPage);
  res.json({
    page,
    per_page: perPage,
    total,
    total_pages: totalPages,
    items,
  });
});

// GET /topic/:id - detail
app.get('/topic/:id', (req, res) => {
  const id = req.params.id;
  const topic = (db.rangkuman_topik || []).find(t => String(t.topik_id) === String(id));
  if (!topic) return res.status(404).json({ error: 'Topic not found' });
  res.json(topic);
});

// GET /search?q=...
app.get('/search', (req, res) => {
  const q = (req.query.q || '').toString().trim().toLowerCase();
  if (!q) return res.json({ query: q, results: [] });
  const results = [];
  (db.rangkuman_topik || []).forEach(topic => {
    if ((topic.judul_topik || '').toString().toLowerCase().includes(q)) {
      results.push({ topik_id: topic.topik_id, judul_topik: topic.judul_topik, match_in: 'judul_topik' });
      return;
    }
    if (Array.isArray(topic.konten)) {
      for (const k of topic.konten) {
        const block = JSON.stringify(k).toLowerCase();
        if (block.includes(q)) {
          results.push({ topik_id: topic.topik_id, judul_topik: topic.judul_topik, match_in: 'konten' });
          break;
        }
      }
    }
    if (Array.isArray(topic.kuis)) {
      for (const qq of topic.kuis) {
        if (qq.pertanyaan?.toLowerCase().includes(q)) {
          results.push({ topik_id: topic.topik_id, judul_topik: topic.judul_topik, match_in: 'kuis_pertanyaan' });
          break;
        }
        for (const p of qq.pilihan || []) {
          if (p?.toLowerCase().includes(q)) {
            results.push({ topik_id: topic.topik_id, judul_topik: topic.judul_topik, match_in: 'kuis_pilihan' });
            break;
          }
        }
      }
    }
  });
  res.json({ query: q, results });
});

// GET /topics/:id - alias for backwards compatibility
app.get('/topics/:id', (req, res) => {
  const id = req.params.id;
  const topic = (db.rangkuman_topik || []).find(t => String(t.topik_id) === String(id));
  if (!topic) return res.status(404).json({ error: 'Topic not found' });
  res.json(topic);
});

// POST /topics - add a new topic (requires UPLOAD_SECRET if configured)
app.post('/topics', (req, res) => {
  if (UPLOAD_SECRET && String(req.query.secret || '') !== String(UPLOAD_SECRET)) {
    return res.status(403).json({ error: 'Forbidden. Missing or invalid secret.' });
  }
  const incoming = req.body;
  if (!incoming || typeof incoming !== 'object') return res.status(400).json({ error: 'Invalid JSON body' });
  if (!incoming.topik_id || !incoming.judul_topik) return res.status(400).json({ error: 'Missing topik_id or judul_topik' });

  // prevent duplicate
  const exists = (db.rangkuman_topik || []).some(t => String(t.topik_id) === String(incoming.topik_id));
  if (exists) return res.status(409).json({ error: 'Topic with this id already exists' });

  db.rangkuman_topik = db.rangkuman_topik || [];
  db.rangkuman_topik.push(incoming);
  try {
    fs.writeFileSync(DATA_PATH, JSON.stringify(db, null, 2), 'utf8');
    loadData();
    res.json({ ok: true, message: 'Topic added', topic: incoming });
  } catch (err) {
    console.error('Failed to add topic:', err);
    res.status(500).json({ error: 'Failed to save topic' });
  }
});

// PUT /topic/:id - update existing topic (requires UPLOAD_SECRET if configured)
app.put('/topic/:id', (req, res) => {
  if (UPLOAD_SECRET && String(req.query.secret || '') !== String(UPLOAD_SECRET)) {
    return res.status(403).json({ error: 'Forbidden. Missing or invalid secret.' });
  }
  const id = req.params.id;
  const incoming = req.body;
  if (!incoming || typeof incoming !== 'object') return res.status(400).json({ error: 'Invalid JSON body' });
  const idx = (db.rangkuman_topik || []).findIndex(t => String(t.topik_id) === String(id));
  if (idx === -1) return res.status(404).json({ error: 'Topic not found' });

  const updated = { ...db.rangkuman_topik[idx], ...incoming };
  db.rangkuman_topik[idx] = updated;
  try {
    fs.writeFileSync(DATA_PATH, JSON.stringify(db, null, 2), 'utf8');
    loadData();
    res.json({ ok: true, message: 'Topic updated', topic: updated });
  } catch (err) {
    console.error('Failed to update topic:', err);
    res.status(500).json({ error: 'Failed to save topic' });
  }
});

// DELETE /topic/:id - remove a topic (requires UPLOAD_SECRET if configured)
app.delete('/topic/:id', (req, res) => {
  if (UPLOAD_SECRET && String(req.query.secret || '') !== String(UPLOAD_SECRET)) {
    return res.status(403).json({ error: 'Forbidden. Missing or invalid secret.' });
  }
  const id = req.params.id;
  const before = (db.rangkuman_topik || []).length;
  db.rangkuman_topik = (db.rangkuman_topik || []).filter(t => String(t.topik_id) !== String(id));
  if (db.rangkuman_topik.length === before) return res.status(404).json({ error: 'Topic not found' });
  try {
    fs.writeFileSync(DATA_PATH, JSON.stringify(db, null, 2), 'utf8');
    loadData();
    res.json({ ok: true, message: 'Topic deleted', topics: db.rangkuman_topik.length });
  } catch (err) {
    console.error('Failed to delete topic:', err);
    res.status(500).json({ error: 'Failed to delete topic' });
  }
});

// POST /upload - save new JSON (optional UPLOAD_SECRET)
app.post('/upload', (req, res) => {
  if (UPLOAD_SECRET && String(req.query.secret || '') !== String(UPLOAD_SECRET)) {
    return res.status(403).json({ error: 'Forbidden. Missing or invalid secret.' });
  }
  const incoming = req.body;
  if (!incoming || typeof incoming !== 'object') return res.status(400).json({ error: 'Invalid JSON body' });
  // basic validation
  if (!incoming.judul_materi || !Array.isArray(incoming.rangkuman_topik)) {
    return res.status(400).json({ error: 'Invalid structure: expected { judul_materi, rangkuman_topik[] }' });
  }
  try {
    fs.writeFileSync(DATA_PATH, JSON.stringify(incoming, null, 2), 'utf8');
    loadData();
    res.json({ ok: true, message: 'JSON uploaded successfully', topics: db.rangkuman_topik?.length ?? 0 });
  } catch (err) {
    console.error('UPLOAD ERROR:', err);
    res.status(500).json({ error: 'Failed to save JSON' });
  }
});

// GET /reload - reload from disk (optional RELOAD_SECRET)
app.get('/reload', (req, res) => {
  if (RELOAD_SECRET && String(req.query.secret || '') !== String(RELOAD_SECRET)) {
    return res.status(403).json({ error: 'Forbidden. Missing or invalid secret.' });
  }
  loadData();
  res.json({ ok: true, message: 'Reloaded', topics: db.rangkuman_topik?.length ?? 0 });
});

// Home / docs
app.get('/', (req, res) => {
  const host = req.headers.host || `localhost:${PORT}`;
  const base = `${req.protocol}://${host}`;
  const protectionInfo = [];
  if (RELOAD_SECRET) protectionInfo.push('Reload is protected by RELOAD_SECRET');
  if (UPLOAD_SECRET) protectionInfo.push('Upload is protected by UPLOAD_SECRET');
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(`<!doctype html><html><body><h2>PBM Materi API</h2><ul>
    <li><a href="${base}/pretty">/pretty</a></li>
    <li><a href="${base}/materi">/materi</a></li>
    <li><a href="${base}/topics">/topics</a></li>
    <li>/topic/:id</li>
    <li><a href="${base}/search?q=test">/search?q=test</a></li>
    <li><a href="${base}/reload">/reload</a></li>
    ${protectionInfo.map(i => `<li style="color:darkred">${i}</li>`).join('')}
    <li>POST /upload</li>
  </ul></body></html>`);
});

// health
app.get('/health', (req, res) => res.json({ ok: true, uptime: process.uptime() }));

// START SERVER
const PORT = process.env.PORT || 3333;
app.listen(PORT, '0.0.0.0', async () => {
  console.log(`PBM API running (bound to 0.0.0.0) on port ${PORT}`);
  console.log('JSON Path:', DATA_PATH);
  const nets = os.networkInterfaces();
  Object.keys(nets).forEach(ifname => {
    for (const net of nets[ifname]) {
      if (net.family === 'IPv4' && !net.internal) {
        console.log(` - http://${net.address}:${PORT}`);
      }
    }
  });
  const localURL = `http://localhost:${PORT}`;
  console.log(` - (local) ${localURL}`);
  // Try to open default browser in a cross-platform way without extra deps
  try {
    const platform = process.platform;
    if (platform === 'win32') {
      // start "" "url"
      exec(`start "" "${localURL}"`);
    } else if (platform === 'darwin') {
      exec(`open "${localURL}"`);
    } else {
      exec(`xdg-open "${localURL}"`);
    }
    console.log('Attempted to open browser:', localURL);
  } catch (err) {
    console.error('Failed to open browser:', err);
  }
});

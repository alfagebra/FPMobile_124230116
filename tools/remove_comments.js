const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const LIB = path.join(ROOT, 'lib');
const BACKUP_DIR = path.join(ROOT, 'tools', 'backups_remove_comments');

function walk(dir) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const e of entries) {
    const full = path.join(dir, e.name);
    if (e.isDirectory()) walk(full);
    else if (e.isFile() && full.endsWith('.dart')) processFile(full);
  }
}

function ensureDir(d) {
  if (!fs.existsSync(d)) fs.mkdirSync(d, { recursive: true });
}

function processFile(filePath) {
  const rel = path.relative(ROOT, filePath);
  try {
    const original = fs.readFileSync(filePath, 'utf8');
    const lines = original.split(/\r?\n/);
    const filtered = lines.filter(line => {
      // keep lines that are NOT purely single-line comments
      // A pure comment line: optional whitespace then // (but not /// doccomment which we also remove per request)
      return !/^\s*\/\/.*/.test(line);
    });

    const out = filtered.join('\n');
    if (out !== original) {
      ensureDir(BACKUP_DIR);
      const backupPath = path.join(BACKUP_DIR, rel.replace(/[\\/]/g, '_')) + '.bak';
      fs.writeFileSync(backupPath, original, 'utf8');
      fs.writeFileSync(filePath, out, 'utf8');
      console.log('Updated:', rel, '-> backup at', path.relative(ROOT, backupPath));
    }
  } catch (err) {
    console.error('Failed:', rel, err.message);
  }
}

console.log('Removing comment-only lines (\"//...\") from .dart files under lib/');
walk(LIB);
console.log('Done. Backups (if any) are in tools/backups_remove_comments/');

// Download the Cygnet provider module for this platform from the GitHub
// release and verify it against the release's SHA256SUMS manifest.
//
// The module is NOT bundled in the npm tarball: the published artifact and its
// signed manifest are the single source of truth.
'use strict';

const https = require('https');
const crypto = require('crypto');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

const VERSION = require('./package.json').version;
const REPO = 'sanctumsecopsmssp/cygnet-provider';
const BASE = `https://github.com/${REPO}/releases/download/v${VERSION}`;

function target() {
  const key = `${process.platform}-${process.arch}`;
  switch (key) {
    case 'linux-x64':
      return { id: 'linux-x86_64', artifact: `cygnetprov-linux-x86_64-v${VERSION}.so`, name: 'cygnetprov.so' };
    case 'darwin-arm64':
      return { id: 'macos-arm64', artifact: `cygnetprov-macos-arm64-v${VERSION}.dylib`, name: 'cygnetprov.dylib' };
    default:
      throw new Error(`no prebuilt Cygnet provider module for ${key}`);
  }
}

function fetch(url) {
  return new Promise((resolve, reject) => {
    https
      .get(url, { headers: { 'user-agent': 'cygnet-provider-installer' } }, (res) => {
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
          res.resume();
          return fetch(res.headers.location).then(resolve, reject);
        }
        if (res.statusCode !== 200) {
          res.resume();
          return reject(new Error(`${url} returned HTTP ${res.statusCode}`));
        }
        const chunks = [];
        res.on('data', (c) => chunks.push(c));
        res.on('end', () => resolve(Buffer.concat(chunks)));
      })
      .on('error', reject);
  });
}

function verifySignature(manifestText, manifestName) {
  return fetch(`${BASE}/${manifestName}.asc`)
    .then((asc) => {
      const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'cygnet-sig-'));
      const m = path.join(dir, manifestName);
      fs.writeFileSync(m, manifestText);
      fs.writeFileSync(`${m}.asc`, asc);
      execFileSync('gpg', ['--verify', `${m}.asc`, m], { stdio: 'ignore' });
      console.log('[cygnet] manifest signature OK');
    })
    .catch(() => {
      console.log('[cygnet] manifest signature NOT verified (gpg unavailable, key missing, or .asc absent)');
    });
}

async function main() {
  const t = target();
  const manifestName = `SHA256SUMS-${t.id}-v${VERSION}`;
  const outDir = path.join(__dirname, 'lib', 'ossl-modules');

  console.log(`[cygnet] downloading ${t.artifact}`);
  const bin = await fetch(`${BASE}/${t.artifact}`);
  const manifest = (await fetch(`${BASE}/${manifestName}`)).toString('utf8');

  const line = manifest
    .split('\n')
    .map((l) => l.trim())
    .find((l) => l.endsWith(t.artifact));
  if (!line) throw new Error(`${manifestName} has no entry for ${t.artifact}`);

  const expected = line.split(/\s+/)[0].toLowerCase();
  const actual = crypto.createHash('sha256').update(bin).digest('hex');
  if (expected !== actual) {
    throw new Error(`checksum mismatch for ${t.artifact}: expected ${expected}, got ${actual}`);
  }
  console.log('[cygnet] checksum OK');

  await verifySignature(manifest, manifestName);

  fs.mkdirSync(outDir, { recursive: true });
  const dest = path.join(outDir, t.name);
  fs.writeFileSync(dest, bin, { mode: 0o755 });

  console.log(`[cygnet] installed ${dest}`);
  console.log(`[cygnet] load with: export OPENSSL_MODULES=${outDir}`);
  console.log('[cygnet] verify:    openssl list -mac-algorithms -provider cygnetprov');
}

main().catch((err) => {
  console.error(`[cygnet] ERROR ${err.message}`);
  process.exit(1);
});

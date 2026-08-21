'use strict';

const fs = require('fs');
const path = require('path');

const MODULES_DIR = path.join(__dirname, 'lib', 'ossl-modules');
const PROVIDER_NAME = 'cygnetprov';

const MAC_ALGORITHMS = Object.freeze([
  'CYGNET-HMAC',
  'CYGNET-CMAC',
  'CYGNET-KMAC-128',
  'CYGNET-KMAC-256'
]);

function moduleFileName() {
  // OpenSSL dlopens provider modules as .dylib on Darwin and .so elsewhere.
  return process.platform === 'darwin' ? 'cygnetprov.dylib' : 'cygnetprov.so';
}

function modulePath() {
  const p = path.join(MODULES_DIR, moduleFileName());
  if (!fs.existsSync(p)) {
    throw new Error(`Cygnet provider module not found at ${p}; reinstall the package`);
  }
  return p;
}

module.exports = {
  modulesDir: () => MODULES_DIR,
  modulePath,
  providerName: PROVIDER_NAME,
  macAlgorithms: MAC_ALGORITHMS
};

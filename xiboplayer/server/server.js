#!/usr/bin/env node
/**
 * Xibo Player - Local Server for Chromium Kiosk
 *
 * Serves the bundled PWA player and proxies CMS API requests.
 * Uses @xiboplayer/proxy for all proxy routes and static serving.
 *
 * Installed by xiboplayer-chromium RPM/DEB at /usr/libexec/xiboplayer-chromium/server/
 *
 * Usage:
 *   node server.js [--port=8765] [--pwa-path=/path/to/pwa/dist]
 */

const fs = require('fs');
const os = require('os');
const path = require('path');

const APP_VERSION = '0.2.0';

// Parse CLI args
const args = process.argv.slice(2);
const portArg = args.find(a => a.startsWith('--port='));
const pwaArg = args.find(a => a.startsWith('--pwa-path='));
const serverPort = portArg ? parseInt(portArg.split('=')[1], 10) : 8765;
const pwaPath = pwaArg
  ? pwaArg.split('=')[1]
  : path.join(__dirname, 'node_modules/@xiboplayer/pwa/dist');

// Read CMS config from config.json (if present) for setup-free kiosk deployment
const configDir = process.env.XDG_CONFIG_HOME || path.join(os.homedir(), '.config');
const configPath = path.join(configDir, 'xiboplayer', 'chromium', 'config.json');
let cmsConfig;
try {
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  if (config.cmsAddress) {
    cmsConfig = {
      cmsAddress: config.cmsAddress,
      cmsKey: config.cmsKey || '',
      displayName: config.displayName || '',
    };
    console.log(`[Server] CMS config loaded from ${configPath}: ${cmsConfig.cmsAddress}`);
  }
} catch (err) {
  if (err.code !== 'ENOENT') {
    console.warn(`[Server] Failed to read config: ${err.message}`);
  }
}

console.log(`[Server] PWA path: ${pwaPath}`);
console.log(`[Server] Port: ${serverPort}`);

import('@xiboplayer/proxy').then(({ startServer }) => {
  return startServer({ port: serverPort, pwaPath, appVersion: APP_VERSION, cmsConfig });
}).catch((err) => {
  console.error('[Server] Failed to start:', err.message);
  process.exit(1);
});

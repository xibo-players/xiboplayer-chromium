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

console.log(`[Server] PWA path: ${pwaPath}`);
console.log(`[Server] Port: ${serverPort}`);

import('@xiboplayer/proxy').then(({ startServer }) => {
  return startServer({ port: serverPort, pwaPath, appVersion: APP_VERSION });
}).catch((err) => {
  console.error('[Server] Failed to start:', err.message);
  process.exit(1);
});

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
 *   node server.js [--port=8766] [--pwa-path=/path/to/pwa/dist]
 */

const fs = require('fs');
const os = require('os');
const path = require('path');

const APP_VERSION = '0.2.0';

// Parse CLI args
const args = process.argv.slice(2);
const portArg = args.find(a => a.startsWith('--port='));
const pwaArg = args.find(a => a.startsWith('--pwa-path='));
// Port priority: CLI --port > config.json serverPort > default 8766
let defaultPort = 8766;
const pwaPath = pwaArg
  ? pwaArg.split('=')[1]
  : path.join(__dirname, 'node_modules/@xiboplayer/pwa/dist');

// Read config.json (if present) for CMS config and serverPort
const configDir = process.env.XDG_CONFIG_HOME || path.join(os.homedir(), '.config');
const configPath = path.join(configDir, 'xiboplayer', 'chromium', 'config.json');
let rawConfig;
try {
  rawConfig = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  if (rawConfig.serverPort) defaultPort = rawConfig.serverPort;
  if (rawConfig.cmsUrl) {
    console.log(`[Server] CMS config loaded from ${configPath}: ${rawConfig.cmsUrl}`);
  }
} catch (err) {
  if (err.code !== 'ENOENT') {
    console.warn(`[Server] Failed to read config: ${err.message}`);
  }
}

const serverPort = portArg ? parseInt(portArg.split('=')[1], 10) : defaultPort;

// XDG-compliant data directory for DiskCache media storage
const dataHome = process.env.XDG_DATA_HOME || path.join(os.homedir(), '.local', 'share');
const dataDir = path.join(dataHome, 'xiboplayer', 'chromium');

console.log(`[Server] PWA path: ${pwaPath}`);
console.log(`[Server] Port: ${serverPort}`);
console.log(`[Server] Data dir: ${dataDir}`);

// Import SDK modules (ESM) and start server
Promise.all([
  import('@xiboplayer/proxy'),
  import('@xiboplayer/utils/config'),
]).then(([{ startServer }, { extractPwaConfig }]) => {
  // Extract PWA config using SDK's deny-list filter (Chromium-specific extras excluded)
  const pwaConfig = rawConfig ? extractPwaConfig(rawConfig, ['browser', 'extraBrowserFlags']) : undefined;
  return startServer({ port: serverPort, pwaPath, appVersion: APP_VERSION, pwaConfig, configFilePath: configPath, dataDir });
}).catch((err) => {
  console.error('[Server] Failed to start:', err.message);
  process.exit(1);
});

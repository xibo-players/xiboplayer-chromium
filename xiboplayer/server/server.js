#!/usr/bin/env node
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2024-2026 Pau Aliagas <linuxnow@gmail.com>
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
const instanceArg = args.find(a => a.startsWith('--instance='));
const instanceName = instanceArg ? instanceArg.split('=')[1] : '';
const instanceDir = instanceName ? `chromium-${instanceName}` : 'chromium';
// Port priority: CLI --port > config.json serverPort > default 8766
let defaultPort = 8766;
const pwaPath = pwaArg
  ? pwaArg.split('=')[1]
  : path.join(__dirname, 'node_modules/@xiboplayer/pwa/dist');

// Read config.json (if present) for CMS config and serverPort
const configDir = process.env.XDG_CONFIG_HOME || path.join(os.homedir(), '.config');
const configPath = path.join(configDir, 'xiboplayer', instanceDir, 'config.json');
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

// XDG-compliant data directory for ContentStore media cache.
// Shared across all instances on the same machine — same CMS content is
// stored once, not per-instance. Safe: ContentStore uses atomic writes.
// Per-CMS isolation is handled by the {cmsId} subdirectory inside dataDir.
const dataHome = process.env.XDG_DATA_HOME || path.join(os.homedir(), '.local', 'share');
const dataDir = path.join(dataHome, 'xiboplayer', 'shared');

console.log(`[Server] PWA path: ${pwaPath}`);
console.log(`[Server] Port: ${serverPort}`);
console.log(`[Server] Data dir: ${dataDir}`);

// Import SDK modules (ESM) and start server
Promise.all([
  import('@xiboplayer/proxy'),
  import('@xiboplayer/utils/config'),
]).then(([{ startServer }, { extractPwaConfig, computeCmsId }]) => {
  // Extract PWA config using SDK's deny-list filter (Chromium-specific extras excluded)
  const pwaConfig = rawConfig ? extractPwaConfig(rawConfig, ['browser', 'extraBrowserFlags', 'allowShellCommands']) : undefined;

  // Inject CMS ID for per-CMS cache namespacing
  if (pwaConfig && pwaConfig.cmsUrl) {
    const cmsId = computeCmsId(pwaConfig.cmsUrl);
    if (cmsId) pwaConfig.cmsId = cmsId;
  }
  const allowShellCommands = !!(rawConfig && rawConfig.allowShellCommands);
  const listenAddress = rawConfig?.listenAddress || (rawConfig?.sync?.isLead ? '0.0.0.0' : 'localhost');
  const syncSecret = rawConfig?.sync?.cmsKey || rawConfig?.cmsKey;
  const syncGroupId = rawConfig?.sync?.syncGroupId;
  const isLead = rawConfig?.sync?.isLead;
  const displayId = rawConfig?.hardwareKey;
  return startServer({ port: serverPort, listenAddress, pwaPath, appVersion: APP_VERSION, pwaConfig, configFilePath: configPath, dataDir, allowShellCommands, syncSecret, syncGroupId, isLead, displayId });
}).catch((err) => {
  console.error('[Server] Failed to start:', err.message);
  process.exit(1);
});

#!/usr/bin/env node
/**
 * Local CORS proxy for Payout Renotify.
 *
 * The payout scheduler API is only reachable on VPN and does not allow browser
 * cross-origin requests. This proxy runs on your machine (like the Python tool)
 * and forwards requests to the scheduler.
 *
 * Usage: node tools/renotify-proxy/server.js
 */

const http = require('http');
const https = require('https');

const PORT = 8747;
const HOST = '127.0.0.1';

const TARGETS = {
  staging: 'https://payout-scheduler.codapay.net/backoffice/notify',
  production: 'https://payout-scheduler.codainfra.net/backoffice/notify',
};

function setCors(req, res) {
  const origin = req.headers.origin;
  if (origin) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Vary', 'Origin');
  } else {
    res.setHeader('Access-Control-Allow-Origin', '*');
  }
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Access-Control-Allow-Private-Network', 'true');
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', (chunk) => {
      body += chunk;
    });
    req.on('end', () => resolve(body));
    req.on('error', reject);
  });
}

function forwardToScheduler(targetUrl, payoutId) {
  return new Promise((resolve, reject) => {
    const url = new URL(targetUrl);
    const payload = JSON.stringify({payoutIds: [payoutId]});

    const options = {
      hostname: url.hostname,
      port: url.port || 443,
      path: url.pathname,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload),
      },
    };

    const proxyReq = https.request(options, (proxyRes) => {
      let data = '';
      proxyRes.on('data', (chunk) => {
        data += chunk;
      });
      proxyRes.on('end', () => {
        resolve({
          statusCode: proxyRes.statusCode || 502,
          body: data,
          contentType: proxyRes.headers['content-type'] || 'application/json',
        });
      });
    });

    proxyReq.on('error', (error) => {
      reject(error);
    });

    proxyReq.write(payload);
    proxyReq.end();
  });
}

const server = http.createServer(async (req, res) => {
  setCors(req, res);

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  if (req.method === 'GET' && req.url === '/health') {
    res.writeHead(200, {'Content-Type': 'application/json'});
    res.end(JSON.stringify({ok: true}));
    return;
  }

  if (req.method !== 'POST' || req.url !== '/notify') {
    res.writeHead(404, {'Content-Type': 'application/json'});
    res.end(JSON.stringify({message: 'Not found'}));
    return;
  }

  try {
    const raw = await readBody(req);
    const {environment, payoutId} = JSON.parse(raw || '{}');

    if (!environment || !payoutId) {
      res.writeHead(400, {'Content-Type': 'application/json'});
      res.end(JSON.stringify({message: 'Missing environment or payoutId'}));
      return;
    }

    const targetUrl = TARGETS[environment];
    if (!targetUrl) {
      res.writeHead(400, {'Content-Type': 'application/json'});
      res.end(JSON.stringify({message: 'Invalid environment'}));
      return;
    }

    const upstream = await forwardToScheduler(targetUrl, payoutId);
    res.writeHead(upstream.statusCode, {'Content-Type': upstream.contentType});
    res.end(upstream.body);
  } catch (error) {
    res.writeHead(502, {'Content-Type': 'application/json'});
    res.end(
      JSON.stringify({
        message: 'Please connect to the VPN before using this tool.',
        error: error.message,
      }),
    );
  }
});

server.listen(PORT, HOST, () => {
  console.log(`Payout Renotify proxy listening on http://${HOST}:${PORT}`);
  console.log('Connect to VPN, then use Payout Renotify in PE Ops.');
});

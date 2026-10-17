'use strict';
const https = require('https');
const officialPrefix = 'https://github.com/WkJ01N/Orbit/releases/download/';
function getJson(url, redirects = 0) {
  if (redirects > 5 || !url.startsWith('https://')) return Promise.reject(new Error('Invalid release redirect'));
  return new Promise((resolve,reject) => {
    const request = https.get(url, { headers: { 'User-Agent':'Orbit-updates', Accept:'application/vnd.github+json' } }, (response) => {
      if ([301,302,303,307,308].includes(response.statusCode)) { response.resume(); getJson(new URL(response.headers.location,url).href, redirects+1).then(resolve,reject); return; }
      if (response.statusCode !== 200) { response.resume(); reject(new Error('GitHub metadata unavailable')); return; }
      let bytes = 0; const chunks = [];
      response.on('data', (chunk) => { bytes += chunk.length; if (bytes > 3*1024*1024) { response.destroy(); reject(new Error('Metadata too large')); } else chunks.push(chunk); });
      response.on('error',reject);
      response.on('end', () => { try { resolve(JSON.parse(Buffer.concat(chunks).toString('utf8'))); } catch(e) { reject(e); } });
    });
    request.setTimeout(10000, () => request.destroy(new Error('GitHub metadata timeout')));
    request.on('error',reject);
  });
}
async function latest(fetch = getJson) {
  const release = await fetch('https://api.github.com/repos/WkJ01N/Orbit/releases/latest');
  if (release.draft || release.prerelease || !/^v?\d+\.\d+\.\d+(\+\d+)?$/.test(release.tag_name)) throw new Error('No stable release');
  const asset = (release.assets || []).find((a) => a.name === 'update-manifest.json' && a.browser_download_url.startsWith(officialPrefix));
  if (asset) {
    try { release.orbitManifest = await fetch(asset.browser_download_url); } catch (_) { /* Digest may be supplied by the official asset API. */ }
  }
  release.assets = [...(release.assets || [])].sort((a, b) => Number(/-(?:android-)?(arm64-v8a|armeabi-v7a|x86_64)\.apk$/.test(a.name)) - Number(/-(?:android-)?(arm64-v8a|armeabi-v7a|x86_64)\.apk$/.test(b.name)));
  return release;
}
function stable(release) {
  return release && !release.draft && !release.prerelease && /^v?\d+\.\d+\.\d+(\+\d+)?$/.test(release.tag_name);
}
async function history(page = 1, fetch = getJson) {
  if (!Number.isInteger(page) || page < 1 || page > 1000) throw new Error('Invalid page');
  const releases = await fetch(`https://api.github.com/repos/WkJ01N/Orbit/releases?per_page=20&page=${page}`);
  if (!Array.isArray(releases)) throw new Error('Invalid releases');
  return { releases: releases.filter(stable), hasMore: releases.length >= 20 };
}
async function release(tag, fetch = getJson) {
  if (!/^v\d+\.\d+\.\d+$/.test(tag)) throw new Error('Invalid tag');
  // Reuse the existing stable-release validation and manifest hydration.
  return latest(async (url) => fetch(url.endsWith('/releases/latest') ? `https://api.github.com/repos/WkJ01N/Orbit/releases/tags/${tag}` : url));
}
module.exports = { latest, history, release };

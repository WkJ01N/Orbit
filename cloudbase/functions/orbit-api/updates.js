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
  return release;
}
module.exports = { latest };

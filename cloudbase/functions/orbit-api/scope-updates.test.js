'use strict';
const test=require('node:test');const assert=require('node:assert/strict');
const {visibleEntity}=require('./sync-visibility');const {normalize,effectiveInput}=require('./sync-policy');const {latest}=require('./updates');
test('old clients never receive settings; disabled categories never receive snapshots or deletes',()=>{
 assert.equal(visibleEntity({type:'settingGroup',id:'strong'},{}),false);
 assert.equal(visibleEntity({type:'settingGroup',id:'strong'},{supportsSettings:true,selection:{strong:false}}),false);
 assert.equal(visibleEntity({type:'courseSession',deleted:true},{selection:{courses:false}}),false);
 assert.equal(visibleEntity({type:'settingGroup',id:'strong'},{supportsSettings:true,selection:{strong:true}}),true);
});
test('shared policy overrides request scopes; full snapshot previews are read-only exceptions',()=>{
 const defaults=normalize();assert.equal(defaults.selection.strong,false);assert.equal(defaults.selection.courses,true);
 const policy=normalize({mode:'shared',selection:{deadlines:true},revision:2});
 assert.deepEqual(effectiveInput({selection:{courses:true}},policy).selection,policy.selection);
 assert.equal(effectiveInput({snapshot:true,previewAll:true,supportsSettings:true},policy).selection,undefined);
 assert.deepEqual(effectiveInput({previewAll:true,supportsSettings:true},policy).selection,policy.selection);
 assert.throws(()=>normalize({mode:'bad'}));
});
test('public update metadata is obtained from official stable GitHub releases only',async()=>{
 const calls=[];const payload={tag_name:'v1.5.3',draft:false,prerelease:false,assets:[{name:'update-manifest.json',browser_download_url:'https://github.com/WkJ01N/Orbit/releases/download/v1.5.3/update-manifest.json'}]};
 const release=await latest(async(url)=>{calls.push(url);return calls.length===1?{...payload}:{version:'1.5.3',buildNumber:25};});
 assert.equal(release.orbitManifest.buildNumber,25);assert.ok(calls[0].startsWith('https://api.github.com/'));
 await assert.rejects(latest(async()=>({...payload,prerelease:true})));
 let count=0;await latest(async()=>{count++;return{...payload,assets:[{name:'update-manifest.json',browser_download_url:'https://mirror.invalid/checksum'}]};});assert.equal(count,1);
});

test('universal APK comes first for clients without ABI selection', async () => {
 const release = await latest(async () => ({tag_name:'v1.5.6', assets:[
  {name:'orbit-v1.5.6-android-arm64-v8a.apk'}, {name:'orbit-v1.5.6-android.apk'}, {name:'orbit-v1.5.6-x86_64.apk'}
 ]}));
 assert.equal(release.assets[0].name, 'orbit-v1.5.6-android.apk');
});

// Exercise the shipped inline UI with a deterministic DOM/clock and no camera.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '../camera_linux/live_vision.py'), 'utf8');
const script = source.split('<script>')[1].split('</script>')[0];

async function check(failure) {
  let now = 0, reject = false, clears = 0;
  const callbacks = new Map();
  const ctx = {clearRect(){clears++;}, drawImage(){}, strokeRect(){}, fillText(){}};
  const canvas = {dataset:{}, getContext:()=>ctx};
  const state = {}, stats = {};
  const result = {state:'LIVE', jpeg_base64:'fixture', frame_seq:7,
    camera_session:'fixture-session', jpeg_sha256:'fixture-hash', age_ms:10,
    result_max_age_ms:1600, autonomous_grasp_allowed:false,
    detections:[{category:'bottle',confidence:.9,bbox_xyxy:[1,2,3,4]}]};
  const sandbox = {
    document:{getElementById:id=>({view:canvas,state,stats})[id]},
    performance:{now:()=>now}, AbortController,
    setTimeout:()=>1, clearTimeout(){}, setInterval:(fn,ms)=>callbacks.set(ms,fn),
    Image:class {constructor(){this.width=10;this.height=10;} async decode(){}},
    fetch:async()=>{if(reject)throw Error('offline');return {json:async()=>({...result})};}
  };
  vm.runInNewContext(script, sandbox);
  await new Promise(setImmediate);
  assert.equal(canvas.dataset.frameSeq,'7');
  assert.equal(JSON.parse(stats.textContent).state,'LIVE');
  if(failure==='watchdog'){now=1591;callbacks.get(50)();}
  else {reject=true;await callbacks.get(200)();await new Promise(setImmediate);}
  const after=JSON.parse(stats.textContent);
  assert.equal(after.state,failure==='watchdog'?'STALE':'CONNECTION_ERROR');
  assert.deepEqual(after.detections,[]);
  assert.equal(after.autonomous_grasp_allowed,false);
  for(const key of ['frame_seq','camera_session','jpeg_sha256','jpeg_base64'])
    assert.equal(after[key],undefined);
  assert.equal(canvas.dataset.frameSeq,'');
  assert.equal(canvas.dataset.jpegSha256,'');
  assert.ok(clears>0);
}
(async()=>{await check('watchdog');await check('network');console.log('UI expiry/network checks: 2 passed');})()
  .catch(error=>{console.error(error);process.exitCode=1;});

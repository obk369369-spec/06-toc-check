const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {pathToFileURL}=require('node:url');
const {chromium}=require('playwright');

function browserPath(){return [
  process.env.BROWSER_EXECUTABLE,
  process.env['ProgramFiles(x86)']&&path.join(process.env['ProgramFiles(x86)'],'Microsoft','Edge','Application','msedge.exe'),
  process.env.ProgramFiles&&path.join(process.env.ProgramFiles,'Microsoft','Edge','Application','msedge.exe')
].filter(Boolean).find(fs.existsSync);}

(async()=>{
 const entry=process.env.TOOL006_ENTRYPOINT||path.resolve(__dirname,'..','TOOL006_TOC','toc_lock_v2_26_v10_실제본체반영_HOLD.html');
 const browser=await chromium.launch({headless:true,executablePath:browserPath()});
 const context=await browser.newContext({permissions:['clipboard-read','clipboard-write']});
 const page=await context.newPage();const errors=[];
 page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
 await page.goto(pathToFileURL(entry).href);await page.waitForLoadState('load');
 const ids=['btnTestCase','btnRun','btnPickPoint','btnSendDiag','btnResetDiag','btnClearIn','btnClearOut','btnCopyOut','inputTopButton','outputTopButton'];
 for(const id of ids) assert.equal(await page.locator('#'+id).count(),1,`${id} missing or duplicated`);
 assert.equal(await page.locator('button').count(),10);
 assert.equal(await page.locator('#btnSendDiag').textContent(),'자가분석·개선');

 const recovered=JSON.parse(fs.readFileSync(path.join(__dirname,'..','fixtures','tool006_regression.json'),'utf8')).cases[0];
 await page.locator('#depthSel').selectOption('2');
 await page.locator('#taIn').fill(recovered.input.join('\n'));
 await page.locator('#btnRun').click();
 assert.equal(await page.locator('#copyBuffer').inputValue(),recovered.expected.join('\n'));

 await page.locator('#btnTestCase').click();
 assert.match(await page.locator('#stateTxt').textContent(),/PASS|HOLD/);
 await page.locator('#btnResetDiag').click();assert.equal(await page.locator('#packetPreview').textContent(),'패킷 미리보기 없음');
 await page.locator('#btnPickPoint').click();assert.equal(await page.locator('#pickModeTxt').textContent(),'ON');
 await page.locator('#btnPickPoint').click();assert.equal(await page.locator('#pickModeTxt').textContent(),'OFF');
 await page.locator('#btnClearOut').click();assert.match(await page.locator('#outList').textContent(),/정리 결과/);
 await page.locator('#btnClearIn').click();assert.equal(await page.locator('#taIn').inputValue(),'');

 const actual=['1 Overview','1.1 Scope','1.1.1 Explicit Detail','2 By Product','2.1 Primary Segment','2.1.1 Deep Segment','3 Appendix'].join('\n');
 const expected=['1 Overview','  1.1 Scope','2 By Product','  2.1 Primary Segment','3 Appendix'].join('\n');
 await page.locator('#depthSel').selectOption('2');await page.locator('#taIn').fill(actual);await page.locator('#btnRun').click();
 assert.equal(await page.locator('#stateTxt').textContent(),'PASS');
 assert.equal(await page.locator('#copyBuffer').inputValue(),expected);
 assert.equal(await page.locator('#outList .depth-3').count(),0);
 await page.locator('#btnCopyOut').click();assert.equal((await page.evaluate(()=>navigator.clipboard.readText())).replace(/\r\n/g,'\n'),expected);

 await page.locator('#taIn').evaluate(el=>{el.scrollTop=el.scrollHeight;el.focus()});await page.locator('#inputTopButton').click();
 assert.equal(await page.locator('#taIn').evaluate(el=>el.scrollTop),0);
 await page.locator('#outBox').evaluate(el=>{el.scrollTop=el.scrollHeight;el.focus()});await page.locator('#outputTopButton').click();
 assert.equal(await page.locator('#outBox').evaluate(el=>el.scrollTop),0);
 assert.deepEqual(errors,[]);
 await browser.close();
 console.log('PASS: TOOL006 10-button actual click flow + exact depth-2 output + clipboard E2E');
})().catch(e=>{console.error(e);process.exit(1)});

// Changed-scope contract tests. VM DOM double is NOT a browser/actual E2E claim.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..');
const html=fs.readFileSync(path.join(root,'TOOL006_TOC','toc_lock_v2_26_v10_실제본체반영_HOLD.html'),'utf8');
const contract=html.match(/<script id="T6_ANOMALY_CONTRACT" type="application\/json">([\s\S]*?)<\/script>/)[1];
let source=html.match(/<script id="T6_V10_ENGINE_RULES">([\s\S]*?)<\/script>/)[1];
source=source.replace('// Single authoritative execution path.','window.inspectContract=()=>({transaction,validateOutput});\n// Single authoritative execution path.');
const nodes={},callbacks=[];
function node(id){return nodes[id]??=( {value:'',textContent:'',innerHTML:'',disabled:false,addEventListener(){}} );}
node('T6_ANOMALY_CONTRACT').textContent=contract;node('depthSel').value='2';
const window={},document={getElementById:node,addEventListener:(e,f)=>callbacks.push(f),querySelectorAll:()=>[]};
vm.runInNewContext(source,{window,document,crypto:require('node:crypto').webcrypto,console});callbacks.forEach(f=>f());
let passed=0;
function test(name,fn){fn();passed++;console.log('PASS '+name);}
test('actual-source fixture output reuse at changed engine boundary',()=>{
 const actual=JSON.parse(fs.readFileSync(path.join(root,'fixtures/tool006_regression.json'),'utf8')).cases[0];
 node('taIn').value=actual.input.join('\n');const out=window.runTocStableV10();
 assert.equal(out.status,'PASS');assert.equal(node('copyBuffer').value,actual.expected.join('\n'));
});
test('immutable original identity and consumed recovery across replay',()=>{
 node('taIn').value='1 Market Overview\n(This section explains the study assumptions)';
 const first=window.runTocStableV10();assert.equal(first.status,'HOLD');assert.equal(node('copyBuffer').value,'');
 node('btnSendDiag').onclick();let tx=window.inspectContract().transaction;
 assert.equal(tx.status,'PASS');assert.equal(tx.original_run_id,first.original_run_id);assert.equal(tx.recovery_attempts,1);
 assert.equal(node('taIn').value,tx.original_input);assert.equal(node('copyBuffer').value,'1 Market Overview');
 tx.original_run_id='changed';assert.equal(tx.original_run_id,first.original_run_id);
 window.runTocStableV10();node('btnSendDiag').onclick();assert.equal(node('lastCode').textContent,'REPEATED_AUTO_REPAIR_FORBIDDEN');
});
test('unknown remains HOLD and consumes exactly one attempt',()=>{
 node('taIn').value='Executive Summary\nUnexpected orphan detail without known parent';window.runTocStableV10();node('btnSendDiag').onclick();
 assert.equal(window.inspectContract().transaction.status,'HOLD');assert.equal(node('btnCopyOut').disabled,true);
 node('btnSendDiag').onclick();assert.equal(node('lastCode').textContent,'REPEATED_AUTO_REPAIR_FORBIDDEN');
});
test('same headings at different positions retained and full depth preserved',()=>{
 node('taIn').value='1 Overview\n1.1 Scope\n1.1.1 Detail\n2 Overview\n2.1 Scope';
 assert.equal(window.runTocStableV10().status,'PASS');
 assert.equal(node('copyBuffer').value,'1 Overview\n  1.1 Scope\n    1.1.1 Detail\n2 Overview\n  2.1 Scope');
});
test('pre-output rejects missing/reordered/changed title/changed depth',()=>{
 const {transaction:tx,validateOutput:check}=window.inspectContract();
 assert.equal(check(tx,tx.rows.slice(1)).status,'HOLD');
 assert.equal(check(tx,[...tx.rows].reverse()).status,'HOLD');
 assert.equal(check(tx,tx.rows.map((r,i)=>i? r:{...r,text:'1 Changed'})).status,'HOLD');
 assert.equal(check(tx,tx.rows.map((r,i)=>i===2?{...r,depth:2}:r)).status,'HOLD');
});
test('input change blocks recovery rather than silently reassigning run',()=>{
 const id=window.inspectContract().transaction.original_run_id;node('taIn').value+='\n3 Appendix';node('btnSendDiag').onclick();
 assert.equal(node('lastCode').textContent,'INPUT_CHANGED_RUN_REQUIRED');
 assert.notEqual(window.runTocStableV10().original_run_id,id);
});
test('all shared verified noise rules HOLD then correct without deleting real headings',()=>{
 node('taIn').value='1 Overview\n** note\nList Of Tables 2\nList of Figures\n2 Appendix';
 assert.equal(window.runTocStableV10().status,'HOLD');node('btnSendDiag').onclick();
 assert.equal(node('copyBuffer').value,'1 Overview\n2 Appendix');
});
console.log(JSON.stringify({scope:'VM_contract_only',passed}));

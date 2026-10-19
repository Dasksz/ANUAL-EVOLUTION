const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const source=fs.readFileSync(path.join(__dirname,'../src/js/app.js'),'utf8');
const helpers=source.slice(source.indexOf('    let importInputRevision = 0;'),source.indexOf('    // Setup event listeners for the modal visibility',source.indexOf('    let importInputRevision = 0;')));
const readerCode=source.slice(source.indexOf('    function processExcelFile(file)'),source.indexOf('    if (fileInput) {',source.indexOf('    function processExcelFile(file)')));
test('changing file or pasted text invalidates old preview and ignores a slower previous file',()=>{
 const readers=[],events={};let analyses=0;
 const textarea={value:'old',addEventListener:(event,fn)=>{events[event]=fn}};
 const confirm={disabled:false};
 const ctx=vm.createContext({pendingImportUpdates:[{old:true}],importTextarea:textarea,importConfirmBtn:confirm,analysisContainer:{classList:{add(){}}},analysisBadges:{textContent:'old'},dropZone:null,Uint8Array,console,document:{getElementById:id=>id==='import-goals-textarea'?textarea:{click:()=>{analyses++}}},FileReader:class {constructor(){readers.push(this)}readAsArrayBuffer(){}},XLSX:{read:bytes=>({SheetNames:['Goals'],Sheets:{Goals:[[bytes[0]]]}}),utils:{sheet_to_json:sheet=>sheet}}});
 vm.runInContext(helpers+readerCode,ctx);
 ctx.processExcelFile({name:'old.xlsx'});assert.equal(confirm.disabled,true);assert.equal(ctx.pendingImportUpdates.length,0);
 ctx.processExcelFile({name:'new.xlsx'});
 readers[1].onload({target:{result:new Uint8Array([2]).buffer}});assert.equal(textarea.value,'2');assert.equal(analyses,1);
 readers[0].onload({target:{result:new Uint8Array([1]).buffer}});assert.equal(textarea.value,'2');assert.equal(analyses,1);
 ctx.processExcelFile({name:'third.xlsx'});textarea.value='pasted replacement';events.input();
 readers[2].onload({target:{result:new Uint8Array([3]).buffer}});assert.equal(textarea.value,'pasted replacement');assert.equal(analyses,1);
});

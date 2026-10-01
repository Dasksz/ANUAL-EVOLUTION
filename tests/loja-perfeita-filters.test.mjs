import {test} from 'node:test';
import assert from 'node:assert/strict';
import {cascadeFilters} from '../src/js/loja-perfeita-filters.mjs';
const rows=[
 {filiais:'05',supervisores:'ROMULO',vendedores:'A',cidades:'ILHEUS',redes:null,pesquisadores:'X'},
 {filiais:'05',supervisores:'ROMULO',vendedores:'B',cidades:'ITABUNA',redes:'REDE 1',pesquisadores:'Y'},
 {filiais:'08',supervisores:'TIAGO',vendedores:'C',cidades:'ILHEUS',redes:'REDE 2',pesquisadores:'Z'}
];
test('supervisor constrains vendors, city, branch and researchers',()=>{
 const {options}=cascadeFilters(rows,{supervisores:'ROMULO'},'supervisores');
 assert.deepEqual(options.vendedores,['A','B']);assert.deepEqual(options.filiais,['05']);assert.deepEqual(options.pesquisadores,['X','Y']);
});
test('latest selection has priority and removes incompatible old filters',()=>{
 const {selected,options}=cascadeFilters(rows,{supervisores:'ROMULO',vendedores:'C',filiais:'08'},'supervisores');
 assert.equal(selected.vendedores,'');assert.equal(selected.filiais,'');assert.deepEqual(options.vendedores,['A','B']);
});
test('each filter excludes itself, keeping valid alternatives selectable',()=>{
 const {options}=cascadeFilters(rows,{supervisores:'ROMULO',vendedores:'A'});
 assert.deepEqual(options.vendedores,['A','B']);assert.deepEqual(options.cidades,['ILHEUS']);
});
test('network groups participate in cascading and reset restores all options',()=>{
 const {options}=cascadeFilters(rows,{redes:'S/ REDE'},'redes');assert.deepEqual(options.vendedores,['A']);
 assert.deepEqual(cascadeFilters(rows,{}).options.vendedores,['A','B','C']);
 assert.deepEqual(cascadeFilters(rows,{redes:'C/ REDE'}).options.vendedores,['B','C']);
});

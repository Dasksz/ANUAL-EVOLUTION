import test from 'node:test';
import assert from 'node:assert/strict';
import { samePortfolioConfig } from '../src/js/portfolio-config.mjs';
const versions=[{start_ym:200001,clients:[{code:'12034',percent:70},{code:'12125',percent:30}]}];
test('unchanged configuration ignores order and numeric formatting',()=>{
 assert.equal(samePortfolioConfig(versions,200001,[{code:'12125',percent:'30.00'},{code:'12034',percent:70}]),true);
});
test('client, percentage and effective month changes require saving',()=>{
 assert.equal(samePortfolioConfig(versions,202611,versions[0].clients),false);
 assert.equal(samePortfolioConfig(versions,200001,[{code:'12034',percent:100}]),false);
 assert.equal(samePortfolioConfig(versions,200001,[{code:'12034',percent:60},{code:'12125',percent:40}]),false);
});

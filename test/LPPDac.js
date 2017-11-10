/* eslint-env mocha */
/* eslint-disable no-await-in-loop */
const TestRPC = require('ethereumjs-testrpc');
const chai = require('chai');
const { Vault, LiquidPledgingMock, LiquidPledgingState } = require('liquidpledging');
const LPPDac = require('../lib/LPPDac');
const MiniMeToken = require('minimetoken/js/minimetoken');
const MiniMeTokenState = require('minimetoken/js/minimetokenstate');
const Web3 = require('web3');

const assert = chai.assert;
const assertFail = require('./helpers/assertFail');

describe('LPPDac test', function() {
  this.timeout(0);

  let web3;
  let accounts;
  let liquidPledging;
  let liquidPledgingState;
  let vault;
  let dac;
  let dac2;
  let minime;
  let minime2;
  let minimeTokenState;
  let giver1;
  let giver2;
  let project1;
  let dacOwner1;
  let dacOwner2;
  let testrpc;

  before(async () => {
    testrpc = TestRPC.server({
      ws: true,
      gasLimit: 6500000,
      total_accounts: 10,
    });

    testrpc.listen(8546, '127.0.0.1', (err) => {});

    web3 = new Web3('ws://localhost:8546');
    accounts = await web3.eth.getAccounts();

    giver1 = accounts[1];
    project1 = accounts[2];
    dacOwner1 = accounts[3];
    dacOwner2 = accounts[4];
    giver2 = accounts[6];
  });

  after((done) => {
    testrpc.close();
    done();
  });

  it('Should deploy LPPDac contract and add delegate to liquidPledging', async () => {
    vault = await Vault.new(web3);
    liquidPledging = await LiquidPledgingMock.new(web3, vault.$address);
    await vault.setLiquidPledging(liquidPledging.$address);

    liquidPledgingState = new LiquidPledgingState(liquidPledging);

    dac = await LPPDac.new(web3, liquidPledging.$address, 'DAC 1', 'URL1', 0, 'DAC 1 Token', 'DAC1', { from: dacOwner1}); // pledgeAdmin #1

    minime = new MiniMeToken(web3, await dac.token());
    minimeTokenState = new MiniMeTokenState(minime);

    const lpState = await liquidPledgingState.getState();
    assert.equal(lpState.admins.length, 2);
    const lpManager = lpState.admins[1];
    assert.equal(lpManager.type, 'Delegate');
    assert.equal(lpManager.addr, dac.$address);
    assert.equal(lpManager.name, 'DAC 1');
    assert.equal(lpManager.commitTime, '0');
    assert.equal(lpManager.canceled, false);
    assert.equal(lpManager.plugin, dac.$address);

    assert.equal(await dac.liquidPledging(), liquidPledging.$address);
    assert.equal(await dac.idProject(), '1');

    const tState = await minimeTokenState.getState();
    assert.equal(tState.totalSupply, 0);
    assert.equal(tState.name, 'DAC 1 Token');
    assert.equal(tState.controller, dac.$address);
    assert.equal(await minime.symbol(), 'DAC1');
  });

  it('Should not generate tokens when added as pledge delegate', async function() {
    await liquidPledging.addGiver('Giver1', 'URL', 0, 0x0, { from: giver1 }); // pledgeAdmin #2
    await liquidPledging.donate(2, 1, { from: giver1, value: 1000 });

    const st = await liquidPledgingState.getState();
    assert.equal(st.pledges[2].amount, 1000);
    assert.equal(st.pledges[2].owner, 2);

    const giverTokenBal = await minime.balanceOf(giver1);
    const totalTokenSupply = await minime.totalSupply();
    assert.equal(giverTokenBal, 0);
    assert.equal(totalTokenSupply, 0);
  });

  it('Should send tokens to giver when committing to project', async function() {
    // create project
    await liquidPledging.addProject('Project1', 'URL', project1, 0, 0, 0x0, { from: project1, gas: 1000000 }); // pledgeAdmin #3
    // delegate to project1
    await dac.transfer(1, 2, 1000, 3, { from: dacOwner1 });

    // set the time
    const now = Math.floor(new Date().getTime() / 1000);
    await liquidPledging.setMockedTime(now);

    await liquidPledging.normalizePledge(3, { gas: 500000 });

    const st = await liquidPledgingState.getState();
    assert.equal(st.pledges[4].amount, 1000);
    assert.equal(st.pledges[4].owner, 3);
    assert.equal(st.pledges[3].amount, 0);
    assert.equal(st.pledges[2].amount, 0);

    const giverTokenBal = await minime.balanceOf(giver1);
    const totalTokenSupply = await minime.totalSupply();
    assert.equal(giverTokenBal, 1000);
    assert.equal(totalTokenSupply, 1000);
  });

  it('Should not send tokens to giver when revoking pledge from delegate', async function() {
    // donate to delegate1
    await liquidPledging.donate(2, 1, { from: giver1, value: 1000 });
    await liquidPledging.transfer(2, 2, 1000, 2, { from: giver1, $extraGas: 200000 });

    const st = await liquidPledgingState.getState();
    assert.equal(st.pledges[1].amount, 1000);
    assert.equal(st.pledges[1].owner, 2);

    const giverTokenBal = await minime.balanceOf(giver1);
    const totalTokenSupply = await minime.totalSupply();
    assert.equal(giverTokenBal, 1000);
    assert.equal(totalTokenSupply, 1000);
  });

  it('Should only generate tokens for first delegate in chain.', async function() {
    dac2 = await LPPDac.new(web3, liquidPledging.$address, 'DAC 2', 'URL2', 0, 'DAC 2 Token', 'DAC2', { from: dacOwner2});
    minime2 = new MiniMeToken(web3, await dac2.token());

    // add delegate 1
    await liquidPledging.transfer(2, 1, 1000, 1, { from: giver1, $extraGas: 200000 });
    // add delegate 2
    await dac.transfer(1, 2, 1000, 4, { from: dacOwner1 });

    // delegate to project1
    await dac2.transfer(4, 5, 1000, 3, { from: dacOwner2 });

    // set the time
    const now = Math.floor(new Date().getTime() / 1000);
    await liquidPledging.setMockedTime(now);

    await liquidPledging.normalizePledge(6, { gas: 500000 });

    const st = await liquidPledgingState.getState();
    assert.equal(st.pledges[4].amount, 1000);
    assert.equal(st.pledges[4].owner, 3);

    const giverTokenBal = await minime.balanceOf(giver1);
    const totalTokenSupply = await minime.totalSupply();
    assert.equal(giverTokenBal, 2000);
    assert.equal(totalTokenSupply, 2000);

    const giverToken2Bal = await minime2.balanceOf(giver1);
    const totalToken2Supply = await minime2.totalSupply();
    assert.equal(giverToken2Bal, 0);
    assert.equal(totalToken2Supply, 0);
  });

});

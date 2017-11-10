/* eslint-env mocha */
/* eslint-disable no-await-in-loop */
const TestRPC = require('ethereumjs-testrpc');
const chai = require('chai');
const { Vault, LiquidPledging, LiquidPledgingState } = require('liquidpledging');
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
  let minime;
  let minimeTokenState;
  let giver1;
  let giver2;
  let project1;
  let dacOwner1;
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
    giver2 = accounts[6];
  });

  after((done) => {
    testrpc.close();
    done();
  });

  it('Should deploy LPPDac contract and add delegate to liquidPledging', async () => {
    vault = await Vault.new(web3);
    liquidPledging = await LiquidPledging.new(web3, vault.$address);
    await vault.setLiquidPledging(liquidPledging.$address);

    liquidPledgingState = new LiquidPledgingState(liquidPledging);

    dac = await LPPDac.new(web3, liquidPledging.$address, 'DAC 1', 'URL1', 0, 'DAC 1 Token', 'DAC1', { from: dacOwner1}); // pledgeAdmin #1

    minime = new MiniMeToken(web3, await dac.token());
    minimeTokenState = new MiniMeTokenState(minime);

    const lpState = await liquidPledgingState.getState();
    assert.equal(lpState.admins.length, 2);
    const lpManager = lpState.admins[1];
    assert.equal(lpManager.type, 'Project');
    assert.equal(lpManager.addr, dac.$address);
    assert.equal(lpManager.name, 'DAC 1');
    assert.equal(lpManager.commitTime, '0');
    assert.equal(lpManager.canceled, false);
    assert.equal(lpManager.plugin, dac.$address);

    assert.equal(await dac.liquidPledging(), liquidPledging.$address);
    assert.equal(dac.idProject(), '1');
    assert.equal(dac.token(), minime.$address);

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
    assert(st.pledges[2].amount, 1000);
    assert(st.pledges[2].owner, 1);

    const giverTokenBal = await minime.balanceOf(giver1);
    const totalTokenSupply = await minime.totalSupply();
    assert(giverTokenBal, 0);
    assert(totalTokenSupply, 0);
  });

  // it('Should be able to transfer pledge to another project', async function() {
  //   await liquidPledging.addProject('Project1', 'URL', project1, 0, 0, 0x0, { from: project1, gas: 1000000 }); // pledgeAdmin #3
  //   await campaign.transfer(1, 2, 1000, 3, { from: campaignOwner1, gas: 300000 });
  //
  //   const st = await liquidPledgingState.getState();
  //   assert(st.pledges[3].amount, 1000);
  //   assert(st.pledges[3].owner, 3);
  //   assert(st.pledges[2].amount, 0);
  // });
  //
  // it('Should be able to change reviewer', async function() {
  //   await campaign.changeReviewer(reviewer2, { from: reviewer1 });
  //
  //   const st = await campaign.getState();
  //   assert.equal(st.reviewer, reviewer1);
  //   assert.equal(st.newReviewer, reviewer2);
  //
  //   await campaign.acceptNewReviewer({ from: reviewer2, gas: 40000 });
  //
  //   const st2 = await campaign.getState();
  //   assert.equal(st2.reviewer, reviewer2);
  //   assert.equal(st2.newReviewer, '0x0000000000000000000000000000000000000000');
  // });
  //
  // it('Owner should not be able to change reviewer', async function() {
  //   await assertFail(async () => await campaign.changeReviewer(reviewer1, { from: campaignOwner1 }));
  // });
  //
  // it('Reviewer should be able to cancel campaign', async function() {
  //   await campaign.cancelCampaign({ from: reviewer2 });
  //
  //   const canceled = await campaign.isCanceled();
  //   assert.equal(canceled, true);
  // });
  //
  // it('Should deploy another campaign', async function() {
  //   campaign = await LPPCampaign.new(web3, liquidPledging.$address, 'Campaign 2', 'URL2', 0, reviewer1, 'Campaign 2 Token', 'CPG2', { from: campaignOwner1 }); // pledgeAdmin #4
  //
  //   const canceled = await campaign.isCanceled();
  //   assert.equal(canceled, false);
  // });
  //
  // it('Random should not be able to cancel campaign', async function() {
  //   await assertFail(async () => await campaign.cancelCampaign({ from: accounts[9] }));
  // });
  //
  // it('Owner should be able to cancel campaign', async function() {
  //   await campaign.cancelCampaign({ from: campaignOwner1 });
  //
  //   const canceled = await campaign.isCanceled();
  //   assert.equal(canceled, true);
  //   console.log(JSON.stringify(await liquidPledgingState.getState(), null, 2));
  // });
});

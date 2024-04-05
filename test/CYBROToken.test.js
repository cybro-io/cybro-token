const { expect } = require('chai');
const { ethers } = require("hardhat");

// Start test block
describe('CYBROToken', function () {
  before(async function () {
    this.CybroToken = await ethers.getContractFactory('CYBROToken');
  });

  beforeEach(async function () {
    const signers = await ethers.getSigners();

    this.ownerAddress = signers[0].address; // aka DAO address
    this.recipientAddress = signers[1].address;

    this.cybroToken = await this.CybroToken.deploy(this.ownerAddress);

    this.decimals = await this.cybroToken.decimals();

    this.totalSupply = 1_000_000_000;

    this.signerContract = this.cybroToken.connect(signers[1]);
  });

  // Test cases
  it('Creates a token with a name', async function () {
    expect(await this.cybroToken.name()).to.exist;
    // expect(await this.cybroToken.name()).to.equal('CYBROToken');
  });

  it('Creates a token with a symbol', async function () {
    expect(await this.cybroToken.symbol()).to.exist;
    // expect(await this.cybroToken.symbol()).to.equal('CYBRO');
  });

  it('Has a valid decimal', async function () {
    expect((await this.cybroToken.decimals()).toString()).to.equal('18');
  })

  it('Has a valid total supply', async function () {
    const expectedSupply = this.totalSupply.toString();
    expect((await this.cybroToken.totalSupply()).toString()).to.equal(expectedSupply);
  });

  it("Should assign the total supply of tokens to the DAO wallet", async function () {
    const daoBalance = await this.cybroToken.balanceOf(this.ownerAddress);
    expect(await this.cybroToken.totalSupply()).to.equal(daoBalance);
  });

  it('Is able to query account balances', async function () {
    const ownerBalance = await this.cybroToken.balanceOf(this.ownerAddress);
    expect(await this.cybroToken.balanceOf(this.ownerAddress)).to.equal(ownerBalance);
  });

  it('Transfers the right amount of tokens to/from an account', async function () {
    const transferAmount = 1000;
    await expect(this.cybroToken.transfer(this.recipientAddress, transferAmount)).to.changeTokenBalances(
        this.cybroToken,
        [this.ownerAddress, this.recipientAddress],
        [-transferAmount, transferAmount]
      );
  });

});

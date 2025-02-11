const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("VictorVoltageToken", function () {
  let VictorVoltageToken;
  let token: any;
  let owner: any;
  let addr1: any;
  let addr2: any;
  let addr3: any;
  let treasuryWallet: any;
  let lpWallet: any;
  let tithingWallet: any;
  let uniswapPair: any;

  const TOTAL_SUPPLY = ethers.parseEther("170000000000000");

  beforeEach(async function () {
    [
      owner,
      addr1,
      addr2,
      addr3,
      treasuryWallet,
      lpWallet,
      tithingWallet,
      uniswapPair,
    ] = await ethers.getSigners();

    VictorVoltageToken = await ethers.getContractFactory("VictorVoltageToken");
    token = await VictorVoltageToken.deploy(
      treasuryWallet.address,
      lpWallet.address,
      tithingWallet.address
    );
    await token.waitForDeployment();
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await token.owner()).to.equal(owner.address);
    });

    it("Should assign the total supply of tokens to the owner", async function () {
      const ownerBalance = await token.balanceOf(owner.address);
      expect(await token.totalSupply()).to.equal(ownerBalance);
    });

    it("Should set the correct wallet addresses", async function () {
      expect(await token.treasuryWallet()).to.equal(treasuryWallet.address);
      expect(await token.lpWallet()).to.equal(lpWallet.address);
      expect(await token.tithingWallet()).to.equal(tithingWallet.address);
    });
  });

  describe("Transactions", function () {
    it("Should transfer tokens between accounts", async function () {
      await token.transfer(addr1.address, 50);
      const addr1Balance = await token.balanceOf(addr1.address);
      expect(addr1Balance).to.equal(50);

      await token.connect(addr1).transfer(addr2.address, 50);
      const addr2Balance = await token.balanceOf(addr2.address);
      expect(addr2Balance).to.equal(50);
    });

    it("Should fail if sender doesn't have enough tokens", async function () {
      const initialOwnerBalance = await token.balanceOf(owner.address);
      await expect(
        token.connect(addr1).transfer(owner.address, 1)
      ).to.be.revertedWithCustomError(token, "ERC20InsufficientBalance");
      expect(await token.balanceOf(owner.address)).to.equal(
        initialOwnerBalance
      );
    });

    it("Should update balances after transfers", async function () {
      await token.transfer(addr1.address, 10000000);

      const initialAddr1Balance = await token.balanceOf(addr1.address);

      await token.connect(addr1).transfer(addr2.address, 200000);
      await token.connect(addr1).transfer(addr3.address, 200000);

      const finalAddr1Balance = await token.balanceOf(addr1.address);
      expect(finalAddr1Balance).to.be.lt(initialAddr1Balance - BigInt(400000));

      const addr2Balance = await token.balanceOf(addr2.address);
      expect(addr2Balance).to.be.lt(200000);

      const addr3Balance = await token.balanceOf(addr3.address);
      expect(addr3Balance).to.be.lt(200000);
    });
  });

  describe("Taxes", function () {
    it("Should apply transfer tax", async function () {
      await token.transfer(addr1.address, 10000000);
      await token.connect(addr1).transfer(addr2.address, 1000000);
      const addr2Balance = await token.balanceOf(addr2.address);
      expect(addr2Balance).to.be.lt(1000000);
    });

    it("Should apply buy/sell tax", async function () {
      await token.setUniswapPair(uniswapPair.address);
      await token.transfer(addr1.address, 10000000);
      await token.connect(addr1).transfer(uniswapPair.address, 1000000);
      const pairBalance = await token.balanceOf(uniswapPair.address);
      expect(pairBalance).to.be.lt(1000000);
    });

    it("Should not apply tax to excluded addresses", async function () {
      await token.excludeFromFees(addr1.address, true);
      await token.transfer(addr1.address, 10000);
      const addr1Balance = await token.balanceOf(addr1.address);
      expect(addr1Balance).to.equal(10000);
    });
  });

  describe("Admin functions", function () {
    it("Should update wallet addresses", async function () {
      await token.updateTreasuryWallet(addr1.address);
      expect(await token.treasuryWallet()).to.equal(addr1.address);

      await token.updateLpWallet(addr2.address);
      expect(await token.lpWallet()).to.equal(addr2.address);

      await token.updateTithingWallet(owner.address);
      expect(await token.tithingWallet()).to.equal(owner.address);
    });

    it("Should set Uniswap pair", async function () {
      await token.setUniswapPair(uniswapPair.address);
      expect(await token.uniswapPair()).to.equal(uniswapPair.address);
    });

    it("Should exclude and include addresses from reward", async function () {
      await token.excludeFromReward(addr1.address);
      await token.includeInReward(addr1.address);
    });

    it("Should set max transaction amount", async function () {
      const newMaxAmount = ethers.parseEther("1000000");
      await token.setMaxTransactionAmount(newMaxAmount);
      expect(await token.maxTransactionAmount()).to.equal(newMaxAmount);
    });

    it("Should pause and unpause the contract", async function () {
      await token.pause();
      await expect(
        token.transfer(addr1.address, 100)
      ).to.be.revertedWithCustomError(token, "EnforcedPause");

      await token.unpause();
      await expect(token.transfer(addr1.address, 100)).to.not.be.reverted;
    });
  });
});

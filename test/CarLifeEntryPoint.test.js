const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("CarLifeEntryPoint Simple", function () {
  let carLifeEntryPoint;
  let carLifePaymaster;
  let carToken;
  let owner;

  before(async function () {
    [owner] = await ethers.getSigners();

    // Deploy CAR token
    const CAR = await ethers.getContractFactory("ERC20Mock");
    carToken = await CAR.deploy("CarLife", "CAR");
    await carToken.waitForDeployment();

    // Deploy Paymaster
    const CarLifePaymaster = await ethers.getContractFactory("CarLifePaymaster");
    const carTokenAddress = await carToken.getAddress();
    carLifePaymaster = await CarLifePaymaster.deploy(carTokenAddress);
    await carLifePaymaster.waitForDeployment();

    // Deploy EntryPoint
    const CarLifeEntryPoint = await ethers.getContractFactory("CarLifeEntryPoint");
    const paymasterAddress = await carLifePaymaster.getAddress();
    const maxOpsPerHandleOps = 10;

    console.log("Deploying CarLifeEntryPoint with paymaster:", paymasterAddress);
    carLifeEntryPoint = await CarLifeEntryPoint.deploy(paymasterAddress, maxOpsPerHandleOps);
    await carLifeEntryPoint.waitForDeployment();

    console.log("CarLifeEntryPoint deployed to:", await carLifeEntryPoint.getAddress());
  });

  describe("Deployment", function () {
    it("Should set correct paymaster", async function () {
      const paymaster = await carLifeEntryPoint.paymaster();
      console.log("Paymaster address from contract:", paymaster);
      expect(paymaster).to.equal(await carLifePaymaster.getAddress());
    });

    it("Should set correct owner", async function () {
      const entryOwner = await carLifeEntryPoint.owner();
      console.log("Owner address from contract:", entryOwner);
      expect(entryOwner).to.equal(owner.address);
    });

    it("Should set correct max ops per handle ops", async function () {
      const maxOps = await carLifeEntryPoint.maxOpsPerHandleOps();
      console.log("Max ops per handle ops:", maxOps);
      expect(maxOps).to.equal(10);
    });
  });
});

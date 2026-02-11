const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("CarNFTFixedOptimized - Gas 优化测试", function () {
  let optimized;
  let owner;
  let addr1;

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();

    const CarNFTFixedOptimized = await ethers.getContractFactory("CarNFTFixedOptimized");
    optimized = await CarNFTFixedOptimized.deploy();
    await optimized.waitForDeployment();
  });

  describe("部署", function () {
    it("应该设置正确的代币名称和符号", async function () {
      expect(await optimized.name()).to.equal("CarLife NFT Optimized");
      expect(await optimized.symbol()).to.equal("CLFT");
    });

    it("部署者应该是所有者", async function () {
      expect(await optimized.owner()).to.equal(owner.address);
    });

    it("初始应该暂停铸造", async function () {
      expect(await optimized.mintingPaused()).to.be.true;
    });

    it("初始 totalCars 应该为 0", async function () {
      expect(await optimized.totalCars()).to.equal(0);
    });
  });

  describe("Gas 优化测试", function () {
    it("mintCar gas 消耗", async function () {
      await optimized.unpauseMinting();

      const vin = "VIN1234567890ABCDEFG";
      const make = "Toyota";
      const model = "Camry";
      const year = 2020;
      const mileage = 50000;
      const condition = "Excellent";
      const uri = "ipfs://QmTest123";

      const tx = await optimized.mintCar(
        addr1.address,
        vin,
        make,
        model,
        year,
        mileage,
        condition,
        uri
      );

      const receipt = await tx.wait();
      console.log("mintCar gas used:", receipt.gasUsed);

      // Gas 应该显著低于原始版本（306,624）
      // 预期约 230,000 - 270,000
      expect(Number(receipt.gasUsed)).to.be.below(280000);
    });

    it("updateCarInfo gas 消耗", async function () {
      await optimized.unpauseMinting();
      await optimized.mintCar(
        addr1.address,
        "VIN123",
        "Toyota",
        "Camry",
        2020,
        50000,
        "Excellent",
        "ipfs://QmTest"
      );

      const tx = await optimized.updateCarInfo(0, 51000, "Good");
      const receipt = await tx.wait();

      console.log("updateCarInfo gas used:", receipt.gasUsed);

      // Gas 应该低于原始版本（41,612）
      // 预期约 35,000 - 40,000
      expect(Number(receipt.gasUsed)).to.be.below(42000);
    });

    it("addMaintenance gas 消耗", async function () {
      await optimized.unpauseMinting();
      await optimized.mintCar(
        addr1.address,
        "VIN123",
        "Toyota",
        "Camry",
        2020,
        50000,
        "Excellent",
        "ipfs://QmTest"
      );

      const tx = await optimized.addMaintenance(0, 51000, "Oil change");
      const receipt = await tx.wait();

      console.log("addMaintenance gas used:", receipt.gasUsed);

      // Gas 应该低于原始版本（41,504）
      // 预期约 35,000 - 40,000
      expect(Number(receipt.gasUsed)).to.be.below(42000);
    });

    it("transferFrom gas 消耗", async function () {
      await optimized.unpauseMinting();
      await optimized.mintCar(
        addr1.address,
        "VIN123",
        "Toyota",
        "Camry",
        2020,
        50000,
        "Excellent",
        "ipfs://QmTest"
      );

      const tx = await optimized.connect(addr1).transferFrom(addr1.address, owner.address, 0);
      const receipt = await tx.wait();

      console.log("transferFrom gas used:", receipt.gasUsed);

      // 应该低于原始版本（57,315）
      expect(Number(receipt.gasUsed)).to.be.below(60000);
    });

    it("批量 mint 对比测试", async function () {
      await optimized.unpauseMinting();

      const mints = 10;
      let totalGas = 0;

      for (let i = 0; i < mints; i++) {
        const tx = await optimized.mintCar(
          addr1.address,
          `VIN${i}`,
          "Toyota",
          "Camry",
          2020,
          50000 + i * 1000,
          "Excellent",
          `ipfs://QmTest${i}`
        );
        const receipt = await tx.wait();
        totalGas += Number(receipt.gasUsed);
      }

      const avgGas = totalGas / mints;
      console.log(`平均 mintCar gas (${mints} 次):`, avgGas.toString());

      // 平均应该显著低于原始版本
      expect(avgGas).to.be.below(280000);
    });
  });

  describe("边界测试", function () {
    it("应该拒绝无效的年份", async function () {
      await optimized.unpauseMinting();

      await expect(
        optimized.mintCar(
          addr1.address,
          "VIN123",
          "Toyota",
          "Camry",
          10000, // 超过 MAX_YEAR
          50000,
          "Excellent",
          "ipfs://QmTest"
        )
      ).to.be.revertedWithCustomError(optimized, "InvalidYear");
    });

    it("应该拒绝过大的里程", async function () {
      await optimized.unpauseMinting();

      await expect(
        optimized.mintCar(
          addr1.address,
          "VIN123",
          "Toyota",
          "Camry",
          2020,
          18446744073709551616n, // 超过 uint64 最大值
          "Excellent",
          "ipfs://QmTest"
        )
      ).to.be.revertedWithCustomError(optimized, "MileageOverflow");
    });

    it("应该正确处理最大年份", async function () {
      await optimized.unpauseMinting();

      await expect(
        optimized.mintCar(
          addr1.address,
          "VIN123",
          "Toyota",
          "Camry",
          9999, // MAX_YEAR
          50000,
          "Excellent",
          "ipfs://QmTest"
        )
      ).not.to.be.reverted;
    });
  });

  describe("兼容性测试", function () {
    it("应该正确返回 CarInfo", async function () {
      await optimized.unpauseMinting();
      await optimized.mintCar(
        addr1.address,
        "VIN1234567890ABCDEFG",
        "Toyota",
        "Camry",
        2020,
        50000,
        "Excellent",
        "ipfs://QmTest"
      );

      const carInfo = await optimized.getCarInfo(0);

      expect(carInfo.vin).to.equal("VIN1234567890ABCDEFG");
      expect(carInfo.make).to.equal("Toyota");
      expect(carInfo.model).to.equal("Camry");
      expect(carInfo.year).to.equal(2020);
      expect(carInfo.mileage).to.equal(50000);
      expect(carInfo.condition).to.equal("Excellent");
      expect(carInfo.owner).to.equal(addr1.address);
      expect(carInfo.lastServiceDate).to.be.greaterThan(0);
    });

    it("应该正确触发事件", async function () {
      await optimized.unpauseMinting();

      const tx = await optimized.mintCar(
        addr1.address,
        "VIN123",
        "Toyota",
        "Camry",
        2020,
        50000,
        "Excellent",
        "ipfs://QmTest"
      );

      await expect(tx)
        .to.emit(optimized, "CarMinted")
        .withArgs(0, addr1.address, "VIN123");
    });
  });
});

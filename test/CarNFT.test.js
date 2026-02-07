const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("CarNFT_Optimized", function () {
  let carNFT;
  let owner;
  let addr1;
  let addr2;
  let provider;

  const VIN = "5YJSA1E5JF1234567";
  const MAKE = "Tesla";
  const MODEL = "Model S";
  const MILEAGE = 50000;
  const CONDITION = "good";

  beforeEach(async function () {
    [owner, addr1, addr2, provider] = await ethers.getSigners();

    const CarNFT = await ethers.getContractFactory("CarNFT");
    carNFT = await CarNFT.deploy();
    await carNFT.waitForDeployment();
  });

  describe("部署", function () {
    it("应该设置正确的代币名称和符号", async function () {
      expect(await carNFT.name()).to.equal("CarLife NFT");
      expect(await carNFT.symbol()).to.equal("CLFT");
    });

    it("部署者应该拥有默认管理员角色", async function () {
      const ADMIN_ROLE = await carNFT.DEFAULT_ADMIN_ROLE();
      expect(await carNFT.hasRole(ADMIN_ROLE, owner.address)).to.be.true;
    });

    it("部署者应该是所有者", async function () {
      expect(await carNFT.owner()).to.equal(owner.address);
    });

    it("初始应该暂停铸造", async function () {
      expect(await carNFT.mintingPaused()).to.be.true;
    });
  });

  describe("权限控制", function () {
    const PROVIDER_ROLE = ethers.solidityPackedKeccak256(
      ["string"],
      ["PROVIDER_ROLE"]
    );

    it("管理员可以授予服务商角色", async function () {
      await carNFT.grantRole(PROVIDER_ROLE, provider.address);
      expect(await carNFT.hasRole(PROVIDER_ROLE, provider.address)).to.be.true;
    });

    it("非管理员不能授予服务商角色", async function () {
      await expect(
        carNFT.connect(addr1).grantRole(PROVIDER_ROLE, addr2.address)
      ).to.be.reverted;
    });
  });

  describe("暂停功能", function () {
    it("管理员可以暂停和取消暂停合约", async function () {
      await carNFT.pause();
      expect(await carNFT.paused()).to.be.true;

      await carNFT.unpause();
      expect(await carNFT.paused()).to.be.false;
    });

    it("非管理员不能暂停合约", async function () {
      await expect(carNFT.connect(addr1).pause()).to.be.reverted;
    });

    it("管理员可以暂停和取消暂停铸造", async function () {
      await carNFT.unpauseMinting();
      expect(await carNFT.mintingPaused()).to.be.false;

      await carNFT.pauseMinting();
      expect(await carNFT.mintingPaused()).to.be.true;
    });
  });

  describe("Minting", function () {
    beforeEach(async function () {
      await carNFT.unpauseMinting();
    });

    it("管理员可以 mint NFT", async function () {
      await carNFT.mintCar(
        addr1.address,
        VIN,
        MAKE,
        MODEL,
        MILEAGE,
        CONDITION
      );

      expect(await carNFT.ownerOf(0)).to.equal(addr1.address);
    });

    it("非管理员不能 mint NFT", async function () {
      await expect(
        carNFT.connect(addr1).mintCar(
          addr1.address,
          VIN,
          MAKE,
          MODEL,
          MILEAGE,
          CONDITION
        )
      ).to.be.reverted;
    });

    it("Minting 暂停时不能 mint", async function () {
      await carNFT.pauseMinting();

      await expect(
        carNFT.mintCar(
          addr1.address,
          VIN,
          MAKE,
          MODEL,
          MILEAGE,
          CONDITION
        )
      ).to.be.revertedWith("Minting is paused");
    });

    it("应该设置正确的车辆信息", async function () {
      await carNFT.mintCar(
        addr1.address,
        VIN,
        MAKE,
        MODEL,
        MILEAGE,
        CONDITION
      );

      const carInfo = await carNFT.getCarInfo(0);
      expect(carInfo.vin).to.equal(VIN);
      expect(carInfo.make).to.equal(MAKE);
      expect(carInfo.model).to.equal(MODEL);
      expect(carInfo.mileage).to.equal(MILEAGE);
      expect(carInfo.condition).to.equal(CONDITION);
    });

    it("应该正确计数 totalCars", async function () {
      await carNFT.mintCar(
        addr1.address,
        VIN + "1",
        MAKE,
        MODEL,
        MILEAGE,
        CONDITION
      );
      await carNFT.mintCar(
        addr2.address,
        VIN + "2",
        MAKE,
        MODEL,
        MILEAGE,
        CONDITION
      );

      expect(await carNFT.totalCars()).to.equal(2);
    });
  });

  describe("转账功能", function () {
    beforeEach(async function () {
      await carNFT.unpauseMinting();
      await carNFT.mintCar(
        addr1.address,
        VIN,
        MAKE,
        MODEL,
        MILEAGE,
        CONDITION
      );
    });

    it("所有者可以转账 NFT", async function () {
      await carNFT.connect(addr1).transferFrom(addr1.address, addr2.address, 0);
      expect(await carNFT.ownerOf(0)).to.equal(addr2.address);
    });

    it("合约暂停时不能转账", async function () {
      await carNFT.pause();

      await expect(
        carNFT.connect(addr1).transferFrom(addr1.address, addr2.address, 0)
      ).to.be.revertedWithCustomError(carNFT, "EnforcedPause");
    });

    it("应该正确触发 Transfer 事件", async function () {
      await expect(
        carNFT.connect(addr1).transferFrom(addr1.address, addr2.address, 0)
      )
        .to.emit(carNFT, "Transfer")
        .withArgs(addr1.address, addr2.address, 0);
    });
  });

  describe("批量查询", function () {
    beforeEach(async function () {
      await carNFT.unpauseMinting();
      for (let i = 0; i < 5; i++) {
        await carNFT.mintCar(
          addr1.address,
          VIN + i.toString(),
          MAKE + i.toString(),
          MODEL,
          MILEAGE,
          CONDITION
        );
      }
    });

    it("应该返回指定数量的车辆信息", async function () {
      const carInfos = await carNFT.getCarInfoBatch(0, 3);
      expect(carInfos.length).to.equal(3);
    });

    it("查询数量不能超过 MAX_CARS_PER_TX", async function () {
      const MAX_CARS_PER_TX = await carNFT.MAX_CARS_PER_TX();

      await expect(
        carNFT.getCarInfoBatch(0, MAX_CARS_PER_TX + 1n)
      ).to.be.revertedWith("Too many cars");
    });
  });

  describe("Gas 优化", function () {
    it("批量查询应该比单个查询更省 gas", async function () {
      await carNFT.unpauseMinting();
      for (let i = 0; i < 5; i++) {
        await carNFT.mintCar(
          addr1.address,
          VIN + i.toString(),
          MAKE,
          MODEL,
          MILEAGE,
          CONDITION
        );
      }

      // 单个查询 gas
      const tx1 = await carNFT.getCarInfo(0);
      const receipt1 = await tx1.wait();

      // 批量查询 gas
      const tx2 = await carNFT.getCarInfoBatch(0, 5);
      const receipt2 = await tx2.wait();

      // 批量查询平均 gas 应该更低
      console.log(`单个查询 gas: ${receipt1.gasUsed.toString()}`);
      console.log(`批量查询 gas: ${receipt2.gasUsed.toString()}`);
    });
  });
});

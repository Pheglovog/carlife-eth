const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("CarNFT_Fixed", function () {
  let carNFT;
  let owner;
  let addr1;
  let addr2;
  let provider;

  const VIN = "5YJSA1E5JF1234567";
  const MAKE = "Tesla";
  const MODEL = "Model S";
  const YEAR = 2023;
  const MILEAGE = 50000;
  const CONDITION = "good";
  const URI = "ipfs://QmExample123";

  beforeEach(async function () {
    [owner, addr1, addr2, provider] = await ethers.getSigners();

    const CarNFT_Fixed = await ethers.getContractFactory("CarNFT_Fixed");
    carNFT = await CarNFT_Fixed.deploy();
    await carNFT.waitForDeployment();
  });

  describe("部署", function () {
    it("应该设置正确的代币名称和符号", async function () {
      expect(await carNFT.name()).to.equal("CarLife NFT");
      expect(await carNFT.symbol()).to.equal("CLFT");
    });

    it("部署者应该是所有者", async function () {
      expect(await carNFT.owner()).to.equal(owner.address);
    });

    it("初始应该暂停铸造", async function () {
      expect(await carNFT.mintingPaused()).to.be.true;
    });

    it("初始 totalCars 应该为 0", async function () {
      expect(await carNFT.totalCars()).to.equal(0);
    });
  });

  describe("Pausable 功能", function () {
    it("所有者可以暂停和取消暂停合约", async function () {
      await carNFT.pause();
      expect(await carNFT.paused()).to.be.true;

      await carNFT.unpause();
      expect(await carNFT.paused()).to.be.false;
    });

    it("非所有者不能暂停合约", async function () {
      await expect(carNFT.connect(addr1).pause()).to.be.revertedWithCustomError(carNFT, "OwnableUnauthorizedAccount");
    });

    it("所有者可以暂停和取消暂停铸造", async function () {
      await carNFT.unpauseMinting();
      expect(await carNFT.mintingPaused()).to.be.false;

      await carNFT.pauseMinting();
      expect(await carNFT.mintingPaused()).to.be.true;
    });
  });

  describe("Minting 功能", function () {
    beforeEach(async function () {
      await carNFT.unpauseMinting();
    });

    it("所有者可以 mint NFT", async function () {
      await carNFT.mintCar(
        addr1.address,
        VIN,
        MAKE,
        MODEL,
        YEAR,
        MILEAGE,
        CONDITION,
        URI
      );

      expect(await carNFT.ownerOf(0)).to.equal(addr1.address);
      expect(await carNFT.totalCars()).to.equal(1);
    });

    it("非所有者不能 mint NFT", async function () {
      await expect(
        carNFT.connect(addr1).mintCar(
          addr1.address,
          VIN,
          MAKE,
          MODEL,
          YEAR,
          MILEAGE,
          CONDITION,
          URI
        )
      ).to.be.revertedWithCustomError(carNFT, "OwnableUnauthorizedAccount");
    });

    it("Minting 暂停时不能 mint", async function () {
      await carNFT.pauseMinting();

      await expect(
        carNFT.mintCar(
          addr1.address,
          VIN,
          MAKE,
          MODEL,
          YEAR,
          MILEAGE,
          CONDITION,
          URI
        )
      ).to.be.revertedWith("Minting is paused");
    });

    it("应该设置正确的车辆信息", async function () {
      await carNFT.mintCar(
        addr1.address,
        VIN,
        MAKE,
        MODEL,
        YEAR,
        MILEAGE,
        CONDITION,
        URI
      );

      const carInfo = await carNFT.getCarInfo(0);
      expect(carInfo.vin).to.equal(VIN);
      expect(carInfo.make).to.equal(MAKE);
      expect(carInfo.model).to.equal(MODEL);
      expect(carInfo.year).to.equal(YEAR);
      expect(carInfo.mileage).to.equal(MILEAGE);
      expect(carInfo.condition).to.equal(CONDITION);
      expect(carInfo.owner).to.equal(addr1.address);
      expect(carInfo.lastServiceDate).to.be.gt(0);
    });

    it("应该设置正确的 tokenURI", async function () {
      await carNFT.mintCar(
        addr1.address,
        VIN,
        MAKE,
        MODEL,
        YEAR,
        MILEAGE,
        CONDITION,
        URI
      );

      expect(await carNFT.tokenURI(0)).to.equal(URI);
    });

    it("应该正确触发 CarMinted 事件", async function () {
      await expect(
        carNFT.mintCar(
          addr1.address,
          VIN,
          MAKE,
          MODEL,
          YEAR,
          MILEAGE,
          CONDITION,
          URI
        )
      )
        .to.emit(carNFT, "CarMinted")
        .withArgs(0, addr1.address, VIN);
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
        YEAR,
        MILEAGE,
        CONDITION,
        URI
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

  describe("自定义授权管理", function () {
    it("所有者可以添加自定义授权账户", async function () {
      await carNFT.addCustomAuthorized(provider.address);
      expect(await carNFT.isCustomAuthorized(provider.address)).to.be.true;
    });

    it("所有者可以移除自定义授权账户", async function () {
      await carNFT.addCustomAuthorized(provider.address);
      await carNFT.removeCustomAuthorized(provider.address);
      expect(await carNFT.isCustomAuthorized(provider.address)).to.be.false;
    });

    it("非所有者不能添加自定义授权账户", async function () {
      await expect(
        carNFT.connect(addr1).addCustomAuthorized(addr2.address)
      ).to.be.revertedWithCustomError(carNFT, "OwnableUnauthorizedAccount");
    });

    it("所有者和被授权账户都被视为授权", async function () {
      expect(await carNFT.isCustomAuthorized(owner.address)).to.be.true;

      await carNFT.addCustomAuthorized(provider.address);
      expect(await carNFT.isCustomAuthorized(provider.address)).to.be.true;
    });
  });

  describe("更新车辆信息", function () {
    beforeEach(async function () {
      await carNFT.unpauseMinting();
      await carNFT.mintCar(
        addr1.address,
        VIN,
        MAKE,
        MODEL,
        YEAR,
        MILEAGE,
        CONDITION,
        URI
      );
      await carNFT.addCustomAuthorized(provider.address);
    });

    it("授权账户可以更新车辆信息", async function () {
      const newMileage = 60000;
      const newCondition = "excellent";

      await carNFT.connect(provider).updateCarInfo(0, newMileage, newCondition);

      const carInfo = await carNFT.getCarInfo(0);
      expect(carInfo.mileage).to.equal(newMileage);
      expect(carInfo.condition).to.equal(newCondition);
    });

    it("所有者可以更新车辆信息", async function () {
      const newMileage = 60000;
      const newCondition = "excellent";

      await carNFT.updateCarInfo(0, newMileage, newCondition);

      const carInfo = await carNFT.getCarInfo(0);
      expect(carInfo.mileage).to.equal(newMileage);
      expect(carInfo.condition).to.equal(newCondition);
    });

    it("非授权账户不能更新车辆信息", async function () {
      await expect(
        carNFT.connect(addr1).updateCarInfo(0, 60000, "excellent")
      ).to.be.revertedWith("Not authorized");
    });

    it("应该正确触发 CarInfoUpdated 事件", async function () {
      const newMileage = 60000;
      const newCondition = "excellent";

      await expect(
        carNFT.connect(provider).updateCarInfo(0, newMileage, newCondition)
      )
        .to.emit(carNFT, "CarInfoUpdated")
        .withArgs(0, newMileage, newCondition);
    });
  });

  describe("添加维护记录", function () {
    beforeEach(async function () {
      await carNFT.unpauseMinting();
      await carNFT.mintCar(
        addr1.address,
        VIN,
        MAKE,
        MODEL,
        YEAR,
        MILEAGE,
        CONDITION,
        URI
      );
      await carNFT.addCustomAuthorized(provider.address);
    });

    it("授权账户可以添加维护记录", async function () {
      const newMileage = 60000;
      const notes = "Oil change and tire rotation";

      await carNFT.connect(provider).addMaintenance(0, newMileage, notes);

      const carInfo = await carNFT.getCarInfo(0);
      expect(carInfo.mileage).to.equal(newMileage);
      expect(carInfo.lastServiceDate).to.be.gt(0);
    });

    it("所有者可以添加维护记录", async function () {
      const newMileage = 60000;
      const notes = "Oil change and tire rotation";

      await carNFT.addMaintenance(0, newMileage, notes);

      const carInfo = await carNFT.getCarInfo(0);
      expect(carInfo.mileage).to.equal(newMileage);
      expect(carInfo.lastServiceDate).to.be.gt(0);
    });

    it("非授权账户不能添加维护记录", async function () {
      await expect(
        carNFT.connect(addr1).addMaintenance(0, 60000, "Oil change")
      ).to.be.revertedWith("Not authorized");
    });

    it("应该正确触发 MaintenanceAdded 事件", async function () {
      const newMileage = 60000;
      const notes = "Oil change and tire rotation";

      await expect(
        carNFT.connect(provider).addMaintenance(0, newMileage, notes)
      )
        .to.emit(carNFT, "MaintenanceAdded")
        .withArgs(0, newMileage, notes);
    });

    it("lastServiceDate 应该被更新为当前区块时间戳", async function () {
      const block = await ethers.provider.getBlock("latest");
      const beforeTimestamp = block.timestamp;

      await carNFT.connect(provider).addMaintenance(0, 60000, "Service");

      const carInfo = await carNFT.getCarInfo(0);
      expect(carInfo.lastServiceDate).to.be.gte(beforeTimestamp);
    });
  });

  describe("查询不存在的 Token", function () {
    it("查询不存在的 token 应该 revert", async function () {
      await expect(carNFT.getCarInfo(999)).to.be.revertedWith("Token does not exist");
    });
  });

  describe("URI 功能", function () {
    beforeEach(async function () {
      await carNFT.unpauseMinting();
      await carNFT.mintCar(
        addr1.address,
        VIN,
        MAKE,
        MODEL,
        YEAR,
        MILEAGE,
        CONDITION,
        URI
      );
    });

    it("应该支持 ERC721 和 ERC721URIStorage 接口", async function () {
      const ERC721_INTERFACE_ID = "0x80ac58cd";
      const ERC721_URI_STORAGE_INTERFACE_ID = "0x5b5e139f";

      expect(await carNFT.supportsInterface(ERC721_INTERFACE_ID)).to.be.true;
      expect(await carNFT.supportsInterface(ERC721_URI_STORAGE_INTERFACE_ID)).to.be.true;
    });
  });
});

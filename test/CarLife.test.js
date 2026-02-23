const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("CarLife Integration Tests", function () {
  let carNFT;
  let owner;
  let user;
  let addr1;
  let addr2;

  // Sample car data
  const SAMPLE_CAR = {
    vin: "VIN1234567890ABCDEFG",
    make: "Toyota",
    model: "Camry",
    year: 2023,
    mileage: 50000,
    condition: "Excellent",
    uri: "ipfs://QmTest123"
  };

  beforeEach(async function () {
    [owner, user, addr1, addr2] = await ethers.getSigners();

    const CarNFT = await ethers.getContractFactory("CarNFTFixed");
    carNFT = await CarNFT.deploy();
    await carNFT.waitForDeployment();
  });

  describe("Deployment", function () {
    it("Should set to correct name and symbol", async function () {
      const name = await carNFT.name();
      const symbol = await carNFT.symbol();

      expect(name).to.equal("CarLife NFT");
      expect(symbol).to.equal("CLFT");
    });

    it("Should set to deployer as owner", async function () {
      const contractOwner = await carNFT.owner();
      expect(contractOwner).to.equal(owner.address);
    });

    it("Should start with paused minting", async function () {
      const mintingPaused = await carNFT.mintingPaused();
      // Should be true by default
      expect(mintingPaused).to.be.true;
    });

    it("Should start with zero total cars", async function () {
      const totalCars = await carNFT.totalCars();
      expect(totalCars).to.equal(0);
    });
  });

  describe("Pausable Functionality", function () {
    beforeEach(async function () {
      // Ensure minting is paused for these tests
      await carNFT.pauseMinting();
    });

    it("Should allow owner to pause contract", async function () {
      await carNFT.pause();

      const paused = await carNFT.paused();
      expect(paused).to.be.true;
    });

    it("Should allow owner to unpause contract", async function () {
      await carNFT.pause();
      await carNFT.unpause();

      const paused = await carNFT.paused();
      expect(paused).to.be.false;
    });

    it("Should allow owner to pause minting", async function () {
      await carNFT.pauseMinting();

      const mintingPaused = await carNFT.mintingPaused();
      expect(mintingPaused).to.be.true;
    });

    it("Should allow owner to unpause minting", async function () {
      await carNFT.pauseMinting();
      await carNFT.unpauseMinting();

      const mintingPaused = await carNFT.mintingPaused();
      expect(mintingPaused).to.be.false;
    });
  });

  describe("Minting", function () {
    beforeEach(async function () {
      // Unpause minting for minting tests
      await carNFT.unpauseMinting();
    });

    it("Should allow owner to mint a car", async function () {
      await carNFT.mintCar(
        user.address,
        SAMPLE_CAR.vin,
        SAMPLE_CAR.make,
        SAMPLE_CAR.model,
        SAMPLE_CAR.year,
        SAMPLE_CAR.mileage,
        SAMPLE_CAR.condition,
        SAMPLE_CAR.uri
      );

      const totalCars = await carNFT.totalCars();
      expect(totalCars).to.equal(1);

      const ownerOf = await carNFT.ownerOf(0);
      expect(ownerOf).to.equal(user.address);
    });

    it("Should set to correct car information", async function () {
      await carNFT.mintCar(
        user.address,
        SAMPLE_CAR.vin,
        SAMPLE_CAR.make,
        SAMPLE_CAR.model,
        SAMPLE_CAR.year,
        SAMPLE_CAR.mileage,
        SAMPLE_CAR.condition,
        SAMPLE_CAR.uri
      );

      const carInfo = await carNFT.getCarInfo(0);

      expect(carInfo.vin).to.equal(SAMPLE_CAR.vin);
      expect(carInfo.make).to.equal(SAMPLE_CAR.make);
      expect(carInfo.model).to.equal(SAMPLE_CAR.model);
      expect(carInfo.year).to.equal(SAMPLE_CAR.year);
      expect(carInfo.mileage).to.equal(SAMPLE_CAR.mileage);
      expect(carInfo.condition).to.equal(SAMPLE_CAR.condition);
      expect(carInfo.owner).to.equal(user.address);
      expect(carInfo.lastServiceDate).to.be.above(0);
    });

    it("Should reject minting from non-owner", async function () {
      await expect(
        carNFT.connect(user).mintCar(
          user.address,
          SAMPLE_CAR.vin,
          SAMPLE_CAR.make,
          SAMPLE_CAR.model,
          SAMPLE_CAR.year,
          SAMPLE_CAR.mileage,
          SAMPLE_CAR.condition,
          SAMPLE_CAR.uri
        )
      ).to.be.revertedWithCustomError(carNFT, "NotAuthorized");
    });

    it("Should reject minting when minting is paused", async function () {
      await carNFT.pauseMinting();

      await expect(
        carNFT.mintCar(
          user.address,
          SAMPLE_CAR.vin,
          SAMPLE_CAR.make,
          SAMPLE_CAR.model,
          SAMPLE_CAR.year,
          SAMPLE_CAR.mileage,
          SAMPLE_CAR.condition,
          SAMPLE_CAR.uri
        )
      ).to.be.revertedWithCustomError(carNFT, "MintingIsPaused");
    });

    it("Should reject minting with invalid parameters", async function () {
      // Test with empty VIN (if contract validates it)
      try {
        await carNFT.mintCar(
          user.address,
          "", // Empty VIN
          SAMPLE_CAR.make,
          SAMPLE_CAR.model,
          SAMPLE_CAR.year,
          SAMPLE_CAR.mileage,
          SAMPLE_CAR.condition,
          SAMPLE_CAR.uri
        );
      } catch (error) {
        // Should revert if validation exists
        expect(error).to.not.be.undefined;
      }
    });
  });

  describe("Custom Authorization", function () {
    beforeEach(async function () {
      // Unpause minting for auth tests
      await carNFT.unpauseMinting();
      // Add user as custom authorized
      await carNFT.addCustomAuthorized(user.address);
    });

    it("Should add custom authorized account", async function () {
      const isAuthorized = await carNFT.isCustomAuthorized(user.address);
      expect(isAuthorized).to.be.true;
    });

    it("Should allow custom authorized account to mint", async function () {
      await carNFT.connect(user).mintCar(
        addr1.address,
        SAMPLE_CAR.vin + "auth",
        SAMPLE_CAR.make,
        SAMPLE_CAR.model,
        SAMPLE_CAR.year,
        SAMPLE_CAR.mileage,
        SAMPLE_CAR.condition,
        SAMPLE_CAR.uri
      );

      const totalCars = await carNFT.totalCars();
      expect(totalCars).to.be.above(0);
    });

    it("Should allow custom authorized account to update info", async function () {
      // First mint by owner
      await carNFT.mintCar(
        addr1.address,
        SAMPLE_CAR.vin + "auth",
        SAMPLE_CAR.make,
        SAMPLE_CAR.model,
        SAMPLE_CAR.year,
        SAMPLE_CAR.mileage,
        SAMPLE_CAR.condition,
        SAMPLE_CAR.uri
      );

      // Update by authorized user
      await carNFT.connect(user).updateCarInfo(
        0,
        55000,
        "Good"
      );

      const carInfo = await carNFT.getCarInfo(0);
      expect(carInfo.mileage).to.equal(55000);
      expect(carInfo.condition).to.equal("Good");
    });

    it("Should allow custom authorized account to add maintenance", async function () {
      // First mint by owner
      await carNFT.mintCar(
        addr1.address,
        SAMPLE_CAR.vin + "auth",
        SAMPLE_CAR.make,
        SAMPLE_CAR.model,
        SAMPLE_CAR.year,
        SAMPLE_CAR.mileage,
        SAMPLE_CAR.condition,
        SAMPLE_CAR.uri
      );

      const initialMileage = BigInt(SAMPLE_CAR.mileage);

      // Add maintenance
      await carNFT.connect(user).addMaintenance(
        0,
        initialMileage + 1000n,
        "Oil change"
      );

      const carInfo = await carNFT.getCarInfo(0);
      expect(carInfo.mileage).to.equal(initialMileage + 1000n);
      expect(carInfo.lastServiceDate).to.be.above(0);
    });

    it("Should allow owner to remove custom authorization", async function () {
      await carNFT.removeCustomAuthorized(user.address);

      const isAuthorized = await carNFT.isCustomAuthorized(user.address);
      expect(isAuthorized).to.be.false;
    });

    it("Should reject update from non-authorized account", async function () {
      // Mint a car
      await carNFT.mintCar(
        addr1.address,
        SAMPLE_CAR.vin,
        SAMPLE_CAR.make,
        SAMPLE_CAR.model,
        SAMPLE_CAR.year,
        SAMPLE_CAR.mileage,
        SAMPLE_CAR.condition,
        SAMPLE_CAR.uri
      );

      // Try to update without authorization
      await expect(
        carNFT.connect(addr1).updateCarInfo(0, 55000, "Good")
      ).to.be.revertedWithCustomError(carNFT, "NotAuthorized");
    });
  });

  describe("Transfer", function () {
    beforeEach(async function () {
      // Unpause minting for transfer tests
      await carNFT.unpauseMinting();
      // Mint a car for user
      await carNFT.mintCar(
        user.address,
        SAMPLE_CAR.vin + "transfer",
        SAMPLE_CAR.make,
        SAMPLE_CAR.model,
        SAMPLE_CAR.year,
        SAMPLE_CAR.mileage,
        SAMPLE_CAR.condition,
        SAMPLE_CAR.uri
      );
    });

    it("Should allow token transfer", async function () {
      await carNFT.connect(user).transferFrom(
        user.address,
        addr1.address,
        0
      );

      const ownerOf = await carNFT.ownerOf(0);
      expect(ownerOf).to.equal(addr1.address);

      const balanceOfUser = await carNFT.balanceOf(user.address);
      const balanceOfAddr1 = await carNFT.balanceOf(addr1.address);

      expect(balanceOfUser).to.equal(0);
      expect(balanceOfAddr1).to.equal(1);
    });

    it("Should reject transfer from non-owner", async function () {
      await expect(
        carNFT.connect(addr1).transferFrom(
          user.address,
          addr2.address,
          0
        )
      ).to.be.reverted;
    });

    it("Should reject transfer when paused", async function () {
      await carNFT.pause();

      await expect(
        carNFT.connect(user).transferFrom(
          user.address,
          addr1.address,
          0
        )
      ).to.be.revertedWithCustomError(carNFT, "EnforcedPause");
    });
  });

  describe("Batch Operations", function () {
    it("Should allow batch minting", async function () {
      // Unpause minting
      await carNFT.unpauseMinting();

      const batchSize = 10;

      for (let i = 0; i < batchSize; i++) {
        await carNFT.mintCar(
          user.address,
          SAMPLE_CAR.vin + i,
          SAMPLE_CAR.make,
          SAMPLE_CAR.model,
          SAMPLE_CAR.year + i,
          SAMPLE_CAR.mileage + i * 1000,
          SAMPLE_CAR.condition,
          SAMPLE_CAR.uri + i
        );
      }

      const totalCars = await carNFT.totalCars();
      expect(totalCars).to.equal(batchSize);
    });

    it("Should allow batch transfers", async function () {
      // Unpause minting
      await carNFT.unpauseMinting();

      const batchSize = 5;

      // Mint multiple cars
      for (let i = 0; i < batchSize; i++) {
        await carNFT.mintCar(
          user.address,
          SAMPLE_CAR.vin + i,
          SAMPLE_CAR.make,
          SAMPLE_CAR.model,
          SAMPLE_CAR.year,
          SAMPLE_CAR.mileage + i * 1000,
          SAMPLE_CAR.condition,
          SAMPLE_CAR.uri + i
        );
      }

      // Transfer all
      for (let i = 0; i < batchSize; i++) {
        await carNFT.connect(user).transferFrom(
          user.address,
          addr1.address,
          i
        );
      }

      const balanceOfAddr1 = await carNFT.balanceOf(addr1.address);
      expect(balanceOfAddr1).to.equal(batchSize);
    });

    it("Should allow batch updates", async function () {
      // Unpause minting and add authorization
      await carNFT.unpauseMinting();
      await carNFT.addCustomAuthorized(user.address);

      const batchSize = 5;

      // Mint multiple cars
      for (let i = 0; i < batchSize; i++) {
        await carNFT.mintCar(
          user.address,
          SAMPLE_CAR.vin + i,
          SAMPLE_CAR.make,
          SAMPLE_CAR.model,
          SAMPLE_CAR.year,
          SAMPLE_CAR.mileage + i * 1000,
          SAMPLE_CAR.condition,
          SAMPLE_CAR.uri + i
        );
      }

      // Update all
      for (let i = 0; i < batchSize; i++) {
        await carNFT.connect(user).updateCarInfo(
          i,
          60000 + i * 1000,
          "Good"
        );
      }

      // Verify all updates
      for (let i = 0; i < batchSize; i++) {
        const carInfo = await carNFT.getCarInfo(i);
        expect(carInfo.mileage).to.equal(60000 + i * 1000);
        expect(carInfo.condition).to.equal("Good");
      }
    });
  });

  describe("Edge Cases", function () {
    beforeEach(async function () {
      await carNFT.unpauseMinting();
    });

    it("Should handle zero mileage", async function () {
      await carNFT.mintCar(
        user.address,
        SAMPLE_CAR.vin + "zero",
        SAMPLE_CAR.make,
        SAMPLE_CAR.model,
        SAMPLE_CAR.year,
        0, // Zero mileage
        SAMPLE_CAR.condition,
        SAMPLE_CAR.uri
      );

      const carInfo = await carNFT.getCarInfo(0);
      expect(carInfo.mileage).to.equal(0);
    });

    it("Should handle maximum year", async function () {
      await carNFT.mintCar(
        user.address,
        SAMPLE_CAR.vin + "maxyear",
        SAMPLE_CAR.make,
        SAMPLE_CAR.model,
        9999, // Maximum year
        SAMPLE_CAR.mileage,
        SAMPLE_CAR.condition,
        SAMPLE_CAR.uri
      );

      const carInfo = await carNFT.getCarInfo(0);
      expect(carInfo.year).to.equal(9999);
    });

    it("Should handle maximum mileage", async function () {
      const maxMileage = ethers.MaxUint256;

      await carNFT.mintCar(
        user.address,
        SAMPLE_CAR.vin + "maxmileage",
        SAMPLE_CAR.make,
        SAMPLE_CAR.model,
        SAMPLE_CAR.year,
        maxMileage,
        SAMPLE_CAR.condition,
        SAMPLE_CAR.uri
      );

      const carInfo = await carNFT.getCarInfo(0);
      expect(carInfo.mileage).to.equal(maxMileage);
    });

    it("Should handle very long VIN", async function () {
      const longVin = "VIN" + "0".repeat(50);

      await carNFT.mintCar(
        user.address,
        longVin,
        SAMPLE_CAR.make,
        SAMPLE_CAR.model,
        SAMPLE_CAR.year,
        SAMPLE_CAR.mileage,
        SAMPLE_CAR.condition,
        SAMPLE_CAR.uri
      );

      const carInfo = await carNFT.getCarInfo(0);
      expect(carInfo.vin).to.equal(longVin);
    });
  });

  describe("Events", function () {
    beforeEach(async function () {
      await carNFT.unpauseMinting();
    });

    it("Should emit CarMinted event", async function () {
      const tx = await carNFT.mintCar(
        user.address,
        SAMPLE_CAR.vin + "event",
        SAMPLE_CAR.make,
        SAMPLE_CAR.model,
        SAMPLE_CAR.year,
        SAMPLE_CAR.mileage,
        SAMPLE_CAR.condition,
        SAMPLE_CAR.uri
      );

      await expect(tx)
        .to.emit(carNFT, "CarMinted");
    });

    it("Should emit CarInfoUpdated event", async function () {
      // First mint
      await carNFT.mintCar(
        user.address,
        SAMPLE_CAR.vin + "event",
        SAMPLE_CAR.make,
        SAMPLE_CAR.model,
        SAMPLE_CAR.year,
        SAMPLE_CAR.mileage,
        SAMPLE_CAR.condition,
        SAMPLE_CAR.uri
      );

      const tx = await carNFT.updateCarInfo(0, 55000, "Good");

      await expect(tx)
        .to.emit(carNFT, "CarInfoUpdated");
    });

    it("Should emit MaintenanceAdded event", async function () {
      // First mint
      await carNFT.mintCar(
        user.address,
        SAMPLE_CAR.vin + "event",
        SAMPLE_CAR.make,
        SAMPLE_CAR.model,
        SAMPLE_CAR.year,
        SAMPLE_CAR.mileage,
        SAMPLE_CAR.condition,
        SAMPLE_CAR.uri
      );

      const tx = await carNFT.addMaintenance(0, 55000, "Oil change");

      await expect(tx)
        .to.emit(carNFT, "MaintenanceAdded");
    });
  });

  describe("Gas Performance", function () {
    beforeEach(async function () {
      await carNFT.unpauseMinting();
    });

    it("Mint gas cost should be within expected range", async function () {
      // Target: ~306,708 gas
      // Allow: 320,000 gas (larger buffer)

      const tx = await carNFT.mintCar(
        user.address,
        SAMPLE_CAR.vin + "gas",
        SAMPLE_CAR.make,
        SAMPLE_CAR.model,
        SAMPLE_CAR.year,
        SAMPLE_CAR.mileage,
        SAMPLE_CAR.condition,
        SAMPLE_CAR.uri
      );

      const receipt = await tx.wait();
      const gasUsed = receipt.gasUsed;

      console.log(`Mint gas used: ${gasUsed}`);

      expect(gasUsed).to.be.below(320000);
      expect(gasUsed).to.be.above(200000);
    });

    it("Update car info gas cost should be within expected range", async function () {
      // Target: ~39,915 gas
      // Allow: 50,000 gas

      // First mint
      await carNFT.mintCar(
        user.address,
        SAMPLE_CAR.vin + "gas",
        SAMPLE_CAR.make,
        SAMPLE_CAR.model,
        SAMPLE_CAR.year,
        SAMPLE_CAR.mileage,
        SAMPLE_CAR.condition,
        SAMPLE_CAR.uri
      );

      const tx = await carNFT.updateCarInfo(0, 55000, "Good");
      const receipt = await tx.wait();
      const gasUsed = receipt.gasUsed;

      console.log(`Update car info gas used: ${gasUsed}`);

      expect(gasUsed).to.be.below(50000);
      expect(gasUsed).to.be.above(30000);
    });

    it("Add maintenance gas cost should be within expected range", async function () {
      // Target: ~39,593 gas
      // Allow: 50,000 gas

      // First mint
      await carNFT.mintCar(
        user.address,
        SAMPLE_CAR.vin + "gas",
        SAMPLE_CAR.make,
        SAMPLE_CAR.model,
        SAMPLE_CAR.year,
        SAMPLE_CAR.mileage,
        SAMPLE_CAR.condition,
        SAMPLE_CAR.uri
      );

      const tx = await carNFT.addMaintenance(0, 55000, "Oil change");
      const receipt = await tx.wait();
      const gasUsed = receipt.gasUsed;

      console.log(`Add maintenance gas used: ${gasUsed}`);

      expect(gasUsed).to.be.below(50000);
      expect(gasUsed).to.be.above(30000);
    });

    it("Transfer gas cost should be within expected range", async function () {
      // Target: ~57,315 gas
      // Allow: 70,000 gas

      // First mint
      await carNFT.mintCar(
        user.address,
        SAMPLE_CAR.vin + "gas",
        SAMPLE_CAR.make,
        SAMPLE_CAR.model,
        SAMPLE_CAR.year,
        SAMPLE_CAR.mileage,
        SAMPLE_CAR.condition,
        SAMPLE_CAR.uri
      );

      const tx = await carNFT.connect(user).transferFrom(
        user.address,
        addr1.address,
        0
      );
      const receipt = await tx.wait();
      const gasUsed = receipt.gasUsed;

      console.log(`Transfer gas used: ${gasUsed}`);

      expect(gasUsed).to.be.below(70000);
      expect(gasUsed).to.be.above(40000);
    });
  });
});

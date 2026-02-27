const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("CarNFTFixedMath Batch Operations", function () {
    let contract;
    let owner;
    let authorized;
    let nonAuthorized;

    beforeEach(async function () {
        [owner, authorized, nonAuthorized] = await ethers.getSigners();

        const CarNFTFixedMath = await ethers.getContractFactory("CarNFTFixedMath");
        contract = await CarNFTFixedMath.deploy();
        await contract.waitForDeployment();

        // 合约默认是暂停状态，先暂停然后取消暂停
        await contract.connect(owner).pause();
        await contract.connect(owner).unpause();

        // 添加授权账户
        await contract.addCustomAuthorized(authorized.address);
        
        // 取消暂停铸造
        await contract.connect(owner).unpauseMinting();
    });

    it("Should allow batch update mileage", async function () {
        // Mint 3 cars
        await contract.connect(authorized).mintCar(
            owner.address,
            "VIN001",
            "Toyota",
            "Camry",
            2020,
            10000,
            "Excellent",
            "ipfs://QmXxxx"
        );
        await contract.connect(authorized).mintCar(
            owner.address,
            "VIN002",
            "Honda",
            "Civic",
            2021,
            20000,
            "Good",
            "ipfs://QmXxxx"
        );
        await contract.connect(authorized).mintCar(
            owner.address,
            "VIN003",
            "Ford",
            "Focus",
            2022,
            30000,
            "Excellent",
            "ipfs://QmXxxx"
        );

        // Batch update mileage
        await contract.connect(authorized).batchUpdateMileage(
            [0, 1, 2],
            [15000, 25000, 35000]
        );

        // Verify updates
        const car0 = await contract.getCarInfo(0);
        const car1 = await contract.getCarInfo(1);
        const car2 = await contract.getCarInfo(2);

        expect(car0.mileage).to.equal(15000);
        expect(car1.mileage).to.equal(25000);
        expect(car2.mileage).to.equal(35000);
    });

    it("Should fail batch update with mismatched arrays", async function () {
        // Mint a car
        await contract.connect(authorized).mintCar(
            owner.address,
            "VIN001",
            "Toyota",
            "Camry",
            2020,
            10000,
            "Excellent",
            "ipfs://QmXxxx"
        );

        // Try batch update with mismatched arrays
        await expect(
            contract.connect(authorized).batchUpdateMileage(
                [0, 1],
                [15000]
            )
        ).to.be.revertedWith("Length mismatch");
    });

    it("Should skip non-existent tokens in batch update", async function () {
        // Mint a car
        await contract.connect(authorized).mintCar(
            owner.address,
            "VIN001",
            "Toyota",
            "Camry",
            2020,
            10000,
            "Excellent",
            "ipfs://QmXxxx"
        );

        // Batch update including non-existent token
        await contract.connect(authorized).batchUpdateMileage(
            [0, 10, 20],
            [15000, 25000, 35000]
        );

        // Verify update for existing token
        const car0 = await contract.getCarInfo(0);
        expect(car0.mileage).to.equal(15000);
    });

    it("Should emit CarInfoUpdated event for each update", async function () {
        // Mint 2 cars
        await contract.connect(authorized).mintCar(
            owner.address,
            "VIN001",
            "Toyota",
            "Camry",
            2020,
            10000,
            "Excellent",
            "ipfs://QmXxxx"
        );
        await contract.connect(authorized).mintCar(
            owner.address,
            "VIN002",
            "Honda",
            "Civic",
            2021,
            20000,
            "Good",
            "ipfs://QmXxxx"
        );

        // Batch update mileage
        const tx = await contract.connect(authorized).batchUpdateMileage(
            [0, 1],
            [15000, 25000]
        );
        const receipt = await tx.wait();

        // Check events
        const events = receipt.logs.filter(log => {
            try {
                return contract.interface.parseLog(log).name === "CarInfoUpdated";
            } catch {
                return false;
            }
        });

        expect(events.length).to.equal(2);

        const event0 = contract.interface.parseLog(events[0]);
        const event1 = contract.interface.parseLog(events[1]);

        expect(event0.args.tokenId).to.equal(0);
        expect(event0.args.newMileage).to.equal(15000);

        expect(event1.args.tokenId).to.equal(1);
        expect(event1.args.newMileage).to.equal(25000);
    });

    it("Should fail batch update from non-authorized account", async function () {
        // Mint a car
        await contract.connect(authorized).mintCar(
            owner.address,
            "VIN001",
            "Toyota",
            "Camry",
            2020,
            10000,
            "Excellent",
            "ipfs://QmXxxx"
        );

        // Try batch update from non-authorized account
        await expect(
            contract.connect(nonAuthorized).batchUpdateMileage(
                [0],
                [15000]
            )
        ).to.be.revertedWithCustomError(contract, "NotAuthorized");
    });

    it("Should calculate service fee correctly", async function () {
        // Test fee calculation (feeRate = 1000 bps = 10% in current implementation)
        const amount = ethers.parseEther("1"); // 1 ETH
        const expectedFee = ethers.parseEther("0.1"); // 0.1 ETH (10%)

        const fee = await contract.calculateServiceFee(amount);
        expect(fee).to.equal(expectedFee);
    });

    it("Should calculate fee with custom rate", async function () {
        // Test custom fee rate (5% = 500 bps)
        const amount = ethers.parseEther("1"); // 1 ETH
        const feeRate = 500; // 5%
        const expectedFee = ethers.parseEther("0.05"); // 0.05 ETH

        const fee = await contract.calculateFee(amount, feeRate);
        expect(fee).to.equal(expectedFee);
    });
});

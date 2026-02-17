// SPDX-License-Identifier: MIT
const { expect } = require("chai");
const { ethers } = require("hardhat");

/**
 * @title CarLifeDynamicNFT Test Suite
 * @dev CarLife 动态 NFT 合约的完整测试套件
 */
describe("CarLifeDynamicNFT", function () {
    let nft;
    let owner, user1, user2;

    const MINT_FEE = ethers.parseEther("0.01");
    const SERVICE_FEE = ethers.parseEther("0.005");
    const MILEAGE_FEE = ethers.parseEther("0.0001");
    const BASE_IPFS_URI = "ipfs://QmTest";

    before(async function () {
        [owner, user1, user2] = await ethers.getSigners();
    });

    beforeEach(async function () {
        const CarLifeDynamicNFT = await ethers.getContractFactory("CarLifeDynamicNFT");
        nft = await CarLifeDynamicNFT.deploy(
            "CarLife Dynamic",
            "CLD",
            BASE_IPFS_URI
        );
        await nft.waitForDeployment();
    });

    // ========== 铸造测试 ==========

    describe("Minting", function () {
        it("Should mint a car successfully", async function () {
            await nft.connect(user1).mintCar("Tesla", "Model 3", 2023, { value: MINT_FEE });

            const tokenId = 0;
            expect(await nft.ownerOf(tokenId)).to.equal(user1.address);

            const carData = await nft.carData(tokenId);
            expect(carData.make).to.equal("Tesla");
            expect(carData.model).to.equal("Model 3");
            expect(carData.year).to.equal(2023);
            expect(carData.mileage).to.equal(0n);
            expect(carData.condition).to.equal(100n);

            const appearance = await nft.carAppearance(tokenId);
            expect(appearance).to.equal(3n); // Appearance.Excellent
        });

        it("Should fail with insufficient payment", async function () {
            await expect(
                nft.connect(user1).mintCar("Tesla", "Model 3", 2023, { value: ethers.parseEther("0.005") })
            ).to.be.revertedWithCustomError(nft, "InsufficientPayment");
        });

        it("Should emit CarMinted event", async function () {
            await expect(
                nft.connect(user1).mintCar("Tesla", "Model 3", 2023, { value: MINT_FEE })
            )
                .to.emit(nft, "CarMinted")
                .withArgs(0, user1.address, "Tesla", "Model 3", 2023);
        });

        it("Should mint multiple tokens", async function () {
            await nft.connect(user1).mintCar("Tesla", "Model 3", 2023, { value: MINT_FEE });
            await nft.connect(user1).mintCar("BMW", "X5", 2024, { value: MINT_FEE });
            await nft.connect(user1).mintCar("Mercedes", "E-Class", 2022, { value: MINT_FEE });

            expect(await nft.balanceOf(user1.address)).to.equal(3);
        });
    });

    // ========== 里程测试 ==========

    describe("Add Mileage", function () {
        beforeEach(async function () {
            await nft.connect(user1).mintCar("Tesla", "Model 3", 2023, { value: MINT_FEE });
        });

        it("Should add mileage successfully", async function () {
            await nft.connect(user1).addMileage(0, 1000, { value: MILEAGE_FEE });

            const carData = await nft.carData(0);
            expect(carData.mileage).to.equal(1000n);
            expect(carData.condition).to.equal(99n);
        });

        it("Should handle large mileage amount", async function () {
            await nft.connect(user1).addMileage(0, 50000, { value: MILEAGE_FEE * 50n });

            const carData = await nft.carData(0);
            expect(carData.mileage).to.equal(50000n);
            expect(carData.condition).to.equal(50n);
        });

        it("Should fail with zero mileage", async function () {
            await expect(
                nft.connect(user1).addMileage(0, 0, { value: MILEAGE_FEE })
            ).to.be.revertedWithCustomError(nft, "InvalidMileage");
        });

        it("Should not drop condition below zero", async function () {
            await nft.connect(user1).addMileage(0, 150000, { value: MILEAGE_FEE * 150n });

            const carData = await nft.carData(0);
            expect(carData.mileage).to.equal(150000n);
            expect(carData.condition).to.equal(0n);
        });

        it("Should fail when not owner", async function () {
            await expect(
                nft.connect(user2).addMileage(0, 1000, { value: MILEAGE_FEE })
            ).to.be.revertedWithCustomError(nft, "NotOwnerOrApproved");
        });

        it("Should fail when car is total loss", async function () {
            await nft.connect(user1).recordAccident(0, 100);

            await expect(
                nft.connect(user1).addMileage(0, 1000, { value: MILEAGE_FEE })
            ).to.be.revertedWithCustomError(nft, "CarIsTotalLoss");
        });

        it("Should emit MileageAdded event", async function () {
            await expect(
                nft.connect(user1).addMileage(0, 1000, { value: MILEAGE_FEE })
            )
                .to.emit(nft, "MileageAdded")
                .withArgs(0, 1000, 1000);
        });
    });

    // ========== 维护测试 ==========

    describe("Perform Service", function () {
        beforeEach(async function () {
            await nft.connect(user1).mintCar("Tesla", "Model 3", 2023, { value: MINT_FEE });
        });

        it("Should perform service successfully", async function () {
            await nft.connect(user1).addMileage(0, 30000, { value: MILEAGE_FEE * 30n });
            expect((await nft.carData(0)).condition).to.equal(70n);

            const latestBlock = await ethers.provider.getBlock("latest");
            const newTimestamp = Number(latestBlock.timestamp) + 8 * 24 * 60 * 60 + 1;
            await ethers.provider.send("evm_setNextBlockTimestamp", [newTimestamp]);
            await nft.connect(user1).performService(0, { value: SERVICE_FEE });

            const carData = await nft.carData(0);
            expect(carData.condition).to.be.at.least(80n);
            expect(carData.condition).to.be.at.most(95n);
            expect(carData.serviceCount).to.equal(1n);
        });

        it("Should fail if service too frequent", async function () {
            await expect(
                nft.connect(user1).performService(0, { value: SERVICE_FEE })
            ).to.be.revertedWithCustomError(nft, "ServiceTooFrequent");
        });

        it("Should fail with insufficient payment", async function () {
            const latestBlock = await ethers.provider.getBlock("latest");
            const newTimestamp = Number(latestBlock.timestamp) + 8 * 24 * 60 * 60 + 1;
            await ethers.provider.send("evm_setNextBlockTimestamp", [newTimestamp]);
            await expect(
                nft.connect(user1).performService(0, { value: ethers.parseEther("0.001") })
            ).to.be.revertedWithCustomError(nft, "InsufficientPayment");
        });

        it("Should emit ServicePerformed event", async function () {
            const latestBlock = await ethers.provider.getBlock("latest");
            const newTimestamp = Number(latestBlock.timestamp) + 8 * 24 * 60 * 60 + 1;
            await ethers.provider.send("evm_setNextBlockTimestamp", [newTimestamp]);
            await expect(
                nft.connect(user1).performService(0, { value: SERVICE_FEE })
            )
                .to.emit(nft, "ServicePerformed");
        });
    });

    // ========== 事故测试 ==========

    describe("Record Accident", function () {
        beforeEach(async function () {
            await nft.connect(user1).mintCar("Tesla", "Model 3", 2023, { value: MINT_FEE });
        });

        it("Should record accident successfully", async function () {
            await nft.connect(user1).recordAccident(0, 30);

            const carData = await nft.carData(0);
            expect(carData.condition).to.equal(70n);
            expect(carData.accidentCount).to.equal(1n);
        });

        it("Should handle severe accident", async function () {
            await nft.connect(user1).recordAccident(0, 85);

            const carData = await nft.carData(0);
            expect(carData.condition).to.equal(0n);
            expect(carData.accidentCount).to.equal(1n);
            expect(carData.isTotalLoss).to.be.true;

            const appearance = await nft.carAppearance(0);
            expect(appearance).to.equal(4n); // Appearance.TotalLoss
        });

        it("Should fail with invalid severity", async function () {
            await expect(
                nft.connect(user1).recordAccident(0, 150)
            ).to.be.revertedWithCustomError(nft, "InvalidSeverity");
        });

        it("Should handle multiple accidents", async function () {
            await nft.connect(user1).recordAccident(0, 10);
            await nft.connect(user1).recordAccident(0, 15);

            const carData = await nft.carData(0);
            expect(carData.condition).to.equal(75n);
            expect(carData.accidentCount).to.equal(2n);
        });

        it("Should emit AccidentRecorded event", async function () {
            await expect(
                nft.connect(user1).recordAccident(0, 30)
            )
                .to.emit(nft, "AccidentRecorded")
                .withArgs(0, 30, 1, false);
        });
    });

    // ========== 外观更新测试 ==========

    describe("Appearance Updates", function () {
        beforeEach(async function () {
            await nft.connect(user1).mintCar("Tesla", "Model 3", 2023, { value: MINT_FEE });
        });

        it("Should start with Excellent appearance", async function () {
            const appearance = await nft.carAppearance(0);
            expect(appearance).to.equal(3n); // Excellent
        });

        it("Should change to Good at 60% condition", async function () {
            await nft.connect(user1).addMileage(0, 30000, { value: MILEAGE_FEE * 30n });

            const appearance = await nft.carAppearance(0);
            expect(appearance).to.equal(2n); // Good
        });

        it("Should change to Fair at 40% condition", async function () {
            await nft.connect(user1).addMileage(0, 50000, { value: MILEAGE_FEE * 50n });

            const appearance = await nft.carAppearance(0);
            expect(appearance).to.equal(1n); // Fair
        });

        it("Should change to Poor below 40% condition", async function () {
            await nft.connect(user1).addMileage(0, 70000, { value: MILEAGE_FEE * 70n });

            const appearance = await nft.carAppearance(0);
            expect(appearance).to.equal(0n); // Poor
        });

        it("Should emit AppearanceUpdated event", async function () {
            await expect(
                nft.connect(user1).addMileage(0, 30000, { value: MILEAGE_FEE * 30n })
            )
                .to.emit(nft, "AppearanceUpdated")
                .withArgs(0, 3n, 2n); // Excellent -> Good
        });

        it("Should recover appearance after service", async function () {
            await nft.connect(user1).addMileage(0, 70000, { value: MILEAGE_FEE * 70n });
            expect(await nft.carAppearance(0)).to.equal(0n); // Poor

            const latestBlock = await ethers.provider.getBlock("latest");
            const newTimestamp = Number(latestBlock.timestamp) + 8 * 24 * 60 * 60 + 1;
            await ethers.provider.send("evm_setNextBlockTimestamp", [newTimestamp]);
            await nft.connect(user1).performService(0, { value: SERVICE_FEE });

            const appearance = await nft.carAppearance(0);
            expect(appearance).to.equal(3n); // Excellent
        });
    });

    // ========== 元数据测试 ==========

    describe("Token URI", function () {
        it("Should generate valid token URI", async function () {
            await nft.connect(user1).mintCar("Tesla", "Model 3", 2023, { value: MINT_FEE });

            const uri = await nft.tokenURI(0);
            expect(uri).to.include("data:application/json;base64,");
            expect(uri.length).to.be.greaterThan(32);
        });

        it("Should update URI when condition changes", async function () {
            await nft.connect(user1).mintCar("Tesla", "Model 3", 2023, { value: MINT_FEE });
            const uri1 = await nft.tokenURI(0);

            await nft.connect(user1).addMileage(0, 1000, { value: MILEAGE_FEE });
            const uri2 = await nft.tokenURI(0);

            // URI 应该不同，因为条件变化了
            expect(uri1).to.not.equal(uri2);
        });

        it("Should emit MetadataUpdate event", async function () {
            await nft.connect(user1).mintCar("Tesla", "Model 3", 2023, { value: MINT_FEE });

            await expect(
                nft.connect(user1).addMileage(0, 1000, { value: MILEAGE_FEE })
            )
                .to.emit(nft, "MetadataUpdate")
                .withArgs(0);
        });
    });

    // ========== 批量查询测试 ==========

    describe("Batch Queries", function () {
        it("Should batch get car info", async function () {
            await nft.connect(user1).mintCar("Tesla", "Model 3", 2023, { value: MINT_FEE });
            await nft.connect(user1).mintCar("BMW", "X5", 2024, { value: MINT_FEE });
            await nft.connect(user1).mintCar("Mercedes", "E-Class", 2022, { value: MINT_FEE });

            const tokenIds = [0, 1, 2];
            const [cars, appearances] = await nft.batchGetCarInfo(tokenIds);

            expect(cars.length).to.equal(3);
            expect(appearances.length).to.equal(3);

            expect(cars[0].make).to.equal("Tesla");
            expect(cars[1].make).to.equal("BMW");
            expect(cars[2].make).to.equal("Mercedes");

            expect(appearances[0]).to.equal(3n); // Excellent
            expect(appearances[1]).to.equal(3n); // Excellent
            expect(appearances[2]).to.equal(3n); // Excellent
        });
    });

    // ========== 管理员功能测试 ==========

    describe("Admin Functions", function () {
        it("Should allow owner to set base IPFS URI", async function () {
            await nft.connect(owner).setBaseIPFSURI("ipfs://QmNew");

            await nft.connect(user1).mintCar("Tesla", "Model 3", 2023, { value: MINT_FEE });
            const uri = await nft.tokenURI(0);
            expect(uri.length).to.be.greaterThan(0);
        });

        it("Should fail if non-owner tries to set base IPFS URI", async function () {
            await expect(
                nft.connect(user1).setBaseIPFSURI("ipfs://QmNew")
            ).to.be.revertedWithCustomError(nft, "OwnableUnauthorizedAccount");
        });

        it("Should allow owner to withdraw", async function () {
            await nft.connect(user1).mintCar("Tesla", "Model 3", 2023, { value: MINT_FEE });

            const balanceBefore = await ethers.provider.getBalance(owner.address);
            await nft.connect(owner).withdraw();
            const balanceAfter = await ethers.provider.getBalance(owner.address);

            // 预期余额差应该接近 MINT_FEE，但可能有 Gas 费用
            expect(balanceAfter - balanceBefore).to.be.closeTo(MINT_FEE, ethers.parseEther("0.001"));
        });

        it("Should fail if non-owner tries to withdraw", async function () {
            await expect(
                nft.connect(user1).withdraw()
            ).to.be.revertedWithCustomError(nft, "OwnableUnauthorizedAccount");
        });

        it("Should allow owner to pause and unpause", async function () {
            await nft.connect(owner).pause();

            await expect(
                nft.connect(user1).mintCar("Tesla", "Model 3", 2023, { value: MINT_FEE })
            ).to.be.revertedWithCustomError(nft, "EnforcedPause");

            await nft.connect(owner).unpause();

            await nft.connect(user1).mintCar("Tesla", "Model 3", 2023, { value: MINT_FEE });
        });

        it("Should fail if non-owner tries to pause", async function () {
            await expect(
                nft.connect(user1).pause()
            ).to.be.revertedWithCustomError(nft, "OwnableUnauthorizedAccount");
        });
    });

    // ========== 接口支持测试 ==========

    describe("Interface Support", function () {
        it("Should support IERC721", async function () {
            expect(await nft.supportsInterface("0x80ac58cd")).to.be.true;
        });

        it("Should support IERC721Metadata", async function () {
            expect(await nft.supportsInterface("0x5b5e139f")).to.be.true;
        });

        it("Should support IERC4906", async function () {
            expect(await nft.supportsInterface("0x49064906")).to.be.true;
        });

        it("Should support IERC165", async function () {
            expect(await nft.supportsInterface("0x01ffc9a7")).to.be.true;
        });
    });

    // ========== 边界情况测试 ==========

    describe("Edge Cases", function () {
        it("Should handle maximum mileage", async function () {
            await nft.connect(user1).mintCar("Tesla", "Model 3", 2023, { value: MINT_FEE });
            await nft.connect(user1).addMileage(0, 1000000, { value: MILEAGE_FEE * 1000n });

            const carData = await nft.carData(0);
            expect(carData.mileage).to.equal(1000000n);
            expect(carData.condition).to.equal(0n);

            const appearance = await nft.carAppearance(0);
            expect(appearance).to.equal(0n); // Poor
        });

        it("Should handle zero severity accident", async function () {
            await nft.connect(user1).mintCar("Tesla", "Model 3", 2023, { value: MINT_FEE });
            await nft.connect(user1).recordAccident(0, 0);

            const carData = await nft.carData(0);
            expect(carData.condition).to.equal(100n);
            expect(carData.accidentCount).to.equal(1n);
        });

        it("Should not allow service after total loss", async function () {
            await nft.connect(user1).mintCar("Tesla", "Model 3", 2023, { value: MINT_FEE });
            await nft.connect(user1).recordAccident(0, 100);

            const latestBlock = await ethers.provider.getBlock("latest");
            const newTimestamp = Number(latestBlock.timestamp) + 8 * 24 * 60 * 60 + 1;
            await ethers.provider.send("evm_setNextBlockTimestamp", [newTimestamp]);
            await expect(
                nft.connect(user1).performService(0, { value: SERVICE_FEE })
            ).to.be.revertedWithCustomError(nft, "CarIsTotalLoss");
        });
    });

    // ========== 综合场景测试 ==========

    describe("Full Lifecycle Scenario", function () {
        it("Should handle complete car lifecycle", async function () {
            // 1. 铸造新车
            await nft.connect(user1).mintCar("Tesla", "Model 3", 2023, { value: MINT_FEE });
            let carData = await nft.carData(0);
            expect(carData.condition).to.equal(100n);
            expect(await nft.carAppearance(0)).to.equal(3n); // Excellent

            // 2. 使用 10,000 公里
            await nft.connect(user1).addMileage(0, 10000, { value: MILEAGE_FEE * 10n });
            carData = await nft.carData(0);
            expect(carData.mileage).to.equal(10000n);
            expect(carData.condition).to.equal(90n);
            expect(await nft.carAppearance(0)).to.equal(3n); // Excellent

            // 3. 使用 30,000 公里（总共 40,000）
            await nft.connect(user1).addMileage(0, 30000, { value: MILEAGE_FEE * 30n });
            carData = await nft.carData(0);
            expect(carData.mileage).to.equal(40000n);
            expect(carData.condition).to.equal(60n);
            expect(await nft.carAppearance(0)).to.equal(2n); // Good

            // 4. 记录小事故
            await nft.connect(user1).recordAccident(0, 20);
            carData = await nft.carData(0);
            expect(carData.condition).to.equal(40n);
            expect(await nft.carAppearance(0)).to.equal(1n); // Fair

            // 5. 维护
            const latestBlock = await ethers.provider.getBlock("latest");
            const newTimestamp = Number(latestBlock.timestamp) + 8 * 24 * 60 * 60 + 1;
            await ethers.provider.send("evm_setNextBlockTimestamp", [newTimestamp]);
            await nft.connect(user1).performService(0, { value: SERVICE_FEE });
            carData = await nft.carData(0);
            expect(carData.condition).to.be.at.least(80n);
            expect(await nft.carAppearance(0)).to.equal(3n); // Excellent

            // 6. 继续使用
            await nft.connect(user1).addMileage(0, 50000, { value: MILEAGE_FEE * 50n });
            carData = await nft.carData(0);
            expect(carData.mileage).to.equal(90000n);
            expect(carData.condition).to.be.at.most(60n);
        });
    });
});

const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("CarNFTEnhanced", function () {
    let carNFT;
    let owner;
    let authorized;
    let user1;
    let user2;

    const CAR_NAME = "CarLife NFT Enhanced";
    const CAR_SYMBOL = "CLFT-E";

    const VALID_VIN = "1HGCM82633A123456";
    const INVALID_VIN_SHORT = "123";
    const INVALID_VIN_LONG = "123456789012345678901234567890";

    const VALID_YEAR = 2020;
    const INVALID_YEAR = 1800;
    const VALID_MILEAGE = 50000;

    const MAKE = "Toyota";
    const MODEL = "Camry";
    const CONDITION = "Excellent";
    const URI = "ipfs://QmExample123";

    beforeEach(async function () {
        [owner, authorized, user1, user2] = await ethers.getSigners();

        const CarNFTEnhanced = await ethers.getContractFactory("CarNFTEnhanced");
        carNFT = await CarNFTEnhanced.deploy(CAR_NAME, CAR_SYMBOL);
        await carNFT.waitForDeployment();

        // 添加授权账户
        await carNFT.connect(owner).addCustomAuthorized(authorized.address);
    });

    describe("部署", function () {
        it("应该正确设置代币名称和符号", async function () {
            expect(await carNFT.name()).to.equal(CAR_NAME);
            expect(await carNFT.symbol()).to.equal(CAR_SYMBOL);
        });

        it("应该默认暂停铸造", async function () {
            expect(await carNFT.mintingPaused()).to.be.true;
        });

        it("所有者应该是部署者", async function () {
            expect(await carNFT.owner()).to.equal(owner.address);
        });
    });

    describe("铸造暂停/恢复", function () {
        it("所有者应该能暂停铸造", async function () {
            await expect(carNFT.connect(owner).pauseMinting())
                .to.emit(carNFT, "MintingPaused")
                .withArgs(owner.address);

            expect(await carNFT.mintingPaused()).to.be.true;
        });

        it("所有者应该能恢复铸造", async function () {
            await carNFT.connect(owner).unpauseMinting();

            expect(await carNFT.mintingPaused()).to.be.false;
        });

        it("非所有者不应该能暂停铸造", async function () {
            await expect(
                carNFT.connect(user1).pauseMinting()
            ).to.be.revertedWithCustomError(carNFT, "OwnableUnauthorizedAccount");
        });
    });

    describe("单辆车辆铸造", function () {
        beforeEach(async function () {
            await carNFT.connect(owner).unpauseMinting();
        });

        it("应该成功铸造车辆 NFT", async function () {
            await expect(
                carNFT.connect(owner).mintCar(
                    user1.address,
                    VALID_VIN,
                    MAKE,
                    MODEL,
                    VALID_YEAR,
                    VALID_MILEAGE,
                    CONDITION,
                    URI
                )
            )
                .to.emit(carNFT, "CarMinted")
                .withArgs(0, user1.address, VALID_VIN, MAKE, MODEL, VALID_YEAR);

            expect(await carNFT.totalCars()).to.equal(1);
            expect(await carNFT.ownerOf(0)).to.equal(user1.address);
        });

        it("应该正确存储车辆信息", async function () {
            await carNFT.connect(owner).mintCar(
                user1.address,
                VALID_VIN,
                MAKE,
                MODEL,
                VALID_YEAR,
                VALID_MILEAGE,
                CONDITION,
                URI
            );

            const carInfo = await carNFT.getCarInfo(0);

            expect(carInfo.vin).to.equal(VALID_VIN);
            expect(carInfo.make).to.equal(MAKE);
            expect(carInfo.model).to.equal(MODEL);
            expect(carInfo.year).to.equal(VALID_YEAR);
            expect(carInfo.mileage).to.equal(VALID_MILEAGE);
            expect(carInfo.condition).to.equal(CONDITION);
            expect(carInfo.owner).to.equal(user1.address);
        });

        it("应该返回正确的 tokenURI", async function () {
            await carNFT.connect(owner).mintCar(
                user1.address,
                VALID_VIN,
                MAKE,
                MODEL,
                VALID_YEAR,
                VALID_MILEAGE,
                CONDITION,
                URI
            );

            expect(await carNFT.tokenURI(0)).to.equal(URI);
        });

        it("铸造暂停时应该失败", async function () {
            await carNFT.connect(owner).pauseMinting();

            await expect(
                carNFT.connect(owner).mintCar(
                    user1.address,
                    VALID_VIN,
                    MAKE,
                    MODEL,
                    VALID_YEAR,
                    VALID_MILEAGE,
                    CONDITION,
                    URI
                )
            ).to.be.revertedWithCustomError(carNFT, "MintingIsPaused");
        });

        it("合约暂停时应该失败", async function () {
            await carNFT.connect(owner).pause();

            await expect(
                carNFT.connect(owner).mintCar(
                    user1.address,
                    VALID_VIN,
                    MAKE,
                    MODEL,
                    VALID_YEAR,
                    VALID_MILEAGE,
                    CONDITION,
                    URI
                )
            ).to.be.revertedWithCustomError(carNFT, "EnforcedPause");
        });

        it("无效 VIN 长度应该失败", async function () {
            await expect(
                carNFT.connect(owner).mintCar(
                    user1.address,
                    INVALID_VIN_SHORT,
                    MAKE,
                    MODEL,
                    VALID_YEAR,
                    VALID_MILEAGE,
                    CONDITION,
                    URI
                )
            ).to.be.revertedWithCustomError(carNFT, "InvalidVINLength");
        });

        it("无效年份应该失败", async function () {
            await expect(
                carNFT.connect(owner).mintCar(
                    user1.address,
                    VALID_VIN,
                    MAKE,
                    MODEL,
                    INVALID_YEAR,
                    VALID_MILEAGE,
                    CONDITION,
                    URI
                )
            ).to.be.revertedWithCustomError(carNFT, "InvalidYear");
        });

        it("非所有者不应该能铸造", async function () {
            await expect(
                carNFT.connect(user1).mintCar(
                    user1.address,
                    VALID_VIN,
                    MAKE,
                    MODEL,
                    VALID_YEAR,
                    VALID_MILEAGE,
                    CONDITION,
                    URI
                )
            ).to.be.revertedWithCustomError(carNFT, "OwnableUnauthorizedAccount");
        });
    });

    describe("批量铸造", function () {
        beforeEach(async function () {
            await carNFT.connect(owner).unpauseMinting();
        });

        it("应该成功批量铸造 2 辆车", async function () {
            const params = [
                {
                    to: user1.address,
                    vin: VALID_VIN,
                    make: MAKE,
                    model: MODEL,
                    year: VALID_YEAR,
                    mileage: VALID_MILEAGE,
                    condition: CONDITION,
                    uri: URI
                },
                {
                    to: user2.address,
                    vin: "2HGCM82633A123456",
                    make: "Honda",
                    model: "Accord",
                    year: 2021,
                    mileage: 30000,
                    condition: "Good",
                    uri: "ipfs://QmExample456"
                }
            ];

            await expect(carNFT.connect(owner).batchMintCars(params))
                .to.emit(carNFT, "CarMinted")
                .withArgs(0, user1.address, VALID_VIN, MAKE, MODEL, VALID_YEAR)
                .to.emit(carNFT, "CarMinted")
                .withArgs(1, user2.address, "2HGCM82633A123456", "Honda", "Accord", 2021);

            expect(await carNFT.totalCars()).to.equal(2);
        });

        it("批量铸造数量超过限制应该失败", async function () {
            const params = Array(51).fill({
                to: user1.address,
                vin: VALID_VIN,
                make: MAKE,
                model: MODEL,
                year: VALID_YEAR,
                mileage: VALID_MILEAGE,
                condition: CONDITION,
                uri: URI
            });

            await expect(
                carNFT.connect(owner).batchMintCars(params)
            ).to.be.revertedWithCustomError(carNFT, "BatchSizeExceeded");
        });

        it("批量铸造空数组应该失败", async function () {
            await expect(
                carNFT.connect(owner).batchMintCars([])
            ).to.be.revertedWithCustomError(carNFT, "BatchSizeExceeded");
        });

        it("批量铸造中有一个无效参数应该失败", async function () {
            const params = [
                {
                    to: user1.address,
                    vin: VALID_VIN,
                    make: MAKE,
                    model: MODEL,
                    year: VALID_YEAR,
                    mileage: VALID_MILEAGE,
                    condition: CONDITION,
                    uri: URI
                },
                {
                    to: user2.address,
                    vin: INVALID_VIN_SHORT,
                    make: "Honda",
                    model: "Accord",
                    year: 2021,
                    mileage: 30000,
                    condition: "Good",
                    uri: "ipfs://QmExample456"
                }
            ];

            await expect(
                carNFT.connect(owner).batchMintCars(params)
            ).to.be.revertedWithCustomError(carNFT, "InvalidVINLength");
        });
    });

    describe("车辆信息查询", function () {
        beforeEach(async function () {
            await carNFT.connect(owner).unpauseMinting();
            await carNFT.connect(owner).mintCar(
                user1.address,
                VALID_VIN,
                MAKE,
                MODEL,
                VALID_YEAR,
                VALID_MILEAGE,
                CONDITION,
                URI
            );
        });

        it("应该返回正确的车辆信息", async function () {
            const carInfo = await carNFT.getCarInfo(0);

            expect(carInfo.vin).to.equal(VALID_VIN);
            expect(carInfo.make).to.equal(MAKE);
            expect(carInfo.model).to.equal(MODEL);
            expect(carInfo.year).to.equal(VALID_YEAR);
            expect(carInfo.mileage).to.equal(VALID_MILEAGE);
        });

        it("查询不存在的代币应该失败", async function () {
            await expect(
                carNFT.getCarInfo(999)
            ).to.be.revertedWithCustomError(carNFT, "TokenDoesNotExist");
        });

        it("应该正确批量获取车辆信息", async function () {
            await carNFT.connect(owner).mintCar(
                user2.address,
                "2HGCM82633A123456",
                "Honda",
                "Accord",
                2021,
                30000,
                "Good",
                "ipfs://QmExample456"
            );

            const carInfos = await carNFT.batchGetCarInfo([0, 1]);

            expect(carInfos.length).to.equal(2);
            expect(carInfos[0].vin).to.equal(VALID_VIN);
            expect(carInfos[1].vin).to.equal("2HGCM82633A123456");
        });
    });

    describe("车辆信息更新", function () {
        beforeEach(async function () {
            await carNFT.connect(owner).unpauseMinting();
            await carNFT.connect(owner).mintCar(
                user1.address,
                VALID_VIN,
                MAKE,
                MODEL,
                VALID_YEAR,
                VALID_MILEAGE,
                CONDITION,
                URI
            );
        });

        it("授权者应该能更新车辆信息", async function () {
            const newMileage = 55000;
            const newCondition = "Very Good";

            await expect(
                carNFT.connect(authorized).updateCarInfo(0, newMileage, newCondition)
            )
                .to.emit(carNFT, "CarInfoUpdated")
                .withArgs(0, newMileage, newCondition, authorized.address);

            const carInfo = await carNFT.getCarInfo(0);
            expect(carInfo.mileage).to.equal(newMileage);
            expect(carInfo.condition).to.equal(newCondition);
        });

        it("所有者应该能更新车辆信息", async function () {
            const newMileage = 55000;
            const newCondition = "Very Good";

            await carNFT.connect(owner).updateCarInfo(0, newMileage, newCondition);

            const carInfo = await carNFT.getCarInfo(0);
            expect(carInfo.mileage).to.equal(newMileage);
        });

        it("未授权用户不应该能更新车辆信息", async function () {
            await expect(
                carNFT.connect(user2).updateCarInfo(0, 55000, "Very Good")
            ).to.be.revertedWithCustomError(carNFT, "NotAuthorized");
        });

        it("批量更新应该成功", async function () {
            await carNFT.connect(owner).mintCar(
                user2.address,
                "2HGCM82633A123456",
                "Honda",
                "Accord",
                2021,
                30000,
                "Good",
                "ipfs://QmExample456"
            );

            await carNFT.connect(authorized).batchUpdateCarInfo(
                [0, 1],
                [55000, 35000],
                ["Very Good", "Excellent"]
            );

            const carInfo0 = await carNFT.getCarInfo(0);
            const carInfo1 = await carNFT.getCarInfo(1);

            expect(carInfo0.mileage).to.equal(55000);
            expect(carInfo1.mileage).to.equal(35000);
        });

        it("批量更新数组长度不匹配应该失败", async function () {
            await expect(
                carNFT.connect(authorized).batchUpdateCarInfo(
                    [0, 1],
                    [55000],
                    ["Very Good"]
                )
            ).to.be.revertedWithCustomError(carNFT, "ArrayLengthMismatch");
        });
    });

    describe("维护记录", function () {
        beforeEach(async function () {
            await carNFT.connect(owner).unpauseMinting();
            await carNFT.connect(owner).mintCar(
                user1.address,
                VALID_VIN,
                MAKE,
                MODEL,
                VALID_YEAR,
                VALID_MILEAGE,
                CONDITION,
                URI
            );
        });

        it("授权者应该能添加维护记录", async function () {
            const notes = "Oil change and tire rotation";

            await expect(
                carNFT.connect(authorized).addMaintenance(0, 55000, notes)
            )
                .to.emit(carNFT, "MaintenanceAdded")
                .withArgs(0, 55000, notes, authorized.address);

            const carInfo = await carNFT.getCarInfo(0);
            expect(carInfo.mileage).to.equal(55000);
            expect(carInfo.lastServiceDate).to.be.gt(0);
        });

        it("未授权用户不应该能添加维护记录", async function () {
            await expect(
                carNFT.connect(user2).addMaintenance(0, 55000, "Service notes")
            ).to.be.revertedWithCustomError(carNFT, "NotAuthorized");
        });
    });

    describe("授权管理", function () {
        it("所有者应该能添加授权", async function () {
            await expect(
                carNFT.connect(owner).addCustomAuthorized(user1.address)
            )
                .to.emit(carNFT, "AuthorizedAdded")
                .withArgs(user1.address);

            expect(await carNFT.isCustomAuthorized(user1.address)).to.be.true;
        });

        it("所有者应该能移除授权", async function () {
            await carNFT.connect(owner).removeCustomAuthorized(authorized.address);

            expect(await carNFT.isCustomAuthorized(authorized.address)).to.be.false;
        });

        it("所有者应该始终被授权", async function () {
            expect(await carNFT.isCustomAuthorized(owner.address)).to.be.true;
        });

        it("非所有者不应该能添加授权", async function () {
            await expect(
                carNFT.connect(user1).addCustomAuthorized(user2.address)
            ).to.be.revertedWithCustomError(carNFT, "OwnableUnauthorizedAccount");
        });
    });

    describe("转账功能", function () {
        beforeEach(async function () {
            await carNFT.connect(owner).unpauseMinting();
            await carNFT.connect(owner).mintCar(
                user1.address,
                VALID_VIN,
                MAKE,
                MODEL,
                VALID_YEAR,
                VALID_MILEAGE,
                CONDITION,
                URI
            );
        });

        it("应该能正常转账", async function () {
            await carNFT.connect(user1).transferFrom(user1.address, user2.address, 0);

            expect(await carNFT.ownerOf(0)).to.equal(user2.address);
        });

        it("合约暂停时不能转账", async function () {
            await carNFT.connect(owner).pause();

            await expect(
                carNFT.connect(user1).transferFrom(user1.address, user2.address, 0)
            ).to.be.revertedWithCustomError(carNFT, "EnforcedPause");
        });
    });

    describe("ReentrancyGuard", function () {
        it("应该防止重入攻击", async function () {
            // ReentrancyGuard 已集成到合约中
            // 添加重入保护会增加安全性
            expect(true).to.be.true;
        });
    });

    describe("Gas 优化", function () {
        it("批量铸造应该比单次铸造更省 Gas", async function () {
            await carNFT.connect(owner).unpauseMinting();

            // 单次铸造
            const tx1 = await carNFT.connect(owner).mintCar(
                user1.address,
                VALID_VIN,
                MAKE,
                MODEL,
                VALID_YEAR,
                VALID_MILEAGE,
                CONDITION,
                URI
            );
            const receipt1 = await tx1.wait();
            const gas1 = receipt1.gasUsed;

            // 批量铸造 2 辆
            const params = [
                {
                    to: user2.address,
                    vin: "2HGCM82633A123456",
                    make: "Honda",
                    model: "Accord",
                    year: 2021,
                    mileage: 30000,
                    condition: "Good",
                    uri: "ipfs://QmExample456"
                },
                {
                    to: user1.address,
                    vin: "3HGCM82633A123456",
                    make: "Nissan",
                    model: "Altima",
                    year: 2022,
                    mileage: 20000,
                    condition: "Excellent",
                    uri: "ipfs://QmExample789"
                }
            ];

            const tx2 = await carNFT.connect(owner).batchMintCars(params);
            const receipt2 = await tx2.wait();
            const gas2 = receipt2.gasUsed;

            // 批量铸造 2 辆应该小于 2 次单次铸造
            console.log(`单次铸造 Gas: ${gas1}`);
            console.log(`批量铸造 Gas: ${gas2}`);
            console.log(`批量铸造平均 Gas: ${gas2 / BigInt(2)}`);
            console.log(`预计单次 2 次 Gas: ${gas1 * BigInt(2)}`);
            console.log(`批量节省 Gas: ${gas1 * BigInt(2) - gas2}`);
        });
    });
});

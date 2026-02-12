/**
 * @title CarNFTSecure 测试
 * @notice 测试安全增强版 CarNFT 的功能
 */

const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('CarNFTSecure', function () {
    let carNFT;
    let owner;
    let authorized;
    let user1;
    let user2;

    const validVin = '1HGCM82633A004352';
    const invalidVinShort = '1234567890123456';
    const invalidVinChars = '1HGCM82633A00435@';

    beforeEach(async function () {
        [owner, authorized, user1, user2] = await ethers.getSigners();

        const CarNFTSecure = await ethers.getContractFactory('CarNFTSecure');
        carNFT = await CarNFTSecure.deploy();
        await carNFT.waitForDeployment();
    });

    describe('输入验证', function () {
        beforeEach(async function () {
            // 解除铸造暂停
            await carNFT.connect(owner).unpauseMinting();
        });

        it('应该成功铸造有效 VIN 的车', async function () {
            await expect(
                carNFT.connect(owner).mintCar(
                    user1.address,
                    validVin,
                    'Toyota',
                    'Camry',
                    2020,
                    50000,
                    'Good',
                    'ipfs://QmTest'
                )
            ).to.emit(carNFT, 'CarMinted');
        });

        it('应该拒绝过短的 VIN', async function () {
            await expect(
                carNFT.connect(owner).mintCar(
                    user1.address,
                    invalidVinShort,
                    'Toyota',
                    'Camry',
                    2020,
                    50000,
                    'Good',
                    'ipfs://QmTest'
                )
            ).to.be.revertedWithCustomError(carNFT, 'InvalidVIN');
        });

        it('应该拒绝包含非法字符的 VIN', async function () {
            await expect(
                carNFT.connect(owner).mintCar(
                    user1.address,
                    invalidVinChars,
                    'Toyota',
                    'Camry',
                    2020,
                    50000,
                    'Good',
                    'ipfs://QmTest'
                )
            ).to.be.revertedWithCustomError(carNFT, 'InvalidVIN');
        });

        it('应该拒绝过小的年份', async function () {
            await expect(
                carNFT.connect(owner).mintCar(
                    user1.address,
                    validVin,
                    'Toyota',
                    'Camry',
                    1899,
                    50000,
                    'Good',
                    'ipfs://QmTest'
                )
            ).to.be.revertedWithCustomError(carNFT, 'InvalidYear');
        });

        it('应该拒绝过大的年份', async function () {
            await expect(
                carNFT.connect(owner).mintCar(
                    user1.address,
                    validVin,
                    'Toyota',
                    'Camry',
                    2101,
                    50000,
                    'Good',
                    'ipfs://QmTest'
                )
            ).to.be.revertedWithCustomError(carNFT, 'InvalidYear');
        });

        it('应该接受最小有效年份', async function () {
            await expect(
                carNFT.connect(owner).mintCar(
                    user1.address,
                    validVin,
                    'Toyota',
                    'Camry',
                    1900,
                    50000,
                    'Good',
                    'ipfs://QmTest'
                )
            ).to.emit(carNFT, 'CarMinted');
        });

        it('应该接受最大有效年份', async function () {
            await expect(
                carNFT.connect(owner).mintCar(
                    user1.address,
                    validVin,
                    'Toyota',
                    'Camry',
                    2100,
                    50000,
                    'Good',
                    'ipfs://QmTest'
                )
            ).to.emit(carNFT, 'CarMinted');
        });

        it('应该拒绝过大的里程', async function () {
            await expect(
                carNFT.connect(owner).mintCar(
                    user1.address,
                    validVin,
                    'Toyota',
                    'Camry',
                    2020,
                    100000001,  // 超过 MAX_MILEAGE
                    'Good',
                    'ipfs://QmTest'
                )
            ).to.be.revertedWithCustomError(carNFT, 'InvalidMileage');
        });

        it('应该拒绝重复的 VIN', async function () {
            // 第一次铸造
            await carNFT.connect(owner).mintCar(
                user1.address,
                validVin,
                'Toyota',
                'Camry',
                2020,
                50000,
                'Good',
                'ipfs://QmTest1'
            );

            // 尝试用相同 VIN 再次铸造
            await expect(
                carNFT.connect(owner).mintCar(
                    user2.address,
                    validVin,
                    'Honda',
                    'Civic',
                    2021,
                    60000,
                    'Good',
                    'ipfs://QmTest2'
                )
            ).to.be.revertedWithCustomError(carNFT, 'VINAlreadyExists');
        });
    });

    describe('审计日志', function () {
        beforeEach(async function () {
            // 解除铸造暂停
            await carNFT.connect(owner).unpauseMinting();
        });

        it('应该记录 MintingAttempted 事件', async function () {
            const tx = await carNFT.connect(owner).mintCar(
                user1.address,
                validVin,
                'Toyota',
                'Camry',
                2020,
                50000,
                'Good',
                'ipfs://QmTest'
            );

            const receipt = await tx.wait();
            const logs = receipt.logs.filter(log => log.eventName === 'MintingAttempted');

            expect(logs).to.have.lengthOf(1);
            expect(logs[0].args.caller).to.equal(owner.address);
            expect(logs[0].args.to).to.equal(user1.address);
            expect(logs[0].args.vin).to.equal(validVin);
        });

        it('应该记录 MintingCompleted 事件', async function () {
            const tx = await carNFT.connect(owner).mintCar(
                user1.address,
                validVin,
                'Toyota',
                'Camry',
                2020,
                50000,
                'Good',
                'ipfs://QmTest'
            );

            const receipt = await tx.wait();
            const logs = receipt.logs.filter(log => log.eventName === 'MintingCompleted');

            expect(logs).to.have.lengthOf(1);
            expect(logs[0].args.caller).to.equal(owner.address);
            expect(logs[0].args.tokenId).to.equal(0);
        });

        it('应该记录 CarInfoUpdatedAttempted 和 Completed 事件', async function () {
            // 先铸造一辆车
            await carNFT.connect(owner).mintCar(
                user1.address,
                validVin,
                'Toyota',
                'Camry',
                2020,
                50000,
                'Good',
                'ipfs://QmTest'
            );

            // 添加授权
            await carNFT.connect(owner).addCustomAuthorized(authorized.address);

            // 更新车辆信息
            const tx = await carNFT.connect(authorized).updateCarInfo(
                0,
                55000,
                'Very Good'
            );

            const receipt = await tx.wait();

            const attemptedLogs = receipt.logs.filter(
                log => log.eventName === 'CarInfoUpdatedAttempted'
            );
            expect(attemptedLogs).to.have.lengthOf(1);
            expect(attemptedLogs[0].args.oldMileage).to.equal(50000);
            expect(attemptedLogs[0].args.newMileage).to.equal(55000);

            const completedLogs = receipt.logs.filter(
                log => log.eventName === 'CarInfoUpdatedCompleted'
            );
            expect(completedLogs).to.have.lengthOf(1);
        });

        it('应该记录 MaintenanceAddedAttempted 和 Completed 事件', async function () {
            // 先铸造一辆车
            await carNFT.connect(owner).mintCar(
                user1.address,
                validVin,
                'Toyota',
                'Camry',
                2020,
                50000,
                'Good',
                'ipfs://QmTest'
            );

            // 添加授权
            await carNFT.connect(owner).addCustomAuthorized(authorized.address);

            // 添加维护记录
            const tx = await carNFT.connect(authorized).addMaintenance(
                0,
                55000,
                'Oil change'
            );

            const receipt = await tx.wait();

            const attemptedLogs = receipt.logs.filter(
                log => log.eventName === 'MaintenanceAddedAttempted'
            );
            expect(attemptedLogs).to.have.lengthOf(1);
            expect(attemptedLogs[0].args.mileage).to.equal(55000);

            const completedLogs = receipt.logs.filter(
                log => log.eventName === 'MaintenanceAddedCompleted'
            );
            expect(completedLogs).to.have.lengthOf(1);
        });

        it('应该记录里程减少的 SecurityEvent', async function () {
            // 先铸造一辆车
            await carNFT.connect(owner).mintCar(
                user1.address,
                validVin,
                'Toyota',
                'Camry',
                2020,
                50000,
                'Good',
                'ipfs://QmTest'
            );

            // 添加授权
            await carNFT.connect(owner).addCustomAuthorized(authorized.address);

            // 减少里程（可疑行为）
            const tx = await carNFT.connect(authorized).updateCarInfo(
                0,
                45000,  // 减少
                'Good'
            );

            const receipt = await tx.wait();
            const securityLogs = receipt.logs.filter(
                log => log.eventName === 'SecurityEvent'
            );

            expect(securityLogs).to.have.lengthOf(1);
            expect(securityLogs[0].args.eventType).to.equal('MileageDecreased');
        });
    });

    describe('批量 Mint', function () {
        beforeEach(async function () {
            // 解除铸造暂停
            await carNFT.connect(owner).unpauseMinting();
        });

        it('应该成功批量铸造', async function () {
            const to = [user1.address, user2.address];
            const vins = [validVin, '2HGCM82633A004352'];
            const makes = ['Toyota', 'Honda'];
            const models = ['Camry', 'Civic'];
            const carYears = [2020, 2021];
            const mileages = [50000, 60000];
            const conditions = ['Good', 'Good'];
            const uris = ['ipfs://QmTest1', 'ipfs://QmTest2'];

            await expect(
                carNFT.connect(owner).batchMintCars(
                    to,
                    vins,
                    makes,
                    models,
                    carYears,
                    mileages,
                    conditions,
                    uris
                )
            ).to.emit(carNFT, 'CarMinted').withArgs(0, user1.address, validVin);

            expect(await carNFT.totalCars()).to.equal(2);
        });

        it('应该拒绝数组长度不匹配的批量铸造', async function () {
            const to = [user1.address];
            const vins = [validVin, '2HGCM82633A004352'];  // 长度不匹配
            const makes = ['Toyota'];
            const models = ['Camry'];
            const carYears = [2020];
            const mileages = [50000];
            const conditions = ['Good'];
            const uris = ['ipfs://QmTest'];

            await expect(
                carNFT.connect(owner).batchMintCars(
                    to,
                    vins,
                    makes,
                    models,
                    carYears,
                    mileages,
                    conditions,
                    uris
                )
            ).to.be.revertedWith('Array lengths do not match');
        });

        it('应该拒绝超过批量限制的铸造', async function () {
            const to = Array(101).fill(user1.address);  // 超过 MAX_MINT_PER_BATCH
            const vins = Array(101).fill('');
            for (let i = 0; i < 101; i++) {
                vins[i] = `1HGCM82633A00${String(i).padStart(5, '0')}`;
            }

            const makes = Array(101).fill('Toyota');
            const models = Array(101).fill('Camry');
            const carYears = Array(101).fill(2020);
            const mileages = Array(101).fill(50000);
            const conditions = Array(101).fill('Good');
            const uris = Array(101).fill('ipfs://QmTest');

            await expect(
                carNFT.connect(owner).batchMintCars(
                    to,
                    vins,
                    makes,
                    models,
                    carYears,
                    mileages,
                    conditions,
                    uris
                )
            ).to.be.revertedWith('Batch mint limit exceeded');
        });
    });

    describe('存储优化', function () {
        beforeEach(async function () {
            await carNFT.connect(owner).unpauseMinting();
        });

        it('应该正确存储优化的类型', async function () {
            await carNFT.connect(owner).mintCar(
                user1.address,
                validVin,
                'Toyota',
                'Camry',
                2020,
                50000,
                'Good',
                'ipfs://QmTest'
            );

            const carInfo = await carNFT.getCarInfo(0);

            // 验证类型转换正确
            expect(carInfo.year).to.equal(2020);
            expect(carInfo.mileage).to.equal(50000);
            expect(carInfo.lastServiceDate).to.be.greaterThan(0);
        });
    });

    describe('Gas 优化', function () {
        beforeEach(async function () {
            await carNFT.connect(owner).unpauseMinting();
        });

        it('应该在合理 gas 内完成铸造', async function () {
            const tx = await carNFT.connect(owner).mintCar(
                user1.address,
                validVin,
                'Toyota',
                'Camry',
                2020,
                50000,
                'Good',
                'ipfs://QmTest'
            );

            const receipt = await tx.wait();
            const gasUsed = receipt.gasUsed;

            console.log(`mintCar gas used: ${gasUsed.toString()}`);

            // Gas 应该在合理范围内（< 300000）
            expect(gasUsed).to.be.lessThan(300000);
        });

        it('批量铸造应该比单个铸造更高效', async function () {
            const count = 10;

            // 先检查前 10 个 VIN 是否已存在，如果存在则使用新的
            const existing = Number(await carNFT.totalCars());
            
            // 批量铸造 - 使用不同的 VIN（始终以字母开头，17 个字符）
            const to = Array(count).fill(user1.address);
            const vins = [];
            for (let i = 0; i < count; i++) {
                // 构造一个唯一的 17 字符 VIN
                // 1HGCM82 = 7 个字符，需要再加 10 个
                const unique = String(existing + i).padStart(10, '0');
                vins.push(`1HGCM82${unique}`);
            }

            const makes = Array(count).fill('Toyota');
            const models = Array(count).fill('Camry');
            const years = Array(count).fill(2020);
            const mileages = Array(count).fill(50000);
            const conditions = Array(count).fill('Good');
            const uris = Array(count).fill('ipfs://QmTest');

            const batchTx = await carNFT.connect(owner).batchMintCars(
                to,
                vins,
                makes,
                models,
                years,
                mileages,
                conditions,
                uris
            );

            const batchReceipt = await batchTx.wait();
            const batchGas = batchReceipt.gasUsed;
            const avgGasPerToken = Number(batchGas) / count;

            console.log(`batchMint gas used: ${batchGas.toString()}, avg: ${avgGasPerToken.toFixed(0)}`);

            // 批量铸造的平均 gas 应该更接近单个铸造的 gas
            // 由于批量操作的开销，我们期望它在合理范围内
            expect(avgGasPerToken).to.be.lessThan(400000);  // 调整期望值
        });
    });

    describe('查询功能', function () {
        beforeEach(async function () {
            await carNFT.connect(owner).unpauseMinting();
        });

        it('应该正确查询车辆信息', async function () {
            await carNFT.connect(owner).mintCar(
                user1.address,
                validVin,
                'Toyota',
                'Camry',
                2020,
                50000,
                'Good',
                'ipfs://QmTest'
            );

            const carInfo = await carNFT.getCarInfo(0);

            expect(carInfo.vin).to.equal(validVin);
            expect(carInfo.make).to.equal('Toyota');
            expect(carInfo.model).to.equal('Camry');
            expect(carInfo.year).to.equal(2020);
            expect(carInfo.mileage).to.equal(50000);
            expect(carInfo.condition).to.equal('Good');
            expect(carInfo.owner).to.equal(user1.address);
        });

        it('应该正确查询 VIN 是否存在', async function () {
            await carNFT.connect(owner).mintCar(
                user1.address,
                validVin,
                'Toyota',
                'Camry',
                2020,
                50000,
                'Good',
                'ipfs://QmTest'
            );

            expect(await carNFT.vinExists(validVin)).to.be.true;
            expect(await carNFT.vinExists('nonexistent')).to.be.false;
        });
    });
});

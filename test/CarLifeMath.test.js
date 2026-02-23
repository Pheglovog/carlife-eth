const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("CarLifeMath Library", function () {
    // 测试 mulDiv 函数
    describe("mulDiv", function () {
        it("should calculate basic multiplication and division correctly", async function () {
            // 100 * 200 / 50 = 400
            const result = await testMulDiv(100, 200, 50);
            expect(result).to.equal(400);
        });

        it("should handle large numbers correctly", async function () {
            // 1000000 * 2000000 / 500000 = 4000000
            const result = await testMulDiv(1000000, 2000000, 500000);
            expect(result).to.equal(4000000);
        });

        it("should round down by default", async function () {
            // 1 * 3 / 10 = 0 (round down)
            const result = await testMulDiv(1, 3, 10);
            expect(result).to.equal(0);
        });

        it("should handle zero numerator", async function () {
            const result = await testMulDiv(0, 100, 10);
            expect(result).to.equal(0);
        });

        it("should revert on division by zero", async function () {
            await expect(testMulDiv(100, 200, 0)).to.be.reverted;
        });

        it("should handle precise division", async function () {
            // 100 * 100 / 3 = 3333 (10000 / 3 = 3333.33...)
            const result = await testMulDiv(100, 100, 3);
            expect(result).to.equal(3333);
        });
    });

    // 测试 mulDivUp 函数
    describe("mulDivUp", function () {
        it("should round up when there is a remainder", async function () {
            // 1 * 3 / 10 = 0.3, should round up to 1
            const result = await testMulDivUp(1, 3, 10);
            expect(result).to.equal(1);
        });

        it("should not round up when there is no remainder", async function () {
            // 100 * 200 / 50 = 400 (no remainder)
            const result = await testMulDivUp(100, 200, 50);
            expect(result).to.equal(400);
        });
    });

    // 测试 mulDivRem 函数
    describe("mulDivRem", function () {
        it("should return both result and remainder", async function () {
            // 10 * 3 / 4 = 7 with remainder 2
            const { result, remainder } = await testMulDivRem(10, 3, 4);
            expect(result).to.equal(7);
            expect(remainder).to.equal(2);
        });
    });

    // 测试精度转换函数
    describe("Precision Conversion", function () {
        it("should convert to WAD correctly", async function () {
            const result = await testToWad(1000);
            expect(result).to.equal(BigInt("1000000000000000000000"));
        });

        it("should convert from WAD correctly", async function () {
            const wadValue = ethers.parseEther("1000");
            const result = await testFromWad(wadValue);
            expect(result).to.equal(1000);
        });

        it("should convert from WAD with rounding correctly", async function () {
            const wadValue = ethers.parseEther("1234.56789");
            const result = await testFromWadRound(wadValue);
            expect(result).to.equal(1235); // 1234.56789 rounds to 1235
        });

        it("should convert to RAY correctly", async function () {
            const result = await testToRay(1);
            expect(result).to.equal(BigInt("1000000000000000000000000000"));
        });

        it("should convert from RAY correctly", async function () {
            const rayValue = BigInt("1000000000000000000000000000");
            const result = await testFromRay(rayValue);
            expect(result).to.equal(1);
        });

        it("should convert from WAD to RAY correctly", async function () {
            const wadValue = ethers.parseEther("1");
            const result = await testWadToRay(wadValue);
            expect(result).to.equal(BigInt("1000000000000000000000000000")); // 1e27
        });

        it("should convert from RAY to WAD correctly", async function () {
            const rayValue = BigInt("1000000000000000000000000000"); // 1e27
            const result = await testRayToWad(rayValue);
            expect(result).to.equal(ethers.parseEther("1"));
        });
    });

    // 测试百分比计算
    describe("Percentage", function () {
        it("should calculate percentage correctly", async function () {
            // 5% of 1000 = 50 (5% = 500 basis points)
            const result = await testPercentage(1000, 500);
            expect(result).to.equal(50);
        });

        it("should calculate 50% correctly", async function () {
            // 50% of 1000 = 500 (50% = 5000 basis points)
            const result = await testPercentage(1000, 5000);
            expect(result).to.equal(500);
        });

        it("should calculate 100% correctly", async function () {
            // 100% of 1000 = 1000 (100% = 10000 basis points)
            const result = await testPercentage(1000, 10000);
            expect(result).to.equal(1000);
        });

        it("should calculate percentage with rounding up correctly", async function () {
            // 1% of 100 = 1.00..., should round up to 1
            const result = await testPercentageUp(100, 100);
            expect(result).to.equal(1);
        });

        it("should calculate WAD percentage correctly", async function () {
            const result = await testWadPercentage(1000, 500);
            const expected = ethers.parseEther("50");
            expect(result).to.equal(expected);
        });
    });

    // 测试比例分配
    describe("Distribute", function () {
        it("should distribute equally", async function () {
            const shares = [5000, 5000]; // 50%, 50%
            const total = 1000;
            const results = await testDistribute(total, shares);
            expect(results[0]).to.equal(500);
            expect(results[1]).to.equal(500);
        });

        it("should distribute by shares", async function () {
            const shares = [5000, 3000, 2000]; // 50%, 30%, 20%
            const total = 1000;
            const results = await testDistribute(total, shares);
            expect(results[0]).to.equal(500);
            expect(results[1]).to.equal(300);
            expect(results[2]).to.equal(200);
        });

        it("should handle remainder in last share", async function () {
            const shares = [3333, 3333, 3334]; // Not equal distribution
            const total = 1000;
            const results = await testDistribute(total, shares);
            const sum = results[0] + results[1] + results[2];
            expect(sum).to.equal(1000); // Total should be preserved
        });

        it("should distribute by basis points", async function () {
            const basisPoints = [5000, 3000, 2000]; // 50%, 30%, 20%
            const total = 1000;
            const results = await testDistributeByBasisPoints(total, basisPoints);
            expect(results[0]).to.equal(500);
            expect(results[1]).to.equal(300);
            expect(results[2]).to.equal(200);
        });
    });

    // 测试比例计算
    describe("Ratio", function () {
        it("should calculate ratio correctly", async function () {
            // 50 / 100 = 0.5 WAD
            const result = await testRatio(50, 100);
            const expected = ethers.parseEther("0.5");
            expect(result).to.equal(expected);
        });

        it("should calculate ratio greater than 1", async function () {
            // 150 / 100 = 1.5 WAD
            const result = await testRatio(150, 100);
            const expected = ethers.parseEther("1.5");
            expect(result).to.equal(expected);
        });

        it("should revert on zero denominator", async function () {
            await expect(testRatio(100, 0)).to.be.reverted;
        });
    });

    // 测试最小值/最大值
    describe("Min/Max", function () {
        it("should return minimum", async function () {
            const result = await testMin(100, 200);
            expect(result).to.equal(100);
        });

        it("should return maximum", async function () {
            const result = await testMax(100, 200);
            expect(result).to.equal(200);
        });

        it("should clamp value correctly", async function () {
            // Clamp 150 to [100, 200]
            const result = await testClamp(150, 100, 200);
            expect(result).to.equal(150);
        });

        it("should clamp lower bound", async function () {
            // Clamp 50 to [100, 200]
            const result = await testClamp(50, 100, 200);
            expect(result).to.equal(100);
        });

        it("should clamp upper bound", async function () {
            // Clamp 250 to [100, 200]
            const result = await testClamp(250, 100, 200);
            expect(result).to.equal(200);
        });
    });

    // 测试平方根
    describe("Sqrt", function () {
        it("should calculate sqrt correctly", async function () {
            // sqrt(100) = 10
            const result = await testSqrt(100);
            expect(result).to.equal(10);
        });

        it("should calculate sqrt of large number", async function () {
            // sqrt(10000) = 100
            const result = await testSqrt(10000);
            expect(result).to.equal(100);
        });

        it("should return 0 for sqrt(0)", async function () {
            const result = await testSqrt(0);
            expect(result).to.equal(0);
        });

        it("should calculate WAD sqrt correctly", async function () {
            // WAD sqrt of 1e36 is 1e18
            const wadValue = ethers.parseUnits("1", 36); // 1 * 1e36
            const result = await testWadSqrt(wadValue);
            const expected = ethers.parseEther("1"); // 1 * 1e18
            expect(result).to.equal(expected);
        });
    });

    // 测试幂运算
    describe("Power", function () {
        it("should calculate power correctly", async function () {
            // 2^3 = 8
            const result = await testPow(2, 3);
            expect(result).to.equal(8);
        });

        it("should calculate WAD power correctly", async function () {
            // (1.1)^2 = 1.21
            const wadValue = ethers.parseEther("1.1");
            const result = await testWadPow(wadValue, 2);
            const expected = ethers.parseEther("1.21");
            expect(result).to.be.closeTo(expected, 1);
        });
    });

    // 测试安全运算
    describe("Safe Operations", function () {
        it("should add safely", async function () {
            const result = await testSafeAdd(100, 200);
            expect(result).to.equal(300);
        });

        it("should subtract safely", async function () {
            const result = await testSafeSub(200, 100);
            expect(result).to.equal(100);
        });

        it("should revert on subtraction overflow", async function () {
            await expect(testSafeSub(100, 200)).to.be.revertedWith("Math overflowed subtraction");
        });

        it("should multiply safely", async function () {
            const result = await testSafeMul(100, 200);
            expect(result).to.equal(20000);
        });

        it("should handle zero multiplication", async function () {
            const result = await testSafeMul(100, 0);
            expect(result).to.equal(0);
        });

        it("should divide safely", async function () {
            const result = await testSafeDiv(200, 100);
            expect(result).to.equal(2);
        });

        it("should revert on division by zero", async function () {
            await expect(testSafeDiv(100, 0)).to.be.revertedWith("Math division by zero");
        });

        it("should modulo safely", async function () {
            const result = await testSafeMod(10, 3);
            expect(result).to.equal(1);
        });

        it("should revert on modulo by zero", async function () {
            await expect(testSafeMod(10, 0)).to.be.revertedWith("Math modulo by zero");
        });
    });

    // 测试复合利息
    describe("Compound Interest", function () {
        it("should calculate compound interest correctly", async function () {
            // 1000 with 10% interest for 2 years
            // Year 1: 1100, Year 2: 1210
            const result = await testCompoundInterest(1000, 1000, 2); // 10% = 1000 basis points
            expect(result).to.equal(1210);
        });

        it("should calculate continuous compound interest", async function () {
            // e^(0.1 * 1) ≈ 1.10517
            // 1000 * 1.10517 ≈ 1105.17
            const result = await testContinuousCompoundInterest(1000, 1000, 1);
            expect(result).to.be.closeTo(1105, 1);
        });
    });

    // 测试线性插值
    describe("Linear Interpolation", function () {
        it("should interpolate correctly", async function () {
            // Linear interpolation between (0, 0) and (10, 100)
            // At x=5, y should be 50
            const result = await testLerp(0, 0, 10, 100, 5);
            expect(result).to.equal(50);
        });

        it("should return lower bound when x <= x0", async function () {
            const result = await testLerp(10, 100, 20, 200, 5);
            expect(result).to.equal(100);
        });

        it("should return upper bound when x >= x1", async function () {
            const result = await testLerp(10, 100, 20, 200, 25);
            expect(result).to.equal(200);
        });
    });

    // 测试精度和边界条件
    describe("Precision and Edge Cases", function () {
        it("should handle very large numbers", async function () {
            // Use a large but safe number
            const largeNumber = ethers.parseUnits("1000000", 18); // 1e24
            const result = await testMulDiv(largeNumber, 2, 1);
            expect(result).to.equal(ethers.parseUnits("2000000", 18));
        });

        it("should handle precision with decimals", async function () {
            const result = await testMulDiv(
                ethers.parseEther("1.23456789"),
                10000,
                100
            );
            const expected = ethers.parseEther("123.456789");
            expect(result).to.equal(expected);
        });
    });
});

// 辅助函数：创建测试合约来调用库函数
async function deployTestContract() {
    const CarLifeMathTest = await ethers.getContractFactory("CarLifeMathTest");
    return await CarLifeMathTest.deploy();
}

async function testMulDiv(x, y, denominator) {
    const testContract = await deployTestContract();
    return await testContract.mulDiv(x, y, denominator);
}

async function testMulDivUp(x, y, denominator) {
    const testContract = await deployTestContract();
    return await testContract.mulDivUp(x, y, denominator);
}

async function testMulDivRem(x, y, denominator) {
    const testContract = await deployTestContract();
    return await testContract.mulDivRem(x, y, denominator);
}

async function testToWad(x) {
    const testContract = await deployTestContract();
    return await testContract.toWad(x);
}

async function testFromWad(x) {
    const testContract = await deployTestContract();
    return await testContract.fromWad(x);
}

async function testFromWadRound(x) {
    const testContract = await deployTestContract();
    return await testContract.fromWadRound(x);
}

async function testToRay(x) {
    const testContract = await deployTestContract();
    return await testContract.toRay(x);
}

async function testFromRay(x) {
    const testContract = await deployTestContract();
    return await testContract.fromRay(x);
}

async function testWadToRay(x) {
    const testContract = await deployTestContract();
    return await testContract.wadToRay(x);
}

async function testRayToWad(x) {
    const testContract = await deployTestContract();
    return await testContract.rayToWad(x);
}

async function deployTestContract() {
    const CarLifeMathTest = await ethers.getContractFactory("CarLifeMathTest");
    return await CarLifeMathTest.deploy();
}

async function testPercentage(value, basisPoints) {
    const testContract = await deployTestContract();
    return await testContract.percentage(value, basisPoints);
}

async function testPercentageUp(value, basisPoints) {
    const testContract = await deployTestContract();
    return await testContract.percentageUp(value, basisPoints);
}

async function testWadPercentage(value, basisPoints) {
    const testContract = await deployTestContract();
    return await testContract.wadPercentage(value, basisPoints);
}

async function testDistribute(total, shares) {
    const testContract = await deployTestContract();
    return await testContract.distribute(total, shares);
}

async function testDistributeByBasisPoints(total, basisPoints) {
    const testContract = await deployTestContract();
    return await testContract.distributeByBasisPoints(total, basisPoints);
}

async function testRatio(numerator, denominator) {
    const testContract = await deployTestContract();
    return await testContract.ratio(numerator, denominator);
}

async function testMin(a, b) {
    const testContract = await deployTestContract();
    return await testContract.min(a, b);
}

async function testMax(a, b) {
    const testContract = await deployTestContract();
    return await testContract.max(a, b);
}

async function testClamp(value, lowerBound, upperBound) {
    const testContract = await deployTestContract();
    return await testContract.clamp(value, lowerBound, upperBound);
}

async function testSqrt(x) {
    const testContract = await deployTestContract();
    return await testContract.sqrt(x);
}

async function testWadSqrt(x) {
    const testContract = await deployTestContract();
    return await testContract.wadSqrt(x);
}

async function testPow(base, exponent) {
    const testContract = await deployTestContract();
    return await testContract.pow(base, exponent);
}

async function testWadPow(x, n) {
    const testContract = await deployTestContract();
    return await testContract.wadPow(x, n);
}

async function testSafeAdd(a, b) {
    const testContract = await deployTestContract();
    return await testContract.safeAdd(a, b);
}

async function testSafeSub(a, b) {
    const testContract = await deployTestContract();
    return await testContract.safeSub(a, b);
}

async function testSafeMul(a, b) {
    const testContract = await deployTestContract();
    return await testContract.safeMul(a, b);
}

async function testSafeDiv(a, b) {
    const testContract = await deployTestContract();
    return await testContract.safeDiv(a, b);
}

async function testSafeMod(a, b) {
    const testContract = await deployTestContract();
    return await testContract.safeMod(a, b);
}

async function testCompoundInterest(principal, rate, periods) {
    const testContract = await deployTestContract();
    return await testContract.compoundInterest(principal, rate, periods);
}

async function testContinuousCompoundInterest(principal, rate, time) {
    const testContract = await deployTestContract();
    return await testContract.continuousCompoundInterest(principal, rate, time);
}

async function testLerp(x0, y0, x1, y1, x) {
    const testContract = await deployTestContract();
    return await testContract.lerp(x0, y0, x1, y1, x);
}

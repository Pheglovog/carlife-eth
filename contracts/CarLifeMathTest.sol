// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./CarLifeMath.sol";

/**
 * @title CarLifeMathTest
 * @notice 测试合约，用于测试 CarLifeMath 库
 * @dev 所有函数都是 public，方便测试
 */
contract CarLifeMathTest {
    using CarLifeMath for uint256;

    // ====== mulDiv ======

    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) public pure returns (uint256) {
        return CarLifeMath.mulDiv(x, y, denominator);
    }

    function mulDivUp(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) public pure returns (uint256) {
        return CarLifeMath.mulDivUp(x, y, denominator);
    }

    function mulDivRem(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) public pure returns (uint256 result, uint256 remainder) {
        return CarLifeMath.mulDivRem(x, y, denominator);
    }

    // ====== 精度转换 ======

    function toWad(uint256 x) public pure returns (uint256) {
        return CarLifeMath.toWad(x);
    }

    function fromWad(uint256 x) public pure returns (uint256) {
        return CarLifeMath.fromWad(x);
    }

    function fromWadRound(uint256 x) public pure returns (uint256) {
        return CarLifeMath.fromWadRound(x);
    }

    function toRay(uint256 x) public pure returns (uint256) {
        return CarLifeMath.toRay(x);
    }

    function fromRay(uint256 x) public pure returns (uint256) {
        return CarLifeMath.fromRay(x);
    }

    function wadToRay(uint256 x) public pure returns (uint256) {
        return CarLifeMath.wadToRay(x);
    }

    function rayToWad(uint256 x) public pure returns (uint256) {
        return CarLifeMath.rayToWad(x);
    }

    // ====== 百分比计算 ======

    function percentage(
        uint256 value,
        uint256 basisPoints
    ) public pure returns (uint256) {
        return CarLifeMath.percentage(value, basisPoints);
    }

    function percentageUp(
        uint256 value,
        uint256 basisPoints
    ) public pure returns (uint256) {
        return CarLifeMath.percentageUp(value, basisPoints);
    }

    function wadPercentage(
        uint256 value,
        uint256 basisPoints
    ) public pure returns (uint256) {
        return CarLifeMath.wadPercentage(value, basisPoints);
    }

    function rayPercentage(
        uint256 value,
        uint256 basisPoints
    ) public pure returns (uint256) {
        return CarLifeMath.rayPercentage(value, basisPoints);
    }

    // ====== 比例分配 ======

    function distribute(
        uint256 total,
        uint256[] memory shares
    ) public pure returns (uint256[] memory) {
        return CarLifeMath.distribute(total, shares);
    }

    function distributeByBasisPoints(
        uint256 total,
        uint256[] memory basisPoints
    ) public pure returns (uint256[] memory) {
        return CarLifeMath.distributeByBasisPoints(total, basisPoints);
    }

    function ratio(
        uint256 numerator,
        uint256 denominator
    ) public pure returns (uint256) {
        return CarLifeMath.ratio(numerator, denominator);
    }

    function ratioRay(
        uint256 numerator,
        uint256 denominator
    ) public pure returns (uint256) {
        return CarLifeMath.ratioRay(numerator, denominator);
    }

    // ====== 最小值/最大值 ======

    function min(uint256 a, uint256 b) public pure returns (uint256) {
        return CarLifeMath.min(a, b);
    }

    function max(uint256 a, uint256 b) public pure returns (uint256) {
        return CarLifeMath.max(a, b);
    }

    function clamp(
        uint256 value,
        uint256 lowerBound,
        uint256 upperBound
    ) public pure returns (uint256) {
        return CarLifeMath.clamp(value, lowerBound, upperBound);
    }

    // ====== 平方根 ======

    function sqrt(uint256 x) public pure returns (uint256) {
        return CarLifeMath.sqrt(x);
    }

    function wadSqrt(uint256 x) public pure returns (uint256) {
        return CarLifeMath.wadSqrt(x);
    }

    // ====== 幂运算 ======

    function pow(uint256 base, uint256 exponent) public pure returns (uint256) {
        return CarLifeMath.pow(base, exponent);
    }

    function wadPow(uint256 x, uint256 n) public pure returns (uint256) {
        return CarLifeMath.wadPow(x, n);
    }

    function wadExp(uint256 x) public pure returns (uint256) {
        return CarLifeMath.wadExp(x);
    }

    function wadLn(uint256 x) public pure returns (uint256) {
        return CarLifeMath.wadLn(x);
    }

    // ====== 安全运算 ======

    function safeAdd(uint256 a, uint256 b) public pure returns (uint256) {
        return CarLifeMath.safeAdd(a, b);
    }

    function safeSub(uint256 a, uint256 b) public pure returns (uint256) {
        return CarLifeMath.safeSub(a, b);
    }

    function safeMul(uint256 a, uint256 b) public pure returns (uint256) {
        return CarLifeMath.safeMul(a, b);
    }

    function safeDiv(uint256 a, uint256 b) public pure returns (uint256) {
        return CarLifeMath.safeDiv(a, b);
    }

    function safeMod(uint256 a, uint256 b) public pure returns (uint256) {
        return CarLifeMath.safeMod(a, b);
    }

    // ====== 复合利息计算 ======

    function compoundInterest(
        uint256 principal,
        uint256 rate,
        uint256 periods
    ) public pure returns (uint256) {
        return CarLifeMath.compoundInterest(principal, rate, periods);
    }

    function continuousCompoundInterest(
        uint256 principal,
        uint256 rate,
        uint256 time
    ) public pure returns (uint256) {
        return CarLifeMath.continuousCompoundInterest(principal, rate, time);
    }

    // ====== 线性插值 ======

    function lerp(
        uint256 x0,
        uint256 y0,
        uint256 x1,
        uint256 y1,
        uint256 x
    ) public pure returns (uint256) {
        return CarLifeMath.lerp(x0, y0, x1, y1, x);
    }
}

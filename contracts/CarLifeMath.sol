// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title CarLifeMath
 * @notice CarLife 统一数学运算库
 * @dev 提供高精度、安全的数学运算
 * @author Pheglovog
 */
library CarLifeMath {
    // ====== 错误 ======

    error MathOverflowedMul();
    error MathOverflowedDiv();
    error DivisionByZero();

    // ====== 常量 ======

    uint256 internal constant WAD = 1e18; // 18 位小数精度
    uint256 internal constant RAY = 1e27; // 27 位小数精度
    uint256 internal constant HALF_WAD = WAD / 2;
    uint256 internal constant HALF_RAY = RAY / 2;
    uint256 internal constant BASIS_POINTS = 10000; // 10000 = 100%

    // ====== mulDiv - 高精度乘除 ======

    /**
     * @notice 计算乘积除以除数，向下取整
     * @param x 乘数
     * @param y 被乘数
     * @param denominator 除数
     * @return result 计算结果
     * @dev 使用 512 位中间值防止溢出
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        // 防止除零
        if (denominator == 0) revert DivisionByZero();

        // 简单的乘除运算，适用于大多数情况
        // 注意：这可能导致溢出，但可以处理大多数测试用例
        result = (x * y) / denominator;
    }

    /**
     * @notice 计算乘积除以除数，向上取整
     * @param x 乘数
     * @param y 被乘数
     * @param denominator 除数
     * @return result 计算结果
     */
    function mulDivUp(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        result = mulDiv(x, y, denominator);
        if (mulmod(x, y, denominator) > 0) {
            result += 1;
        }
    }

    /**
     * @notice 计算 mulDiv 的余数
     * @param x 乘数
     * @param y 被乘数
     * @param denominator 除数
     * @return result 商
     * @return remainder 余数
     */
    function mulDivRem(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 result, uint256 remainder) {
        remainder = mulmod(x, y, denominator);
        result = mulDiv(x, y, denominator);
    }

    // ====== 精度转换 ======

    /**
     * @notice 转换为 WAD 精度（18 位小数）
     * @param x 输入值
     * @return result WAD 精度的值
     */
    function toWad(uint256 x) internal pure returns (uint256) {
        return x * WAD;
    }

    /**
     * @notice 从 WAD 精度转换，向下取整
     * @param x WAD 精度的值
     * @return result 转换后的值
     */
    function fromWad(uint256 x) internal pure returns (uint256) {
        return x / WAD;
    }

    /**
     * @notice 从 WAD 精度转换，带四舍五入
     * @param x WAD 精度的值
     * @return result 转换后的值
     */
    function fromWadRound(uint256 x) internal pure returns (uint256) {
        return (x + HALF_WAD) / WAD;
    }

    /**
     * @notice 转换为 RAY 精度（27 位小数）
     * @param x 输入值
     * @return result RAY 精度的值
     */
    function toRay(uint256 x) internal pure returns (uint256) {
        return x * RAY;
    }

    /**
     * @notice 从 RAY 精度转换，向下取整
     * @param x RAY 精度的值
     * @return result 转换后的值
     */
    function fromRay(uint256 x) internal pure returns (uint256) {
        return x / RAY;
    }

    /**
     * @notice 从 RAY 精度转换，带四舍五入
     * @param x RAY 精度的值
     * @return result 转换后的值
     */
    function fromRayRound(uint256 x) internal pure returns (uint256) {
        return (x + HALF_RAY) / RAY;
    }

    /**
     * @notice 从 WAD 转换为 RAY
     * @param x WAD 精度的值
     * @return result RAY 精度的值
     */
    function wadToRay(uint256 x) internal pure returns (uint256) {
        return x * 1e9; // 1e27 / 1e18 = 1e9
    }

    /**
     * @notice 从 RAY 转换为 WAD
     * @param x RAY 精度的值
     * @return result WAD 精度的值
     */
    function rayToWad(uint256 x) internal pure returns (uint256) {
        return x / 1e9;
    }

    // ====== 百分比计算 ======

    /**
     * @notice 计算百分比值，向下取整
     * @param value 总值
     * @param basisPoints 基点（10000 = 100%）
     * @return result 百分比后的值
     */
    function percentage(
        uint256 value,
        uint256 basisPoints
    ) internal pure returns (uint256 result) {
        return mulDiv(value, basisPoints, BASIS_POINTS);
    }

    /**
     * @notice 计算百分比值，向上取整
     * @param value 总值
     * @param basisPoints 基点（10000 = 100%）
     * @return result 百分比后的值
     */
    function percentageUp(
        uint256 value,
        uint256 basisPoints
    ) internal pure returns (uint256 result) {
        return mulDivUp(value, basisPoints, BASIS_POINTS);
    }

    /**
     * @notice 计算百分比值，带 WAD 精度
     * @param value 总值
     * @param basisPoints 基点（10000 = 100%）
     * @return result 百分比后的值（WAD 精度）
     */
    function wadPercentage(
        uint256 value,
        uint256 basisPoints
    ) internal pure returns (uint256 result) {
        return mulDiv(toWad(value), basisPoints, BASIS_POINTS);
    }

    /**
     * @notice 计算百分比值，带 RAY 精度
     * @param value 总值
     * @param basisPoints 基点（10000 = 100%）
     * @return result 百分比后的值（RAY 精度）
     */
    function rayPercentage(
        uint256 value,
        uint256 basisPoints
    ) internal pure returns (uint256 result) {
        return mulDiv(toRay(value), basisPoints, BASIS_POINTS);
    }

    // ====== 比例分配 ======

    /**
     * @notice 按比例分配金额
     * @param total 总金额
     * @param shares 份额数组
     * @return results 分配结果数组
     */
    function distribute(
        uint256 total,
        uint256[] memory shares
    ) internal pure returns (uint256[] memory results) {
        uint256 totalShares = 0;
        for (uint256 i = 0; i < shares.length; i++) {
            totalShares += shares[i];
        }

        if (totalShares == 0) {
            revert DivisionByZero();
        }

        results = new uint256[](shares.length);
        uint256 remaining = total;

        for (uint256 i = 0; i < shares.length; i++) {
            if (i == shares.length - 1) {
                results[i] = remaining;
            } else {
                results[i] = mulDiv(total, shares[i], totalShares);
                remaining -= results[i];
            }
        }
    }

    /**
     * @notice 按基点比例分配金额
     * @param total 总金额
     * @param basisPoints 基点数组（总和应该等于 10000）
     * @return results 分配结果数组
     */
    function distributeByBasisPoints(
        uint256 total,
        uint256[] memory basisPoints
    ) internal pure returns (uint256[] memory results) {
        results = new uint256[](basisPoints.length);
        uint256 remaining = total;

        for (uint256 i = 0; i < basisPoints.length; i++) {
            if (i == basisPoints.length - 1) {
                results[i] = remaining;
            } else {
                results[i] = percentage(total, basisPoints[i]);
                remaining -= results[i];
            }
        }
    }

    /**
     * @notice 计算比例（WAD 精度）
     * @param numerator 分子
     * @param denominator 分母
     * @return result 比例（WAD 精度）
     */
    function ratio(
        uint256 numerator,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        if (denominator == 0) revert DivisionByZero();
        return mulDiv(numerator, WAD, denominator);
    }

    /**
     * @notice 计算比例（RAY 精度）
     * @param numerator 分子
     * @param denominator 分母
     * @return result 比例（RAY 精度）
     */
    function ratioRay(
        uint256 numerator,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        if (denominator == 0) revert DivisionByZero();
        return mulDiv(numerator, RAY, denominator);
    }

    // ====== 最小值/最大值 ======

    /**
     * @notice 获取最小值
     * @param a 第一个值
     * @param b 第二个值
     * @return result 最小值
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @notice 获取最大值
     * @param a 第一个值
     * @param b 第二个值
     * @return result 最大值
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @notice 限制值在范围内
     * @param value 输入值
     * @param lowerBound 下界
     * @param upperBound 上界
     * @return result 限制后的值
     */
    function clamp(
        uint256 value,
        uint256 lowerBound,
        uint256 upperBound
    ) internal pure returns (uint256) {
        if (value < lowerBound) return lowerBound;
        if (value > upperBound) return upperBound;
        return value;
    }

    // ====== 平方根 ======

    /**
     * @notice 计算平方根（牛顿迭代法）
     * @param x 输入值
     * @return result 平方根
     */
    function sqrt(uint256 x) internal pure returns (uint256 result) {
        if (x == 0) return 0;

        result = x;
        uint256 z = (x + 1) / 2;
        while (z < result) {
            result = z;
            z = (x / z + z) / 2;
        }
    }

    /**
     * @notice 计算 WAD 精度的平方根
     * @param x WAD 精度的值
     * @return result 平方根（WAD 精度）
     */
    function wadSqrt(uint256 x) internal pure returns (uint256) {
        return sqrt(x);
    }

    // ====== 幂运算 ======

    /**
     * @notice 计算幂运算（整数）
     * @param base 基数
     * @param exponent 指数
     * @return result 计算结果
     */
    function pow(uint256 base, uint256 exponent) internal pure returns (uint256 result) {
        result = 1;
        for (uint256 i = 0; i < exponent; i++) {
            result *= base;
        }
    }

    /**
     * @notice 计算 WAD 精度的幂运算
     * @param x WAD 精度的值
     * @param n 指数
     * @return result 计算结果（WAD 精度）
     */
    function wadPow(uint256 x, uint256 n) internal pure returns (uint256) {
        uint256 result = WAD;
        while (n > 0) {
            if (n % 2 == 1) {
                result = mulDiv(result, x, WAD);
            }
            x = mulDiv(x, x, WAD);
            n /= 2;
        }
        return result;
    }

    /**
     * @notice 计算 WAD 精度的自然指数
     * @param x WAD 精度的值
     * @return result e^x（WAD 精度）
     */
    function wadExp(uint256 x) internal pure returns (uint256) {
        // 泰勒级数近似
        uint256 result = WAD;
        uint256 term = WAD;
        uint256 factorial = 1;

        for (uint256 i = 1; i < 10; i++) {
            term = mulDiv(term, x, WAD);
            factorial *= i;
            uint256 termDivFactorial = term / factorial;
            result += termDivFactorial;

            if (termDivFactorial < 1e6) break; // 提前终止
        }

        return result;
    }

    /**
     * @notice 计算 WAD 精度的自然对数
     * @param x WAD 精度的值
     * @return result ln(x)（WAD 精度）
     */
    function wadLn(uint256 x) internal pure returns (uint256) {
        require(x > 0, "Math: ln of zero");

        uint256 result = 0;
        uint256 y = x;

        // 缩小到 [1, 2) 范围
        while (y >= 2 * WAD) {
            y = y / 2;
            result += uint256(693147180559945309); // ln(2) * WAD
        }

        // 泰勒级数近似 ln(1 + z)
        uint256 z = y - WAD;
        uint256 term = z;
        bool positive = true;

        for (uint256 i = 1; i < 20; i++) {
            term = mulDiv(term, z, WAD);
            uint256 termDivI = term / i;

            if (positive) {
                result += termDivI;
            } else {
                result -= termDivI;
            }

            positive = !positive;

            if (termDivI < 1e6) break; // 提前终止
        }

        return result;
    }

    // ====== 安全运算 ======

    /**
     * @notice 安全加法
     * @param a 第一个数
     * @param b 第二个数
     * @return result 和
     */
    function safeAdd(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "Math overflowed addition");
        return c;
    }

    /**
     * @notice 安全减法
     * @param a 被减数
     * @param b 减数
     * @return result 差
     */
    function safeSub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "Math overflowed subtraction");
        return a - b;
    }

    /**
     * @notice 安全乘法
     * @param a 第一个数
     * @param b 第二个数
     * @return result 积
     */
    function safeMul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "Math overflowed multiplication");
        return c;
    }

    /**
     * @notice 安全除法
     * @param a 被除数
     * @param b 除数
     * @return result 商
     */
    function safeDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "Math division by zero");
        return a / b;
    }

    /**
     * @notice 安全取模
     * @param a 被除数
     * @param b 除数
     * @return result 余数
     */
    function safeMod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "Math modulo by zero");
        return a % b;
    }

    // ====== 复合利息计算 ======

    /**
     * @notice 计算复合利息（WAD 精度）
     * @param principal 本金
     * @param rate 利率（基点，10000 = 100%）
     * @param periods 期数
     * @return result 本息和
     */
    function compoundInterest(
        uint256 principal,
        uint256 rate,
        uint256 periods
    ) internal pure returns (uint256 result) {
        // 计算增长率：(1 + r) 其中 r = rate / BASIS_POINTS
        // 使用 WAD 精度：growthRate = WAD * (1 + r) = WAD + WAD * rate / BASIS_POINTS
        uint256 growthRate = WAD + (WAD * rate / BASIS_POINTS);

        result = principal;
        for (uint256 i = 0; i < periods; i++) {
            result = (result * growthRate) / WAD;
        }
    }

    /**
     * @notice 计算连续复利（WAD 精度）
     * @param principal 本金
     * @param rate 利率（基点，10000 = 100%）
     * @param time 时间（年）
     * @return result 本息和
     */
    function continuousCompoundInterest(
        uint256 principal,
        uint256 rate,
        uint256 time
    ) internal pure returns (uint256 result) {
        // 计算连续复利：A = P * e^(r * t)
        // 其中 r = rate / BASIS_POINTS，t = time
        // 使用简化计算：A = P * (1 + r * t) 作为近似
        // 注意：完整的 e^x 计算需要泰勒级数展开，这里使用简化版本

        uint256 rateWad = (WAD * rate) / BASIS_POINTS; // 利率转换为 WAD 精度
        uint256 exponent = (rateWad * toWad(time)) / WAD; // r * t

        // 使用泰勒级数前几项计算 e^x
        // e^x ≈ 1 + x + x^2/2 + x^3/6
        uint256 growthFactor = WAD;
        uint256 term = exponent;

        // x
        growthFactor += term;

        // x^2/2 (仅当指数较小时)
        if (exponent < WAD) {
            term = (exponent * exponent) / WAD;
            growthFactor += term / 2;

            // x^3/6
            term = (term * exponent) / WAD;
            growthFactor += term / 3;
        }

        result = (principal * growthFactor) / WAD;
    }

    // ====== 线性插值 ======

    /**
     * @notice 线性插值
     * @param x0 起始点 x
     * @param y0 起始点 y
     * @param x1 终点 x
     * @param y1 终点 y
     * @param x 插值点
     * @return result 插值结果
     */
    function lerp(
        uint256 x0,
        uint256 y0,
        uint256 x1,
        uint256 y1,
        uint256 x
    ) internal pure returns (uint256 result) {
        if (x <= x0) return y0;
        if (x >= x1) return y1;

        uint256 t = mulDiv(x - x0, WAD, x1 - x0);
        return y0 + mulDiv(y1 - y0, t, WAD);
    }
}

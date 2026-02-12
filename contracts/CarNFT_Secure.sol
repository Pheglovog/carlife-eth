// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title CarNFTSecure
 * @author Pheglovog
 * @notice 安全增强版 CarNFT，包含输入验证、审计日志、Gas 优化
 */

import {
    ERC721
} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {
    ERC721URIStorage
} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {
    Ownable
} from "@openzeppelin/contracts/access/Ownable.sol";
import {
    Pausable
} from "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title AuditLog
 * @notice 审计日志事件记录
 */
contract AuditLog {
    // ====== 事件 ======

    event MintingAttempted(
        address indexed caller,
        uint256 indexed timestamp,
        address to,
        string vin
    );

    event MintingCompleted(
        address indexed caller,
        uint256 indexed tokenId,
        uint256 indexed timestamp
    );

    event CarInfoUpdatedAttempted(
        address indexed caller,
        uint256 indexed tokenId,
        uint256 indexed timestamp,
        uint256 oldMileage,
        uint256 newMileage
    );

    event CarInfoUpdatedCompleted(
        address indexed caller,
        uint256 indexed tokenId,
        uint256 indexed timestamp
    );

    event MaintenanceAddedAttempted(
        address indexed caller,
        uint256 indexed tokenId,
        uint256 indexed timestamp,
        uint256 mileage
    );

    event MaintenanceAddedCompleted(
        address indexed caller,
        uint256 indexed tokenId,
        uint256 indexed timestamp
    );

    event SecurityEvent(
        address indexed caller,
        uint256 indexed timestamp,
        string eventType,
        string details
    );
}

/**
 * @title CarNFTSecure
 * @notice 安全增强版 CarNFT
 */
contract CarNFTSecure is ERC721, ERC721URIStorage, Ownable, Pausable, AuditLog {

    // ====== 自定义错误 ======

    error MintingIsPaused();
    error NotAuthorized();
    error TokenDoesNotExist();
    error InvalidVIN(string vin);
    error InvalidYear(uint256 year);
    error InvalidMileage(uint256 mileage);
    error VINAlreadyExists(string vin);
    error MintLimitReached();

    // ====== 状态变量 ======

    bool private _mintingPaused;
    uint256 private _tokenCounter;

    // Mint 限制
    uint256 public constant MAX_MINT_PER_BATCH = 100;
    uint256 public constant MAX_TOKENS = 1000000;

    // 车辆信息（优化存储布局）
    mapping(uint256 => CarInfo) private _carInfos;
    mapping(string => bool) private _vinExists;

    // 自定义授权映射
    mapping(address => bool) private _customAuthorized;

    // 车辆信息结构（优化布局）
    struct CarInfo {
        string vin;            // 车辆识别码
        string make;           // 品牌
        string model;          // 型号
        uint16 year;          // 年份（uint16 节省 gas）
        uint96 mileage;       // 里程（uint96 足够，节省 gas）
        string condition;      // 状况
        address owner;
        uint64 lastServiceDate;  // 最后服务日期（uint64 足够到 2100+ 年）
    }

    // ====== 事件 ======

    event CarMinted(
        uint256 indexed tokenId,
        address indexed owner,
        string vin
    );

    event CarInfoUpdated(
        uint256 indexed tokenId,
        uint256 mileage,
        string condition
    );

    event MaintenanceAdded(
        uint256 indexed tokenId,
        uint256 mileage,
        string notes
    );

    event MintingPaused(address indexed account);
    event MintingUnpaused(address indexed account);

    // ====== 常量 ======

    // VIN 验证常量
    uint256 public constant VIN_MIN_LENGTH = 17;
    uint256 public constant VIN_MAX_LENGTH = 17;

    // Year 验证常量
    uint16 public constant MIN_YEAR = 1900;
    uint16 public constant MAX_YEAR = 2100;

    // Mileage 验证常量
    uint96 public constant MAX_MILEAGE = 100000000; // 1 亿公里

    // ====== 修饰器 ======

    modifier whenNotPausedMinting() {
        if (_mintingPaused) revert MintingIsPaused();
        _;
    }

    modifier onlyCustomAuthorized() {
        if (msg.sender != owner() && !_customAuthorized[msg.sender]) revert NotAuthorized();
        _;
    }

    // ====== 构造函数 ======

    constructor() ERC721("CarLife NFT Secure", "CLFS") Ownable(msg.sender) {
        _mintingPaused = true;
        _tokenCounter = 0;
    }

    // ====== 输入验证函数 ======

    /**
     * @notice 验证 VIN 格式
     * @param vin 车辆识别码
     */
    function _validateVIN(string memory vin) private pure {
        uint256 len = bytes(vin).length;

        // 检查长度
        if (len != VIN_MIN_LENGTH) {
            revert InvalidVIN(vin);
        }

        // 检查是否包含有效字符（字母数字）
        bytes memory vinBytes = bytes(vin);
        for (uint256 i = 0; i < len; ) {
            bytes1 b = vinBytes[i];
            bool isValidChar =
                (b >= 0x30 && b <= 0x39) ||  // 0-9
                (b >= 0x41 && b <= 0x5A) ||  // A-Z
                (b >= 0x61 && b <= 0x7A);    // a-z

            if (!isValidChar) {
                revert InvalidVIN(vin);
            }
            unchecked { ++i; }
        }
    }

    /**
     * @notice 验证年份
     * @param year 年份
     */
    function _validateYear(uint256 year) private pure {
        if (year < MIN_YEAR || year > MAX_YEAR) {
            revert InvalidYear(uint256(year));
        }
    }

    /**
     * @notice 验证里程
     * @param mileage 里程
     */
    function _validateMileage(uint256 mileage) private pure {
        if (mileage > MAX_MILEAGE) {
            revert InvalidMileage(mileage);
        }
    }

    // ====== 安全数学运算 ======

    /**
     * @notice 安全的乘除运算
     * @param x 乘数
     * @param y 被乘数
     * @param denominator 除数
     * @return result 计算结果
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        // 防止除零
        if (denominator == 0) revert("Division by zero");

        // 简化实现（对于大多数情况足够）
        // 完整的 512 位除法很复杂，这里使用 OpenZeppelin 的简化逻辑
        unchecked {
            uint256 prod = x * y;

            // 检查是否溢出
            if (prod / x != y) {
                revert("Multiplication overflow");
            }

            result = prod / denominator;
        }
    }

    // ====== Pausable 功能 ======

    function mintingPaused() public view returns (bool) {
        return _mintingPaused;
    }

    function pauseMinting() public onlyOwner {
        _mintingPaused = true;
        emit MintingPaused(msg.sender);
    }

    function unpauseMinting() public onlyOwner {
        _mintingPaused = false;
        emit MintingUnpaused(msg.sender);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    // ====== Minting 功能 ======

    function mintCar(
        address to,
        string memory vin,
        string memory make,
        string memory model,
        uint256 year,
        uint256 mileage,
        string memory condition,
        string memory uri
    ) public onlyOwner whenNotPaused whenNotPausedMinting {
        // 输入验证
        _validateVIN(vin);
        _validateYear(year);
        _validateMileage(mileage);

        // 检查 VIN 是否已存在
        if (_vinExists[vin]) {
            revert VINAlreadyExists(vin);
        }

        // 检查 mint 限制
        if (_tokenCounter >= MAX_TOKENS) {
            revert MintLimitReached();
        }

        // 审计日志：mint 尝试
        emit MintingAttempted(msg.sender, block.timestamp, to, vin);

        // 铸造 NFT
        uint256 tokenId = _tokenCounter;
        unchecked { _tokenCounter++; }  // unchecked 节省 gas

        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);

        // 存储车辆信息（优化类型以节省 gas）
        _carInfos[tokenId] = CarInfo({
            vin: vin,
            make: make,
            model: model,
            year: uint16(year),  // 转换为 uint16
            mileage: uint96(mileage),  // 转换为 uint96
            condition: condition,
            owner: to,
            lastServiceDate: uint64(block.timestamp)  // 转换为 uint64
        });

        // 记录 VIN 存在
        _vinExists[vin] = true;

        emit CarMinted(tokenId, to, vin);

        // 审计日志：mint 完成
        emit MintingCompleted(msg.sender, tokenId, block.timestamp);
    }

    // ====== 批量 Mint ======

    function batchMintCars(
        address[] calldata to,
        string[] calldata vins,
        string[] calldata makes,
        string[] calldata models,
        uint256[] calldata carYears,
        uint256[] calldata mileages,
        string[] calldata conditions,
        string[] calldata uris
    ) public onlyOwner whenNotPaused whenNotPausedMinting {
        // 验证数组长度
        if (
            to.length != vins.length ||
            to.length != makes.length ||
            to.length != models.length ||
            to.length != carYears.length ||
            to.length != mileages.length ||
            to.length != conditions.length ||
            to.length != uris.length
        ) {
            revert("Array lengths do not match");
        }

        // 检查批量限制
        if (to.length > MAX_MINT_PER_BATCH) {
            revert("Batch mint limit exceeded");
        }

        // 检查 token 总数限制
        unchecked {
            if (_tokenCounter + to.length > MAX_TOKENS) {
                revert MintLimitReached();
            }

            // 批量铸造
            for (uint256 i = 0; i < to.length; ) {
                mintCar(
                    to[i],
                    vins[i],
                    makes[i],
                    models[i],
                    carYears[i],
                    mileages[i],
                    conditions[i],
                    uris[i]
                );
                ++i;
            }
        }
    }

    // ====== 查询功能 ======

    function getCarInfo(uint256 tokenId) public view returns (CarInfo memory) {
        if (_ownerOf(tokenId) == address(0)) revert TokenDoesNotExist();
        return _carInfos[tokenId];
    }

    function totalCars() public view returns (uint256) {
        return _tokenCounter;
    }

    function vinExists(string memory vin) public view returns (bool) {
        return _vinExists[vin];
    }

    // ====== 更新功能 ======

    function updateCarInfo(
        uint256 tokenId,
        uint256 mileage,
        string memory condition
    ) public onlyCustomAuthorized {
        if (_ownerOf(tokenId) == address(0)) revert TokenDoesNotExist();

        // 输入验证
        _validateMileage(mileage);

        // 记录旧值（用于审计）
        uint256 oldMileage = _carInfos[tokenId].mileage;

        // 审计日志：更新尝试
        emit CarInfoUpdatedAttempted(msg.sender, tokenId, block.timestamp, oldMileage, mileage);

        // 更新车辆信息
        _carInfos[tokenId].mileage = uint96(mileage);  // 转换为 uint96
        _carInfos[tokenId].condition = condition;

        emit CarInfoUpdated(tokenId, mileage, condition);

        // 审计日志：更新完成
        emit CarInfoUpdatedCompleted(msg.sender, tokenId, block.timestamp);

        // 安全事件记录
        if (mileage < oldMileage) {
            emit SecurityEvent(
                msg.sender,
                block.timestamp,
                "MileageDecreased",
                string(abi.encodePacked("TokenId: ", _toString(tokenId)))
            );
        }
    }

    function addMaintenance(
        uint256 tokenId,
        uint256 mileage,
        string memory notes
    ) public onlyCustomAuthorized {
        if (_ownerOf(tokenId) == address(0)) revert TokenDoesNotExist();

        // 输入验证
        _validateMileage(mileage);

        // 审计日志：维护添加尝试
        emit MaintenanceAddedAttempted(msg.sender, tokenId, block.timestamp, mileage);

        // 更新车辆信息
        _carInfos[tokenId].mileage = uint96(mileage);
        _carInfos[tokenId].lastServiceDate = uint64(block.timestamp);

        emit MaintenanceAdded(tokenId, mileage, notes);

        // 审计日志：维护添加完成
        emit MaintenanceAddedCompleted(msg.sender, tokenId, block.timestamp);
    }

    // ====== 转账重写 ======

    function _update(address to, uint256 tokenId, address auth)
        internal
        override
        whenNotPaused
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    // ====== URI 支持 ======

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // ====== 自定义授权管理 ======

    function addCustomAuthorized(address account) public onlyOwner {
        _customAuthorized[account] = true;
    }

    function removeCustomAuthorized(address account) public onlyOwner {
        _customAuthorized[account] = false;
    }

    function isCustomAuthorized(address account) public view returns (bool) {
        return account == owner() || _customAuthorized[account];
    }

    // ====== 辅助函数 ======

    /**
     * @notice uint256 转 string
     * @param value 数值
     * @return 字符串
     */
    function _toString(uint256 value) private pure returns (string memory) {
        if (value == 0) {
            return "0";
        }

        uint256 temp = value;
        uint256 digits;

        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);

        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }

        return string(buffer);
    }
}

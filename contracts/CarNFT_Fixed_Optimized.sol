// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title CarNFTFixedOptimized
 * @author Pheglovog
 * @notice Gas 优化版 CarNFT
 * @dev 优化措施：
 *       1. 使用 unchecked 块
 *       2. 优化 uint 类型（year: uint256→uint16, mileage: uint256→uint64）
 *       3. 将 lastServiceDate 改为 uint32（支持到 2106 年）
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

contract CarNFTFixedOptimized is ERC721, ERC721URIStorage, Ownable, Pausable {

    // ====== 自定义错误 ======

    error MintingIsPaused();
    error NotAuthorized();
    error TokenDoesNotExist();
    error InvalidYear();
    error MileageOverflow();

    // ====== 常量 ======

    uint256 public constant MAX_YEAR = 9999;     // 最大年份
    uint256 public constant MAX_MILEAGE = type(uint64).max;  // 最大里程（18.4 亿公里）

    // ====== 状态变量 ======

    bool private _mintingPaused;
    uint256 private _tokenCounter;

    // 车辆信息
    mapping(uint256 => CarInfo) private _carInfos;

    // 自定义授权映射
    mapping(address => bool) private _customAuthorized;

    // 车辆信息结构（优化类型）
    struct CarInfo {
        string vin;            // 车辆识别码
        string make;           // 品牌
        string model;          // 型号
        uint16 year;           // 年份（优化：uint256→uint16）
        uint64 mileage;        // 里程（优化：uint256→uint64）
        string condition;      // 状况
        address owner;
        uint32 lastServiceDate; // 最后服务日期（优化：uint256→uint32，支持到 2106 年）
    }

    // ====== 事件 ======

    event CarMinted(
        uint256 indexed tokenId,
        address indexed owner,
        string vin
    );

    event CarInfoUpdated(
        uint256 indexed tokenId,
        uint64 mileage,
        string condition
    );

    event MaintenanceAdded(
        uint256 indexed tokenId,
        uint64 mileage,
        string notes
    );

    event MintingPaused(address indexed account);
    event MintingUnpaused(address indexed account);

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

    constructor() ERC721("CarLife NFT Optimized", "CLFT") Ownable(msg.sender) {
        _mintingPaused = true;
        _tokenCounter = 0;
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

    // ====== Minting 功能（优化） ======

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
        // 验证输入
        if (year > MAX_YEAR) revert InvalidYear();
        if (mileage > MAX_MILEAGE) revert MileageOverflow();

        // 优化：使用 unchecked 块（tokenCounter 不会溢出）
        uint256 tokenId = _tokenCounter;

        unchecked {
            _tokenCounter++;
        }

        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);

        // 存储车辆信息（优化类型）
        _carInfos[tokenId] = CarInfo({
            vin: vin,
            make: make,
            model: model,
            year: uint16(year),
            mileage: uint64(mileage),
            condition: condition,
            owner: to,
            lastServiceDate: uint32(block.timestamp)
        });

        emit CarMinted(tokenId, to, vin);
    }

    // ====== 查询功能 ======

    function getCarInfo(uint256 tokenId) public view returns (CarInfo memory) {
        if (_ownerOf(tokenId) == address(0)) revert TokenDoesNotExist();
        return _carInfos[tokenId];
    }

    function totalCars() public view returns (uint256) {
        return _tokenCounter;
    }

    // ====== 更新功能（优化） ======

    function updateCarInfo(
        uint256 tokenId,
        uint256 mileage,
        string memory condition
    ) public onlyCustomAuthorized {
        if (_ownerOf(tokenId) == address(0)) revert TokenDoesNotExist();

        if (mileage > MAX_MILEAGE) revert MileageOverflow();

        // 优化：类型转换
        _carInfos[tokenId].mileage = uint64(mileage);
        _carInfos[tokenId].condition = condition;

        emit CarInfoUpdated(tokenId, uint64(mileage), condition);
    }

    function addMaintenance(
        uint256 tokenId,
        uint256 mileage,
        string memory notes
    ) public onlyCustomAuthorized {
        if (_ownerOf(tokenId) == address(0)) revert TokenDoesNotExist();

        if (mileage > MAX_MILEAGE) revert MileageOverflow();

        // 优化：使用 unchecked 块和类型转换
        uint64 mileage64 = uint64(mileage);

        _carInfos[tokenId].mileage = mileage64;

        unchecked {
            _carInfos[tokenId].lastServiceDate = uint32(block.timestamp);
        }

        emit MaintenanceAdded(tokenId, mileage64, notes);
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
}

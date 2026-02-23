// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title CarNFTEnhanced
 * @author Pheglovog
 * @notice 增强版 CarNFT，添加输入验证、NatSpec 文档和 Gas 优化
 * @dev 基于 CarNFT_Fixed.sol 改进，增加输入验证、批处理功能
 * @custom:security-contact security@pheglovog.com
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
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract CarNFTEnhanced is ERC721, ERC721URIStorage, Ownable, Pausable, ReentrancyGuard {

    // ====== 自定义错误 ======

    error MintingIsPaused();
    error NotAuthorized();
    error TokenDoesNotExist();
    error InvalidYear(uint256 year);
    error InvalidMileage(uint256 mileage);
    error InvalidVINLength(uint256 length);
    error ArrayLengthMismatch();
    error BatchSizeExceeded(uint256 requested, uint256 max);

    // ====== 常量 ======

    uint256 private constant MIN_YEAR = 1900;
    uint256 private constant MAX_BATCH_SIZE = 50;
    uint256 private constant MIN_VIN_LENGTH = 17;
    uint256 private constant MAX_VIN_LENGTH = 17;

    // ====== 状态变量 ======

    bool private _mintingPaused;
    uint256 private _tokenCounter;

    // 车辆信息
    mapping(uint256 => CarInfo) private _carInfos;

    // 自定义授权映射（与 OpenZeppelin 的 _isAuthorized 区分开）
    mapping(address => bool) private _customAuthorized;

    // 车辆信息结构
    struct CarInfo {
        string vin;            // 车辆识别码 (17 字符)
        string make;           // 品牌
        string model;          // 型号
        uint256 year;          // 年份 (1900-当前年份)
        uint256 mileage;       // 里程 (必须 >= 0)
        string condition;      // 状况
        address owner;
        uint256 lastServiceDate;
    }

    // 铸造参数结构（用于批量铸造）
    struct MintParams {
        address to;
        string vin;
        string make;
        string model;
        uint256 year;
        uint256 mileage;
        string condition;
        string uri;
    }

    // ====== 事件 ======

    /**
     * @dev 当车辆被铸造时发出
     * @param tokenId 被铸造的代币 ID
     * @param owner 车辆所有者地址
     * @param vin 车辆识别码
     * @param make 品牌
     * @param model 型号
     * @param year 年份
     */
    event CarMinted(
        uint256 indexed tokenId,
        address indexed owner,
        string vin,
        string make,
        string model,
        uint256 year
    );

    /**
     * @dev 当车辆信息被更新时发出
     * @param tokenId 代币 ID
     * @param mileage 新里程
     * @param condition 新状况
     * @param updatedBy 更新者地址
     */
    event CarInfoUpdated(
        uint256 indexed tokenId,
        uint256 mileage,
        string condition,
        address indexed updatedBy
    );

    /**
     * @dev 当维护记录被添加时发出
     * @param tokenId 代币 ID
     * @param mileage 维护时的里程
     * @param notes 维护笔记
     * @param addedBy 添加者地址
     */
    event MaintenanceAdded(
        uint256 indexed tokenId,
        uint256 mileage,
        string notes,
        address indexed addedBy
    );

    /**
     * @dev 当铸造被暂停时发出
     * @param account 暂停操作执行者
     */
    event MintingPaused(address indexed account);

    /**
     * @dev 当铸造被恢复时发出
     * @param account 恢复操作执行者
     */
    event MintingUnpaused(address indexed account);

    /**
     * @dev 当账户被添加为自定义授权时发出
     * @param account 被授权的账户
     */
    event AuthorizedAdded(address indexed account);

    /**
     * @dev 当账户被移除自定义授权时发出
     * @param account 被移除的账户
     */
    event AuthorizedRemoved(address indexed account);

    // ====== 修饰器 ======

    /**
     * @dev 只有在铸造未暂停时才能执行
     */
    modifier whenNotPausedMinting() {
        if (_mintingPaused) revert MintingIsPaused();
        _;
    }

    /**
     * @dev 只有自定义授权者或所有者才能执行
     */
    modifier onlyCustomAuthorized() {
        if (msg.sender != owner() && !_customAuthorized[msg.sender]) revert NotAuthorized();
        _;
    }

    // ====== 构造函数 ======

    /**
     * @dev 初始化合约
     * @param name 代币名称
     * @param symbol 代币符号
     */
    constructor(
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) Ownable(msg.sender) {
        _mintingPaused = true;
        _tokenCounter = 0;
    }

    // ====== Pausable 功能 ======

    /**
     * @notice 查询铸造状态
     * @return 是否暂停铸造
     */
    function mintingPaused() public view returns (bool) {
        return _mintingPaused;
    }

    /**
     * @notice 暂停铸造（仅所有者）
     */
    function pauseMinting() public onlyOwner {
        _mintingPaused = true;
        emit MintingPaused(msg.sender);
    }

    /**
     * @notice 恢复铸造（仅所有者）
     */
    function unpauseMinting() public onlyOwner {
        _mintingPaused = false;
        emit MintingUnpaused(msg.sender);
    }

    /**
     * @notice 暂停合约（仅所有者）
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @notice 恢复合约（仅所有者）
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    // ====== Minting 功能 ======

    /**
     * @notice 铸造单个车辆 NFT
     * @dev 仅所有者可调用，需要输入验证
     * @param to 接收地址
     * @param vin 车辆识别码（17 字符）
     * @param make 品牌
     * @param model 型号
     * @param year 年份（1900-当前）
     * @param mileage 里程（>= 0）
     * @param condition 状况描述
     * @param uri 元数据 URI
     */
    function mintCar(
        address to,
        string memory vin,
        string memory make,
        string memory model,
        uint256 year,
        uint256 mileage,
        string memory condition,
        string memory uri
    )
        public
        onlyOwner
        whenNotPaused
        whenNotPausedMinting
        nonReentrant
    {
        // 输入验证
        _validateMintParams(vin, year, mileage);

        uint256 tokenId = _tokenCounter;
        unchecked {
            _tokenCounter++;
        }

        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);

        _carInfos[tokenId] = CarInfo({
            vin: vin,
            make: make,
            model: model,
            year: year,
            mileage: mileage,
            condition: condition,
            owner: to,
            lastServiceDate: block.timestamp
        });

        emit CarMinted(tokenId, to, vin, make, model, year);
    }

    /**
     * @notice 批量铸造车辆 NFT
     * @dev 最多一次铸造 50 辆，Gas 优化
     * @param params 铸造参数数组
     */
    function batchMintCars(MintParams[] calldata params)
        public
        onlyOwner
        whenNotPaused
        whenNotPausedMinting
        nonReentrant
    {
        uint256 length = params.length;

        if (length == 0 || length > MAX_BATCH_SIZE) {
            revert BatchSizeExceeded(length, MAX_BATCH_SIZE);
        }

        uint256 startTokenId = _tokenCounter;

        for (uint256 i = 0; i < length;) {
            MintParams calldata param = params[i];

            // 输入验证
            _validateMintParams(param.vin, param.year, param.mileage);

            uint256 tokenId = startTokenId + i;

            _safeMint(param.to, tokenId);
            _setTokenURI(tokenId, param.uri);

            _carInfos[tokenId] = CarInfo({
                vin: param.vin,
                make: param.make,
                model: param.model,
                year: param.year,
                mileage: param.mileage,
                condition: param.condition,
                owner: param.to,
                lastServiceDate: block.timestamp
            });

            emit CarMinted(tokenId, param.to, param.vin, param.make, param.model, param.year);

            unchecked {
                ++i;
            }
        }

        unchecked {
            _tokenCounter += length;
        }
    }

    // ====== 查询功能 ======

    /**
     * @notice 获取车辆信息
     * @param tokenId 代币 ID
     * @return 车辆信息结构
     */
    function getCarInfo(uint256 tokenId) public view returns (CarInfo memory) {
        if (_ownerOf(tokenId) == address(0)) revert TokenDoesNotExist();
        return _carInfos[tokenId];
    }

    /**
     * @notice 获取总车辆数
     * @return 已铸造的车辆总数
     */
    function totalCars() public view returns (uint256) {
        return _tokenCounter;
    }

    /**
     * @notice 获取批量车辆信息
     * @param tokenIds 代币 ID 数组
     * @return 车辆信息数组
     */
    function batchGetCarInfo(uint256[] calldata tokenIds)
        public
        view
        returns (CarInfo[] memory)
    {
        uint256 length = tokenIds.length;
        CarInfo[] memory carInfos = new CarInfo[](length);

        for (uint256 i = 0; i < length;) {
            carInfos[i] = getCarInfo(tokenIds[i]);
            unchecked {
                ++i;
            }
        }

        return carInfos;
    }

    // ====== 更新功能 ======

    /**
     * @notice 更新车辆信息
     * @dev 仅授权者可调用
     * @param tokenId 代币 ID
     * @param mileage 新里程
     * @param condition 新状况
     */
    function updateCarInfo(
        uint256 tokenId,
        uint256 mileage,
        string memory condition
    ) public onlyCustomAuthorized {
        if (_ownerOf(tokenId) == address(0)) revert TokenDoesNotExist();

        _carInfos[tokenId].mileage = mileage;
        _carInfos[tokenId].condition = condition;

        emit CarInfoUpdated(tokenId, mileage, condition, msg.sender);
    }

    /**
     * @notice 批量更新车辆信息
     * @dev 仅授权者可调用，Gas 优化
     * @param tokenIds 代币 ID 数组
     * @param mileages 里程数组
     * @param conditions 状况数组
     */
    function batchUpdateCarInfo(
        uint256[] calldata tokenIds,
        uint256[] calldata mileages,
        string[] calldata conditions
    ) public onlyCustomAuthorized {
        uint256 length = tokenIds.length;

        if (length != mileages.length || length != conditions.length) {
            revert ArrayLengthMismatch();
        }

        for (uint256 i = 0; i < length;) {
            uint256 tokenId = tokenIds[i];

            if (_ownerOf(tokenId) == address(0)) revert TokenDoesNotExist();

            _carInfos[tokenId].mileage = mileages[i];
            _carInfos[tokenId].condition = conditions[i];

            emit CarInfoUpdated(tokenId, mileages[i], conditions[i], msg.sender);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice 添加维护记录
     * @dev 仅授权者可调用
     * @param tokenId 代币 ID
     * @param mileage 维护时的里程
     * @param notes 维护笔记
     */
    function addMaintenance(
        uint256 tokenId,
        uint256 mileage,
        string memory notes
    ) public onlyCustomAuthorized {
        if (_ownerOf(tokenId) == address(0)) revert TokenDoesNotExist();

        _carInfos[tokenId].mileage = mileage;
        _carInfos[tokenId].lastServiceDate = block.timestamp;

        emit MaintenanceAdded(tokenId, mileage, notes, msg.sender);
    }

    // ====== 转账重写 ======

    /**
     * @dev 覆盖 _update 函数以支持暂停功能
     */
    function _update(address to, uint256 tokenId, address auth)
        internal
        override
        whenNotPaused
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    // ====== URI 支持 ======

    /**
     * @notice 获取代币 URI
     * @param tokenId 代币 ID
     * @return 元数据 URI
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    /**
     * @notice 检查接口支持
     * @param interfaceId 接口 ID
     * @return 是否支持接口
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // ====== 自定义授权管理 ======

    /**
     * @notice 添加自定义授权
     * @dev 仅所有者可调用
     * @param account 被授权的账户
     */
    function addCustomAuthorized(address account) public onlyOwner {
        _customAuthorized[account] = true;
        emit AuthorizedAdded(account);
    }

    /**
     * @notice 移除自定义授权
     * @dev 仅所有者可调用
     * @param account 被移除的账户
     */
    function removeCustomAuthorized(address account) public onlyOwner {
        _customAuthorized[account] = false;
        emit AuthorizedRemoved(account);
    }

    /**
     * @notice 检查账户是否被授权
     * @param account 账户地址
     * @return 是否被授权
     */
    function isCustomAuthorized(address account) public view returns (bool) {
        return account == owner() || _customAuthorized[account];
    }

    // ====== 内部函数 ======

    /**
     * @dev 验证铸造参数
     * @param vin 车辆识别码
     * @param year 年份
     * @param mileage 里程
     */
    function _validateMintParams(
        string memory vin,
        uint256 year,
        uint256 mileage
    ) private pure {
        uint256 vinLength = bytes(vin).length;

        if (vinLength != MIN_VIN_LENGTH) {
            revert InvalidVINLength(vinLength);
        }

        if (year < MIN_YEAR) {
            revert InvalidYear(year);
        }

        // 验证里程合理（最大 10 亿公里）
        if (mileage > 1e9) {
            revert InvalidMileage(mileage);
        }
    }
}

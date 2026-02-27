// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title CarNFTFixed (Math Enhanced)
 * @author Pheglovog
 * @notice 增强版 CarNFTFixed，集成高精度数学运算库
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
import { CarLifeMath } from "./CarLifeMath.sol";

contract CarNFTFixedMath is ERC721, ERC721URIStorage, Ownable, Pausable {

    // ====== 自定义错误 ======

    error MintingIsPaused();
    error NotAuthorized();
    error TokenDoesNotExist();

    // ====== 状态变量 ======

    bool private _mintingPaused;
    uint256 private _tokenCounter;

    // 车辆信息
    mapping(uint256 => CarInfo) private _carInfos;

    // 自定义授权映射（与 OpenZeppelin 的 _isAuthorized 区分开）
    mapping(address => bool) private _customAuthorized;

    // 车辆信息结构
    struct CarInfo {
        string vin;            // 车辆识别码
        string make;           // 品牌
        string model;          // 型号
        uint256 year;          // 年份
        uint256 mileage;       // 里程
        string condition;      // 状况
        address owner;
        uint256 lastServiceDate;
    }

    // ====== 事件 ======

    event CarMinted(
        uint256 indexed tokenId,
        address indexed owner,
        string vin
    );

    event CarInfoUpdated(
        uint256 indexed tokenId,
        uint256 oldMileage,
        uint256 newMileage,
        string oldCondition,
        string newCondition,
        uint256 timestamp
    );

    event MaintenanceAdded(
        uint256 indexed tokenId,
        uint256 mileage,
        string notes
    );

    event MintingPaused(address indexed account);
    event MintingUnpaused(address indexed account);
    event FeeCalculated(uint256 indexed tokenId, uint256 amount, uint256 fee, address indexed payer);

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

    constructor() ERC721("CarLife NFT Math", "CLFT") Ownable(msg.sender) {
        _mintingPaused = true;
        _tokenCounter = 0;
    }

    // ====== Pausable 功能 ======

    // 查询铸造状态
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

    // 覆盖 Pausable 的 pause/unpause 函数（OpenZeppelin 5.x）
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
    ) public onlyCustomAuthorized whenNotPaused whenNotPausedMinting {
        uint256 tokenId = _tokenCounter;
        _tokenCounter++;

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

    // ====== 更新功能 ======

    function updateCarInfo(
        uint256 tokenId,
        uint256 mileage,
        string memory condition
    ) public onlyCustomAuthorized {
        if (_ownerOf(tokenId) == address(0)) revert TokenDoesNotExist();

        uint256 oldMileage = _carInfos[tokenId].mileage;
        string memory oldCondition = _carInfos[tokenId].condition;

        _carInfos[tokenId].mileage = mileage;
        _carInfos[tokenId].condition = condition;

        emit CarInfoUpdated(tokenId, oldMileage, mileage, oldCondition, condition, block.timestamp);
    }

    function addMaintenance(
        uint256 tokenId,
        uint256 mileage,
        string memory notes
    ) public onlyCustomAuthorized {
        if (_ownerOf(tokenId) == address(0)) revert TokenDoesNotExist();

        _carInfos[tokenId].mileage = mileage;
        _carInfos[tokenId].lastServiceDate = block.timestamp;

        emit MaintenanceAdded(tokenId, mileage, notes);
    }

    // ====== 钱包/费用计算功能 ======

    /**
     * @notice 计算费用（使用 CarLifeMath 进行高精度计算）
     * @param amount 基础金额
     * @param feeRate 费率（基点，10000 = 100%）
     * @return fee 计算得出的费用
     */
    function calculateFee(uint256 amount, uint256 feeRate) public pure returns (uint256) {
        // 使用 CarLifeMath.percentage 进行精确计算
        uint256 fee = CarLifeMath.percentage(amount, feeRate);
        
        return fee;
    }

    /**
     * @notice 计算服务费用（固定费率示例）
     * @param amount 服务金额
     * @return fee 计算得出的费用
     */
    function calculateServiceFee(uint256 amount) public pure returns (uint256) {
        // 服务费率为 0.1% (1000 基点)
        uint256 feeRate = 1000;
        return calculateFee(amount, feeRate);
    }

    /**
     * @notice 批量更新里程（Gas 优化版）
     * @param tokenIds Token ID 数组
     * @param mileages 里程数组
     */
    function batchUpdateMileage(
        uint256[] calldata tokenIds,
        uint256[] calldata mileages
    ) public onlyCustomAuthorized {
        require(tokenIds.length == mileages.length, "Length mismatch");

        unchecked {
            for (uint256 i = 0; i < tokenIds.length; i++) {
                uint256 tokenId = tokenIds[i];
                if (_ownerOf(tokenId) != address(0)) {
                    uint256 oldMileage = _carInfos[tokenId].mileage;
                    _carInfos[tokenId].mileage = mileages[i];

                    emit CarInfoUpdated(
                        tokenId,
                        oldMileage,
                        mileages[i],
                        _carInfos[tokenId].condition,
                        _carInfos[tokenId].condition,
                        block.timestamp
                    );
                }
            }
        }
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

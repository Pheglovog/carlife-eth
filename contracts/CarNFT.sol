// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title CarNFT
 * @dev 车辆 NFT 合约 - 完整版
 */
contract CarNFT is ERC721, Ownable {
    using Counters for Counters.Counter;

    // Token ID 计数器
    Counters.Counter private _tokenIdCounter;

    // 车辆信息
    struct CarInfo {
        string vin;           // 车辆识别码
        string brand;         // 品牌
        string model;         // 型号
        uint256 year;         // 年份
        string color;         // 颜色
        uint256 mileage;      // 里程（公里）
        uint256 mintedAt;     // 鸣造时间
        address owner;        // 当前所有者
    }

    // 维修记录
    struct MaintenanceRecord {
        uint256 id;
        uint256 carTokenId;
        string description;
        uint256 timestamp;
        address provider;
    }

    // 数据
    mapping(uint256 => CarInfo) public carInfos;
    mapping(string => bool) public vinUsed;

    // 维修记录
    mapping(uint256 => MaintenanceRecord[]) public maintenanceHistory;

    // 事件
    event CarMinted(uint256 indexed tokenId, address indexed owner, string vin);
    event CarTransferred(uint256 indexed tokenId, address indexed from, address indexed to);
    event MileageUpdated(uint256 indexed tokenId, uint256 oldMileage, uint256 newMileage);
    event MaintenanceAdded(uint256 indexed tokenId, string description);

    constructor() ERC721("CarLife Car NFT", "CAR") {}

    /**
     * @dev 鸣造车辆 NFT
     */
    function mintCar(
        address to,
        string memory vin,
        string memory brand,
        string memory model,
        uint256 year,
        string memory color,
        uint256 mileage,
        string memory uri
    ) public onlyOwner returns (uint256) {
        require(!vinUsed[vin], "VIN already used");
        require(bytes(vin).length == 17, "Invalid VIN length");
        require(year >= 1900 && year <= 2100, "Invalid year");

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);

        carInfos[tokenId] = CarInfo({
            vin: vin,
            brand: brand,
            model: model,
            year: year,
            color: color,
            mileage: mileage,
            mintedAt: block.timestamp,
            owner: to
        });

        vinUsed[vin] = true;

        emit CarMinted(tokenId, to, vin);

        return tokenId;
    }

    /**
     * @dev 更新里程
     */
    function updateMileage(uint256 tokenId, uint256 mileage) public {
        require(_exists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
        require(mileage > carInfos[tokenId].mileage, "Mileage must increase");

        uint256 oldMileage = carInfos[tokenId].mileage;
        carInfos[tokenId].mileage = mileage;

        emit MileageUpdated(tokenId, oldMileage, mileage);
    }

    /**
     * @dev 添加维修记录
     */
    function addMaintenance(
        uint256 carTokenId,
        string memory description
    ) public {
        require(_exists(carTokenId), "Car token does not exist");

        MaintenanceRecord memory record = MaintenanceRecord({
            id: maintenanceHistory[carTokenId].length,
            carTokenId: carTokenId,
            description: description,
            timestamp: block.timestamp,
            provider: msg.sender
        });

        maintenanceHistory[carTokenId].push(record);

        emit MaintenanceAdded(carTokenId, description);
    }

    /**
     * @dev 获取车辆信息
     */
    function getCarInfo(uint256 tokenId) public view returns (CarInfo memory) {
        require(_exists(tokenId), "Token does not exist");
        return carInfos[tokenId];
    }

    /**
     * @dev 获取维修记录
     */
    function getMaintenanceHistory(uint256 tokenId) public view returns (MaintenanceRecord[] memory) {
        require(_exists(tokenId), "Token does not exist");
        return maintenanceHistory[tokenId];
    }

    /**
     * @dev 转移 NFT 时更新所有者
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        carInfos[tokenId].owner = to;
    }

    /**
     * @dev 检查 VIN 是否已使用
     */
    function isVinUsed(string memory vin) public view returns (bool) {
        return vinUsed[vin];
    }

    /**
     * @dev 检查 Token 是否存在
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return ownerOf(tokenId) != address(0);
    }
}

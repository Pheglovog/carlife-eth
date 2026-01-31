// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title CarLife
 * @dev CarLife 主合约 - 统一管理车辆 NFT、服务注册、数据 Token
 */
contract CarLife is ERC721, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;

    // Token 计数器
    Counters.Counter private _carTokenCounter;
    Counters.Counter private _dataTokenCounter;

    // 服务商计数器
    Counters.Counter private _providerCounter;
    Counters.Counter private _serviceCounter;

    // 服务类型
    enum ServiceType {
        MAINTENANCE,  // 维修
        INSURANCE,    // 保险
        WASH,         // 洗车
        GAS,          // 加油
        PARKING,      // 停车
        RENTAL        // 租赁
    }

    // 车辆 NFT
    struct CarInfo {
        uint256 id;
        string vin;
        string brand;
        string model;
        uint256 year;
        string color;
        uint256 mileage;
        uint256 mintedAt;
        address owner;
    }

    // 服务商
    struct ServiceProvider {
        uint256 id;
        string name;
        address wallet;
        ServiceType serviceType;
        string location;
        uint256 rating;          // 评分 * 100 (0-10000)
        uint256 reviewCount;      // 评价数量
        bool active;
        uint256 registeredAt;
    }

    // 服务
    struct Service {
        uint256 id;
        uint256 providerId;
        string title;
        string description;
        uint256 price;
        string currency;
        bool available;
    }

    // 评价
    struct Review {
        uint256 id;
        uint256 serviceId;
        address reviewer;
        uint256 rating;         // 1-5 * 100 (100-500)
        string comment;
        uint256 timestamp;
    }

    // 数据记录
    struct DataRecord {
        uint256 id;
        uint256 carTokenId;
        enum DataType {
            MILEAGE,
            MAINTENANCE,
            DRIVING_STYLE,
            LOCATION,
            USAGE
        } dataType;
        bytes encryptedData;
        string dataHash;
        uint256 price;
        bool forSale;
        address owner;
        uint256 createdAt;
    }

    // 映射
    mapping(uint256 => CarInfo) public carInfos;
    mapping(string => bool) public vinUsed;

    mapping(uint256 => ServiceProvider) public providers;
    mapping(address => uint256) public providerIdByAddress;

    mapping(uint256 => Service) public services;
    mapping(uint256 => Review[]) public serviceReviews;

    mapping(uint256 => DataRecord) public dataRecords;
    mapping(bytes32 => bool) public dataHashUsed;

    // 事件
    event CarMinted(uint256 indexed tokenId, address indexed owner, string vin);
    event CarTransferred(uint256 indexed tokenId, address indexed from, address indexed to);
    event MileageUpdated(uint256 indexed tokenId, uint256 oldMileage, uint256 newMileage);

    event ProviderRegistered(uint256 indexed providerId, string name, address wallet);
    event ServiceAdded(uint256 indexed serviceId, uint256 providerId, string title);
    event ReviewAdded(uint256 indexed serviceId, address reviewer, uint256 rating);

    event DataMinted(uint256 indexed recordId, uint256 carTokenId);
    event DataPurchased(uint256 indexed recordId, address buyer, uint256 price);

    string public constant NAME = "CarLife";
    string public constant SYMBOL = "CL";
    string public constant VERSION = "1.0.0";

    constructor() ERC721(NAME, SYMBOL) {}

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

        uint256 tokenId = _carTokenCounter.current();
        _carTokenCounter.increment();

        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);

        carInfos[tokenId] = CarInfo({
            id: tokenId,
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
        require(_carTokenExists(tokenId), "Car token does not exist");
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
        require(mileage > carInfos[tokenId].mileage, "Mileage must increase");

        uint256 oldMileage = carInfos[tokenId].mileage;
        carInfos[tokenId].mileage = mileage;

        emit MileageUpdated(tokenId, oldMileage, mileage);
    }

    /**
     * @dev 鸣造数据记录
     */
    function mintDataRecord(
        address to,
        uint256 carTokenId,
        uint256 dataType,
        bytes memory encryptedData,
        string memory dataHash,
        uint256 price
    ) public returns (uint256) {
        require(!_carTokenExists(carTokenId), "Car token does not exist");
        require(carInfos[carTokenId].owner == to, "Not car owner");

        bytes32 hash = keccak256(abi.encodePacked(dataHash));
        require(!dataHashUsed[hash], "Hash already used");

        uint256 recordId = _dataTokenCounter.current();
        _dataTokenCounter.increment();

        dataRecords[recordId] = DataRecord({
            id: recordId,
            carTokenId: carTokenId,
            dataType: DataRecord.DataType(dataType),
            encryptedData: encryptedData,
            dataHash: dataHash,
            price: price,
            forSale: false,
            owner: to,
            createdAt: block.timestamp
        });

        dataHashUsed[hash] = true;

        emit DataMinted(recordId, carTokenId);

        return recordId;
    }

    /**
     * @dev 获取车辆信息
     */
    function getCarInfo(uint256 tokenId) public view returns (CarInfo memory) {
        require(_carTokenExists(tokenId), "Car token does not exist");
        return carInfos[tokenId];
    }

    /**
     * @dev 获取用户车辆列表
     */
    function getUserCars(address owner) public view returns (uint256[] memory) {
        uint256 balance = balanceOf(owner);
        uint256[] memory tokens = new uint256[](balance);

        uint256 index = 0;
        for (uint256 i = 0; i < balance; i++) {
            tokens[index] = tokenOfOwnerByIndex(owner, i);
            index++;
        }

        return tokens;
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
    function _carTokenExists(uint256 tokenId) internal view returns (bool) {
        return ownerOf(tokenId) != address(0);
    }
}

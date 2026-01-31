// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title DataToken
 * @dev 车辆数据 Token 合约
 */
contract DataToken is ERC721 {
    constructor() ERC721("CarLife Data Token", "DATA") {}

    // 数据类型
    enum DataType {
        MILEAGE,    // 里程数据
        MAINTENANCE, // 维修记录
        DRIVING_STYLE, // 驾驶习惯
        LOCATION,      // 停车记录
        USAGE         // 使用记录
    }

    // 数据记录
    struct DataRecord {
        uint256 id;
        uint256 carTokenId;      // 关联的车辆 NFT
        DataType dataType;
        bytes encryptedData;     // 加密的数据
        string dataHash;         // 数据哈希
        uint256 price;           // 数据价格
        bool forSale;            // 是否在售
        address owner;            // 数据所有者
        uint256 createdAt;
    }

    mapping(uint256 => DataRecord) public dataRecords;
    mapping(bytes32 => bool) public dataHashUsed;

    event DataMinted(uint256 indexed recordId, uint256 carTokenId, DataType dataType);
    event DataPurchased(uint256 indexed recordId, address buyer, uint256 price);
    event DataListed(uint256 indexed recordId, uint256 price);

    function mintDataRecord(
        uint256 carTokenId,
        DataType dataType,
        bytes memory encryptedData,
        string memory dataHash,
        uint256 price
    ) public returns (uint256) {
        require(!dataHashUsed[keccak256(abi.encodePacked(dataHash))], "Hash already used");

        uint256 recordId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        dataRecords[recordId] = DataRecord({
            id: recordId,
            carTokenId: carTokenId,
            dataType: dataType,
            encryptedData: encryptedData,
            dataHash: dataHash,
            price: price,
            forSale: false,
            owner: msg.sender,
            createdAt: block.timestamp
        });

        dataHashUsed[keccak256(abi.encodePacked(dataHash))] = true;

        emit DataMinted(recordId, carTokenId, dataType);

        return recordId;
    }

    function listForSale(uint256 recordId, uint256 price) public {
        require(dataRecords[recordId].owner == msg.sender, "Not owner");

        dataRecords[recordId].price = price;
        dataRecords[recordId].forSale = true;

        emit DataListed(recordId, price);
    }

    function purchaseData(uint256 recordId) public payable {
        require(dataRecords[recordId].forSale, "Not for sale");
        require(msg.value >= dataRecords[recordId].price, "Insufficient payment");

        address oldOwner = dataRecords[recordId].owner;
        oldOwner.transfer(msg.value);

        dataRecords[recordId].owner = msg.sender;
        dataRecords[recordId].forSale = false;

        emit DataPurchased(recordId, msg.sender, msg.value);
    }

    function getDataRecord(uint256 recordId) public view returns (DataRecord memory) {
        return dataRecords[recordId];
    }
}

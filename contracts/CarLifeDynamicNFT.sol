// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

/**
 * @title CarLifeDynamicNFT
 * @dev 动态 Car NFT，根据车况和使用历史自动更新元数据和外观
 * @notice 支持基于车况的动态外观更新，集成 EIP-4906 标准事件
 */
contract CarLifeDynamicNFT is ERC721, ERC721URIStorage, Ownable, Pausable {
    using Strings for uint256;
    using Base64 for bytes;

    /// @dev 车辆数据结构
    struct CarData {
        string make;              // 品牌
        string model;             // 型号
        uint256 year;             // 年份
        uint256 mileage;          // 里程（公里）
        uint256 condition;        // 车况 (0-100)
        uint256 lastService;      // 上次维护时间
        uint256 serviceCount;     // 维护次数
        uint256 accidentCount;    // 事故次数
        bool isTotalLoss;         // 是否报废
    }

    /// @dev 外观等级
    enum Appearance {
        Poor,       // 较差 (0-39)
        Fair,       // 一般 (40-59)
        Good,       // 良好 (60-79)
        Excellent,  // 优秀 (80-100)
        TotalLoss   // 报废
    }

    /// @dev 每个车的动态数据
    mapping(uint256 => CarData) public carData;

    /// @dev 每个车的外观等级
    mapping(uint256 => Appearance) public carAppearance;

    /// @dev 基础 IPFS URI
    string private _baseIPFSURI;

    /// @dev 下一个 Token ID
    uint256 private _nextTokenId;

    /// @dev 铸造费（0.01 ETH）
    uint256 public constant MINT_FEE = 0.01 ether;

    /// @dev 维护费用（0.005 ETH）
    uint256 public constant SERVICE_FEE = 0.005 ether;

    /// @dev 里程更新费用（每1000公里 0.001 ETH）
    uint256 public constant MILEAGE_FEE = 0.0001 ether;

    // ========== 事件 ==========

    /// @notice 当里程被添加时触发
    event MileageAdded(uint256 indexed tokenId, uint256 mileageAdded, uint256 totalMileage);

    /// @notice 当执行维护时触发
    event ServicePerformed(uint256 indexed tokenId, uint256 serviceCount, uint256 newCondition);

    /// @notice 当记录事故时触发
    event AccidentRecorded(uint256 indexed tokenId, uint256 severity, uint256 accidentCount, bool isTotalLoss);

    /// @notice 当车辆外观更新时触发
    event AppearanceUpdated(uint256 indexed tokenId, Appearance oldAppearance, Appearance newAppearance);

    /// @notice 当铸造新车辆时触发
    event CarMinted(uint256 indexed tokenId, address indexed owner, string make, string model, uint256 year);

    // ========== 错误 ==========

    error InvalidTokenId();
    error NotOwnerOrApproved();
    error CarIsTotalLoss();
    error InsufficientPayment();
    error InvalidMileage();
    error InvalidSeverity();
    error ServiceTooFrequent();

    // ========== 构造函数 ==========

    /**
     * @notice 构造函数
     * @param name NFT 名称
     * @param symbol NFT 符号
     * @param baseIPFSURI 基础 IPFS URI（用于图片）
     */
    constructor(
        string memory name,
        string memory symbol,
        string memory baseIPFSURI
    ) ERC721(name, symbol) Ownable(msg.sender) {
        _baseIPFSURI = baseIPFSURI;
    }

    // ========== 铸造功能 ==========

    /**
     * @notice 铸造一辆新汽车 NFT
     * @param make 品牌
     * @param model 型号
     * @param year 年份
     * @return tokenId 新 Token ID
     */
    function mintCar(
        string calldata make,
        string calldata model,
        uint256 year
    ) external payable whenNotPaused returns (uint256) {
        if (msg.value < MINT_FEE) {
            revert InsufficientPayment();
        }

        uint256 tokenId = _nextTokenId++;
        _safeMint(msg.sender, tokenId);

        // 初始化车辆数据
        carData[tokenId] = CarData({
            make: make,
            model: model,
            year: year,
            mileage: 0,
            condition: 100,  // 新车车况为 100
            lastService: block.timestamp,
            serviceCount: 0,
            accidentCount: 0,
            isTotalLoss: false
        });

        // 初始化外观为优秀
        carAppearance[tokenId] = Appearance.Excellent;

        // 生成动态元数据
        _updateTokenURI(tokenId);

        emit CarMinted(tokenId, msg.sender, make, model, year);
        return tokenId;
    }

    // ========== 车辆状态更新功能 ==========

    /**
     * @notice 添加里程（每1000公里降低1点车况）
     * @param tokenId Token ID
     * @param miles 添加的里程
     */
    function addMileage(uint256 tokenId, uint256 miles) external payable {
        _checkOwnership(tokenId);
        if (carData[tokenId].isTotalLoss) {
            revert CarIsTotalLoss();
        }
        if (miles == 0) {
            revert InvalidMileage();
        }

        uint256 requiredFee = (miles / 1000) * MILEAGE_FEE;
        if (requiredFee > 0 && msg.value < requiredFee) {
            revert InsufficientPayment();
        }

        CarData storage car = carData[tokenId];
        car.mileage += miles;

        // 车况随里程下降（每1000公里下降1点，最低为0）
        uint256 conditionDrop = miles / 1000;
        if (car.condition >= conditionDrop) {
            car.condition -= conditionDrop;
        } else {
            car.condition = 0;
        }

        // 检查是否需要更新外观
        Appearance oldAppearance = carAppearance[tokenId];
        _updateAppearance(tokenId);
        Appearance newAppearance = carAppearance[tokenId];

        _updateTokenURI(tokenId);

        emit MileageAdded(tokenId, miles, car.mileage);
        if (oldAppearance != newAppearance) {
            emit AppearanceUpdated(tokenId, oldAppearance, newAppearance);
        }
    }

    /**
     * @notice 执行维护（恢复车况到 80-95 之间）
     * @param tokenId Token ID
     */
    function performService(uint256 tokenId) external payable {
        _checkOwnership(tokenId);
        if (carData[tokenId].isTotalLoss) {
            revert CarIsTotalLoss();
        }
        if (msg.value < SERVICE_FEE) {
            revert InsufficientPayment();
        }
        if (block.timestamp - carData[tokenId].lastService < 7 days) {
            revert ServiceTooFrequent();
        }

        CarData storage car = carData[tokenId];
        car.serviceCount++;
        car.lastService = block.timestamp;

        // 维修后车况恢复到 80-95 之间（随机）
        uint256 recovery = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.prevrandao,
            tokenId
        ))) % 16 + 80;
        car.condition = recovery;

        // 检查是否需要更新外观
        Appearance oldAppearance = carAppearance[tokenId];
        _updateAppearance(tokenId);
        Appearance newAppearance = carAppearance[tokenId];

        _updateTokenURI(tokenId);

        emit ServicePerformed(tokenId, car.serviceCount, car.condition);
        if (oldAppearance != newAppearance) {
            emit AppearanceUpdated(tokenId, oldAppearance, newAppearance);
        }
    }

    /**
     * @notice 记录事故（根据严重程度降低车况）
     * @param tokenId Token ID
     * @param severity 严重程度 (0-100)
     */
    function recordAccident(uint256 tokenId, uint256 severity) external {
        _checkOwnership(tokenId);

        if (severity > 100) {
            revert InvalidSeverity();
        }

        CarData storage car = carData[tokenId];
        car.accidentCount++;

        // 根据严重程度降低车况
        if (severity >= 80) {
            // 严重事故，车辆报废
            car.isTotalLoss = true;
            car.condition = 0;
            carAppearance[tokenId] = Appearance.TotalLoss;
        } else {
            // 普通事故，车况下降
            if (car.condition >= severity) {
                car.condition -= severity;
            } else {
                car.condition = 0;
            }

            // 检查是否需要更新外观
            _updateAppearance(tokenId);
        }

        _updateTokenURI(tokenId);

        emit AccidentRecorded(tokenId, severity, car.accidentCount, car.isTotalLoss);
    }

    // ========== 内部函数 ==========

    /**
     * @notice 检查所有权或授权
     * @param tokenId Token ID
     */
    function _checkOwnership(uint256 tokenId) private view {
        address owner = _ownerOf(tokenId);
        if (msg.sender != owner && !isApprovedForAll(owner, msg.sender) && getApproved(tokenId) != msg.sender) {
            revert NotOwnerOrApproved();
        }
    }

    /**
     * @notice 更新车辆外观
     * @param tokenId Token ID
     */
    function _updateAppearance(uint256 tokenId) private {
        CarData memory car = carData[tokenId];

        if (car.isTotalLoss) {
            carAppearance[tokenId] = Appearance.TotalLoss;
        } else if (car.condition >= 80) {
            carAppearance[tokenId] = Appearance.Excellent;
        } else if (car.condition >= 60) {
            carAppearance[tokenId] = Appearance.Good;
        } else if (car.condition >= 40) {
            carAppearance[tokenId] = Appearance.Fair;
        } else {
            carAppearance[tokenId] = Appearance.Poor;
        }
    }

    /**
     * @notice 生成并更新 Token URI
     * @param tokenId Token ID
     */
    function _updateTokenURI(uint256 tokenId) private {
        string memory metadata = _generateMetadata(tokenId);
        _setTokenURI(tokenId, metadata);
        emit MetadataUpdate(tokenId);
    }

    /**
     * @notice 生成元数据
     * @param tokenId Token ID
     * @return metadata 元数据 JSON（Base64 编码）
     */
    function _generateMetadata(uint256 tokenId) private view returns (string memory) {
        CarData memory car = carData[tokenId];
        Appearance appearance = carAppearance[tokenId];
        string memory appearanceURI = _getAppearanceURI(tokenId, appearance);
        string memory status = car.isTotalLoss ? "Total Loss" : "Active";

        string memory metadataJSON = string(abi.encodePacked(
            '{',
            '"name": "', car.make, ' ', car.model, ' #', tokenId.toString(), '",',
            '"description": "A dynamic car NFT that evolves based on usage and condition.",',
            '"image": "', appearanceURI, '",',
            '"attributes": [',
            '{ "trait_type": "Make", "value": "', car.make, '" },',
            '{ "trait_type": "Model", "value": "', car.model, '" },',
            '{ "trait_type": "Year", "value": "', car.year.toString(), '" },',
            '{ "trait_type": "Mileage", "value": "', car.mileage.toString(), '",',
            '  "max_value": "1000000", "display_type": "number" },',
            '{ "trait_type": "Condition", "value": "', car.condition.toString(), '",',
            '  "max_value": "100", "display_type": "boost_percentage" },',
            '{ "trait_type": "Service Count", "value": "', car.serviceCount.toString(), '" },',
            '{ "trait_type": "Accident Count", "value": "', car.accidentCount.toString(), '" },',
            '{ "trait_type": "Status", "value": "', status, '" },',
            '{ "trait_type": "Appearance", "value": "', _appearanceToString(appearance), '" }',
            ']',
            '}'
        ));

        return string(abi.encodePacked(
            "data:application/json;base64,",
            bytes(metadataJSON).encode()
        ));
    }

    /**
     * @notice 获取外观对应的 URI
     * @param tokenId Token ID
     * @param appearance 外观等级
     * @return uri 图片 URI
     */
    function _getAppearanceURI(uint256 tokenId, Appearance appearance) private view returns (string memory) {
        string memory appearanceStr = _appearanceToString(appearance);
        return string(abi.encodePacked(
            _baseIPFSURI,
            "/",
            appearanceStr,
            "/",
            tokenId.toString(),
            ".png"
        ));
    }

    /**
     * @notice 将外观枚举转换为字符串
     * @param appearance 外观等级
     * @return str 字符串
     */
    function _appearanceToString(Appearance appearance) private pure returns (string memory) {
        if (appearance == Appearance.Poor) return "poor";
        if (appearance == Appearance.Fair) return "fair";
        if (appearance == Appearance.Good) return "good";
        if (appearance == Appearance.Excellent) return "excellent";
        return "total-loss";
    }

    // ========== 查询功能 ==========

    /**
     * @notice 获取车辆详细信息
     * @param tokenId Token ID
     * @return car 车辆数据
     */
    function getCarInfo(uint256 tokenId) external view returns (CarData memory) {
        return carData[tokenId];
    }

    /**
     * @notice 获取车辆外观等级
     * @param tokenId Token ID
     * @return appearance 外观等级
     */
    function getCarAppearance(uint256 tokenId) external view returns (Appearance) {
        return carAppearance[tokenId];
    }

    /**
     * @notice 批量获取车辆信息
     * @param tokenIds Token ID 数组
     * @return cars 车辆数据数组
     * @return appearances 外观数组
     */
    function batchGetCarInfo(uint256[] calldata tokenIds)
        external
        view
        returns (CarData[] memory cars, Appearance[] memory appearances)
    {
        cars = new CarData[](tokenIds.length);
        appearances = new Appearance[](tokenIds.length);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            cars[i] = carData[tokenIds[i]];
            appearances[i] = carAppearance[tokenIds[i]];
        }
    }

    // ========== 管理员功能 ==========

    /**
     * @notice 设置基础 IPFS URI（仅管理员）
     * @param newBaseIPFSURI 新的基础 IPFS URI
     */
    function setBaseIPFSURI(string calldata newBaseIPFSURI) external onlyOwner {
        _baseIPFSURI = newBaseIPFSURI;
    }

    /**
     * @notice 提取合约余额（仅管理员）
     */
    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    /**
     * @notice 紧急暂停（仅管理员）
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice 恢复（仅管理员）
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // ========== 重写函数 ==========

    /**
     * @notice Token URI（重写以支持动态元数据）
     * @param tokenId Token ID
     * @return uri Token URI
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721URIStorage, ERC721)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    /**
     * @notice 支持的接口（重写以支持 ERC4906）
     * @param interfaceId 接口 ID
     * @return bool 是否支持
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        // ERC4906 接口 ID: 0x49064906
        bytes4 erc4906InterfaceId = 0x49064906;
        if (interfaceId == erc4906InterfaceId) {
            return true;
        }
        return super.supportsInterface(interfaceId);
    }
}

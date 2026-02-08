// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title CarNFTFixed
 * @author Pheglovog
 * @notice 修复版 CarNFT，兼容 OpenZeppelin 5.x
 */

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract CarNFTFixed is ERC721, ERC721URIStorage, Ownable, Pausable {

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

    // ====== 修饰器 ======

    modifier whenNotPausedMinting() {
        require(!_mintingPaused, "Minting is paused");
        _;
    }

    modifier onlyCustomAuthorized() {
        require(msg.sender == owner() || _customAuthorized[msg.sender], "Not authorized");
        _;
    }

    // ====== 构造函数 ======

    constructor() ERC721("CarLife NFT", "CLFT") Ownable(msg.sender) {
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
    ) public onlyOwner whenNotPaused whenNotPausedMinting {
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
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
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
        require(_ownerOf(tokenId) != address(0), "Token does not exist");

        _carInfos[tokenId].mileage = mileage;
        _carInfos[tokenId].condition = condition;

        emit CarInfoUpdated(tokenId, mileage, condition);
    }

    function addMaintenance(
        uint256 tokenId,
        uint256 mileage,
        string memory notes
    ) public onlyCustomAuthorized {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");

        _carInfos[tokenId].mileage = mileage;
        _carInfos[tokenId].lastServiceDate = block.timestamp;

        emit MaintenanceAdded(tokenId, mileage, notes);
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

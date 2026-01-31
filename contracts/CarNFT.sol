// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @title CarNFT
 * @dev 车辆 NFT 合约，代表车辆数字身份
 */
contract CarNFT is ERC721 {
    constructor() ERC721("CarLife Car NFT", "CAR") {}

    // TODO: 实现车辆 NFT 功能
}

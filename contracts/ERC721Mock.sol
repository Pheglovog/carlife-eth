// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @title ERC721Mock
 * @dev Simple ERC721 mock for testing
 */
contract ERC721Mock is ERC721 {
    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    /**
     * @notice Mint tokens
     * @param to Recipient address
     * @param tokenId Token ID to mint
     */
    function mint(address to, uint256 tokenId) external {
        _safeMint(to, tokenId, "");
    }

    /**
     * @notice Batch mint tokens
     * @param to Recipient address
     * @param tokenIds Array of token IDs to mint
     */
    function batchMint(address to, uint256[] calldata tokenIds) external {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _safeMint(to, tokenIds[i], "");
        }
    }
}

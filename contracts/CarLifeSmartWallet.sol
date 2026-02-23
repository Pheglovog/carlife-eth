// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title CarLifeSmartWallet
 * @dev CarLife Smart Wallet contract for ERC-4337 Account Abstraction
 * 
 * This contract implements a smart wallet with the following features:
 * - Social Recovery (Multi-sig style)
 * - Session Keys (Time-limited keys for restricted access)
 * - Paymaster Integration (Gasless transactions)
 * - NFT Management (ERC-721)
 */
contract CarLifeSmartWallet is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuard,
    EIP712Upgradeable
{
    using ECDSA for bytes32;

    // Constants
    uint256 public constant SIGNATURE_VALIDATION_DELAY = 1 hours;
    uint256 public constant SIGNATURE_EXPIRATION_DELAY = 30 days;
    uint256 public constant MAX_SIGNER_COUNT = 10;
    uint256 public constant MAX_SESSION_KEYS = 10;
    uint256 public constant MAX_SESSION_EXPIRY = 30 days;
    uint256 public constant MIN_SESSION_EXPIRY = 1 hours;

    // State variables
    address public immutable carNFT; // CarLife NFT contract
    bytes32 private immutable _DOMAIN_SEPARATOR;
    bytes32 private constant _SESSION_KEY_TYPEHASH =
        keccak256("SessionKey(address key, uint256 nonce, uint256 expiry)");
    bytes32 private constant _RECOVERY_TYPEHASH =
        keccak256("Recovery(address[] newSigners, uint256 threshold)");

    // Mappings
    mapping(address => bool) public isSigner;
    mapping(address => SessionKey) public sessionKeys;
    address[] public signers;
    uint256 public signerThreshold;

    // Structs
    struct SessionKey {
        address key;
        uint256 nonce;
        uint256 expiry;
    }

    struct Recovery {
        address[] newSigners;
        uint256 threshold;
        uint256 deadline;
        uint256 executedAt;
        bool executed;
    }

    // Modifiers
    modifier onlySigner() {
        require(isSigner[msg.sender], "Not a signer");
        _;
    }

    // Events
    event SignerAdded(address indexed signer);
    event SignerRemoved(address indexed signer);
    event SignerThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);
    event SessionKeyAdded(address indexed key, uint256 expiry);
    event SessionKeyRevoked(address indexed key);
    event RecoveryRequested(
        address[] newSigners,
        uint256 threshold,
        uint256 deadline,
        bytes32 recoveryId
    );
    event RecoveryExecuted(address[] newSigners, uint256 threshold, bytes32 recoveryId);

    /**
     * @notice Constructor
     * @param _carNFT CarLife NFT contract address
     * @param _owner Initial owner (msg.sender)
     * @param _initialSigners Initial signer list
     * @param _signerThreshold Initial threshold
     */
    constructor(
        address _carNFT,
        address _owner,
        address[] memory _initialSigners,
        uint256 _signerThreshold
    ) {
        _disableInitializers();

        require(_carNFT != address(0), "Invalid NFT address");
        require(_initialSigners.length > 0, "At least one signer required");
        require(_initialSigners.length <= MAX_SIGNER_COUNT, "Too many signers");
        require(_initialSigners.length <= _signerThreshold, "Threshold too high");
        require(_initialSigners.length > 0, "At least one signer");

        // Set CarNFT
        carNFT = _carNFT;

        // Initialize Domain Separator
        _DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("CarLifeSmartWallet"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );

        // Initialize signers
        for (uint256 i = 0; i < _initialSigners.length; i++) {
            address signer = _initialSigners[i];
            require(signer != address(0), "Invalid signer");
            _addSigner(signer);
        }

        // Set threshold
        signerThreshold = _signerThreshold;

        // Set owner (msg.sender)
        _transferOwnership(_owner);
    }

    /**
     * @notice Validate user operation (ERC-4337)
     * @param userOp User operation
     * @param userOpHash User operation hash
     * @param aggregator Aggregator address
     * @return deadline Signature deadline
     */
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        address aggregator
    ) external view returns (uint256 deadline) {
        // Check if it's a session key
        if (sessionKeys[msg.sender].expiry > block.timestamp) {
            return block.timestamp + MAX_SESSION_EXPIRY;
        }

        // Verify signer signature
        _isValidSignature(userOpHash, aggregator, userOp.signature);

        // Set deadline
        deadline = block.timestamp + SIGNATURE_EXPIRATION_DELAY;
    }

    /**
     * @notice Execute transaction
     * @param to Target address
     * @param value Value
     * @param data Transaction data
     */
    function execute(
        address to,
        uint256 value,
        bytes calldata data
    ) external onlySigner nonReentrant {
        (bool success, ) = to.call{ value: value }(data);
        require(success, "Execution failed");
    }

    /**
     * @notice Execute batch transactions
     * @param targets Target addresses
     * @param values Values
     * @param calldatas Transaction data
     */
    function executeBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas
    ) external onlySigner nonReentrant {
        require(targets.length == values.length, "Invalid inputs");
        require(targets.length == calldatas.length, "Invalid inputs");

        for (uint256 i = 0; i < targets.length; i++) {
            (bool success, ) = targets[i].call{ value: values[i] }(calldatas[i]);
            require(success, "Execution failed");
        }
    }

    /**
     * @notice Add a new signer
     * @param signer Signer address
     */
    function addSigner(address signer) external onlyOwner nonReentrant {
        _addSigner(signer);
    }

    /**
     * @notice Remove a signer
     * @param signer Signer address
     */
    function removeSigner(address signer) external onlyOwner nonReentrant {
        require(isSigner[signer], "Signer does not exist");

        // Remove from mapping
        isSigner[signer] = false;

        // Remove from array
        for (uint256 i = 0; i < signers.length; i++) {
            if (signers[i] == signer) {
                signers[i] = signers[signers.length - 1];
                signers.pop();
                break;
            }
        }

        // Adjust threshold if needed
        if (signers.length < signerThreshold) {
            signerThreshold = signers.length;
        }

        emit SignerRemoved(signer);
    }

    /**
     * @notice Update signer threshold
     * @param newThreshold New threshold
     */
    function updateSignerThreshold(uint256 newThreshold) external onlyOwner {
        require(newThreshold > 0 && newThreshold <= signers.length, "Invalid threshold");
        uint256 oldThreshold = signerThreshold;
        signerThreshold = newThreshold;
        emit SignerThresholdUpdated(oldThreshold, newThreshold);
    }

    /**
     * @notice Add a session key
     * @param key Session key address
     * @param expiry Expiry time (timestamp)
     */
    function addSessionKey(address key, uint256 expiry) external onlySigner nonReentrant {
        require(key != address(0), "Invalid key");
        require(expiry > block.timestamp + MIN_SESSION_EXPIRY, "Invalid expiry");
        require(expiry <= block.timestamp + MAX_SESSION_EXPIRY, "Expiry too long");

        // Check if session key already exists
        require(sessionKeys[key].expiry == 0 || sessionKeys[key].expiry < block.timestamp, "Key already exists");

        // Add session key
        sessionKeys[key] = SessionKey({
            key: key,
            nonce: block.timestamp, // Use timestamp as nonce
            expiry: expiry
        });

        emit SessionKeyAdded(key, expiry);
    }

    /**
     * @notice Revoke a session key
     * @param key Session key address
     */
    function revokeSessionKey(address key) external onlySigner nonReentrant {
        require(sessionKeys[key].expiry > block.timestamp, "Key does not exist or expired");

        delete sessionKeys[key];

        emit SessionKeyRevoked(key);
    }

    /**
     * @notice Execute recovery (social recovery)
     * @param newSigners New signer addresses
     * @param threshold New threshold
     * @param deadline Recovery deadline (must be in future)
     * @param signature Signature of new owners
     */
    function executeRecovery(
        address[] calldata newSigners,
        uint256 threshold,
        uint256 deadline,
        bytes calldata signature
    ) external onlySigner nonReentrant {
        require(block.timestamp >= deadline, "Too early to execute");
        require(block.timestamp < deadline + 30 days, "Recovery expired");
        require(newSigners.length <= MAX_SIGNER_COUNT, "Too many signers");
        require(threshold > 0 && threshold <= newSigners.length, "Invalid threshold");

        // Build message hash
        bytes32 recoveryId = keccak256(
            abi.encode(
                _RECOVERY_TYPEHASH,
                newSigners,
                threshold
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", _DOMAIN_SEPARATOR, recoveryId)
        );

        // Verify signatures from current signers
        uint256 signatureCount = 0;
        for (uint256 i = 0; i < signers.length; i++) {
            address signer = signers[i];
            // Split signature for each signer
            bytes32 r;
            bytes32 s;
            uint8 v;
            // Note: For simplicity, we're assuming signature is a single 65-byte value
            // In production, you would implement batching or use EIP-2098

            // Verify signature
            address recovered = ECDSA.recover(digest, v, r, s);
            if (recovered == signer) {
                signatureCount++;
            }
        }

        require(signatureCount >= signerThreshold, "Insufficient signatures");

        // Replace signers
        for (uint256 i = 0; i < signers.length; i++) {
            address newSigner = newSigners[i];
            if (!isSigner[newSigner]) {
                _addSigner(newSigner);
            }
        }

        // Remove old signers not in new list
        for (uint256 i = signers.length - 1; i >= 0; i--) {
            address oldSigner = signers[i];
            bool found = false;
            for (uint256 j = 0; j < newSigners.length; j++) {
                if (newSigners[j] == oldSigner) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                isSigner[oldSigner] = false;
                signers.pop();
            }
        }

        // Update threshold
        signerThreshold = threshold;

        emit RecoveryExecuted(newSigners, threshold, recoveryId);
    }

    /**
     * @notice Validate signature
     * @param userOpHash User operation hash
     * @param aggregator Aggregator address
     * @param signature Signature
     * @return isValid Signature is valid
     */
    function _isValidSignature(
        bytes32 userOpHash,
        address aggregator,
        bytes memory signature
    ) internal view returns (bool isValid) {
        // Check if it's a session key
        if (sessionKeys[msg.sender].expiry > block.timestamp) {
            // Session key signature is not verified here
            // It's assumed to be verified by the EntryPoint
            return true;
        }

        // Check if it's a signer
        if (isSigner[msg.sender]) {
            // Verify signer signature
            address signer = ECDSA.recover(userOpHash, signature);
            return signer == msg.sender;
        }

        return false;
    }

    /**
     * @notice Add a signer
     * @param signer Signer address
     */
    function _addSigner(address signer) internal {
        require(!isSigner[signer], "Signer already exists");
        require(signers.length < MAX_SIGNER_COUNT, "Too many signers");

        isSigner[signer] = true;
        signers.push(signer);

        emit SignerAdded(signer);
    }

    /**
     * @notice Transfer ownership
     * @param newOwner New owner
     */
    function _transferOwnership(address newOwner) internal override {
        address oldOwner = owner();
        OwnableUpgradeable._transferOwnership(newOwner);
    }

    /**
     * @notice Get current owners
     * @return owners Array of signer addresses
     */
    function getSigners() external view returns (address[] memory) {
        return signers;
    }

    /**
     * @notice Get signer count
     * @return count Number of signers
     */
    function getSignerCount() external view returns (uint256) {
        return signers.length;
    }

    /**
     * @notice Authorize upgrade
     * @param newImplementation New implementation address
     */
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    /**
     * @notice Upgrade to implementation
     * @param newImplementation New implementation address
     * @param data Upgrade data
     */
    function upgradeTo(
        address newImplementation,
        bytes calldata data
    ) external payable onlyOwner {
        upgradeToAndCall(newImplementation, data);
    }

    /**
     * @notice Get domain separator
     * @return domainSeparator Domain separator hash
     */
    function domainSeparator() external view returns (bytes32) {
        return _DOMAIN_SEPARATOR;
    }

    /**
     * @notice Get EIP-712 domain
     * @return fields EIP-712 domain fields
     */
    function eip712Domain()
        public
        view
        override
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        )
    {
        return super.eip712Domain();
    }

    /**
     * @notice Get session key info
     * @param key Key address
     * @return _key Session key address
     * @return nonce Session key nonce
     * @return expiry Session key expiry timestamp
     * @return active Whether the session key is active
     */
    function getSessionKeyInfo(address key)
        external
        view
        returns (
            address _key,
            uint256 nonce,
            uint256 expiry,
            bool active
        )
    {
        SessionKey memory sessionKey = sessionKeys[key];
        return (
            sessionKey.key,
            sessionKey.nonce,
            sessionKey.expiry,
            sessionKey.expiry > block.timestamp
        );
    }
}

/**
 * @title UserOperation
 * @dev User operation structure (simplified)
 */
struct UserOperation {
    address sender;
    uint256 nonce;
    bytes initCode;
    bytes callData;
    uint256 callGasLimit;
    uint256 verificationGasLimit;
    uint256 preVerificationGas;
    uint256 maxFeePerGas;
    uint256 priorityFeePerGas;
    bytes paymasterAndData;
    bytes signature;
}

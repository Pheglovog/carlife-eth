// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title CarLifeEntryPoint
 * @dev CarLife EntryPoint contract for ERC-4337 Account Abstraction
 * 
 * This contract acts as an aggregator that handles UserOperations from multiple accounts,
 * validates Paymaster balances, verifies account signatures, and executes transactions.
 */
contract CarLifeEntryPoint is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Constants
    uint256 public constant STUB_VALUE = 1 wei;
    uint256 public constant PAYMASTER_VALIDATION_GAS = 5000;
    uint256 public constant USER_VALIDATION_GAS = 100000;
    uint256 public constant PRE_VERIFICATION_GAS = 100000;
    uint256 public constant MAX_OPS_PER_HANDLEOPS = 10;

    // State variables
    ICarLifePaymaster public immutable paymaster;
    mapping(address => uint256) public nonces;
    uint256 public maxOpsPerHandleOps;

    // Events
    event UserOperationEvent(
        bytes32 indexed userOpHash,
        address indexed sender,
        address indexed target,
        uint256 value,
        bytes data,
        bytes signature
    );
    event UserOperationReverted(
        bytes32 indexed userOpHash,
        address indexed sender,
        uint256 reason
    );
    event UserOperationPrefundFailed(
        bytes32 indexed userOpHash,
        address indexed sender,
        uint256 prefund,
        uint256 requiredPrefund
    );
    event UserOperationValidationFailed(
        bytes32 indexed userOpHash,
        address indexed sender,
        address aggregator,
        uint256 reason
    );

    /**
     * @notice Constructor
     * @param _paymaster Paymaster address
     * @param _maxOpsPerHandleOps Max operations per handleOps
     */
    constructor(address _paymaster, uint256 _maxOpsPerHandleOps) Ownable(msg.sender) {
        require(_paymaster != address(0), "Invalid paymaster address");
        require(_maxOpsPerHandleOps > 0 && _maxOpsPerHandleOps <= MAX_OPS_PER_HANDLEOPS, "Invalid max ops");
        
        paymaster = ICarLifePaymaster(_paymaster);
        maxOpsPerHandleOps = _maxOpsPerHandleOps;
    }

    /**
     * @notice Handle UserOperations
     * @dev This function is called by relayers to submit UserOperations
     * @param ops Array of UserOperations
     * @param beneficiary Beneficiary address
     * @return payment Total payment
     * @return infos Array of UserOpInfo
     */
    function handleOps(
        UserOperation[] calldata ops,
        address payable beneficiary
    ) external nonReentrant returns (uint256 payment, UserOpInfo[] memory infos) {
        require(ops.length > 0 && ops.length <= maxOpsPerHandleOps, "Invalid number of ops");
        require(beneficiary != address(0), "Invalid beneficiary");

        infos = new UserOpInfo[](ops.length);

        // Iterate through each UserOperation
        for (uint256 i = 0; i < ops.length; i++) {
            UserOperation calldata op = ops[i];

            // Get UserOperation hash
            bytes32 userOpHash = getUserOpHash(op, address(this), block.chainid);

            // Validate Paymaster
            uint256 requiredPrefund = _getRequiredPrefund(op);
            (bool paymasterValid, bytes memory paymasterContext) = _validatePaymaster(
                op,
                userOpHash,
                requiredPrefund
            );

            if (!paymasterValid) {
                emit UserOperationPrefundFailed(
                    userOpHash,
                    op.sender,
                    _getPrefund(op),
                    requiredPrefund
                );
                continue;
            }

            // Validate Account
            _validateAccount(op, userOpHash);

            // Execute UserOperation
            (bool success, bytes memory returndata) = _execute(op);

            if (success) {
                // Update nonce
                nonces[op.sender]++;

                // Emit success event
                emit UserOperationEvent(
                    userOpHash,
                    op.sender,
                    _getTarget(op),
                    _getValue(op),
                    op.callData,
                    op.signature
                );
            } else {
                // Emit revert event
                emit UserOperationReverted(
                    userOpHash,
                    op.sender,
                    _getRevertReason(returndata)
                );
            }

            // Store UserOpInfo
            infos[i] = UserOpInfo({
                preOpGas: 0, // Simplified
                prefund: requiredPrefund,
                hadPrefund: true,
                usedGas: 0 // Simplified
            });
        }

        // Calculate payment
        payment = _calculatePayment(infos);

        // Pay to beneficiary
        if (payment > 0) {
            payable(beneficiary).transfer(payment);
        }
    }

    /**
     * @notice Get UserOperation hash
     * @param op UserOperation
     * @param entryPoint EntryPoint address
     * @param chainId Chain ID
     * @return opHash UserOperation hash
     */
    function getUserOpHash(
        UserOperation calldata op,
        address entryPoint,
        uint256 chainId
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                op.sender,
                op.nonce,
                keccak256(op.initCode),
                keccak256(op.callData),
                op.callGasLimit,
                op.verificationGasLimit,
                op.preVerificationGas,
                op.maxFeePerGas,
                op.priorityFeePerGas,
                op.paymasterAndData,
                chainId,
                entryPoint
            )
        );
    }

    /**
     * @notice Validate Paymaster
     * @param op UserOperation
     * @param userOpHash UserOperation hash
     * @param requiredPrefund Required prefund
     * @return valid Paymaster is valid
     * @return context Context
     */
    function _validatePaymaster(
        UserOperation calldata op,
        bytes32 userOpHash,
        uint256 requiredPrefund
    ) internal view returns (bool valid, bytes memory context) {
        // Check if paymaster data is set
        if (op.paymasterAndData.length == 0) {
            return (true, new bytes(0));
        }

        // Extract paymaster address
        address pm = address(bytes20(op.paymasterAndData));

        // Check if it's our paymaster
        if (pm != address(paymaster)) {
            return (false, new bytes(0));
        }

        // Call paymaster's validate function
        (bool success, bytes memory returndata) = address(pm).staticcall(
            abi.encodeWithSelector(
                ICarLifePaymaster.validatePaymasterUserOp.selector,
                op,
                userOpHash,
                requiredPrefund
            )
        );

        if (!success) {
            return (false, new bytes(0));
        }

        // Decode context
        context = returndata;
        return (true, context);
    }

    /**
     * @notice Validate Account
     * @param op UserOperation
     * @param userOpHash UserOperation hash
     */
    function _validateAccount(
        UserOperation calldata op,
        bytes32 userOpHash
    ) internal view {
        // If initCode is set, we need to create the account (simplified)
        if (op.initCode.length == 0) {
            // Call account's validateUserOp function
            IAccount account = IAccount(op.sender);

            (bool success, bytes memory returndata) = address(account).staticcall(
                abi.encodeWithSelector(
                    IAccount.validateUserOp.selector,
                    op,
                    userOpHash,
                    address(0)
                )
            );

            require(success, "Account validation failed");

            // Decode deadline
            (uint256 deadline) = abi.decode(returndata, (uint256));
            require(block.timestamp <= deadline, "Signature expired");
        }
    }

    /**
     * @notice Execute UserOperation
     * @param op UserOperation
     * @return success Execution success
     * @return returndata Return data
     */
    function _execute(UserOperation calldata op)
        internal
        returns (bool success, bytes memory returndata)
    {
        address to = _getTarget(op);
        uint256 value = _getValue(op);
        bytes memory data = op.callData;

        // Execute transaction
        (success, returndata) = to.call{ value: value, gas: op.callGasLimit }(data);
    }

    /**
     * @notice Get target address from UserOperation
     * @param op UserOperation
     * @return target Target address
     */
    function _getTarget(UserOperation calldata op)
        internal
        pure
        returns (address target)
    {
        // Extract target from callData
        // This is a simplified implementation
        // In a real scenario, you would parse the ABI
        if (op.callData.length >= 32) {
            target = address(bytes20(op.callData[12:32]));
        } else {
            target = address(0);
        }
    }

    /**
     * @notice Get value from UserOperation
     * @param op UserOperation
     * @return value Value
     */
    function _getValue(UserOperation calldata op)
        internal
        pure
        returns (uint256 value)
    {
        // Extract value from callData
        // This is a simplified implementation
        // In a real scenario, you would parse the ABI
        if (op.callData.length >= 64) {
            value = uint256(bytes32(op.callData[32:64]));
        } else {
            value = 0;
        }
    }

    /**
     * @notice Get prefund from UserOperation
     * @param op UserOperation
     * @return prefund Prefund amount
     */
    function _getPrefund(UserOperation calldata op)
        internal
        pure
        returns (uint256 prefund)
    {
        // Extract prefund from paymasterAndData
        // This is a simplified implementation
        // In a real scenario, you would decode the data
        if (op.paymasterAndData.length >= 20) {
            uint256 paymasterPrefund = uint256(bytes32(op.paymasterAndData[0:20]));
            prefund = paymasterPrefund;
        } else {
            prefund = 0;
        }
    }

    /**
     * @notice Get required prefund
     * @param op UserOperation
     * @return requiredPrefund Required prefund
     */
    function _getRequiredPrefund(UserOperation calldata op)
        internal
        pure
        returns (uint256 requiredPrefund)
    {
        requiredPrefund = op.callGasLimit * op.maxFeePerGas;
        requiredPrefund += op.verificationGasLimit * op.maxFeePerGas;
        requiredPrefund += op.preVerificationGas * op.maxFeePerGas;
        requiredPrefund += op.priorityFeePerGas * STUB_VALUE;

        // Add paymaster prefund
        requiredPrefund += _getPrefund(op);
    }

    /**
     * @notice Calculate payment
     * @param infos Array of UserOpInfo
     * @return payment Total payment
     */
    function _calculatePayment(UserOpInfo[] memory infos)
        internal
        pure
        returns (uint256 payment)
    {
        payment = 0;
        for (uint256 i = 0; i < infos.length; i++) {
            if (infos[i].hadPrefund) {
                payment += infos[i].prefund;
            }
        }
    }

    /**
     * @notice Get revert reason
     * @param returndata Return data
     * @return reason Revert reason
     */
    function _getRevertReason(bytes memory returndata)
        internal
        pure
        returns (uint256 reason)
    {
        // Try to decode error message
        if (returndata.length >= 4) {
            // Error selector is first 4 bytes
            reason = uint256(bytes32(returndata));
        } else {
            reason = 0;
        }
    }

    /**
     * @notice Staticcall wrapper
     * @param target Target address
     * @param data Call data
     * @return success Call success
     * @return returndata Return data
     */
    function staticcall(address target, bytes memory data)
        internal
        returns (bool success, bytes memory returndata)
    {
        // Use STATICCALL to prevent state changes
        (success, returndata) = target.staticcall(data);
    }

    /**
     * @notice Set max ops per handleOps
     * @param _maxOps New max ops
     */
    function setMaxOpsPerHandleOps(uint256 _maxOps) external onlyOwner {
        require(_maxOps > 0 && _maxOps <= MAX_OPS_PER_HANDLEOPS, "Invalid max ops");
        maxOpsPerHandleOps = _maxOps;
    }

    /**
     * @notice Get nonce
     * @param sender Sender address
     * @return nonce Current nonce
     */
    function getNonce(address sender) external view returns (uint256) {
        return nonces[sender];
    }

    /**
     * @notice Receive ETH
     */
    receive() external payable {}
}

/**
 * @title IAccount
 * @dev Account interface
 */
interface IAccount {
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        address aggregator
    ) external view returns (uint256 deadline);
}

/**
 * @title ICarLifePaymaster
 * @dev CarLife Paymaster interface
 */
interface ICarLifePaymaster {
    function validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 requiredPreFund
    ) external view returns (bytes memory context);

    function postOp(
        bytes calldata context,
        uint256 actualGasCost
    ) external payable;
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

/**
 * @title UserOpInfo
 * @dev User operation info structure
 */
struct UserOpInfo {
    uint256 preOpGas;
    uint256 prefund;
    bool hadPrefund;
    uint256 usedGas;
}

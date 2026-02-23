// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title CarLifePaymaster
 * @dev CarLife Paymaster contract for ERC-4337 Account Abstraction
 * 
 * This contract allows users to pay gas fees using CAR tokens,
 * and allows sponsors to sponsor gas for specific users.
 */
contract CarLifePaymaster is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Constants
    uint256 public constant PRICE_COMPARATOR = 1e18;
    uint256 public constant MAX_SPONSORED_USERS = 1000;
    uint256 public constant MAX_ALLOWED_PAYMASTERS = 100;
    uint256 public constant MIN_DEPOSIT_AMOUNT = 1e18; // 1 CAR

    // State variables
    IERC20 public immutable carToken; // CAR token
    
    // Mappings
    mapping(address => uint256) public balances;
    mapping(address => uint256) public sponsoredBalances;
    mapping(address => bool) public isSponsoredUser;
    mapping(address => bool) public isAllowedPaymaster;
    
    // Arrays
    address[] public sponsoredUsers;
    address[] public allowedPaymasters;

    // Configuration
    uint256 public relayerFee = 0.001e18; // 0.1% of CAR
    uint256 public minDeposit = MIN_DEPOSIT_AMOUNT;
    uint256 public withdrawalDelay = 1 days;

    // Events
    event Deposited(address indexed account, uint256 amount);
    event Withdrawn(address indexed account, uint256 amount);
    event Sponsored(address indexed sponsor, address indexed account, uint256 amount);
    event RelayerFeeSet(uint256 oldFee, uint256 newFee);
    event AllowedPaymasterAdded(address indexed paymaster);
    event AllowedPaymasterRemoved(address indexed paymaster);
    event SponsoredUserAdded(address indexed user);
    event SponsoredUserRemoved(address indexed user);
    event MinDepositSet(uint256 oldMin, uint256 newMin);
    event WithdrawalDelaySet(uint256 oldDelay, uint256 newDelay);

    /**
     * @notice Constructor
     * @param _carToken CAR token address
     */
    constructor(address _carToken) Ownable(msg.sender) {
        require(_carToken != address(0), "Invalid token address");
        carToken = IERC20(_carToken);
    }

    /**
     * @notice Deposit CAR tokens to pay for gas
     * @param _amount Amount to deposit
     */
    function deposit(uint256 _amount) external nonReentrant {
        require(_amount >= minDeposit, "Amount below minimum");

        // Transfer CAR tokens
        carToken.safeTransferFrom(msg.sender, address(this), _amount);

        // Update balance
        balances[msg.sender] += _amount;

        emit Deposited(msg.sender, _amount);
    }

    /**
     * @notice Withdraw CAR tokens
     * @param _amount Amount to withdraw
     */
    function withdraw(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Invalid amount");
        require(balances[msg.sender] >= _amount, "Insufficient balance");

        // Check withdrawal delay (optional)
        // For simplicity, we're not implementing withdrawal delay here
        // In production, you would check the timestamp of the last deposit

        // Update balance
        balances[msg.sender] -= _amount;

        // Transfer CAR tokens
        carToken.safeTransfer(msg.sender, _amount);

        emit Withdrawn(msg.sender, _amount);
    }

    /**
     * @notice Sponsor gas for a specific user
     * @param _account User to sponsor
     * @param _amount Amount to sponsor
     */
    function sponsor(address _account, uint256 _amount) external nonReentrant {
        require(_amount > 0, "Invalid amount");
        require(_account != address(0), "Invalid account");

        // Transfer CAR tokens
        carToken.safeTransferFrom(msg.sender, address(this), _amount);

        // Add to sponsored balance
        sponsoredBalances[_account] += _amount;

        // Add to sponsored users if not already
        if (!isSponsoredUser[_account]) {
            require(sponsoredUsers.length < MAX_SPONSORED_USERS, "Too many sponsored users");
            isSponsoredUser[_account] = true;
            sponsoredUsers.push(_account);
            emit SponsoredUserAdded(_account);
        }

        emit Sponsored(msg.sender, _account, _amount);
    }

    /**
     * @notice Revoke sponsorship for a user
     * @param _account User to revoke
     */
    function revokeSponsorship(address _account) external nonReentrant {
        require(isSponsoredUser[_account], "User not sponsored");
        require(sponsoredBalances[_account] == 0, "User has remaining balance");

        // Remove from sponsored users
        isSponsoredUser[_account] = false;
        emit SponsoredUserRemoved(_account);
    }

    /**
     * @notice Add an allowed paymaster
     * @param _paymaster Paymaster address
     */
    function addAllowedPaymaster(address _paymaster) external onlyOwner {
        require(_paymaster != address(0), "Invalid paymaster address");
        require(!isAllowedPaymaster[_paymaster], "Paymaster already allowed");
        require(allowedPaymasters.length < MAX_ALLOWED_PAYMASTERS, "Too many allowed paymasters");

        isAllowedPaymaster[_paymaster] = true;
        allowedPaymasters.push(_paymaster);
        emit AllowedPaymasterAdded(_paymaster);
    }

    /**
     * @notice Remove an allowed paymaster
     * @param _paymaster Paymaster address
     */
    function removeAllowedPaymaster(address _paymaster) external onlyOwner {
        require(isAllowedPaymaster[_paymaster], "Paymaster not allowed");

        isAllowedPaymaster[_paymaster] = false;
        emit AllowedPaymasterRemoved(_paymaster);
    }

    /**
     * @notice Validate paymaster user operation
     * @param _userOp User operation
     * @param _userOpHash User operation hash
     * @param _requiredPreFund Required pre-fund
     * @return _context Context (0 if valid)
     */
    function validatePaymasterUserOp(
        UserOperation calldata _userOp,
        bytes32 _userOpHash,
        uint256 _requiredPreFund
    ) external view returns (bytes memory _context) {
        // Check if the user is sponsored
        if (sponsoredBalances[_userOp.sender] >= _requiredPreFund) {
            return new bytes(0);
        }

        // Check if the user has enough balance
        require(balances[_userOp.sender] >= _requiredPreFund, "Insufficient balance");

        // Check if the paymaster is allowed (if specified)
        // For simplicity, we're not checking allowed paymasters here
        // In production, you would check if _userOp.paymasterAndData is in the allowed list

        return new bytes(0);
    }

    /**
     * @notice Post-operation hook
     * @param _context Context from validatePaymasterUserOp
     * @param _actualGasCost Actual gas cost
     */
    function postOp(
        bytes calldata _context,
        uint256 _actualGasCost
    ) external payable onlyOwner {
        // Calculate total cost
        uint256 totalCost = _actualGasCost;
        
        // Add relayer fee if applicable
        if (relayerFee > 0) {
            totalCost += relayerFee;
        }

        // Deduct from sponsored balance first
        address user = _extractSenderFromContext(_context);
        if (sponsoredBalances[user] >= totalCost) {
            sponsoredBalances[user] -= totalCost;
        } else {
            // Deduct from user's balance
            uint256 remaining = totalCost;
            
            // Use sponsored balance first
            if (sponsoredBalances[user] > 0) {
                remaining -= sponsoredBalances[user];
                sponsoredBalances[user] = 0;
            }
            
            // Then use user's balance
            require(balances[user] >= remaining, "Insufficient balance");
            balances[user] -= remaining;
        }
    }

    /**
     * @notice Set relayer fee
     * @param _relayerFee New relayer fee (in CAR, 1e18)
     */
    function setRelayerFee(uint256 _relayerFee) external onlyOwner {
        uint256 oldFee = relayerFee;
        relayerFee = _relayerFee;
        emit RelayerFeeSet(oldFee, _relayerFee);
    }

    /**
     * @notice Set minimum deposit
     * @param _minDeposit New minimum deposit
     */
    function setMinDeposit(uint256 _minDeposit) external onlyOwner {
        require(_minDeposit > 0, "Invalid minimum deposit");
        uint256 oldMin = minDeposit;
        minDeposit = _minDeposit;
        emit MinDepositSet(oldMin, _minDeposit);
    }

    /**
     * @notice Set withdrawal delay
     * @param _withdrawalDelay New withdrawal delay (in seconds)
     */
    function setWithdrawalDelay(uint256 _withdrawalDelay) external onlyOwner {
        require(_withdrawalDelay >= 0, "Invalid withdrawal delay");
        uint256 oldDelay = withdrawalDelay;
        withdrawalDelay = _withdrawalDelay;
        emit WithdrawalDelaySet(oldDelay, _withdrawalDelay);
    }

    /**
     * @notice Get balance
     * @param _account Account address
     * @return balance Account balance
     */
    function getBalance(address _account) external view returns (uint256) {
        return balances[_account];
    }

    /**
     * @notice Get sponsored balance
     * @param _account Account address
     * @return balance Sponsored balance
     */
    function getSponsoredBalance(address _account) external view returns (uint256) {
        return sponsoredBalances[_account];
    }

    /**
     * @notice Extract sender from context
     * @param _context Context
     * @return sender Sender address
     */
    function _extractSenderFromContext(bytes calldata _context) internal pure returns (address) {
        // For simplicity, we're assuming the context is empty (0x)
        // In production, you would encode the sender in the context
        
        // This is a placeholder implementation
        // In a real implementation, you would decode the sender from the context
        return address(0); // Placeholder
    }

    /**
     * @notice Get all sponsored users
     * @return users Array of sponsored user addresses
     */
    function getSponsoredUsers() external view returns (address[] memory) {
        return sponsoredUsers;
    }

    /**
     * @notice Get all allowed paymasters
     * @return paymasters Array of allowed paymaster addresses
     */
    function getAllowedPaymasters() external view returns (address[] memory) {
        return allowedPaymasters;
    }

    /**
     * @notice Receive ETH (for native token support)
     */
    receive() external payable {
        // For simplicity, we're not handling ETH here
        // In production, you would wrap ETH to WETH
        revert("Native token not supported");
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

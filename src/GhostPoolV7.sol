// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @title GhostPool v4
/// @notice Escrow for intent-based cross-chain USDC transfers
/// @dev Permissionless fill. No Solver. No Registry. Simple. Safe.
contract GhostPoolV7 {
    IERC20 public immutable USDC;
    address public immutable TREASURY;
    address public EXECUTOR;  // must be contract, set once

    mapping(bytes32 => bool) public claimed;
    mapping(bytes32 => address) public relayerForIntent;
    
    uint256 public constant FEE_DENOMINATOR = 100_000;
    uint256 public constant TOTAL_FEE = 50;        // 0.050%
    uint256 public constant TREASURY_FEE = 10;     // 0.010%
    // relayerFee = 40 (0.040%) — implicit (inputAmount - outputAmount - 10)
    uint256 public constant MAX_FILL_DEADLINE = 1 hours;
    uint256 public constant SWEEP_TIMEOUT = 7 days;
    uint256 public constant MAX_ACTIVE_INTENTS = 10;
    uint256 public constant MIN_INPUT_AMOUNT = 1e6;  // 1 USDC
    
    struct Intent {
        address user;
        uint256 inputAmount;
        uint256 outputAmount;
        uint256 destChainId;
        uint32 fillDeadline;
        bool filled;
        bool refunded;
    }
    
    mapping(bytes32 => Intent) public intents;
    mapping(address => uint256) public nonces;
    mapping(address => uint256) public activeIntents;
    
    event IntentSigned(
        bytes32 indexed intentId,
        address indexed user,
        uint256 inputAmount,
        uint256 outputAmount,
        uint256 destChainId,
        uint32 fillDeadline
    );
    event IntentFilled(bytes32 indexed intentId, address indexed relayer);
    event Claimed(bytes32 indexed intentId, address indexed recipient, address indexed relayer, uint256 amount);
    event Swept(bytes32 indexed intentId, uint256 amount);
    event IntentRefunded(bytes32 indexed intentId, address indexed user);
    event ExecutorInitialized(address indexed executor);
    
    error ZeroAddress();
    error ZeroAmount();
    error DeadlinePast();
    error DeadlineTooFar();
    error AlreadyFilled();
    error NotFilled();
    error AlreadyRefunded();
    error Unauthorized();
    error TransferFailed();
    error DeadlineExpired();
    error NotExpired();
    error IntentNotFound();
    error AlreadyInitialized();
    error InvalidOutputAmount();
    error InvalidFee();
    error InvalidSender();
    error TooManyActiveIntents();
    error InvalidRelayer();
    error NotContract();
    error BelowMinimum();
    error InvalidSignature();
    
    constructor(address _usdc, address _treasury) {
        if (_usdc == address(0) || _treasury == address(0)) revert ZeroAddress();
        USDC = IERC20(_usdc);
        TREASURY = _treasury;
    }
    
    function initExecutor(address _executor) external {
        if (EXECUTOR != address(0)) revert AlreadyInitialized();
        if (_executor == address(0)) revert ZeroAddress();
        if (_executor.code.length == 0) revert NotContract();
        EXECUTOR = _executor;
        emit ExecutorInitialized(_executor);
    }
    
    function signIntent(
        uint256 inputAmount,
        uint256 outputAmount,
        uint256 destChainId,
        uint32 fillDeadline
    ) external returns (bytes32) {
        if (msg.sender == address(this)) revert InvalidSender();
        if (msg.sender == EXECUTOR) revert InvalidSender();
        
        if (inputAmount == 0) revert ZeroAmount();
        if (inputAmount < MIN_INPUT_AMOUNT) revert BelowMinimum();
        if (inputAmount <= outputAmount) revert InvalidOutputAmount();
        
        uint256 feeAmount = inputAmount - outputAmount;
        uint256 expectedFee = (inputAmount * TOTAL_FEE) / FEE_DENOMINATOR;
        if (feeAmount != expectedFee) revert InvalidFee();
        
        if (fillDeadline <= block.timestamp) revert DeadlinePast();
        if (fillDeadline > block.timestamp + MAX_FILL_DEADLINE) revert DeadlineTooFar();
        
        if (activeIntents[msg.sender] >= MAX_ACTIVE_INTENTS) revert TooManyActiveIntents();
        
        if (!USDC.transferFrom(msg.sender, address(this), inputAmount)) revert TransferFailed();
        
        uint256 nonce = nonces[msg.sender]++;
        bytes32 intentId = keccak256(abi.encode(
            block.chainid,
            msg.sender,
            nonce,
            inputAmount,
            outputAmount,
            destChainId,
            fillDeadline
        ));
        
        intents[intentId] = Intent({
            user: msg.sender,
            inputAmount: inputAmount,
            outputAmount: outputAmount,
            destChainId: destChainId,
            fillDeadline: fillDeadline,
            filled: false,
            refunded: false
        });
        
        activeIntents[msg.sender]++;
        
        emit IntentSigned(intentId, msg.sender, inputAmount, outputAmount, destChainId, fillDeadline);
        return intentId;
    }
    
    function executeIntent(bytes32 intentId, address relayer) external {
        if (msg.sender != EXECUTOR) revert Unauthorized();

        Intent storage intent = intents[intentId];
        if (intent.user == address(0)) revert IntentNotFound();
        if (intent.filled) revert AlreadyFilled();
        if (intent.refunded) revert AlreadyRefunded();
        if (block.timestamp > intent.fillDeadline) revert DeadlineExpired();
        if (relayer == address(0)) revert ZeroAddress();
        if (relayer == EXECUTOR) revert InvalidRelayer();
        if (relayer == intent.user) revert InvalidRelayer();
        if (relayer == TREASURY) revert InvalidRelayer();

        intent.filled = true;
        activeIntents[intent.user]--;
        
        // 🔑 DO NOT transfer inputAmount. Keep it in Pool.
        // It will be released only via claim() after user signs receipt.
        relayerForIntent[intentId] = relayer;

        emit IntentFilled(intentId, relayer);
    }

    /// @notice User (recipient) signs receipt to release inputAmount to relayer.
    /// Signature binds to (intentId, chainId, contract, recipient).
    /// @notice User signs receipt to release inputAmount - treasuryFee to relayer, treasuryFee to Treasury.
    function claim(bytes32 intentId, bytes calldata sig) external {
        Intent storage intent = intents[intentId];
        if (intent.user == address(0)) revert IntentNotFound();
        if (!intent.filled) revert NotFilled();
        if (intent.refunded) revert AlreadyRefunded();
        if (claimed[intentId]) revert AlreadyFilled();

        bytes32 digest = keccak256(abi.encode(
            intentId,
            block.chainid,
            address(this),
            intent.user,
            intent.outputAmount
        ));
        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest));
        address signer = ECDSA.recover(ethHash, sig);
        if (signer != intent.user) revert InvalidSignature();

        claimed[intentId] = true;

        uint256 treasuryFee = (intent.inputAmount * TREASURY_FEE) / FEE_DENOMINATOR;
        uint256 relayerAmount = intent.inputAmount - treasuryFee;

        address relayer = relayerForIntent[intentId];
        if (!USDC.transfer(TREASURY, treasuryFee)) revert TransferFailed();
        if (!USDC.transfer(relayer, relayerAmount)) revert TransferFailed();

        emit Claimed(intentId, intent.user, relayer, relayerAmount);
    }
    
    function refundIntent(bytes32 intentId) external {
        Intent storage intent = intents[intentId];
        if (intent.user == address(0)) revert IntentNotFound();
        if (msg.sender != intent.user) revert Unauthorized();
        if (intent.filled) revert AlreadyFilled();
        if (intent.refunded) revert AlreadyRefunded();
        if (block.timestamp <= intent.fillDeadline) revert NotExpired();
        
        intent.refunded = true;
        activeIntents[intent.user]--;
        
        if (!USDC.transfer(intent.user, intent.inputAmount)) revert TransferFailed();
        
        emit IntentRefunded(intentId, intent.user);
    }
    
    /// @notice After SWEEP_TIMEOUT from fill, sweep unclaimed inputAmount to Treasury.
    /// Prevents permanent stuck funds from griefing attacks.
    function sweepStuck(bytes32 intentId) external {
        Intent storage intent = intents[intentId];
        if (!intent.filled) revert IntentNotFound();
        if (claimed[intentId]) revert AlreadyFilled();
        if (intent.refunded) revert AlreadyRefunded();
        
        // fillDeadline + SWEEP_TIMEOUT has passed
        if (block.timestamp <= uint256(intent.fillDeadline) + SWEEP_TIMEOUT) revert NotExpired();
        
        claimed[intentId] = true;
        uint256 amount = intent.inputAmount;
        
        if (!USDC.transfer(TREASURY, amount)) revert TransferFailed();
        
        emit Swept(intentId, amount);
    }

    function getIntent(bytes32 intentId) external view returns (Intent memory) {
        return intents[intentId];
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interfaces/IERC20.sol";

interface IGhostPoolV7 {
    struct Intent {
        address user;
        uint256 inputAmount;
        uint256 outputAmount;
        uint256 destChainId;
        uint32 fillDeadline;
        bool filled;
        bool refunded;
    }
    function getIntent(bytes32) external view returns (Intent memory);
    function executeIntent(bytes32, address) external;
}

/// @title GhostExecutorV7
/// @notice v7: Permissionless fill. NO Arb transfer. inputAmount released via claim() only.
contract GhostExecutorV7 {
    IERC20 public immutable USDC;
    IGhostPoolV7 public immutable POOL;
    address public immutable TREASURY;

    uint256 public constant FEE_DENOMINATOR = 100_000;
    uint256 public constant TOTAL_FEE = 50;
    uint256 public constant TREASURY_FEE = 10;

    uint256 public totalFills;
    uint256 public totalVolume;
    uint256 public totalFees;

    event FillExecuted(
        bytes32 indexed intentId,
        address indexed relayer,
        address indexed user,
        uint256 inputAmount,
        uint256 outputAmount
    );

    error ZeroAddress();
    error IntentNotFound();
    error AlreadyFilled();
    error AlreadyRefunded();
    error DeadlineExpired();
    error InvalidFee();
    error InvalidSender();
    error Unauthorized();

    constructor(address _usdc, address _pool, address _treasury) {
        if (_usdc == address(0) || _pool == address(0) || _treasury == address(0)) revert ZeroAddress();
        USDC = IERC20(_usdc);
        POOL = IGhostPoolV7(_pool);
        TREASURY = _treasury;
    }

    /// @notice Permissionless fill. NO Arb transfers. Pool releases inputAmount only via claim().
    function executeFill(bytes32 intentId) external {
        IGhostPoolV7.Intent memory intent = POOL.getIntent(intentId);
        if (intent.user == address(0)) revert IntentNotFound();
        if (intent.filled) revert AlreadyFilled();
        if (intent.refunded) revert AlreadyRefunded();
        if (block.timestamp > intent.fillDeadline) revert DeadlineExpired();
        if (msg.sender == intent.user) revert InvalidSender();

        uint256 feeAmount = intent.inputAmount - intent.outputAmount;
        uint256 expectedFee = (intent.inputAmount * TOTAL_FEE) / FEE_DENOMINATOR;
        if (feeAmount != expectedFee) revert InvalidFee();

        // 🔑 KEY: NO transfers on Arb. Only record fill.
        POOL.executeIntent(intentId, msg.sender);

        totalFills++;
        totalVolume += intent.inputAmount;
        totalFees += feeAmount;

        emit FillExecuted(intentId, msg.sender, intent.user, intent.inputAmount, intent.outputAmount);
    }

    function getStats() external view returns (uint256, uint256, uint256) {
        return (totalFills, totalVolume, totalFees);
    }
}

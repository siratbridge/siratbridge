// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/GhostPoolV7.sol";
import "../src/GhostExecutorV7.sol";

contract MockUSDC {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    function mint(address to, uint256 amount) external { balanceOf[to] += amount; }
    function approve(address spender, uint256 amount) external returns (bool) { allowance[msg.sender][spender] = amount; return true; }
    function transfer(address to, uint256 amount) external returns (bool) { balanceOf[msg.sender] -= amount; balanceOf[to] += amount; return true; }
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount; balanceOf[from] -= amount; balanceOf[to] += amount; return true;
    }
}

contract SweepV7Test is Test {
    GhostPoolV7 pool;
    GhostExecutorV7 executor;
    MockUSDC usdc;

    uint256 constant USER_PK = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address user;
    address relayer = address(0x2);
    address treasury = address(0x3);

    function setUp() public {
        user = vm.addr(USER_PK);
        usdc = new MockUSDC();
        pool = new GhostPoolV7(address(usdc), treasury);
        executor = new GhostExecutorV7(address(usdc), address(pool), treasury);
        pool.initExecutor(address(executor));

        usdc.mint(user, 10_000e6);
        usdc.mint(relayer, 10_000e6);

        vm.prank(user);
        usdc.approve(address(pool), type(uint256).max);
        vm.prank(relayer);
        usdc.approve(address(executor), type(uint256).max);
    }

    // @notice Sweep before timeout → revert
    function test1_SweepBeforeTimeoutReverts() public {
        vm.prank(user);
        bytes32 id = pool.signIntent(100e6, 99.95e6, 8453, uint32(block.timestamp + 30 minutes));

        vm.prank(relayer);
        executor.executeFill(id);

        // Try sweep immediately
        vm.expectRevert();
        pool.sweepStuck(id);
        
        emit log_string("PROTECTED: Cannot sweep before 7 days");
    }

    // @notice Sweep after timeout → Treasury gets inputAmount
    function test2_SweepAfterTimeoutSendsToTreasury() public {
        vm.prank(user);
        bytes32 id = pool.signIntent(100e6, 99.95e6, 8453, uint32(block.timestamp + 30 minutes));

        vm.prank(relayer);
        executor.executeFill(id);

        uint256 treasuryBefore = usdc.balanceOf(treasury);
        
        // Wait 7 days + 1 hour
        vm.warp(block.timestamp + 7 days + 1 hours);

        pool.sweepStuck(id);

        uint256 treasuryAfter = usdc.balanceOf(treasury);
        assertEq(treasuryAfter - treasuryBefore, 100e6, "treasury got 100 USDC");
        assertEq(usdc.balanceOf(address(pool)), 0, "pool empty");
        
        emit log_string("SWEPT: Treasury got 100 USDC after 7 days");
    }

    // @notice Sweep after claim → revert (already claimed)
    function test3_SweepAfterClaimReverts() public {
        vm.prank(user);
        bytes32 id = pool.signIntent(100e6, 99.95e6, 8453, uint32(block.timestamp + 30 minutes));

        vm.prank(relayer);
        executor.executeFill(id);

        // User claims
        GhostPoolV7.Intent memory intent = pool.getIntent(id);
        bytes32 digest = keccak256(abi.encode(
            id, block.chainid, address(pool), intent.user, intent.outputAmount
        ));
        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(USER_PK, ethHash);
        pool.claim(id, abi.encodePacked(r, s, v));

        // Try sweep after 7 days
        vm.warp(block.timestamp + 7 days + 1 hours);

        vm.expectRevert();
        pool.sweepStuck(id);
        
        emit log_string("PROTECTED: Cannot sweep after claim");
    }

    // @notice Sweep cannot lead to double-spend
    function test4_SweepCannotDoubleSpend() public {
        vm.prank(user);
        bytes32 id = pool.signIntent(100e6, 99.95e6, 8453, uint32(block.timestamp + 30 minutes));

        vm.prank(relayer);
        executor.executeFill(id);

        // Sweep after 7 days
        vm.warp(block.timestamp + 7 days + 1 hours);
        pool.sweepStuck(id);

        // User tries refund → must revert (filled = true)
        vm.prank(user);
        vm.expectRevert();
        pool.refundIntent(id);

        // User tries claim → must revert (claimed = true after sweep)
        GhostPoolV7.Intent memory intent = pool.getIntent(id);
        bytes32 digest = keccak256(abi.encode(
            id, block.chainid, address(pool), intent.user, intent.outputAmount
        ));
        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(USER_PK, ethHash);
        
        vm.expectRevert();
        pool.claim(id, abi.encodePacked(r, s, v));
        
        emit log_string("PROTECTED: Sweep blocks all future claims/refunds");
    }
}

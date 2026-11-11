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

contract GhostV7Test is Test {
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

    function _signReceipt(bytes32 intentId, uint256 signerPk) internal view returns (bytes memory) {
        GhostPoolV7.Intent memory intent = pool.getIntent(intentId);
        bytes32 digest = keccak256(abi.encode(
            intentId, block.chainid, address(pool), intent.user, intent.outputAmount
        ));
        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, ethHash);
        return abi.encodePacked(r, s, v);
    }

    // Test 1: Happy Path (with claim)
    function test1_HappyPath() public {
        vm.prank(user);
        bytes32 id = pool.signIntent(100e6, 99.95e6, 8453, uint32(block.timestamp + 30 minutes));

        uint256 relayerBefore = usdc.balanceOf(relayer);

        vm.prank(relayer);
        executor.executeFill(id);

        // Relayer does NOT get inputAmount yet (no claim)
        assertEq(usdc.balanceOf(relayer), relayerBefore, "no payout before claim");

        // User signs receipt
        bytes memory sig = _signReceipt(id, USER_PK);
        pool.claim(id, sig);

        // Now relayer gets inputAmount - treasuryFee
        uint256 relayerAfter = usdc.balanceOf(relayer);
        assertEq(relayerAfter, relayerBefore + 99.99e6, "relayer got 99.99");
    }

    // Test 2: Below Minimum
    function test2_BelowMinimum() public {
        vm.prank(user);
        vm.expectRevert();
        pool.signIntent(500_000, 499_750, 8453, uint32(block.timestamp + 30 minutes));
    }

    // Test 3: Cannot Self Fill
    function test3_CannotSelfFill() public {
        vm.prank(user);
        bytes32 id = pool.signIntent(100e6, 99.95e6, 8453, uint32(block.timestamp + 30 minutes));

        vm.prank(user);
        vm.expectRevert();
        executor.executeFill(id);
    }

    // Test 4: Concurrent Intents
    function test4_ConcurrentIntents() public {
        vm.prank(user);
        bytes32 id1 = pool.signIntent(100e6, 99.95e6, 8453, uint32(block.timestamp + 30 minutes));
        vm.prank(user);
        bytes32 id2 = pool.signIntent(200e6, 199.9e6, 8453, uint32(block.timestamp + 30 minutes));

        assertTrue(id1 != id2, "different IDs");
        assertEq(pool.activeIntents(user), 2, "2 active");
    }

    // Test 5: Deadline Too Far
    function test5_DeadlineTooFar() public {
        vm.prank(user);
        vm.expectRevert();
        pool.signIntent(100e6, 99.95e6, 8453, uint32(block.timestamp + 2 hours));
    }

    // Test 6: Double Fill Reverts
    function test6_DoubleFillReverts() public {
        vm.prank(user);
        bytes32 id = pool.signIntent(100e6, 99.95e6, 8453, uint32(block.timestamp + 30 minutes));

        vm.prank(relayer);
        executor.executeFill(id);

        vm.prank(relayer);
        vm.expectRevert();
        executor.executeFill(id);
    }

    // Test 7: Invalid Fee
    function test7_InvalidFee() public {
        vm.prank(user);
        vm.expectRevert();
        // 100 - 99.9 = 0.1 (0.1% fee, invalid; must be 0.05%)
        pool.signIntent(100e6, 99.9e6, 8453, uint32(block.timestamp + 30 minutes));
    }

    // Test 8: Multiple Users
    function test8_MultipleUsers() public {
        address user2 = address(0x99);
        usdc.mint(user2, 10_000e6);
        vm.prank(user2);
        usdc.approve(address(pool), type(uint256).max);

        vm.prank(user);
        bytes32 id1 = pool.signIntent(100e6, 99.95e6, 8453, uint32(block.timestamp + 30 minutes));
        vm.prank(user2);
        bytes32 id2 = pool.signIntent(200e6, 199.9e6, 8453, uint32(block.timestamp + 30 minutes));

        assertTrue(id1 != id2);
        assertEq(pool.activeIntents(user), 1);
        assertEq(pool.activeIntents(user2), 1);
    }

    // Test 9: Nonce Uniqueness
    function test9_NonceUniqueness() public {
        vm.prank(user);
        bytes32 id1 = pool.signIntent(100e6, 99.95e6, 8453, uint32(block.timestamp + 30 minutes));

        vm.warp(block.timestamp + 10);

        vm.prank(user);
        bytes32 id2 = pool.signIntent(100e6, 99.95e6, 8453, uint32(block.timestamp + 30 minutes));

        assertTrue(id1 != id2, "different IDs");
        assertEq(pool.nonces(user), 2, "2 nonces used");
    }

    // Test 10: Rate Limit
    function test10_RateLimit() public {
        for (uint256 i = 0; i < 10; i++) {
            vm.prank(user);
            pool.signIntent(100e6, 99.95e6, 8453, uint32(block.timestamp + 30 minutes));
        }

        vm.prank(user);
        vm.expectRevert();
        pool.signIntent(100e6, 99.95e6, 8453, uint32(block.timestamp + 30 minutes));
    }

    // Test 11: Refund After Deadline
    function test11_RefundAfterDeadline() public {
        vm.prank(user);
        bytes32 id = pool.signIntent(100e6, 99.95e6, 8453, uint32(block.timestamp + 30 minutes));

        uint256 userBefore = usdc.balanceOf(user);

        vm.warp(block.timestamp + 2 hours);

        vm.prank(user);
        pool.refundIntent(id);

        assertEq(usdc.balanceOf(user), userBefore + 100e6, "user refunded");
    }

    // Test 12: Refund Fails After Fill
    function test12_RefundFailsAfterFill() public {
        vm.prank(user);
        bytes32 id = pool.signIntent(100e6, 99.95e6, 8453, uint32(block.timestamp + 30 minutes));

        vm.prank(relayer);
        executor.executeFill(id);

        vm.warp(block.timestamp + 2 hours);

        vm.prank(user);
        vm.expectRevert();
        pool.refundIntent(id);
    }
}

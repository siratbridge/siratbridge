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

contract FinalV7CompleteTest is Test {
    GhostPoolV7 pool;
    GhostExecutorV7 executor;
    MockUSDC usdc;

    uint256 constant USER_PK = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 constant ATTACKER_PK = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    uint256 constant RELAYER_PK = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;
    uint256 constant OUTPUT_AMOUNT = 99.95e6;
    
    address user;
    address attacker;
    address relayer;
    address treasury = address(0x3);

    function setUp() public {
        user = vm.addr(USER_PK);
        attacker = vm.addr(ATTACKER_PK);
        relayer = vm.addr(RELAYER_PK);
        
        usdc = new MockUSDC();
        pool = new GhostPoolV7(address(usdc), treasury);
        executor = new GhostExecutorV7(address(usdc), address(pool), treasury);
        pool.initExecutor(address(executor));

        usdc.mint(user, 10_000e6);
        usdc.mint(attacker, 10_000e6);
        usdc.mint(relayer, 10_000e6);

        vm.prank(user);
        usdc.approve(address(pool), type(uint256).max);
        vm.prank(attacker);
        usdc.approve(address(executor), type(uint256).max);
        vm.prank(relayer);
        usdc.approve(address(executor), type(uint256).max);
    }

    function _signReceipt(bytes32 intentId, uint256 signerPk) internal view returns (bytes memory) {
        GhostPoolV7.Intent memory intent = pool.getIntent(intentId);
        bytes32 digest = keccak256(abi.encode(
            intentId,
            block.chainid,
            address(pool),
            intent.user,
            intent.outputAmount  // ← read actual outputAmount
        ));
        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, ethHash);
        return abi.encodePacked(r, s, v);
    }

    // Test 5: Cheating relayer loses only gas (no Arb payment occurs)
    function test5_CheatingRelayerLosesOnlyGas() public {
        vm.prank(user);
        bytes32 id = pool.signIntent(100e6, OUTPUT_AMOUNT, 8453, uint32(block.timestamp + 30 minutes));

        uint256 userBefore = usdc.balanceOf(user);
        uint256 attackerBefore = usdc.balanceOf(attacker);
        uint256 poolBefore = usdc.balanceOf(address(pool));

        // Attacker fills (no Base payment)
        vm.prank(attacker);
        executor.executeFill(id);

        uint256 userAfterFill = usdc.balanceOf(user);
        uint256 attackerAfterFill = usdc.balanceOf(attacker);
        uint256 poolAfterFill = usdc.balanceOf(address(pool));

        // User should NOT have received anything on Arb
        assertEq(userAfterFill, userBefore, "user Arb unchanged");
        assertEq(attackerAfterFill, attackerBefore, "attacker Arb unchanged");
        assertEq(poolAfterFill, poolBefore, "pool unchanged on fill (no Arb transfer)");

        emit log_string("PROTECTED: No Arb transfers. Attacker only lost gas.");
    }

    // Test 6: No Arb payout on fill (explicit check)
    function test6_NoArbPayoutOnFill() public {
        vm.prank(user);
        bytes32 id = pool.signIntent(100e6, OUTPUT_AMOUNT, 8453, uint32(block.timestamp + 30 minutes));

        uint256 userBefore = usdc.balanceOf(user);
        
        vm.prank(relayer);
        executor.executeFill(id);

        uint256 userAfter = usdc.balanceOf(user);
        assertEq(userAfter, userBefore, "user Arb unchanged after fill");
        
        emit log_string("PROTECTED: User Arb unchanged on fill");
    }

    // Test 7: Claim pays treasury + relayer correctly
    function test7_ClaimPaysMinusTreasuryFee() public {
        vm.prank(user);
        bytes32 id = pool.signIntent(100e6, OUTPUT_AMOUNT, 8453, uint32(block.timestamp + 30 minutes));

        vm.prank(relayer);
        executor.executeFill(id);

        bytes memory userSig = _signReceipt(id, USER_PK);
        
        uint256 relayerBefore = usdc.balanceOf(relayer);
        uint256 treasuryBefore = usdc.balanceOf(treasury);

        pool.claim(id, userSig);

        uint256 relayerAfter = usdc.balanceOf(relayer);
        uint256 treasuryAfter = usdc.balanceOf(treasury);

        // treasuryFee = 0.01% of 100 = 0.01 USDC
        // relayerAmount = 100 - 0.01 = 99.99 USDC
        assertEq(treasuryAfter - treasuryBefore, 0.01e6, "treasury got 0.01 USDC");
        assertEq(relayerAfter - relayerBefore, 99.99e6, "relayer got 99.99 USDC");
        
        emit log_string("HAPPY: Treasury +0.01, Relayer +99.99");
    }

    // Test 8: Wrong sig (different chain/contract) reverts
    function test8_WrongSigChainContractReverts() public {
        vm.prank(user);
        bytes32 id = pool.signIntent(100e6, OUTPUT_AMOUNT, 8453, uint32(block.timestamp + 30 minutes));

        vm.prank(relayer);
        executor.executeFill(id);

        // Wrong chainId
        bytes32 digest = keccak256(abi.encode(id, block.chainid + 1, address(pool), user, OUTPUT_AMOUNT));
        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(USER_PK, ethHash);
        bytes memory wrongSig = abi.encodePacked(r, s, v);

        vm.expectRevert();
        pool.claim(id, wrongSig);
        
        emit log_string("PROTECTED: Wrong-chain sig reverts");
    }

    // Test 9: Refund still blocked after fill
    function test9_RefundStillBlockedAfterFill() public {
        vm.prank(user);
        bytes32 id = pool.signIntent(100e6, OUTPUT_AMOUNT, 8453, uint32(block.timestamp + 30 minutes));

        vm.prank(relayer);
        executor.executeFill(id);

        vm.warp(block.timestamp + 2 hours);

        vm.prank(user);
        vm.expectRevert();
        pool.refundIntent(id);
        
        emit log_string("PROTECTED: Cannot refund after fill");
    }

    // Test: Happy path
    function testHappyPath() public {
        vm.prank(user);
        bytes32 id = pool.signIntent(100e6, OUTPUT_AMOUNT, 8453, uint32(block.timestamp + 30 minutes));

        vm.prank(relayer);
        executor.executeFill(id);

        bytes memory userSig = _signReceipt(id, USER_PK);
        
        uint256 relayerBefore = usdc.balanceOf(relayer);
        pool.claim(id, userSig);
        uint256 relayerAfter = usdc.balanceOf(relayer);

        assertEq(relayerAfter, relayerBefore + 99.99e6, "relayer got 99.99 USDC");
        assertEq(usdc.balanceOf(address(pool)), 0, "pool empty");
        
        emit log_string("HAPPY PATH: works");
    }

    // Test: Attacker cannot claim without user sig
    function testAttackerCannotClaim() public {
        vm.prank(user);
        bytes32 id = pool.signIntent(100e6, OUTPUT_AMOUNT, 8453, uint32(block.timestamp + 30 minutes));

        vm.prank(attacker);
        executor.executeFill(id);

        bytes memory attackerSig = _signReceipt(id, ATTACKER_PK);
        
        vm.expectRevert();
        pool.claim(id, attackerSig);
        
        emit log_string("PROTECTED: Attacker cannot claim");
    }

    // Test: Invariant - pool balance = sum of unclaimed inputs
    function testInvariant() public {
        // Create 3 intents
        vm.prank(user);
        bytes32 id1 = pool.signIntent(100e6, OUTPUT_AMOUNT, 8453, uint32(block.timestamp + 30 minutes));
        vm.prank(user);
        bytes32 id2 = pool.signIntent(200e6, 199.9e6, 8453, uint32(block.timestamp + 30 minutes));
        vm.prank(user);
        bytes32 id3 = pool.signIntent(300e6, 299.85e6, 8453, uint32(block.timestamp + 30 minutes));

        assertEq(usdc.balanceOf(address(pool)), 600e6, "pool has 600 USDC");

        // Fill all 3
        // Debug: check state before each fill
        emit log_string("Filling id1");
        vm.prank(relayer); executor.executeFill(id1);
        emit log_string("Filling id2");
        vm.warp(block.timestamp + 10);
        vm.prank(relayer); executor.executeFill(id2);
        emit log_string("Filling id3");
        vm.warp(block.timestamp + 10);
        vm.prank(relayer); executor.executeFill(id3);

        assertEq(usdc.balanceOf(address(pool)), 600e6, "pool still has 600 (no transfers)");

        // Claim 2
        bytes memory sig1 = _signReceipt(id1, USER_PK);
        bytes memory sig2 = _signReceipt(id2, USER_PK);
        pool.claim(id1, sig1);
        pool.claim(id2, sig2);

        // Pool should have only id3's inputAmount (300e6)
        assertEq(usdc.balanceOf(address(pool)), 300e6, "pool has only unclaimed 300");
        
        emit log_string("INVARIANT: poolBalance = sum(unclaimed inputs)");
    }
}

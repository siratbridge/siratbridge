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

contract AttackV7FinalTest is Test {
    GhostPoolV7 pool;
    GhostExecutorV7 executor;
    MockUSDC usdc;

    uint256 constant USER_PK = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 constant ATTACKER_PK = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    address user;
    address attacker;
    address treasury = address(0x3);

    function setUp() public {
        user = vm.addr(USER_PK);
        attacker = vm.addr(ATTACKER_PK);
        
        usdc = new MockUSDC();
        pool = new GhostPoolV7(address(usdc), treasury);
        executor = new GhostExecutorV7(address(usdc), address(pool), treasury);
        pool.initExecutor(address(executor));

        usdc.mint(user, 10_000e6);
        usdc.mint(attacker, 10_000e6);

        vm.prank(user);
        usdc.approve(address(pool), type(uint256).max);
        vm.prank(attacker);
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

    /// @notice REPLICATE ATTACK TX 0x0d76... ON v7.2
    /// Attack: Attacker calls executeFill without user sig, then tries to claim
    function testOriginalAttackFailsOnV7() public {
        // 1. User creates intent (100 USDC → Base)
        vm.prank(user);
        bytes32 id = pool.signIntent(100e6, 99.95e6, 8453, uint32(block.timestamp + 30 minutes));

        uint256 userBefore = usdc.balanceOf(user);
        uint256 attackerBefore = usdc.balanceOf(attacker);
        uint256 poolBefore = usdc.balanceOf(address(pool));

        // 2. Attacker calls executeFill (permissionless, no user sig)
        vm.prank(attacker);
        executor.executeFill(id);

        uint256 userAfterFill = usdc.balanceOf(user);
        uint256 attackerAfterFill = usdc.balanceOf(attacker);
        uint256 poolAfterFill = usdc.balanceOf(address(pool));

        emit log_string("=== AFTER executeFill ===");
        emit log_named_int("Attacker net", int(attackerAfterFill) - int(attackerBefore));
        emit log_named_int("User Arb net", int(userAfterFill) - int(userBefore));
        emit log_named_uint("Pool USDC", poolAfterFill);

        // 3. Attacker tries to claim with fake sig
        bytes memory fakeSig = _signReceipt(id, ATTACKER_PK);
        
        vm.prank(attacker);
        vm.expectRevert();
        pool.claim(id, fakeSig);
        
        emit log_string("PROTECTED: Attacker cannot claim with own sig");

        // 4. Attacker tries to claim with empty sig
        vm.prank(attacker);
        vm.expectRevert();
        pool.claim(id, "");

        // 5. Attacker waits past deadline, tries refund
        vm.warp(block.timestamp + 2 hours);
        
        vm.prank(attacker);
        vm.expectRevert(); // filled = true, cannot refund
        pool.refundIntent(id);

        emit log_string("PROTECTED: Cannot refund after fill");

        // 6. Final state check
        uint256 attackerFinal = usdc.balanceOf(attacker);
        uint256 userFinal = usdc.balanceOf(user);
        uint256 poolFinal = usdc.balanceOf(address(pool));

        emit log_string("=== FINAL STATE ===");
        emit log_named_int("Attacker total net", int(attackerFinal) - int(attackerBefore));
        emit log_named_int("User total net", int(userFinal) - int(userBefore));
        emit log_named_uint("Pool USDC", poolFinal);

        // Assertions:
        // 1. User Arb balance unchanged (no double payment)
        assertEq(userFinal, userBefore, "user Arb unchanged");
        
        // 2. Pool retains inputAmount (100 USDC)
        assertEq(poolFinal, poolBefore, "pool unchanged by executeFill (inputAmount retained)");
        
        // 3. Attacker net = 0 (no gain)
        assertEq(attackerFinal, attackerBefore, "attacker net = 0");

        emit log_string("=== VERDICT ===");
        emit log_string("ATTACK FAILED: Attacker gained 0");
        emit log_string("User Arb unchanged");
        emit log_string("Funds stuck in Pool (relayer can claim with user sig)");
    }
}

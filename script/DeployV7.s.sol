// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/GhostPoolV7.sol";
import "../src/GhostExecutorV7.sol";

contract DeployV7 is Script {
    function run() external {
        // Read from env
        address usdc = vm.envAddress("USDC");
        address treasury = vm.envAddress("TREASURY");
        
        console.log("=== Deploying v7.2 ===");
        console.log("USDC:", usdc);
        console.log("TREASURY:", treasury);
        console.log("");
        
        vm.startBroadcast();
        
        // Deploy Pool
        GhostPoolV7 pool = new GhostPoolV7(usdc, treasury);
        console.log("POOL_V7:", address(pool));
        
        // Deploy Executor
        GhostExecutorV7 executor = new GhostExecutorV7(usdc, address(pool), treasury);
        console.log("EXECUTOR_V7:", address(executor));
        
        // Init Executor in Pool
        pool.initExecutor(address(executor));
        console.log("initExecutor: OK");
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("=== Deploy complete ===");
    }
}

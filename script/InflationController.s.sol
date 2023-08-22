// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/InflationController.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        uint64 startTime = 1693440000;  // August 31 2023 00:00:00 GMT
        // 3 years duration
        uint64 duration = 94608000;
        InflationController controller = new InflationController(
            startTime, duration
        );

        vm.stopBroadcast();
    }
}

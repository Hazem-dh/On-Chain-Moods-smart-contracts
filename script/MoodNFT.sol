// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {MoodNFT} from "../src/MoodNFT.sol";

contract MoodNFTScript is Script {
    MoodNFT public moodNFT;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        moodNFT = new MoodNFT();

        vm.stopBroadcast();
    }
}

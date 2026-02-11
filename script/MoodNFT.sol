// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {MoodNFT} from "../src/MoodNFT.sol";

contract MoodNFTScript is Script {
    MoodNFT public moodNFT;

    function setUp() public {}

    function run() public {
        string memory angry = vm.readFile("./assets/anfry.svg");
        string memory happy = vm.readFile("./assets/happy.svg");
        string memory neutral = vm.readFile("./assets/neutral.svg");
        string memory sleepy = vm.readFile("./assets/sleepy.svg");
        string memory surprised = vm.readFile("./assets/surprised.svg");
        vm.startBroadcast();

        moodNFT = new MoodNFT(angry, happy, neutral, sleepy, surprised);
        vm.stopBroadcast();
    }
}

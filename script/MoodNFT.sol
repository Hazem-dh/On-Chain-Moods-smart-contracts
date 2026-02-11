// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {MoodNFT} from "../src/MoodNFT.sol";

contract MoodNFTScript is Script {
    MoodNFT public moodNFT;

    function setUp() public {}

    function run() public {
        string memory angry = vm.readFile("./images/anfry.svg");
        string memory happy = vm.readFile("./images/happy.svg");
        string memory neutral = vm.readFile("./images/neutral.svg");
        string memory sleepy = vm.readFile("./images/sleepy.svg");
        string memory surprised = vm.readFile("./images/surprised.svg");    

        vm.startBroadcast();

        moodNFT = new MoodNFT(angry, happy, neutral, sleepy, surprised);
        vm.stopBroadcast();
    }
}

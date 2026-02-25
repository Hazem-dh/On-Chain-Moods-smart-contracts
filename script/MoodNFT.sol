// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {MoodNFT} from "../src/MoodNFT.sol";

contract MoodNFTScript is Script {
    MoodNFT public moodNft;

    function setUp() public {}

    function run() public {
        string memory happy = vm.readFile("./assets/happy.svg");
        string memory sad = vm.readFile("./assets/sad.svg");
        string memory satisfied = vm.readFile("./assets/sad.svg");

        vm.startBroadcast();

        moodNft = new MoodNFT(sad, satisfied, happy, 0x694AA1769357215DE4FAC081bf1f309aDC325306);
        vm.stopBroadcast();
    }
}

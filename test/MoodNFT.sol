// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MoodNFT} from "../src/MoodNFT.sol";

contract MoodNFTTest is Test {
    MoodNFT public moodNFT;

    function setUp() public {
        string memory angry = vm.readFile("./images/anfry.svg");
        string memory happy = vm.readFile("./images/happy.svg");
        string memory neutral = vm.readFile("./images/neutral.svg");
        string memory sleepy = vm.readFile("./images/sleepy.svg");
        string memory surprised = vm.readFile("./images/surprised.svg");
        moodNFT = new MoodNFT(angry, happy, neutral, sleepy, surprised);
    }

    function test_Increment() public {
        moodNFT.mintMoodNFT(msg.sender);
        assertEq(moodNFT.balanceOf(msg.sender), 1);
    }
}

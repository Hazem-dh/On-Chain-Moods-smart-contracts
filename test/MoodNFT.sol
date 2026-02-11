// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MoodNFT} from "../src/MoodNFT.sol";

contract MoodNFTTest is Test {
    MoodNFT public moodNFT;

    function setUp() public {
        moodNFT = new MoodNFT();
    }

    function test_Increment() public {
        moodNFT.mintMoodNFT(msg.sender);
        assertEq(moodNFT.balanceOf(msg.sender), 1);
    }
}

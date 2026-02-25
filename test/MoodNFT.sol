// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MoodNFT} from "../src/MoodNFT.sol";

contract MoodNFTTest is Test {
    MoodNFT public moodNft;

    function setUp() public {
        string memory happy = vm.readFile("./assets/happy.svg");
        string memory sad = vm.readFile("./assets/sad.svg");
        string memory satisfied = vm.readFile("./assets/sad.svg");

        moodNft = new MoodNFT(sad, satisfied, happy, 0x694AA1769357215DE4FAC081bf1f309aDC325306);
    }

    function test_Increment() public {
        moodNft.mint(1000); // 1 ETH = 10^11 USD (i.e., $1,000,000,000,000)
        assertEq(moodNft.balanceOf(msg.sender), 1);
    }
}

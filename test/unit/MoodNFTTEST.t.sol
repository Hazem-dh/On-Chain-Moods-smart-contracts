// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MoodNFT} from "../../src/MoodNFT.sol";
import {DeployMoodNFTScript} from "../../script/DeployMoodNFT.s.sol";

contract MoodNFTTest is Test {
    DeployMoodNFTScript public deployer;
    MoodNFT public moodNft;

    function setUp() public {
        //string memory happy = vm.readFile("./assets/happy.svg");
        //string memory sad = vm.readFile("./assets/sad.svg");
        //string memory satisfied = vm.readFile("./assets/satisfied.svg");

        deployer = new DeployMoodNFTScript();
        moodNft = MoodNFT(deployer.run());
    }

    function test_mint() public {
        vm.prank(msg.sender);
        MoodNFT(moodNft).mint(1000);
        assertEq(MoodNFT(moodNft).balanceOf(msg.sender), 1);
        
    }
}

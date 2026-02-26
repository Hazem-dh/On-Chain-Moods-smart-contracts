// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {MoodNFT} from "../src/MoodNft.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {console} from "forge-std/console.sol";

contract DeployMoodNFTScript is Script {
    MoodNFT public moodNft;

    function setUp() public {}

    function run() public returns (address) {
        string memory happy = vm.readFile("./assets/happy.svg");
        string memory sad = vm.readFile("./assets/sad.svg");
        string memory satisfied = vm.readFile("./assets/satisfied.svg");
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!

        (address wethUsdPriceFeed, uint256 deployerKey) = helperConfig.activeNetworkConfig();
        vm.startBroadcast(deployerKey);

        moodNft = new MoodNFT(sad, satisfied, happy, wethUsdPriceFeed);

        vm.stopBroadcast();

        return address(moodNft);
    }
}

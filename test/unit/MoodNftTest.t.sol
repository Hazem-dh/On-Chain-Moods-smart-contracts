// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {MoodNFT} from "../../src/MoodNft.sol";
import {DeployMoodNFTScript} from "../../script/DeployMoodNft.s.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract MoodNFTTest is Test {
    MoodNFT public moodNft;
    MockV3Aggregator public mockFeed;

    string public sadSvgUri;
    string public satisfiedSvgUri;
    string public happySvgUri;

    address public USER_A = makeAddr("userA");
    address public USER_B = makeAddr("userB");

    // HelperConfig deploys mock at 2000e8 = $2,000
    int256 constant INITIAL_PRICE = 2000e8;

    // Thresholds (8 decimals)
    uint256 constant THRESHOLD_2000 = 2000e8;
    uint256 constant THRESHOLD_1000 = 1000e8;
    uint256 constant THRESHOLD_5000 = 5000e8;

    // Mood boundaries for THRESHOLD_2000:
    //   HAPPY     : price >= 2000e8 + 10% = 2200e8
    //   SATISFIED : price >= 2000e8 - 10% = 1800e8  &&  price < 2200e8
    //   SAD       : price <  1800e8
    int256 constant PRICE_HAPPY     = 2200e8;
    int256 constant PRICE_SATISFIED = 2000e8;
    int256 constant PRICE_SAT_LOW   = 1800e8;
    int256 constant PRICE_SAD       = 1799e8;
    int256 constant PRICE_VERY_HIGH = 9999e8;
    int256 constant PRICE_VERY_LOW  = 100e8;

    event CreatedNFT(uint256 indexed tokenId, address indexed owner, uint256 threshold);
    event ThresholdUpdated(uint256 indexed tokenId, uint256 newThreshold);

    function setUp() public {
        DeployMoodNFTScript deployer = new DeployMoodNFTScript();
        moodNft = MoodNFT(deployer.run());
        mockFeed = MockV3Aggregator(address(moodNft.PRICEFEED()));

        sadSvgUri       = vm.readFile("./assets/sad.svg");
        satisfiedSvgUri = vm.readFile("./assets/satisfied.svg");
        happySvgUri     = vm.readFile("./assets/happy.svg");
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    function _decodeTokenURI(uint256 tokenId) internal view returns (string memory) {
        string memory uri = moodNft.tokenURI(tokenId);
        bytes memory uriBytes = bytes(uri);
        bytes memory b64 = new bytes(uriBytes.length - 29);
        for (uint256 i = 0; i < b64.length; i++) {
            b64[i] = uriBytes[i + 29];
        }
        return string(Base64.decode(string(b64)));
    }

    function _contains(string memory haystack, string memory needle) internal pure returns (bool) {
        bytes memory h = bytes(haystack);
        bytes memory n = bytes(needle);
        if (n.length == 0) return true;
        if (n.length > h.length) return false;
        for (uint256 i = 0; i <= h.length - n.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < n.length; j++) {
                if (h[i + j] != n[j]) {
                    found = false;
                    break;
                }
            }
            if (found) return true;
        }
        return false;
    }

    function _mintAndSetPrice(int256 price) internal {
        vm.prank(USER_A);
        moodNft.mint(THRESHOLD_2000);
        mockFeed.updateAnswer(price);
    }

    /*//////////////////////////////////////////////////////////////
                            DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    function test_initialTokenCounterIsZero() public view {
        assertEq(moodNft.getTokenCounter(), 0);
    }

    function test_nameAndSymbol() public view {
        assertEq(moodNft.name(), "MoodNFT");
        assertEq(moodNft.symbol(), "MOOD");
    }

    function test_getCurrentPriceMatchesInitial() public view {
        assertEq(moodNft.getCurrentPrice(), uint256(INITIAL_PRICE));
    }

    /*//////////////////////////////////////////////////////////////
                            MINT — HAPPY PATH
    //////////////////////////////////////////////////////////////*/

    function test_mintIncreasesBalance() public {
        vm.prank(USER_A);
        moodNft.mint(THRESHOLD_2000);
        assertEq(moodNft.balanceOf(USER_A), 1);
    }

    function test_mintIncrementsTokenCounter() public {
        vm.prank(USER_A);
        moodNft.mint(THRESHOLD_2000);
        assertEq(moodNft.getTokenCounter(), 1);
    }

    function test_mintTwoUsersGiveDistinctTokenIds() public {
        vm.prank(USER_A);
        moodNft.mint(THRESHOLD_2000);
        vm.prank(USER_B);
        moodNft.mint(THRESHOLD_1000);

        vm.prank(USER_A);
        uint256 idA = moodNft.getMyTokenId();
        vm.prank(USER_B);
        uint256 idB = moodNft.getMyTokenId();

        assertTrue(idA != idB);
    }

    function test_firstMintedTokenIdIsZero() public {
        vm.prank(USER_A);
        moodNft.mint(THRESHOLD_2000);
        vm.prank(USER_A);
        assertEq(moodNft.getMyTokenId(), 0);
    }

    function test_mintSetsCorrectThreshold() public {
        vm.prank(USER_A);
        moodNft.mint(THRESHOLD_2000);
        assertEq(moodNft.getThreshold(0), THRESHOLD_2000);
    }

    function test_mintSetsHasToken() public {
        vm.prank(USER_A);
        moodNft.mint(THRESHOLD_2000);
        vm.prank(USER_A);
        assertTrue(moodNft.hasToken());
    }

    function test_hasTokenFalseBeforeMint() public {
        vm.prank(USER_A);
        assertFalse(moodNft.hasToken());
    }

    function test_mintEmitsCreatedNFTEvent() public {
        vm.expectEmit(true, true, false, true);
        emit CreatedNFT(0, USER_A, THRESHOLD_2000);
        vm.prank(USER_A);
        moodNft.mint(THRESHOLD_2000);
    }

    /*//////////////////////////////////////////////////////////////
                            MINT — REVERTS
    //////////////////////////////////////////////////////////////*/

    function test_revertMintTwiceSameAddress() public {
        vm.startPrank(USER_A);
        moodNft.mint(THRESHOLD_2000);
        vm.expectRevert(MoodNFT.MoodNFT__AlreadyMinted.selector);
        moodNft.mint(THRESHOLD_2000);
        vm.stopPrank();
    }

    function test_revertMintWithZeroThreshold() public {
        vm.prank(USER_A);
        vm.expectRevert(MoodNFT.MoodNFT__InvalidThreshold.selector);
        moodNft.mint(0);
    }

    /*//////////////////////////////////////////////////////////////
                            SOULBOUND
    //////////////////////////////////////////////////////////////*/

    function test_revertOnTransferFrom() public {
        vm.prank(USER_A);
        moodNft.mint(THRESHOLD_2000);
        vm.prank(USER_A);
        vm.expectRevert(MoodNFT.MoodNFT__Soulbound.selector);
        moodNft.transferFrom(USER_A, USER_B, 0);
    }

    function test_revertOnSafeTransferFrom() public {
        vm.prank(USER_A);
        moodNft.mint(THRESHOLD_2000);
        vm.prank(USER_A);
        vm.expectRevert(MoodNFT.MoodNFT__Soulbound.selector);
        moodNft.safeTransferFrom(USER_A, USER_B, 0);
    }

    function test_revertOnSafeTransferFromWithData() public {
        vm.prank(USER_A);
        moodNft.mint(THRESHOLD_2000);
        vm.prank(USER_A);
        vm.expectRevert(MoodNFT.MoodNFT__Soulbound.selector);
        moodNft.safeTransferFrom(USER_A, USER_B, 0, "");
    }

    /*//////////////////////////////////////////////////////////////
                            UPDATE THRESHOLD
    //////////////////////////////////////////////////////////////*/

    function test_updateThresholdChangesStoredValue() public {
        vm.prank(USER_A);
        moodNft.mint(THRESHOLD_2000);
        vm.prank(USER_A);
        moodNft.updateThreshold(THRESHOLD_5000);
        assertEq(moodNft.getThreshold(0), THRESHOLD_5000);
    }



    function test_updateThresholdGetMyThresholdReflectsChange() public {
        vm.prank(USER_A);
        moodNft.mint(THRESHOLD_2000);
        vm.prank(USER_A);
        moodNft.updateThreshold(THRESHOLD_5000);
        vm.prank(USER_A);
        assertEq(moodNft.getMyThreshold(), THRESHOLD_5000);
    }

    function test_revertUpdateThresholdWithZero() public {
        vm.prank(USER_A);
        moodNft.mint(THRESHOLD_2000);
        vm.prank(USER_A);
        vm.expectRevert(MoodNFT.MoodNFT__InvalidThreshold.selector);
        moodNft.updateThreshold(0);
    }

    function test_revertUpdateThresholdWithoutMinting() public {
        vm.prank(USER_A);
        vm.expectRevert(MoodNFT.MoodNFT__NoTokenFound.selector);
        moodNft.updateThreshold(THRESHOLD_2000);
    }

    function test_updateThresholdDoesNotAffectOtherToken() public {
        vm.prank(USER_A);
        moodNft.mint(THRESHOLD_2000);
        vm.prank(USER_B);
        moodNft.mint(THRESHOLD_1000);
        vm.prank(USER_A);
        moodNft.updateThreshold(THRESHOLD_5000);
        // USER_B's token (id 1) unchanged
        assertEq(moodNft.getThreshold(1), THRESHOLD_1000);
    }

    /*//////////////////////////////////////////////////////////////
                            MOOD LOGIC
    //////////////////////////////////////////////////////////////
     * THRESHOLD_2000 = 2000e8
     * 10%            =  200e8
     * HAPPY          : price >= 2200e8
     * SATISFIED      : price >= 1800e8 && price < 2200e8
     * SAD            : price <  1800e8
    //////////////////////////////////////////////////////////////*/

    function test_moodIsHappyAtUpperBoundary() public {
        _mintAndSetPrice(PRICE_HAPPY);
        vm.prank(USER_A);
        assertEq(uint256(moodNft.getMyMood()), uint256(MoodNFT.NFTState.HAPPY));
    }

    function test_moodIsHappyWellAboveThreshold() public {
        _mintAndSetPrice(PRICE_VERY_HIGH);
        vm.prank(USER_A);
        assertEq(uint256(moodNft.getMyMood()), uint256(MoodNFT.NFTState.HAPPY));
    }

    function test_moodIsSatisfiedAtThreshold() public {
        _mintAndSetPrice(PRICE_SATISFIED);
        vm.prank(USER_A);
        assertEq(uint256(moodNft.getMyMood()), uint256(MoodNFT.NFTState.SATISFIED));
    }

    function test_moodIsSatisfiedAtLowerBoundary() public {
        _mintAndSetPrice(PRICE_SAT_LOW);
        vm.prank(USER_A);
        assertEq(uint256(moodNft.getMyMood()), uint256(MoodNFT.NFTState.SATISFIED));
    }

    function test_moodIsSatisfiedJustBelowUpperBoundary() public {
        _mintAndSetPrice(PRICE_HAPPY - 1);
        vm.prank(USER_A);
        assertEq(uint256(moodNft.getMyMood()), uint256(MoodNFT.NFTState.SATISFIED));
    }

    function test_moodIsSadJustBelowLowerBoundary() public {
        _mintAndSetPrice(PRICE_SAD);
        vm.prank(USER_A);
        assertEq(uint256(moodNft.getMyMood()), uint256(MoodNFT.NFTState.SAD));
    }

    function test_moodIsSadWellBelowThreshold() public {
        _mintAndSetPrice(PRICE_VERY_LOW);
        vm.prank(USER_A);
        assertEq(uint256(moodNft.getMyMood()), uint256(MoodNFT.NFTState.SAD));
    }

    function test_getMoodByTokenIdMatchesGetMyMood() public {
        _mintAndSetPrice(PRICE_HAPPY);
        vm.prank(USER_A);
        assertEq(uint256(moodNft.getMood(0)), uint256(MoodNFT.NFTState.HAPPY));
    }

    function test_moodTransitionsSadToSatisfiedToHappy() public {
        vm.prank(USER_A);
        moodNft.mint(THRESHOLD_2000);

        mockFeed.updateAnswer(PRICE_VERY_LOW);
        vm.prank(USER_A);
        assertEq(uint256(moodNft.getMyMood()), uint256(MoodNFT.NFTState.SAD));

        mockFeed.updateAnswer(PRICE_SATISFIED);
        vm.prank(USER_A);
        assertEq(uint256(moodNft.getMyMood()), uint256(MoodNFT.NFTState.SATISFIED));

        mockFeed.updateAnswer(PRICE_VERY_HIGH);
        vm.prank(USER_A);
        assertEq(uint256(moodNft.getMyMood()), uint256(MoodNFT.NFTState.HAPPY));
    }

    function test_moodChangeAfterThresholdUpdateSatisfiedToSad() public {
        _mintAndSetPrice(PRICE_SATISFIED);
        vm.prank(USER_A);
        assertEq(uint256(moodNft.getMyMood()), uint256(MoodNFT.NFTState.SATISFIED));

        vm.prank(USER_A);
        moodNft.updateThreshold(THRESHOLD_5000);
        vm.prank(USER_A);
        assertEq(uint256(moodNft.getMyMood()), uint256(MoodNFT.NFTState.SAD));
    }

    function test_moodChangeAfterThresholdUpdateSadToHappy() public {
        vm.prank(USER_A);
        moodNft.mint(THRESHOLD_5000);
        mockFeed.updateAnswer(PRICE_SATISFIED);
        vm.prank(USER_A);
        assertEq(uint256(moodNft.getMyMood()), uint256(MoodNFT.NFTState.SAD));

        vm.prank(USER_A);
        moodNft.updateThreshold(THRESHOLD_1000);
        vm.prank(USER_A);
        assertEq(uint256(moodNft.getMyMood()), uint256(MoodNFT.NFTState.HAPPY));
    }

    /*//////////////////////////////////////////////////////////////
                        TOKEN URI — STRUCTURE
    //////////////////////////////////////////////////////////////*/

    function test_tokenURIStartsWithBase64DataPrefix() public {
        _mintAndSetPrice(PRICE_SATISFIED);
        string memory uri = moodNft.tokenURI(0);
        bytes memory uriBytes = bytes(uri);
        bytes memory prefix = bytes("data:application/json;base64,");
        for (uint256 i = 0; i < prefix.length; i++) {
            assertEq(uriBytes[i], prefix[i]);
        }
    }

    function test_tokenURIRevertsForNonExistentToken() public {
        vm.expectRevert(MoodNFT.ERC721Metadata__URI_QueryFor_NonExistentToken.selector);
        moodNft.tokenURI(999);
    }

    function test_decodedJsonContainsName() public {
        _mintAndSetPrice(PRICE_SATISFIED);
        assertTrue(_contains(_decodeTokenURI(0), '"name":"MoodNFT"'));
    }

    function test_decodedJsonContainsDescription() public {
        _mintAndSetPrice(PRICE_SATISFIED);
        assertTrue(_contains(_decodeTokenURI(0), "soulbound NFT"));
    }

    function test_decodedJsonContainsPriceTargetTrait() public {
        _mintAndSetPrice(PRICE_SATISFIED);
        assertTrue(_contains(_decodeTokenURI(0), '"trait_type": "Price Target"'));
    }

    function test_decodedJsonContainsPriceTargetValue() public {
        _mintAndSetPrice(PRICE_SATISFIED);
        // THRESHOLD_2000 = 200000000000
        assertTrue(_contains(_decodeTokenURI(0), "200000000000"));
    }

    function test_decodedJsonContainsCurrentEthPriceTrait() public {
        _mintAndSetPrice(PRICE_SATISFIED);
        assertTrue(_contains(_decodeTokenURI(0), '"trait_type": "Current ETH Price"'));
    }

    function test_decodedJsonContainsMoodColorTrait() public {
        _mintAndSetPrice(PRICE_SATISFIED);
        assertTrue(_contains(_decodeTokenURI(0), '"trait_type": "Mood Color"'));
    }

    function test_decodedJsonContainsMoodTrait() public {
        _mintAndSetPrice(PRICE_SATISFIED);
        assertTrue(_contains(_decodeTokenURI(0), '"trait_type": "Mood"'));
    }

    function test_decodedJsonContainsImageKey() public {
        _mintAndSetPrice(PRICE_SATISFIED);
        assertTrue(_contains(_decodeTokenURI(0), '"image":'));
    }

    function test_decodedJsonContainsBackgroundColorKey() public {
        _mintAndSetPrice(PRICE_SATISFIED);
        assertTrue(_contains(_decodeTokenURI(0), '"background_color":'));
    }

    /*//////////////////////////////////////////////////////////////
                    TOKEN URI — SAD IMAGE & METADATA
    //////////////////////////////////////////////////////////////*/

    function test_uri_sadMood_imageIsSadSvg() public {
        _mintAndSetPrice(PRICE_SAD);
        assertTrue(_contains(_decodeTokenURI(0), sadSvgUri), "image should be sad SVG");
    }

    function test_uri_sadMood_moodAttributeIsSad() public {
        _mintAndSetPrice(PRICE_SAD);
        assertTrue(_contains(_decodeTokenURI(0), "SAD"));
    }

    function test_uri_sadMood_colorIs4A90D9() public {
        _mintAndSetPrice(PRICE_SAD);
        assertTrue(_contains(_decodeTokenURI(0), "4A90D9"));
    }

    function test_uri_sadMood_backgroundColorIs4A90D9() public {
        _mintAndSetPrice(PRICE_SAD);
        assertTrue(_contains(_decodeTokenURI(0), '"background_color": "#4A90D9"'));
    }

    function test_uri_sadMood_doesNotContainOtherImages() public {
        _mintAndSetPrice(PRICE_SAD);
        string memory json = _decodeTokenURI(0);
        assertFalse(_contains(json, happySvgUri),     "should not contain happy SVG");
        assertFalse(_contains(json, satisfiedSvgUri), "should not contain satisfied SVG");
    }

    /*//////////////////////////////////////////////////////////////
                TOKEN URI — SATISFIED IMAGE & METADATA
    //////////////////////////////////////////////////////////////*/

    function test_uri_satisfiedMood_imageIsSatisfiedSvg() public {
        _mintAndSetPrice(PRICE_SATISFIED);
        assertTrue(_contains(_decodeTokenURI(0), satisfiedSvgUri), "image should be satisfied SVG");
    }

    function test_uri_satisfiedMood_atLowerBoundaryImageIsSatisfiedSvg() public {
        _mintAndSetPrice(PRICE_SAT_LOW);
        assertTrue(_contains(_decodeTokenURI(0), satisfiedSvgUri), "lower boundary should be satisfied SVG");
    }

    function test_uri_satisfiedMood_moodAttributeIsSatisfied() public {
        _mintAndSetPrice(PRICE_SATISFIED);
        assertTrue(_contains(_decodeTokenURI(0), "SATISFIED"));
    }

    function test_uri_satisfiedMood_colorIsF5A623() public {
        _mintAndSetPrice(PRICE_SATISFIED);
        assertTrue(_contains(_decodeTokenURI(0), "F5A623"));
    }

    function test_uri_satisfiedMood_backgroundColorIsF5A623() public {
        _mintAndSetPrice(PRICE_SATISFIED);
        assertTrue(_contains(_decodeTokenURI(0), '"background_color": "#F5A623"'));
    }

    function test_uri_satisfiedMood_doesNotContainOtherImages() public {
        _mintAndSetPrice(PRICE_SATISFIED);
        string memory json = _decodeTokenURI(0);
        assertFalse(_contains(json, happySvgUri), "should not contain happy SVG");
        assertFalse(_contains(json, sadSvgUri),   "should not contain sad SVG");
    }

    /*//////////////////////////////////////////////////////////////
                    TOKEN URI — HAPPY IMAGE & METADATA
    //////////////////////////////////////////////////////////////*/

    function test_uri_happyMood_imageIsHappySvg() public {
        _mintAndSetPrice(PRICE_HAPPY);
        assertTrue(_contains(_decodeTokenURI(0), happySvgUri), "image should be happy SVG");
    }

    function test_uri_happyMood_atExactUpperBoundaryImageIsHappySvg() public {
        _mintAndSetPrice(PRICE_HAPPY);
        assertTrue(_contains(_decodeTokenURI(0), happySvgUri), "exact upper boundary should be happy SVG");
    }

    function test_uri_happyMood_moodAttributeIsHappy() public {
        _mintAndSetPrice(PRICE_HAPPY);
        assertTrue(_contains(_decodeTokenURI(0), "HAPPY"));
    }

    function test_uri_happyMood_colorIs7ED321() public {
        _mintAndSetPrice(PRICE_HAPPY);
        assertTrue(_contains(_decodeTokenURI(0), "7ED321"));
    }

    function test_uri_happyMood_backgroundColorIs7ED321() public {
        _mintAndSetPrice(PRICE_HAPPY);
        assertTrue(_contains(_decodeTokenURI(0), '"background_color": "#7ED321"'));
    }

    function test_uri_happyMood_doesNotContainOtherImages() public {
        _mintAndSetPrice(PRICE_HAPPY);
        string memory json = _decodeTokenURI(0);
        assertFalse(_contains(json, sadSvgUri),       "should not contain sad SVG");
        assertFalse(_contains(json, satisfiedSvgUri), "should not contain satisfied SVG");
    }

    /*//////////////////////////////////////////////////////////////
                    TOKEN URI — DYNAMIC CHANGES
    //////////////////////////////////////////////////////////////*/

    function test_uri_changesWhenPriceCrossesMoodBoundary() public {
        vm.prank(USER_A);
        moodNft.mint(THRESHOLD_2000);

        mockFeed.updateAnswer(PRICE_SAD);
        string memory jsonSad = _decodeTokenURI(0);

        mockFeed.updateAnswer(PRICE_HAPPY);
        string memory jsonHappy = _decodeTokenURI(0);

        assertFalse(
            keccak256(bytes(jsonSad)) == keccak256(bytes(jsonHappy)),
            "URI must change when mood changes"
        );
        assertTrue(_contains(jsonSad,   sadSvgUri),   "sad json should have sad SVG");
        assertTrue(_contains(jsonHappy, happySvgUri), "happy json should have happy SVG");
    }

    function test_uri_changesAfterThresholdUpdate() public {
        _mintAndSetPrice(PRICE_SATISFIED);
        string memory jsonBefore = _decodeTokenURI(0);
        assertTrue(_contains(jsonBefore, satisfiedSvgUri));

        vm.prank(USER_A);
        moodNft.updateThreshold(THRESHOLD_5000);
        string memory jsonAfter = _decodeTokenURI(0);
        assertTrue(_contains(jsonAfter, sadSvgUri));

        assertFalse(
            keccak256(bytes(jsonBefore)) == keccak256(bytes(jsonAfter)),
            "URI must change after threshold update"
        );
    }

    function test_uri_currentPriceValueUpdatesWithFeed() public {
        _mintAndSetPrice(PRICE_SATISFIED); // 2000e8 = 200000000000
        assertTrue(_contains(_decodeTokenURI(0), "200000000000"));

        mockFeed.updateAnswer(PRICE_HAPPY); // 2200e8 = 220000000000
        assertTrue(_contains(_decodeTokenURI(0), "220000000000"));
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW HELPERS
    //////////////////////////////////////////////////////////////*/

    function test_getCurrentPrice() public view {
        assertEq(moodNft.getCurrentPrice(), uint256(INITIAL_PRICE));
    }

    function test_getMyThreshold() public {
        vm.prank(USER_A);
        moodNft.mint(THRESHOLD_2000);
        vm.prank(USER_A);
        assertEq(moodNft.getMyThreshold(), THRESHOLD_2000);
    }

    function test_getThresholdByTokenId() public {
        vm.prank(USER_A);
        moodNft.mint(THRESHOLD_2000);
        assertEq(moodNft.getThreshold(0), THRESHOLD_2000);
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ
    //////////////////////////////////////////////////////////////*/

    function testFuzz_mintWithAnyNonzeroThreshold(uint256 threshold) public {
        vm.assume(threshold > 0);
        vm.prank(USER_A);
        moodNft.mint(threshold);
        assertEq(moodNft.balanceOf(USER_A), 1);
        assertEq(moodNft.getThreshold(0), threshold);
    }

    function testFuzz_updateThresholdWithAnyNonzeroValue(uint256 newThreshold) public {
        vm.assume(newThreshold > 0);
        vm.prank(USER_A);
        moodNft.mint(THRESHOLD_2000);
        vm.prank(USER_A);
        moodNft.updateThreshold(newThreshold);
        assertEq(moodNft.getThreshold(0), newThreshold);
    }
}
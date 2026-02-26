// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @title MoodNFT
/// @author Your Name
/// @notice A soulbound NFT whose mood dynamically reflects ETH price against the owner's personal price target.
/// @dev Mood is computed at query time via Chainlink ETH/USD price feed — nothing is stored about current mood.
///      Each address can hold only one token. Transfers are disabled.
contract MoodNFT is ERC721, Ownable {
    /// @notice Thrown when an address tries to mint a second token.
    error MoodNFT__AlreadyMinted();
    /// @notice Thrown when the caller has no token.
    error MoodNFT__NoTokenFound();
    /// @notice Thrown when a threshold of zero is provided.
    error MoodNFT__InvalidThreshold();
    /// @notice Thrown when a transfer is attempted. This token is soulbound.
    error MoodNFT__Soulbound();
    /// @notice Thrown when tokenURI is queried for a nonexistent token.
    error ERC721Metadata__URI_QueryFor_NonExistentToken();

    /// @notice The three possible moods of the NFT.
    enum NFTState {
        SAD, // 0 — price well below threshold
        SATISFIED, // 1 — price near threshold
        HAPPY // 2 — price above threshold

    }

    AggregatorV3Interface public immutable PRICEFEED;

    uint256 private tokenCounter;

    string private sadSvgUri;
    string private satisfiedSvgUri;
    string private happySvgUri;

    mapping(uint256 tokenId => uint256 threshold) private priceThreshold;
    mapping(address minter => uint256 tokenId) private addressToTokenId;
    mapping(address minter => bool hasMinted) private hasMintedToken;

    /// @notice Emitted when a new token is minted.
    /// @param tokenId The newly minted token ID.
    /// @param owner The address receiving the token.
    /// @param threshold The owner's initial price target in USD (8 decimals).
    event CreatedNFT(uint256 indexed tokenId, address indexed owner, uint256 threshold);

    /// @notice Emitted when an owner updates their price target.
    /// @param tokenId The token whose threshold was updated.
    /// @param newThreshold The new price target in USD (8 decimals).
    event ThresholdUpdated(uint256 indexed tokenId, uint256 newThreshold);

    /// @notice Deploys the contract with SVG assets and a Chainlink price feed.
    /// @param _sadSvgUri Base64-encoded SVG data URI for the SAD mood.
    /// @param _satisfiedSvgUri Base64-encoded SVG data URI for the SATISFIED mood.
    /// @param _happySvgUri Base64-encoded SVG data URI for the HAPPY mood.
    /// @param _priceFeedAddress Chainlink ETH/USD feed address. Sepolia: 0x694AA1769357215DE4FAC081bf1f309aDC325306
    constructor(
        string memory _sadSvgUri,
        string memory _satisfiedSvgUri,
        string memory _happySvgUri,
        address _priceFeedAddress
    ) ERC721("MoodNFT", "MOOD") Ownable(msg.sender) {
        sadSvgUri = _sadSvgUri;
        satisfiedSvgUri = _satisfiedSvgUri;
        happySvgUri = _happySvgUri;
        PRICEFEED = AggregatorV3Interface(_priceFeedAddress);
    }

    /// @notice Mints one soulbound token to the caller with a personal price target.
    /// @dev Frontend conversion: userInputUsd * 1e8. e.g. $3000 = 300000000000.
    /// @param _threshold The caller's ETH price target in USD with 8 decimals.
    function mint(uint256 _threshold) public {
        if (hasMintedToken[msg.sender]) revert MoodNFT__AlreadyMinted();
        if (_threshold == 0) revert MoodNFT__InvalidThreshold();

        uint256 tokenId = tokenCounter;
        tokenCounter += 1;

        hasMintedToken[msg.sender] = true;
        addressToTokenId[msg.sender] = tokenId;
        priceThreshold[tokenId] = _threshold;

        _safeMint(msg.sender, tokenId);
        emit CreatedNFT(tokenId, msg.sender, _threshold);
    }

    /// @notice Updates the caller's ETH price target.
    /// @dev Token ID is derived from msg.sender. Same 8-decimal format as mint.
    /// @param _newThreshold The new price target in USD with 8 decimals.
    function updateThreshold(uint256 _newThreshold) public {
        if (!hasMintedToken[msg.sender]) revert MoodNFT__NoTokenFound();
        if (_newThreshold == 0) revert MoodNFT__InvalidThreshold();

        uint256 tokenId = addressToTokenId[msg.sender];
        priceThreshold[tokenId] = _newThreshold;
        emit ThresholdUpdated(tokenId, _newThreshold);
    }

    /// @dev Blocks all transfers. Mint (from == 0) passes through.
    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = _ownerOf(tokenId);
        if (from != address(0) && to != address(0)) revert MoodNFT__Soulbound();
        if (to == address(0)) revert MoodNFT__Soulbound(); // no burn either
        return super._update(to, tokenId, auth);
    }

    /// @dev Maps live ETH price against the token's threshold.
    ///      price >= threshold + 10%        → HAPPY
    ///      price >= threshold - 10%        → SATISFIED
    ///      price <  threshold - 10%        → SAD
    function _getMood(uint256 tokenId) internal view returns (NFTState) {
        (, int256 rawPrice,,,) = PRICEFEED.latestRoundData();
        uint256 currentPrice = uint256(rawPrice);
        uint256 threshold = priceThreshold[tokenId];
        uint256 tenPercent = threshold / 10;

        if (currentPrice >= threshold + tenPercent) return NFTState.HAPPY;
        else if (currentPrice >= threshold - tenPercent) return NFTState.SATISFIED;
        else return NFTState.SAD;
    }

    /// @dev Returns "data:application/json;base64," as the base URI.
    function _baseURI() internal pure override returns (string memory) {
        return "data:application/json;base64,";
    }

    /// @notice Returns the on-chain metadata URI for a given token.
    /// @dev Mood and color reflect the live ETH price at time of query.
    /// @param tokenId The token to query.
    /// @return A base64-encoded JSON string containing name, description, attributes, and image.
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (_ownerOf(tokenId) == address(0)) revert ERC721Metadata__URI_QueryFor_NonExistentToken();

        NFTState mood = _getMood(tokenId);

        string memory imageURI;
        string memory moodLabel;
        string memory moodColor;

        if (mood == NFTState.SAD) {
            imageURI = sadSvgUri;
            moodLabel = "SAD";
            moodColor = "4A90D9";
        } else if (mood == NFTState.SATISFIED) {
            imageURI = satisfiedSvgUri;
            moodLabel = "SATISFIED";
            moodColor = "F5A623";
        } else {
            imageURI = happySvgUri;
            moodLabel = "HAPPY";
            moodColor = "7ED321";
        }

        (, int256 rawPrice,,,) = PRICEFEED.latestRoundData();

        return string(
            abi.encodePacked(
                _baseURI(),
                Base64.encode(
                    abi.encodePacked(
                        '{"name":"',
                        name(),
                        '", "description":"A soulbound NFT whose mood reflects ETH price vs your personal target.",',
                        '"attributes": [',
                        '{"trait_type": "Mood", "value": "',
                        moodLabel,
                        '"},',
                        '{"trait_type": "Mood Color", "value": "#',
                        moodColor,
                        '"},',
                        '{"trait_type": "Price Target", "value": ',
                        _uintToString(priceThreshold[tokenId]),
                        "},",
                        '{"trait_type": "Current ETH Price", "value": ',
                        _uintToString(uint256(rawPrice)),
                        "}",
                        "],",
                        '"background_color": "#',
                        moodColor,
                        '",',
                        '"image":"',
                        imageURI,
                        '"}'
                    )
                )
            )
        );
    }

    /// @dev Converts a uint256 to its decimal string representation.
    function _uintToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits--;
            buffer[digits] = bytes1(uint8(48 + value % 10));
            value /= 10;
        }
        return string(buffer);
    }

    /// @notice Returns the total number of tokens ever minted.
    function getTokenCounter() public view returns (uint256) {
        return tokenCounter;
    }

    /// @notice Returns the token ID associated with the caller's address.
    function getMyTokenId() public view returns (uint256) {
        return addressToTokenId[msg.sender];
    }

    /// @notice Returns the caller's current price target.
    function getMyThreshold() public view returns (uint256) {
        return priceThreshold[addressToTokenId[msg.sender]];
    }

    /// @notice Returns the caller's current NFT mood based on live price.
    function getMyMood() public view returns (NFTState) {
        return _getMood(addressToTokenId[msg.sender]);
    }

    /// @notice Returns whether the caller currently holds a token.
    function hasToken() public view returns (bool) {
        return hasMintedToken[msg.sender];
    }

    /// @notice Returns the latest ETH/USD price from Chainlink (8 decimals).
    function getCurrentPrice() public view returns (uint256) {
        (, int256 price,,,) = PRICEFEED.latestRoundData();
        return uint256(price);
    }

    /// @notice Returns the price target for any given token ID.
    /// @param tokenId The token to query.
    function getThreshold(uint256 tokenId) public view returns (uint256) {
        return priceThreshold[tokenId];
    }

    /// @notice Returns the current mood for any given token ID.
    /// @param tokenId The token to query.
    function getMood(uint256 tokenId) public view returns (NFTState) {
        return _getMood(tokenId);
    }
}

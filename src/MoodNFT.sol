// SPDX-License-Identifier: MIT
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

pragma solidity ^0.8.13;

contract MoodNFT is ERC721, Ownable {
    error ERC721Metadata__URI_QueryFor_NonExistentToken();

    enum NFTState {
        ANGRY,
        HAPPY,
        NEUTRAL,
        SLEEPY,
        SURPRISED
    }

    uint256 private tokenCounter;
    string private angrySvgUri;
    string private happySvgUri;
    string private neutralSvgUri;
    string private sleepySvgUri;
    string private surprisedSvgUri;

    mapping(uint256 Id => NFTState State) private tokenIdToState;

    event CreatedNFT(uint256 indexed tokenId);

    constructor(
        string memory _angrySvgUri,
        string memory _happySvgUri,
        string memory _neutralSvgUri,
        string memory _sleepySvgUri,
        string memory _surprisedSvgUri
    ) ERC721("MoodNFT", "MOOD") Ownable(msg.sender) {
        tokenCounter = 0;
        angrySvgUri = _angrySvgUri;
        happySvgUri = _happySvgUri;
        neutralSvgUri = _neutralSvgUri;
        sleepySvgUri = _sleepySvgUri;
        surprisedSvgUri = _surprisedSvgUri;
    }

    function mint() public {
        // TODO - add a check to prevent minting more than 1 NFT per address
        // TODO - add minting logic to assign a  mood to the NFT
        uint256 _tokenCounter = tokenCounter;
        _safeMint(msg.sender, _tokenCounter);
        tokenCounter += 1;
        emit CreatedNFT(_tokenCounter);
    }

    function _baseURI() internal pure override returns (string memory) {
        return "data:application/json;base64,";
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (ownerOf(tokenId) == address(0)) {
            revert ERC721Metadata__URI_QueryFor_NonExistentToken();
        }
        string memory imageURI = happySvgUri;

        if (tokenIdToState[tokenId] == NFTState.ANGRY) {
            imageURI = angrySvgUri;
        } else if (tokenIdToState[tokenId] == NFTState.NEUTRAL) {
            imageURI = neutralSvgUri;
        } else if (tokenIdToState[tokenId] == NFTState.SLEEPY) {
            imageURI = sleepySvgUri;
        } else if (tokenIdToState[tokenId] == NFTState.SURPRISED) {
            imageURI = surprisedSvgUri;
        }
        return string(
            abi.encodePacked(
                _baseURI(),
                Base64.encode(
                    bytes( // bytes casting actually unnecessary as 'abi.encodePacked()' returns a bytes
                        abi.encodePacked(
                            '{"name":"',
                            name(), // You can add whatever name here
                            '", "description":"An NFT that reflects the mood of the owner", ',
                            '"attributes": [{"trait_type": "moodiness", "value": 100}], "image":"',
                            imageURI,
                            '"}'
                        )
                    )
                )
            )
        );
    }

    function mintMoodNFT(address to) public returns (uint256) {
        uint256 newTokenId = tokenCounter;
        _safeMint(to, newTokenId);
        tokenCounter += 1;
        return newTokenId;
    }
}

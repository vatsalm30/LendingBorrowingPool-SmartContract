// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract BorrowApplication is ERC721, ERC721URIStorage, AccessControl
{
    uint applicationIDs = 0;

    mapping(uint256 => uint8) viability;

    mapping(uint256 => address) assets;

    mapping(uint256 => uint256) amountOfAssets;
    mapping(uint256 => uint256) amountOfAssetsFilled;

    mapping(uint256 => bool) filledApps;

    constructor() ERC721("BorrowApp", "BAP") {}

    function safeMint(string memory applicationURI, address asset, uint256 amountOfAsset) public
    {
        _safeMint(msg.sender, applicationIDs, "");
        _setTokenURI(applicationIDs, applicationURI);

        viability[applicationIDs] = 0;

        assets[applicationIDs] = asset;
        amountOfAssets[applicationIDs] = amountOfAsset;
        amountOfAssetsFilled[applicationIDs] = 0;
        filledApps[applicationIDs] = false;

        applicationIDs++;
    }

    function getViability(uint256 appID) public view returns(uint8)
    {
        require(appID < applicationIDs, "Application ID does not exist");

        return viability[appID];
    }

    // MAKE THIS IMPLIEMTNATION MORE ADVANCED
    // restrict function to only be called by the managerial contract
    function updateViability(uint256 appID, uint8 averageRanking) public 
    {
        require(appID < applicationIDs, "Application ID does not exist");
        require(tx.origin != msg.sender, "This function can only be called by a contract");

        viability[appID] = averageRanking;
    }

    function getLastApplication() public view returns(uint256)
    {
        return applicationIDs;
    }

    function getFilled(uint256 appID) public view returns(bool)
    {
        require(appID < applicationIDs, "Application ID does not exist");

        return filledApps[appID];
    }

    function viabilityToInterestRate(uint256 appID) public view returns(uint256)
    {
        require(appID < applicationIDs, "Application ID does not exist");

        return viability[appID] * 1000;
    }


    // restrict function to only be called by the managerial contract
    function lendedAssets(uint256 appID, uint256 lendAmt) public returns(bool)
    {
        require(appID < applicationIDs, "Application ID does not exist");
        require(tx.origin != msg.sender, "This function can only be called by a contract");

        amountOfAssetsFilled[appID] += lendAmt;
        if(amountOfAssetsFilled[appID] >= amountOfAssets[appID])
        {
            filledApps[appID] = true;
            return true;
        }
        return false;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

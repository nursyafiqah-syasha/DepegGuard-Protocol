// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts@5.0.0/token/ERC721/ERC721.sol";
//import "@openzeppelin/contracts@5.0.0/token/ERC721/extensions/ERC721URIStorage.sol";
//import "@openzeppelin/contracts@5.0.0/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts@5.0.0/access/Ownable.sol";
// use this website for reference https://docs.openzeppelin.com/contracts/5.x/api/token/erc721

contract DepegInsuranceNFT is ERC721, Ownable {
    uint256 private _nextTokenId;

    enum Severity {Mild, Moderate, Severe}

    struct PolicyData{
        address stablecoin; //asset being covered, stablecoin, S
        uint256 coverageAmount;//coverage amount, C
        uint256 expiryTimestamp; //when coverage ends (start time + duration)
        Severity severity; // tier of risk covered
        bool isActive; // policy of status
    }

    //we want to map the token id which will incrementally added to the the policy data
    mapping(uint256 => PolicyData) public policies;

    //logged events to search using indexed parameter as filter
    event PolicyMinted(uint256 indexed tokenId, address indexed holder, address stablecoin, uint256 amount);
    event PolicyClaimed (uint256 indexed tokenId);

    //name and symbol of the token
    constructor() ERC721( "DepegInsurance" ,"INSURE") Ownable (msg.sender){
        _nextTokenId = 1;
    }

    // payable function for depositing ether, condition pakai oracle
    function purchasePolicy (address _stablecoin, uint256 _coverageAmount, uint256 _durationInDays, Severity _severity)
    public payable returns (uint256) {
        // ?? calculate premimum formula ??
        uint256 requiredPremium = (_coverageAmount * 1 ether)/100;

        require(msg.value >0, "Premium payment required");

        //calculate expiration
        uint256 expiry = block.timestamp + (_durationInDays * 1 days);

        //increment token id
        uint256 newTokenId = _nextTokenId++;

        //mint nft to buyer
        _safeMint(msg.sender,newTokenId);

        //store specific details mapped to this NFT
        policies[newTokenId] = PolicyData({
            stablecoin: _stablecoin,
            coverageAmount: _coverageAmount,
            expiryTimestamp: expiry,
            severity: _severity,
            isActive: true
        });

        emit PolicyMinted(newTokenId, msg.sender, _stablecoin, _coverageAmount);

        return newTokenId;
    }

    //view policy details, memory used when variable only needed temporarily
    function getPolicyDetails(uint256 _tokenId) public view returns (PolicyData memory){
        //make sure token exists and do not expire

        require(policies[_tokenId].expiryTimestamp != 0, "Policy does not exist");
        return policies[_tokenId];
    }

    // owner NFT can file a claim
    function fileClaim (uint256 _tokenId) public {
        //check ownership
        require(ownerOf(_tokenId) == msg.sender, "Not policy owner");

        PolicyData storage policy = policies[_tokenId];

        //verify validity
        require(policy.isActive, "Policy inactive or already claimed");
        require(block.timestamp <= policy.expiryTimestamp, "Policy expired");

        //verify depeg chainlink oracle price

        //mark as inactive to present double claims
        policy.isActive = false;

        emit PolicyClaimed(_tokenId);

        //payout logic
    }

    //withdraw premiums for insurance provider
    function withdrawFunds() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}

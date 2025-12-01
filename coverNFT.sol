// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts@5.0.0/token/ERC721/ERC721.sol";
//import "@openzeppelin/contracts@5.0.0/token/ERC721/extensions/ERC721URIStorage.sol";
//import "@openzeppelin/contracts@5.0.0/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts@5.0.0/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
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

    //store chainline price feed address for each stablecoin
    mapping(address => address) public stablecoinPriceFeeds;

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

    //set oracle address, only owner can call this function
    function setPriceFeed (address _stablecoin, address _priceFeedAddress) public onlyOwner {
        stablecoinPriceFeeds[_stablecoin] = _priceFeedAddress;
    }

    //get price feed interface , interact with other contracts and call functions in another contract
    function _getPriceFeed(address _stablecoin) internal view returns (AggregatorV3Interface) {
        address feedAddress = stablecoinPriceFeeds[_stablecoin];
        require(feedAddress != address(0), "Price feed not set up for this stablecoin");
        return AggregatorV3Interface(feedAddress);
    }

    function _getPricePercentage(address _stablecoin) internal view returns (uint256){
        AggregatorV3Interface priceFeed = _getPriceFeed(_stablecoin);

        //latestRoundData returns : (roundId, answer, startedAt, updatedAt, answeredInRound)
        //https://docs.chain.link/chainlink-local/api-reference/v022/aggregator-v3-interface
        (int256 answer)  = priceFeed.latestRoundData();

        // price returrned by chain link is scaled by 10^8
        //stablecoin is pegged to 1 usd, feed is X/USD (DAI/USD)
        // if peg is 10^8 a price of 0.95 USD would be 95,000,000
        //number of decimals the value will have
        uint256 decimals = priceFeed.decimals();

        uint256 pegValue = 10**decimals;

        require(price >0, "Chainlink price is invalid or zero");

        uint256 PricePercentage = (uint256(price) * 100)/pegValue;
        return pricePercentage;
    }



    // owner NFT can file a claim
    function fileClaim (uint256 _tokenId) public {
        //check ownership
        require(ownerOf(_tokenId) == msg.sender, "Not policy owner");

        PolicyData storage policy = policies[_tokenId];

        //verify validity
        require(policy.isActive, "Policy inactive or already claimed");
        require(block.timestamp <= policy.expiryTimestamp, "Policy expired");

        //verify depeg chainlink oracle price /depeg detection

        uint256 currentPricePercent = _getSimulatedCurrentPrice(policy.stablecoin);
        uint256 payoutPercent = _getPayoutPercentage(policy.severity,currentPricePercent);

        require (payoutPercent > 0, "Depeg condition not met for policy severity tier");

        //calculate final payout (coverage amount * payment percentage) /100
        uint256 payoutAmount = (coverageAmount * payoutPercent)/100;


        // ensure contract has sufficient funds
        require(address(this).balance >= payoutAmount, "Insufficient contract balance for payout");
        //mark as inactive to present double claims
        policy.isActive = false;

        //payout
        payable(msg.sender).transfer(payoutAmount);

        emit PolicyClaimed(_tokenId);
    }

    //withdraw premiums for insurance provider
    function withdrawFunds() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}

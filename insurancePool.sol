// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import "@openzeppelin/contracts@5.0.0/access/Ownable.sol";
import "@openzeppelin/contracts@5.0.0/token/ERC20/IERC20.sol"; 

// If using a stablecoin like USDC instead of ETH



contract InsurancePool is Ownable {
    address public depegInsuranceNFT;
    uint256 public totalActiveCover;

    address public depegInsuranceNFT;
    uint256 public totalActiveCover;
    mapping(address => uint256) public stakers;

    event LiquidityDeposited(address indexed staker, uint256 amount);
    event LiquidityWithdrawn (address indexed staker, unint256 amount);
    event PolicyClaimPaid (address indexed claimant, unint256 amount);
    event ActiveCoverUpdated (uint256 newTotalActiceCover);


    constructor (address initialOwner)
    Ownable (initialOwner){
        //owner is et by ownable
    }

    // set address of DepegInsuranceNFT contract, only callable once by owner
    function _setInsuranceContract (address _insuranceNFT) public onlyOwner {
        require(depegInsuranceNFT == address(0), "Insurance contract already set");
        depegInsuranceNFT = _insuranceNFT;
    }


    // allow user to deposit eth into pool to act as insurace collateral
    function depositLiquidityPool () public payable {
        require(msg.value >0, "Deposit amount must be greater than zero");

        stakers[msg.sender] += msg.value;

        emit LiquidityDeposited(msg.sender, msg.value);
    }


    // allow user to withdraw their staked ETH, provide liquidity
    // staking funds cannot be withdrawn if they are backing active, unclaimed policies

    function withdrawLiquidiy (uint256 _amount) public {
        require(_amount > 0, "Withdrw amount must be grteher than zero");
        require(stakers[msg.sender]>= _amount, "Insufficient staked balance");
        require(address(this).balance - _amount >= totalActiveCover, "withdrawal reduces cover below required active level");

        stakers[msg.sender] -= _amount;
        (bool success, ) = payable(msg.sender).call{value: _amount} ("");
        require(success, "ETH transfer failed");

        emit LiquidityWithdrawn(msg.sender, _amount);

    }

    // return total ETH balance of the contracts
    function getPoolLiquidity() public view return (uint256) {
        return address(this).balance;
    }

    // returon pool utilization scaled by 1e18
    function getUtilization() public view returns (uint256) {
        uint256 liquidity = getPoolLiquidity();
        if(liquidity == 0)
            return 0;

        return (totalActiveCover * 1e18) / liquidity;
    }

    // transfer premium from policy contract to the pool and updates active cover
    function receivePremiumAndCover (uint256 _premium, uint256 _newCoverAmount)
    public{
        require(msg.sender == depegInsuranceNFT, "Caller is not authorized insurance contract" );
        totalActiveCover += _newCoverAmount;
        emit ActiveCoverUpdated(totalActiveCover);
    }

    // execute a policy payout to a claimant, only callable by insurance contract
    function executePayout (address payale _recipient, uint256 _amount) public {
        require(msg.sender == depegInsuranceNFT, "Only insurance contract can call this");
        require(address(this).balance >= _amount, "Pool has insufficient funds for claim");

        // which policies are claimed and reducing totalActiveCover elsewhere
        //https://docs.soliditylang.org/en/latest/contracts.html

        (bool success, ) = _recipient.call{value: _amount}{""};
        require(success, "Payout transfer failed");
        emit PolicyClaimPaid(_recipient, _amount);
    }


    // active policy expires without a claim
    function reduceActiveCover (uint256 _expiredCoverAmount) public {
        require(msg.sender == depegInsuranceNFT, "Caller not authorized insurance contract");
        require (totalActiveCover >= _expiredCoverAmount, "Underflow: active cover is less than expired amount");

        totalActiveCover -= _expiredCoverAmount;
        emit ActiveCoverUpdated(totalActiveCover);
    }


}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StakeERC20 {

    IERC20 public token;

    // Multiple User can stake.
    /**
    * stakes => [user][amount, duration, interest]
    */

    uint256 constant public MAX_DURATION = 60; // in days
    uint256 constant public DAYS_IN_YEAR = 365;
    uint256 constant public FIXED_RATE = 10; // RATE IN PERCENTAGE

    constructor (address _token) {
        require(_token != address(0), "Token address cannot be zero");
        token = IERC20(_token);
    }

    struct Stake {
        address _address;
        uint256 amount;
        uint256 endTime;
        uint256 expectedInterest;
        bool isComplete;
    }
    Stake[] stakes;
    mapping (address => Stake[]) userStakes;

    function stake(uint256 _amount) external {
        require(msg.sender != address(0), "Address zero detected");
        require(_amount > 0, "Amount must be greater than zero");
        require(token.allowance(msg.sender, address(this)) >= _amount, "Insufficient token allowance");

        // Transfer tokens to this contract
        token.transferFrom(msg.sender, address(this), _amount);

        // Calculate estimated reward for the user 
        Stake memory newStake = Stake({
            _address: msg.sender,
            amount: _amount,
            endTime: block.timestamp + MAX_DURATION * 1 days,
            expectedInterest: calculateInterest(_amount, FIXED_RATE, MAX_DURATION),
            isComplete: false
        });

        stakes.push(newStake);
        userStakes[msg.sender].push(newStake);
    }

    // Claim reward
    function claimReward(uint256 _index) external {
        Stake storage selectedStake = userStakes[msg.sender][_index];
        require(selectedStake.expectedInterest > 0, "No valid stake at the selected index");
        require(block.timestamp > selectedStake.endTime, "Stake is still ongoing");
        require(!selectedStake.isComplete, "Stake already completed");
        require(token.balanceOf(address(this)) >= selectedStake.expectedInterest, "Contract does not have enough funds");

        selectedStake.isComplete = true;
        
        // Transfer the staked amount plus interest to the user
        token.transfer(msg.sender, selectedStake.expectedInterest);
    }

    function getAllUserStakes(address _address) external view returns (Stake[] memory) {
        require(msg.sender != address(0), "Address zero detected.");
        require(userStakes[_address].length > 0, "User not found.");
        return userStakes[_address];
    }

    function calculateInterest(uint256 principal, uint256 rate, uint256 daysStaked) public pure returns (uint256) {
        // Simple interest formula: Interest = P * r * t
        // Where r = interestRate / 100 and t = daysStaked / DAYS_IN_YEAR
        uint256 timeInYears = daysStaked * 1e18 / DAYS_IN_YEAR; // Converting to wei for precision
        uint256 interest = (principal * rate * timeInYears) / (100 * 1e18); // Calculating interest
        return principal + interest;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenTimeLock is Ownable {
    event TokensLocked(
        uint256 amount,
        uint256[] releaseAmount,
        uint256[] releaseTimes
    );
    event TokensReleased(uint256 amount);

    address public token;
    uint256 public amount;
    uint256[] public releaseAmount;
    uint256[] public releaseTimes;

    uint256 public erc20Released;

    constructor(
        address token_,
        uint256 amount_,
        uint256[] memory releaseAmount_,
        uint256[] memory releaseTimes_
    ) Ownable(msg.sender) {
        require(token_ != address(0), "Token is the zero address");
        require(amount_ > 0, "Total amount should be greater than 0");
        require(
            releaseTimes_.length > 0,
            "Release time must more than release time"
        );
        require(
            releaseAmount_.length == releaseTimes_.length,
            "Mixmatched length"
        );

        require(
            releaseTimes_[0] > block.timestamp,
            "Release time must be in the future"
        );
        {
            uint256 releaseAmountIndex;
            for (uint8 i = 1; i < releaseTimes_.length; i++) {
                require(
                    releaseTimes_[i] > releaseTimes_[i - 1],
                    "Release times must be in ascending order and unique."
                );
                releaseAmountIndex += releaseAmount_[i];
            }
            require(
                releaseAmountIndex == amount_,
                "Total released amount must be equal to the total locked token amount"
            );
        }

        token = token_;
        amount = amount_;
        releaseAmount = releaseAmount_;
        releaseTimes = releaseTimes_;

        emit TokensLocked(amount_, releaseAmount_, releaseTimes_);
    }

    function release() public onlyOwner {
        uint256 releasable = canReleaseAmount();
        releaseSome(releasable);
    }

    function releaseSome(uint256 releaseNow) public onlyOwner {
        uint256 releasable = canReleaseAmount();
        require(
            releasable >= releaseNow,
            "Releasable should be greater than releable amount"
        );
        erc20Released += releaseNow;
        emit TokensReleased(releaseNow);
        IERC20(token).transfer(msg.sender, releaseNow);
    }

    function releaseTo(address receiver) public onlyOwner {
        uint256 releasable = canReleaseAmount();
        releaseSomeTo(releasable, receiver);
    }

    function releaseSomeTo(uint256 releaseNow, address receiver)
        public
        onlyOwner
    {
        uint256 releasable = canReleaseAmount();
        require(
            releasable >= releaseNow,
            "Releasable should be greater than releable amount"
        );
        erc20Released += releaseNow;
        emit TokensReleased(releaseNow);
        IERC20(token).transfer(receiver, releaseNow);
    }

    function batchreleaseTo(
        uint256[] memory releaseAmounts,
        address[] memory receivers
    ) public onlyOwner {
        uint256 releasable = canReleaseAmount();
        require(
            releaseAmounts.length > 0,
            "Release time must more than release time"
        );
        require(releaseAmounts.length == receivers.length, "Mixmatched length");
        uint256 releaseAmountIndex;
        for (uint8 i = 1; i < releaseAmounts.length; i++) {
            releaseAmountIndex += releaseAmounts[i];
        }
        require(
            releaseAmountIndex <= releasable,
            "Total released amount must be less than the total releasable token amount"
        );

        erc20Released += releaseAmountIndex;
        emit TokensReleased(releaseAmountIndex);
        for (uint8 i = 1; i < releaseAmounts.length; i++) {
            IERC20(token).transfer(receivers[i], releaseAmounts[i]);
        }
    }

    function canReleaseAmount() public view returns (uint256) {
        return calReleaseAmount(uint256(block.timestamp));
    }

    function calReleaseAmount(uint256 timestamp) public view returns (uint256) {
        if (timestamp < releaseTimes[0]) {
            return 0;
        }
        if (timestamp >= releaseTimes[releaseTimes.length - 1]) {
            return IERC20(token).balanceOf(address(this));
        }
        uint256 releaseNum = 0;
        uint256 releableAmount = 0;
        for (uint8 i = 0; i < releaseTimes.length; i++) {
            if (timestamp >= releaseTimes[i]) {
                releableAmount += releaseAmount[i];
                if (releableAmount >= erc20Released) {
                    releaseNum = releableAmount - erc20Released;
                }
                if (releaseNum > 0) {
                    uint256 balance = IERC20(token).balanceOf(address(this));
                    if (releaseNum > balance) {
                        releaseNum = balance;
                    }
                }
            } else {
                break;
            }
        }
        return releaseNum;
    }
}

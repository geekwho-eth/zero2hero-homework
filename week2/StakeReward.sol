//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract GeekLiquidityMining is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    // GEEK Token合约地址
    IERC20 public geekToken;
    // GREWARD Token合约地址
    IERC20 public grewardToken;
    // 年化利率
    uint256 public constant annualInterest = 42;
    // 区块时间（秒）
    uint256 public constant BLOCK_TIME = 13;
    // 1年的区块数量
    uint256 public constant BLOCKS_PER_YEAR = (365 * 24 * 60 * 60) / BLOCK_TIME;

    struct UserInfo {
        uint256 amount; // 用户存入的GEEK代币数量
        uint256 rewardDebt; // 用户应得奖励的补偿
    }

    // 用户信息映射
    mapping(address => UserInfo) public userInfo;
    uint256 public totalDeposited; // 总存款量
    uint256 public accRewardPerShare; // 每股累积奖励
    uint256 public lastRewardBlock; // 上次计算奖励的区块

    constructor(IERC20 _geekToken, IERC20 _grewardToken) {
        geekToken = _geekToken;
        grewardToken = _grewardToken;
        lastRewardBlock = block.number;
    }

    // 更新奖励池
    function updatePool() public {
        if (block.number <= lastRewardBlock) {
            return;
        }
        if (totalDeposited == 0) {
            lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = block.number - lastRewardBlock;
        uint256 reward = ((annualInterest / 100) * multiplier) /
            BLOCKS_PER_YEAR;
        accRewardPerShare += (reward * 1e12) / totalDeposited;
        lastRewardBlock = block.number;
    }

    // 用户存款
    function deposit(uint256 _amount) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        updatePool();
        if (user.amount > 0) {
            uint256 pending = (user.amount * accRewardPerShare) /
                1e12 -
                user.rewardDebt;
            if (pending > 0) {
                grewardToken.transfer(msg.sender, pending);
            }
        }
        if (_amount > 0) {
            geekToken.transferFrom(msg.sender, address(this), _amount);
            user.amount += _amount;
            totalDeposited += _amount;
        }
        user.rewardDebt = (user.amount * accRewardPerShare) / 1e12;
        emit Deposit(msg.sender, _amount);
    }

    // 用户提款
    function withdraw(uint256 _amount) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "withdraw: not enough balance");
        updatePool();
        uint256 pending = user.amount.mul(accRewardPerShare).div(1e12).sub(
            user.rewardDebt
        );
        if (pending > 0) {
            grewardToken.transfer(msg.sender, pending);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            totalDeposited = totalDeposited.sub(_amount);
            geekToken.transfer(msg.sender, _amount);
        }
        user.rewardDebt = user.amount.mul(accRewardPerShare).div(1e12);
        emit Withdraw(msg.sender, _amount);
    }

    // 领取奖励
    function claimReward() external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        updatePool();
        uint256 pending = user.amount.mul(accRewardPerShare).div(1e12).sub(
            user.rewardDebt
        );
        if (pending > 0) {
            grewardToken.transfer(msg.sender, pending);
        }
        user.rewardDebt = user.amount.mul(accRewardPerShare).div(1e12);
        emit RewardClaimed(msg.sender, pending);
    }

    // 设置奖励代币
    function setRewardToken(IERC20 _grewardToken) external onlyOwner {
        grewardToken = _grewardToken;
    }

    // 查看待领奖励
    function pendingReward(address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 _accRewardPerShare = accRewardPerShare;
        if (block.number > lastRewardBlock && totalDeposited != 0) {
            uint256 multiplier = block.number.sub(lastRewardBlock);
            uint256 reward = ((annualInterest / 100) * multiplier) /
                BLOCKS_PER_YEAR;
            _accRewardPerShare = _accRewardPerShare.add(
                reward.mul(1e12).div(totalDeposited)
            );
        }
        return
            user.amount.mul(_accRewardPerShare).div(1e12).sub(user.rewardDebt);
    }

    // 紧急提款
    function emergencyWithdraw() external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        totalDeposited = totalDeposited.sub(amount);
        geekToken.transfer(msg.sender, amount);
        emit EmergencyWithdraw(msg.sender, amount);
    }

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);
    event EmergencyWithdraw(address indexed user, uint256 amount);
}

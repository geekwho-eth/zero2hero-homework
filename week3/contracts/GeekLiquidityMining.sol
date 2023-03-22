// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract GeekLiquidityMining is Ownable, ReentrancyGuard {
    using SafeERC20 for ERC20;

    // 存款事件
    event Deposit(address indexed user, uint256 amount);
    // 提现事件
    event Withdraw(address indexed user, uint256 amount);
    // 紧急提款事件
    event EmergencyWithdraw(address indexed user, uint256 amount);

    // 质押代币合约地址
    ERC20 public stakeToken;
    // 奖励代币合约地址
    ERC20 public rewardToken;

    // 单池是否限制用户质押数量的开关
    bool public userLimit;
    // 单个用户最多可质押数量
    uint256 public poolLimitPerUser;
    // 限制用户质押数量的区块数，当前区块数>开始区块数+限制质押区块数，不再限制用户质押数量
    uint256 public numberBlocksForUserLimit;
    // 每个质押代币可获取的奖励
    uint256 public accRewardPerShare;
    //  每个区块奖励代币的数量
    uint256 public rewardPerBlock;
    // 精度因子，方便换算，减少精度转换损失。
    uint256 public PRECISION_FACTOR;
    // 最新计算奖励的区块
    uint256 public lastRewardBlock;
    // 开始奖励的区块值
    uint256 public startBlock;
    // 奖励截止的区块值
    uint256 public endBlock;

    struct UserInfo {
        uint256 amount; // 用户存入的质押代币数量
        uint256 rewardDebt; // 用来记录用户已经计算过的奖励
    }

    // 用户质押信息映射
    mapping(address => UserInfo) public userInfo;

    /**
     * @notice 合约初始化
     * @param _stakeToken 质押合约地址
     * @param _rewardToken 奖励代币合约地址
     * @param _startBlock  开始区块编号
     * @param _endBlock 结束区块编号
     * @param _rewardPerBlock 每区块奖励数
     * @param _poolLimitPerUser 每个用户限制质押数量
     * @param _numberBlocksForUserLimit 限制质押数量的区块数
     */
    constructor(
        ERC20 _stakeToken,
        ERC20 _rewardToken,
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _rewardPerBlock,
        uint256 _poolLimitPerUser,
        uint256 _numberBlocksForUserLimit
    ) {
        stakeToken = _stakeToken; // 设置质押合约地址
        rewardToken = _rewardToken; // 设置奖励代币合约地址
        lastRewardBlock = block.number; // 记录最新的区块
        startBlock = _startBlock; // 设置开始时间
        endBlock = _endBlock; // 设置结束时间
        rewardPerBlock = _rewardPerBlock; // 每区块奖励数
        poolLimitPerUser = _poolLimitPerUser; // 每个用户限制质押数量
        numberBlocksForUserLimit = _numberBlocksForUserLimit; // 限制质押数量的区块数
        uint256 decimalsRewardToken = uint256(rewardToken.decimals());
        require(decimalsRewardToken < 30, "Must be less than 30");
        PRECISION_FACTOR = uint256(10 ** (uint256(30) - decimalsRewardToken)); // 初始化精度因子
        lastRewardBlock = startBlock; // 设置开始奖励的区块编号
    }

    /**
     * 更新奖励池
     */
    function _updatePool() internal {
        // 1. 已经计算的区块，不需要再次计算
        // 2. 最新区块比 已计算区块还小，可能出现分叉或回滚，也不再计算。
        if (block.number <= lastRewardBlock) {
            return;
        }
        // 获取当前已质押的代币的数量
        uint256 totalDeposited = stakeToken.balanceOf(address(this));
        if (totalDeposited == 0) {
            lastRewardBlock = block.number;
            return;
        }
        // 待奖励区块数=最新区块编号-上一次已奖励的区块编号
        uint256 multiplier = _getMultiplier(lastRewardBlock, block.number);
        // 待奖励的代币数=待奖励的区块数*每区块奖励数
        uint256 totalReward = multiplier * rewardPerBlock;
        // 更新每个质押代币的累积奖励，这里把结果*精度因子，后续计算需还原回来。
        accRewardPerShare =
            accRewardPerShare +
            (totalReward * PRECISION_FACTOR) /
            totalDeposited;
        lastRewardBlock = block.number;
    }

    // 获取需要计算奖励的区块数
    function _getMultiplier(
        uint256 _from,
        uint256 _to
    ) internal view returns (uint256) {
        if (_to <= endBlock) {
            // 在开始和结束之间
            return _to - _from;
        } else if (_from >= endBlock) {
            // 已结束
            return 0;
        } else {
            return endBlock - _from;
        }
    }

    /**
     * @notice 用户质押获得奖励
     * @param _amount 质押的数量
     */
    function deposit(uint256 _amount) external nonReentrant {
        require(_amount > 0, "deposit: invalid amount");
        UserInfo storage user = userInfo[msg.sender];
        _updatePool();
        // 用户再次质押，需先计算之前的奖励
        if (user.amount > 0) {
            uint256 pending = (user.amount * accRewardPerShare) /
                PRECISION_FACTOR -
                user.rewardDebt;
            if (pending > 0) {
                rewardToken.safeTransfer(address(msg.sender), pending);
            }
        }
        // 累加用户的质押数量
        user.amount = user.amount + _amount;
        stakeToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
        // 记录用户已计算过的奖励
        user.rewardDebt = (user.amount * accRewardPerShare) / PRECISION_FACTOR;
        // 发送事件
        emit Deposit(msg.sender, _amount);
    }

    /**
     * 用户提款
     * @param _amount 提取的数量，当传入0，就是提取未领取的奖励。
     */
    function withdraw(uint256 _amount) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "withdraw: not enough balance");
        // 更新奖励份额
        _updatePool();
        // 先计算待奖励的数量
        uint256 pending = (user.amount * accRewardPerShare) /
            PRECISION_FACTOR -
            user.rewardDebt;
        // 提取指定数量
        if (_amount > 0) {
            user.amount = user.amount - _amount;
            stakeToken.safeTransfer(address(msg.sender), _amount);
        }
        // 发送待领取的奖励
        if (pending > 0) {
            rewardToken.safeTransfer(address(msg.sender), pending);
        }
        // 更新用户已计算的奖励
        user.rewardDebt = (user.amount * accRewardPerShare) / PRECISION_FACTOR;
        emit Withdraw(msg.sender, _amount);
    }

    // ----- 合约控制逻辑 ----- //

    /*
     * @notice 停止奖励代币
     * @dev 只能被所有者调用
     */
    function stopReward() external onlyOwner {
        endBlock = block.number;
    }

    /*
     * @notice 更新开始和结束时间
     * @dev 只能被所有者调用
     */
    function updateStartAndEndBlocks(
        uint256 _startBlock,
        uint256 _endBlock
    ) external onlyOwner {
        require(block.number < startBlock, "Pool has started");
        require(
            _startBlock < _endBlock,
            "New startBlock must be lower than new endBlock"
        );
        require(
            block.number < _startBlock,
            "New startBlock must be higher than current block"
        );

        startBlock = _startBlock;
        endBlock = _endBlock;

        // Set the lastRewardBlock as the startBlock
        lastRewardBlock = startBlock;
    }

    /*
     * @notice 设置奖励代币合约地址
     * @dev 只能被所有者调用
     */
    function setRewardToken(ERC20 _rewardToken) external onlyOwner {
        require(
            address(_rewardToken) != address(0),
            "ERC20: approve from the zero address"
        );
        rewardToken = _rewardToken;
    }

    /*
     * @notice 查看待领奖励
     * @dev 只能被所有者调用
     */
    function pendingReward(address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 totalDeposited = stakeToken.balanceOf(address(this));
        if (block.number > lastRewardBlock && totalDeposited != 0) {
            uint256 multiplier = _getMultiplier(lastRewardBlock, block.number);
            uint256 totalReward = multiplier * rewardPerBlock;
            // 重新计算这段区块的每个质押代币奖励，同时加上之前的每个质押代币的区块奖励。
            uint256 newTokenPerShare = accRewardPerShare +
                (totalReward * PRECISION_FACTOR) /
                totalDeposited;
            return
                (user.amount * newTokenPerShare) /
                PRECISION_FACTOR -
                user.rewardDebt;
        }
        return
            (user.amount * accRewardPerShare) /
            PRECISION_FACTOR -
            user.rewardDebt;
    }

    /**
     * 紧急提款
     */
    function emergencyWithdraw() external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        stakeToken.safeTransfer(address(msg.sender), amount);

        emit EmergencyWithdraw(msg.sender, amount);
    }
}

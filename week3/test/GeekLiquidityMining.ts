import { ethers } from "hardhat";
import { expect } from "chai";
import { loadFixture, mine } from "@nomicfoundation/hardhat-network-helpers";
//require("@nomicfoundation/hardhat-chai-matchers");

describe("GeekLiquidityMining Test", function () {
  const startBlock = ethers.BigNumber.from("1");
  const endBlock = ethers.BigNumber.from("10000");
  const rewardPerBlock = ethers.BigNumber.from("10");
  const poolLimitPerUser = ethers.BigNumber.from("100");
  const numberBlocksForUserLimit = ethers.BigNumber.from("200");
  // stakeToken rewardToken的精度为18，最小单位为wei。
  const decimals = ethers.BigNumber.from(10).pow(18);

  async function deployTokenFixture() {
    const [dev, alice] = await ethers.getSigners();
    // 实例化依赖的2个合约
    const RewardToken = await ethers.getContractFactory("GeekRewardTestToken");
    const StakeToken = await ethers.getContractFactory("GeekTestToken");
    // 智能合约的构造函数参数通过deploy函数传入
    const stakeToken = await StakeToken.deploy("GEEK Test Token", "GTT");
    const rewardToken = await RewardToken.deploy(
      "GEEK Reward Reward Token",
      "GRTT"
    );

    const StakeReward = await ethers.getContractFactory("GeekLiquidityMining");
    const stakeReward = await StakeReward.deploy(
      stakeToken.address,
      rewardToken.address,
      startBlock,
      endBlock,
      rewardPerBlock,
      poolLimitPerUser,
      numberBlocksForUserLimit
    );

    return { dev, alice, stakeReward, stakeToken, rewardToken };
  }

  describe("Deployment", function () {
    it("should have the correct stakeToken and rewardToken", async function () {
      const { dev, stakeReward, stakeToken, rewardToken } = await loadFixture(
        deployTokenFixture
      );

      expect(await stakeReward.stakeToken()).to.equal(stakeToken.address);
      expect(await stakeReward.rewardToken()).to.equal(rewardToken.address);
      expect(await stakeReward.owner()).to.equal(dev.address);
      expect(await stakeReward.startBlock()).to.equal(startBlock);
      expect(await stakeReward.endBlock()).to.equal(endBlock);
      expect(await stakeReward.rewardPerBlock()).to.equal(rewardPerBlock);
      expect(await stakeReward.poolLimitPerUser()).to.equal(poolLimitPerUser);
      expect(await stakeReward.numberBlocksForUserLimit()).to.equal(
        numberBlocksForUserLimit
      );
      expect(await stakeReward.lastRewardBlock()).to.equal(1);
      // 验证stakeToken的总量
      const totalStakeToken = ethers.BigNumber.from(2100).mul(10000);
      const totalSupply = await stakeToken.totalSupply();
      expect(totalSupply).to.equal(totalStakeToken.mul(decimals));
    });
  });

  describe("deposit & withdraw", function () {
    it("transfer alice 100 stake token", async function () {
      const { dev, alice, stakeReward, stakeToken, rewardToken } =
        await loadFixture(deployTokenFixture);
      // 给alice的账户转移100个质押代币
      const amount = ethers.BigNumber.from("100");
      const realAmount = amount.mul(decimals);
      const transferTx = await stakeToken.transfer(alice.address, realAmount);
      const balance = await stakeToken.balanceOf(alice.address);
      expect(balance, "alice balance " + balance).to.equal(realAmount);
      // 实际上从owner账户转移到指定奖励合约地址
      await expect(transferTx)
        .to.emit(stakeToken, "Transfer")
        .withArgs(dev.address, alice.address, realAmount);
    });

    it("alice approve stakeReward contract amount 100", async function () {
      const { dev, alice, stakeReward, stakeToken, rewardToken } =
        await loadFixture(deployTokenFixture);
      // alice授权奖励合约可以转移自己的100个质押代币
      const amount = ethers.BigNumber.from("100");
      const approveTx = await stakeToken
        .connect(alice)
        .approve(stakeReward.address, amount);

      await expect(approveTx)
        .to.emit(stakeToken, "Approval")
        .withArgs(alice.address, stakeReward.address, amount);

      const allowance = await stakeToken.allowance(
        alice.address,
        stakeReward.address
      );
      expect(allowance.toString()).to.equal(amount.toString());
    });

    it("transfer 10000 reward token to stakeReward contract", async function () {
      const { dev, alice, stakeReward, stakeToken, rewardToken } =
        await loadFixture(deployTokenFixture);

      // 给奖励合约转移10000个奖励代币
      const totalRewardAmount = ethers.BigNumber.from("10000");
      const transferTx = await rewardToken.transfer(
        stakeReward.address,
        totalRewardAmount
      );
      expect(await rewardToken.balanceOf(stakeReward.address)).to.equal(
        totalRewardAmount
      );
      // 实际上从owner账户转移到指定奖励合约地址
      await expect(transferTx)
        .to.emit(rewardToken, "Transfer")
        .withArgs(dev.address, stakeReward.address, totalRewardAmount);
    });

    /**
     * alice准备质押之前的操作
     * 1. owner给alice转移100个质押代币
     * 2. alice授权奖励合约可以转移alice的100个质押代币
     * 3. owner给奖励合约转移10000个奖励代币
     */
    async function preDepositFixture() {
      const { dev, alice, stakeReward, stakeToken, rewardToken } =
        await loadFixture(deployTokenFixture);
      // 给alice的账户转移100个质押代币
      const amount = ethers.BigNumber.from("100");
      await stakeToken.transfer(alice.address, amount);
      await stakeToken.balanceOf(alice.address);

      // alice授权奖励合约可以转移自己的100个质押代币
      await stakeToken.connect(alice).approve(stakeReward.address, amount);

      // 给奖励合约转移10000个奖励代币
      const totalRewardAmount = ethers.BigNumber.from("10000");
      await rewardToken.transfer(stakeReward.address, totalRewardAmount);
      return { dev, alice, stakeReward, stakeToken, rewardToken };
    }

    it("alice deposit 100 stake token", async function () {
      const { dev, alice, stakeReward, stakeToken, rewardToken } =
        await loadFixture(preDepositFixture);

      const allowance = await stakeToken.allowance(
        alice.address,
        stakeReward.address
      );
      const amount = ethers.BigNumber.from("100");
      expect(allowance.toString(), "real approve amount " + allowance).to.equal(
        amount.toString()
      );

      // alice给奖励合约质押100个代币
      const depositTx = await stakeReward.connect(alice).deposit(amount);
      // 验证合约的Deposit事件
      await expect(depositTx)
        .to.emit(stakeReward, "Deposit")
        .withArgs(alice.address, amount);

      const userInfo = await stakeReward.userInfo(alice.address);
      expect(userInfo.amount.toString()).to.equal(amount.toString());
    });

    /**
     * alice准备质押之前的操作
     * 1. owner给alice转移100个质押代币
     * 2. alice授权奖励合约可以转移alice的100个质押代币
     * 3. owner给奖励合约转移10000个奖励代币
     * 4. alice质押100个代币
     */
    async function preWithdrawFixture() {
      const { dev, alice, stakeReward, stakeToken, rewardToken } =
        await loadFixture(deployTokenFixture);
      // 给alice的账户转移100个质押代币
      const amount = ethers.BigNumber.from("100");
      await stakeToken.transfer(alice.address, amount);
      await stakeToken.balanceOf(alice.address);

      // alice授权奖励合约可以转移自己的100个质押代币
      await stakeToken.connect(alice).approve(stakeReward.address, amount);

      // 给奖励合约转移10000个奖励代币
      const totalRewardAmount = ethers.BigNumber.from("10000");
      await rewardToken.transfer(stakeReward.address, totalRewardAmount);

      // alice给奖励合约质押100个代币
      await stakeReward.connect(alice).deposit(amount);

      return { dev, alice, stakeReward, stakeToken, rewardToken };
    }

    it("after 100 block number, alice claim reward ,just call withdraw amount=0", async function () {
      const { dev, alice, stakeReward, stakeToken, rewardToken } =
        await loadFixture(preWithdrawFixture);
      // ，
      /**
       * 1. 等待100个区块后，最后在withdraw调用时计算会多一个区块。这是hardhat默认算法。
       * 2. 这里为了计算方便，延迟99个区块,hardhat自动会加一个区块，最后实际计算是100个区块。
       */
      await mine(99);
      // 提取奖励
      const zeroAmount = ethers.BigNumber.from("0");
      const withdrawTx = await stakeReward.connect(alice).withdraw(zeroAmount);
      /**
       * 待领取奖励计算逻辑如下：
       * 1. 先计算每个质押代币的收益份额，全部存入质押代币数量为100.待奖励区块数为100个。
       * 2. 待奖励代币数量=待奖励的区块数*每区块奖励数（rewardPerBlock） = 100 * 10） = 1000。
       * 3. 每个质押代币累计奖励份额（质押1个代币可获取奖励代币数量）=待奖励代币数量*精度因子（1**12）/ 全部质押数量= 1**13。
       * 4. 用户待领取奖励=100*1**13/1**12=1000。
       * 5. 用户领取后，已领取奖励数量为1000
       */
      const rewardAmount = ethers.BigNumber.from("1000");
      await expect(withdrawTx)
        .to.emit(stakeReward, "Withdraw")
        .withArgs(alice.address, zeroAmount)
        .to.emit(rewardToken, "Transfer")
        .withArgs(stakeReward.address, alice.address, rewardAmount);

      const amount = ethers.BigNumber.from("100");
      const totalRewardAmount = ethers.BigNumber.from("10000");

      // const leftReward = await rewardToken.balanceOf(stakeReward.address);
      // 检查用户拿到的奖励代币数量：1000
      expect(await rewardToken.balanceOf(alice.address)).to.equal(rewardAmount);

      // 检查用户已计算的奖励：1000
      const rewardUserInfo = await stakeReward.userInfo(alice.address);
      expect(rewardUserInfo.amount).to.equal(amount);
      expect(rewardUserInfo.rewardDebt).to.equal(rewardAmount);

      // 奖励合约剩余奖励代币数量：10000 - 1000 = 9000
      const left = ethers.BigNumber.from(totalRewardAmount - rewardAmount);
      expect(await rewardToken.balanceOf(stakeReward.address)).to.equal(left);

      // 检查每个质押代币可领取的奖励代币数量：10**13
      const share = ethers.BigNumber.from("10000000000000");
      const stakeShare = await stakeReward.accRewardPerShare();
      expect(stakeShare).to.equal(share);
    });
  });
});

# week3 课后作业
题目：
使用hardhat来完成流动性挖矿合约

要求：
1. 逻辑和course2中介绍一致。
2. 用hardhat完成合约测试。
3. 在localhost和bnbtest两个网络完成部署
4. 使用脚本或任务完成和合约常见的交互（stake、unstake、harvest等）

解答：
新增3个不同的合约代码：
1. GeekLiquidityMining.sol。单币质押挖矿合约。实现上参考pancakeswap的[ID合约挖矿代码](https://bscscan.com/address/0x7accc054bb199ca976c95aee495c9888f566aaaa#code)。
2. GeekRewardTestToken.sol。奖励代币合约，名称：Geek Reward Test Token，代币符号：GRTT，发行量1000万。
3. GeekTestToken.sol。质押代币合约。名称：Geek Test Token，代币符号：GTT，发行量2100万。

部署流程：
1. 部署奖励代币合约GeekTestToken，得到合约地址A。
2. 部署质押代币合约GeekRewardTestToken，得到合约地址B。
3. 部署挖矿合约GeekLiquidityMining，初始化参数按照以下格式传入：
```
_STAKETOKEN：合约地址B
_REWARDTOKEN：合约地址A
_STARTBLOCK：28436092
_ENDBLOCK：30000000
_REWARDPERBLOCK：100000000000000000（每个区块奖励0.1个GRTT，注意这里GRTT的精度为18，所以值=0.1*10**18。）
_POOLLIMITPERUSER: 100000000000000000000 （100个，实际需转为18位精度的数值）
_NUMBERBLOCKSFORUSERLIMIT: 10000（10000个区块后，不再限制用户存入。）

```
得到合约地址C。

4. 用owner地址转账100个质押代币GTT给测试账户A。
5. 测试账户A授权合约地址C可以转移自己的GTT数量为100个。
6. 用owner给质押合约转移1000个奖励代币GRTT。
7. 测试账户A在挖矿合约存入100个GTT，开始获得奖励。
8. 等待100个区块，进行提取奖励。

相关交易ID：
1. [部署质押代币合约](https://testnet.bscscan.com/tx/0xfb9847d34bc8f77f17dcfe83906e7985677c66ebd252ace53928fd1edb34b20f)
2. [部署奖励代币合约](https://testnet.bscscan.com/tx/0x8aa1eb0509924000bed65aca788f182cfab74422d69dd01623ed2687f92968a4)
3. [owner转移100个GTT给测试账户](https://testnet.bscscan.com/tx/0x40047405bfcc92c33b00e2805a880b7755cb4d3cba3f73bb436cddf56539324d)
4. [部署单币质押合约](https://testnet.bscscan.com/tx/0xe29ddd39fd9fce9aa3e5ed3549aa136b8cab3e6b377b551eb6d8cb96cf8236ad)
4. [测试账户授权单币质押挖矿合约可以转移100个GTT](https://testnet.bscscan.com/tx/0xe53ec4c915080c69f38b0ed1d4aad836f8db8f00f432c4572e7b3ad6f5d05138)
6. [owner给质押合约转移1000个奖励代币GRTT](https://testnet.bscscan.com/tx/0xd770df7f88a397055335547199c283fc2e291bffa711f355b40953f02b327301)
7. [测试账户质押100个GTT](https://testnet.bscscan.com/tx/0xc7a58858cd2d5a3e1db5f6ccaf47deee22f02637aea5a93ce2ea5e4740063a82)
8. [测试账户提取奖励](https://testnet.bscscan.com/tx/0x4b466cdec1f0f7f8799703690e4cd689421445e2d92ddb243f6b1c19a6e52df0)
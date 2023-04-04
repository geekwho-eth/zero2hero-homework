# week4 课后作业
题目：
使用hardhat在BNB TestNet部署一套可升级的代理合约，至少包含常量、状态变量以及读写状态变量相关函数。

要求：
1. 合约在浏览器中完成验证、可以调用到逻辑合约的函数。
2. 合约进行初始化设置。
3. 合约完成一次升级，可升级常量值和函数逻辑，并正常运行。
4. 使用脚本或任务完成和合约常见的交互

解答：
新增3个不同的合约代码：
1. UUPSProxy.sol。代理合约，用户直接交互的合约。
2. UUPSProxiable.sol。基础可继承的实现合约。
3. logicImpl1.sol。业务逻辑实现合约1。
3. logicImpl2.sol。业务逻辑实现合约2。

部署&验证流程：
1. 先部署业务逻辑合约1，得到合约地址A.
2. 再部署代理合约，初始化填入合约地址A，部署成功后得到合约地址B。
3. 部署业务逻辑合约2，得到合约地址C
4. 在合约B调用setWord函数，选择器为：0x1d18fc88。在calldata填入参数：0x1d18fc88，点击Transact执行。检查当前代理合约的相关状态值：
implementation=0x0F6D3ef44875C556bc8b93438Ea73d7183311465
words=logicImpl1
5. 修改代理合约指向到合约地址C。在合约B调用选择器，calldata填入参数0x0900f01000000000000000000000000003c0280e58f3f8d444f2308260b6bcf8196a163d，点击点击Transact执行。
检查代理合约状态值：
implementation=0x03c0280e58f3f8d444f2308260b6bcf8196a163d
6. 在合约B调用setWord函数。检查代理合约状态变量的值：
implementation=0x03c0280e58f3f8d444f2308260b6bcf8196a163d
words=logicImpl2

hashex使用：
1. 打开地址：https://abi.hashex.org/
2. 选择your function。
3. 函数名填入：upgrade。选择Add argument添加参数，选择address类型。
填入上面部署得到的合约地址A：0x0F6D3ef44875C556bc8b93438Ea73d7183311465
4. 计算出值：0900f0100000000000000000000000000f6d3ef44875c556bc8b93438ea73d7183311465
5. 填入地址参数改为合约C的地址：0x03c0280e58f3f8d444f2308260b6bcf8196a163d。
6. 计算出值：0900f01000000000000000000000000003c0280e58f3f8d444f2308260b6bcf8196a163d


相关交易ID：
1. [部署合约logicImpl1](https://testnet.bscscan.com/tx/0xfa85599b6ad62c7a3a642bcbe95ed2088e2d9919b72a1da5b970f3defcb67657)
2. [部署代理合约UUPSProxy](https://testnet.bscscan.com/tx/0xade4d165f8165ef14ccdb7b6b851f04797603dfe7e466b4d69d928a192bd414b)
3. [部署合约logicImpl2](https://testnet.bscscan.com/tx/0x4ea5a6279a3af8441a02524c9e94e99dddc9f18b8c707ab46ea43a2bb86d1912)
4. [调用合约logicImpl1的setWord函数](https://testnet.bscscan.com/tx/0xfe9bfecb719d2f8cbd34a886664c9e5bc83b9f638e6e81570f1a4a20f8aae18c)
5. [设置代理到logicImpl2](https://testnet.bscscan.com/tx/0x858db353688a369874167628d0f28bf090093a74bf7061620bfcefd1ecc396b4)
6. [调用合约logicImpl2的setWord函数](https://testnet.bscscan.com/tx/0x59cb1b299081881ad4bc8caae3fd625af91a4e025b5b3cce0fdd80d8b5902542)

总结：
1. 上面这个简单的UUPS只是示例，不建议应用到生产环境。因为如果设置代理到特定的合约时，如果目标合约没有upgrade函数，很容易就把合约升级为"死合约"。因为实现业务逻辑的合约没有upgrade函数，无法再次升级。通用结局方案，可以把升级函数放在代理合约里。
2. 增加状态变量，建议按照顺序增加，不允许修改原有的状态变量申请，不允许修改状态变量声明的顺序。EVM按照申请顺序记录变量solt的插槽位置，有任何不一致会导致变量被覆盖的问题。
3. 另外一个问题，无法调用实现合约的构造函数，通用解决方案是新增initialize函数单独初始化。
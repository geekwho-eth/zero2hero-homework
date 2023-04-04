// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract UUPSProxy {
    // 定义实现合约地址状态变量
    address public implementation;
    // 定义管理员地址
    address public admin;
    string public words; // 字符串，可以通过逻辑合约的函数改变

    // 构造函数，初始化admin和逻辑合约地址
    constructor(address _implementation) {
        admin = msg.sender;
        implementation = _implementation;
    }

    // fallback函数，将调用委托给逻辑合约
    fallback() external payable {
        (bool success, ) = implementation.delegatecall(msg.data);
        require(success, "Call failed");
    }

    // 修复告警
    receive() external payable {}
}

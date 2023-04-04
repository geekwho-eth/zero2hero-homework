// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// 可代理的UUPS合约，实现逻辑合约直接继承该合约
abstract contract UUPSProxiable {
    // 定义实现合约地址状态变量
    address public implementation;
    // 定义管理员地址
    address public admin;

    // UUPS合约通用升级函数，先检查权限，再设置实现逻辑合约地址
    // 函数选择器：
    function upgrade(address newImplementation) external {
        require(msg.sender == admin);
        implementation = newImplementation;
    }
}

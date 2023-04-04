// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./UUPSProxiable.sol";

// UUPS逻辑合约（升级函数写在逻辑合约内）
contract logicImpl1 is UUPSProxiable {
    string public constant VERSION = "1.0.0";
    // 定义字符串变量
    string public words;

    // 改变proxy中状态变量
    function setWords() public {
        words = "logicImpl1";
    }
}

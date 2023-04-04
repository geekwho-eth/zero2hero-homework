// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./UUPSProxiable.sol";

// 新的UUPS逻辑合约
contract logicImpl2 is UUPSProxiable {
    string public constant VERSION = "1.0.1";
    // 定义字符串变量
    string public words;

    // 改变proxy中状态变量
    function setWords() public {
        words = "logicImpl2";
    }
}

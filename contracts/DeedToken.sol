// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";



contract DeedToken is ERC20 {
    constructor() ERC20("DT","DeedToken") {
        _mint(0x70997970C51812dc3A010C7d01b50e0d17dc79C8, 100 );
        _mint(0x90F79bf6EB2c4f870365E785982E1f101E93b906, 100 );
    }
}
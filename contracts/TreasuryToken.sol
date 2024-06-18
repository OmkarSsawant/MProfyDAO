// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";



contract TreasuryToken is ERC20 {
    constructor() ERC20("TT","TreasuryToken") {
        _mint(0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC, 100);
        _mint(0x90F79bf6EB2c4f870365E785982E1f101E93b906, 100);
    }
}
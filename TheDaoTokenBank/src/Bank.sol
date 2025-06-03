// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;



// 编写一个 Bank 合约，实现功能：
// 可以通过 Metamask 等钱包直接给 Bank 合约地址存款
// 在 Bank 合约记录每个地址的存款金额
// 编写 withdraw() 方法，仅管理员可以通过该方法提取资金。
// 用数组记录存款金额的前 3 名用户

contract Bank{
    address public gov;
    mapping (address=>uint256) public balances;

    struct Depositor{
        address addr;
        uint amount;
    }

    Depositor[3] public topDepositors;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed recipient, uint256 amount);

    constructor(address _gov) payable {
        gov = _gov;
    }

    function transferGovernance(address newGov) external onlyGov {
        gov = newGov;
    }

    modifier onlyGov(){
        require(gov == msg.sender,"Not gov");
        _;
    }

    // Receive ETH deposits
    receive() external payable {
        require(msg.value > 0, "Must send ETH");
        balances[msg.sender] += msg.value;
        _updateTopDepositors(msg.sender, balances[msg.sender]);
        emit Deposited(msg.sender, msg.value);
    }

    // Explicit deposit function
    function deposit() external payable {
        require(msg.value > 0, "Must send ETH");
        balances[msg.sender] += msg.value;
        _updateTopDepositors(msg.sender, balances[msg.sender]);
        emit Deposited(msg.sender, msg.value);
    }

     // Gov合约提款
    function withdraw(uint256 amount, address recipient) external onlyGov {
        require(address(this).balance >= amount, "Insufficient balance");
        (bool success, ) = payable(recipient).call{value: amount}("");
        require(success, "Transfer failed");
        emit Withdrawn(recipient, amount);
    }

    // 更新存款前三名（内部逻辑）
    function _updateTopDepositors(address user, uint256 newAmount) private {
        // 检查是否已在排行榜
        for (uint i = 0; i < 3; i++) {
            if (topDepositors[i].addr == user) {
                topDepositors[i].amount = newAmount;
                _sortDepositors();
                return;
            }
        }

        // 与最后一名比较
        if (newAmount > topDepositors[2].amount) {
            topDepositors[2] = Depositor(user, newAmount);
            _sortDepositors();
        }
    }

    // 冒泡排序算法（降序排列）
    function _sortDepositors() private {
        for (uint i = 0; i < 2; i++) {
            for (uint j = 0; j < 2 - i; j++) {
                if (topDepositors[j].amount < topDepositors[j+1].amount) {
                    Depositor memory temp = topDepositors[j];
                    topDepositors[j] = topDepositors[j+1];
                    topDepositors[j+1] = temp;
                }
            }
        }
    }

}

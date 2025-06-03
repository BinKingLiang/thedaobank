// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
pragma abicoder v2;

import "forge-std/Test.sol";
import "../src/Token.sol";
import "../src/Bank.sol";
import "../src/Gov.sol";

contract DaoBankTest is Test {
    Token public token;
    Bank public bank;
    Gov public gov;
    
    address alice = address(0x1);
    address bob = address(0x2);
    address charlie = address(0x3);

    function setUp() public {
        token = new Token();
        // Create Bank with test contract as temporary gov
        bank = new Bank{value: 0}(address(this));
        // Create Gov with token and bank addresses
        gov = new Gov(address(token), address(bank));
        // Transfer governance from test contract to Gov contract
        bank.transferGovernance(address(gov));
        
        // 分配代币给测试用户并授权Gov合约使用
        vm.prank(address(this));
        token.transfer(alice, 1000 * 10 ** token.decimals());
        vm.prank(address(this));
        token.transfer(bob, 2000 * 10 ** token.decimals());
        vm.prank(address(this));
        token.transfer(charlie, 3000 * 10 ** token.decimals());
        
        // Approve Gov contract to transfer voting tokens
        vm.prank(alice);
        token.approve(address(gov), type(uint256).max);
        
        vm.prank(bob);
        token.approve(address(gov), type(uint256).max);
        
        vm.prank(charlie);
        token.approve(address(gov), type(uint256).max);
    }

    function testCreateProposal() public {
        vm.prank(alice);
        gov.createProposal(1 ether, alice);
        
        (uint256 id, address proposer, uint256 amount, address recipient, uint256 startBlock, uint256 endBlock, uint256 forVotes, uint256 againstVotes, Gov.ProposalState state) = gov.proposals(1);
        assertEq(amount, 1 ether);
        assertEq(forVotes, 0);
        assertEq(againstVotes, 0);
    }

    function testVoteAndExecuteProposal() public {
        // Set token approvals for Gov contract
        vm.prank(alice);
        token.approve(address(gov), type(uint256).max);
        vm.prank(bob);
        token.approve(address(gov), type(uint256).max);
        vm.prank(charlie);
        token.approve(address(gov), type(uint256).max);

        // Deposit ETH to Bank using deposit() function
        vm.deal(alice, 10 ether);
        vm.prank(alice);
        bank.deposit{value: 5 ether}();
        assertEq(address(bank).balance, 5 ether, "Bank should have 5 ether");
        
        // 创建提案
        gov.createProposal(1 ether, alice);
        
        // 投票
        vm.prank(alice);
        gov.vote(1, true);
        
        vm.prank(bob);
        gov.vote(1, false);
        
        vm.prank(charlie);
        gov.vote(1, true);
        
        // 跳过投票期
        vm.roll(block.number + 101);
        
        // 验证投票结果
        (,,,,,,uint256 forVotes, uint256 againstVotes,) = gov.proposals(1);
        assertGt(forVotes, againstVotes, "Proposal should have passed");
        
        // 验证Bank余额
        assertGe(address(bank).balance, 1 ether, "Insufficient bank balance");
        
        // 执行提案
        vm.prank(address(gov)); // 使用Gov合约执行
        gov.executeProposal(1);
        assertEq(address(bank).balance, 4 ether, "Bank should have 4 ether after withdrawal");
        
        // Get just the state from the proposal
        (,,,,,,,, Gov.ProposalState state) = gov.proposals(1);
        assertEq(uint(state), uint(Gov.ProposalState.Executed));
        
        // 检查资金是否转移
        assertEq(alice.balance, 6 ether); // 初始10 - 存款5 + 提款1
    }

    function test_RevertWhen_NotGov() public {
        vm.expectRevert("Not gov");
        bank.withdraw(1 ether, alice);
    }
}

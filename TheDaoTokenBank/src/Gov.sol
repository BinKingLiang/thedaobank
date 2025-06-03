// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./Token.sol";
import "./Bank.sol";

contract Gov {
    address public gov;
    
    modifier onlyGov() {
        require(msg.sender == gov, "Not gov");
        _;
    }

    enum ProposalState { Pending, Active, Executed, Rejected }

    struct Proposal {
        uint256 id;
        address proposer;
        uint256 amount;
        address recipient;
        uint256 startBlock;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        ProposalState state;
    }

    Token public token;
    Bank public bank;
    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;

    event ProposalCreated(uint256 indexed id, address indexed proposer, uint256 amount, address recipient);
    event ProposalExecuted(uint256 indexed id);
    event ProposalRejected(uint256 indexed id);

    constructor(address _token, address _bank) {
        token = Token(_token);
        bank = Bank(payable(_bank));
        gov = msg.sender;
    }

    function createProposal(uint256 amount, address recipient) external {
        proposalCount++;
        proposals[proposalCount] = Proposal({
            id: proposalCount,
            proposer: msg.sender,
            amount: amount,
            recipient: recipient,
            startBlock: block.number,
            endBlock: block.number + 100, // 100 blocks voting period
            forVotes: 0,
            againstVotes: 0,
            state: ProposalState.Active
        });
        emit ProposalCreated(proposalCount, msg.sender, amount, recipient);
    }

    function vote(uint256 proposalId, bool support) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.state == ProposalState.Active, "Proposal not active");
        require(block.number <= proposal.endBlock, "Voting period ended");

        uint256 balance = token.balanceOf(msg.sender);
        require(balance > 0, "No tokens to vote");

        // Transfer 1 token to Gov contract to lock voting power
        token.transferFrom(msg.sender, address(this), 1);

        if (support) {
            proposal.forVotes += 1;
        } else {
            proposal.againstVotes += 1;
        }
    }

    function executeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.state == ProposalState.Active, "Proposal not active");
        require(block.number > proposal.endBlock, "Voting period not ended");

        if (proposal.forVotes > proposal.againstVotes) {
            proposal.state = ProposalState.Executed;
            Bank(payable(address(bank))).withdraw(proposal.amount, proposal.recipient);
            emit ProposalExecuted(proposalId);
        } else {
            proposal.state = ProposalState.Rejected;
            emit ProposalRejected(proposalId);
        }
    }
}

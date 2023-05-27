// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/** 
 * @title Voting
 * @dev Implement the voting contract.
 */
contract Voting is Ownable {

    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }

    struct Proposal {
        string description;
        uint voteCount;
        bool exist;
    }

    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    Proposal[] private proposals; // The proposals. Index are identifiers.
    mapping (address => Voter) private voters; // Map an address to a voter. Can't be duplicated (One address = One Vote).
    WorkflowStatus private votingStatus; // The voting status.
    uint private winningProposalId; // The identifier of the winner proposal.

    event VoterRegistered(address voterAddress); 
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted (address voter, uint proposalId);

    // The constructor, called when contract deployed
    constructor() onlyOwner {
        registerVoter(msg.sender); // The owner is registered.
    }

    // Modifier to check if the caller is registered.
    modifier isRegister(){
        require(voters[msg.sender].isRegistered, "This address is not registered.");
        _;
    }

    // Register address when it's allowed by voting status.
    function registerVoter(address whitelistedAddress) onlyOwner public {
        require(votingStatus == WorkflowStatus.RegisteringVoters, "The registration period is pasted.");
        voters[whitelistedAddress] = Voter(true, false, 0);
        emit VoterRegistered(whitelistedAddress);
    }

    // RegisteringVoters ==> ProposalsRegistrationStarted. Only owner.
    function startProposalsRegistration() onlyOwner external {
        require(votingStatus == WorkflowStatus.RegisteringVoters, "The voting status does not allow to start the registration period.");
        _changeWorkflowStatus(WorkflowStatus.ProposalsRegistrationStarted);
    }

    // ProposalsRegistrationStarted ==> ProposalsRegistrationEnded. Only owner.
    function endProposalsRegistration() onlyOwner external  {
        require(votingStatus == WorkflowStatus.ProposalsRegistrationStarted, "The voting status does not allow to end the registration period.");
        _changeWorkflowStatus(WorkflowStatus.ProposalsRegistrationEnded);
    }

    // ProposalsRegistrationEnded ==> VotingSessionStarted. Only owner.
    function startVotingSession() onlyOwner external {
        require(votingStatus == WorkflowStatus.ProposalsRegistrationEnded, "The voting status does not allow to start the voting session.");
        _changeWorkflowStatus(WorkflowStatus.VotingSessionStarted);
    }

    // VotingSessionStarted ==> VotingSessionEnded. Only owner.
    function endVotingSession() onlyOwner external {
        require(votingStatus == WorkflowStatus.VotingSessionStarted, "The voting status does not allow to end the voting session.");
        _changeWorkflowStatus(WorkflowStatus.VotingSessionEnded);
    }

    // Count the votes and stock the proposal winning the vote. VotingSessionEnded ==> VotesTallied. Only owner.
    function countVotes() onlyOwner external {
        require(votingStatus == WorkflowStatus.VotingSessionEnded, "The voting status does not allow to count the voting session.");
        _countWinner();
        _changeWorkflowStatus(WorkflowStatus.VotesTallied);
    }

    // Add a specific proposal. The sender shloud be registered and the register period should be started.
    function sendProposal(string memory description) isRegister external returns (uint) {
        require(votingStatus == WorkflowStatus.ProposalsRegistrationStarted, "The voting status does not allow to send proposal.");
        proposals.push(Proposal(description, 0, true));
        uint proposalId = proposals.length - 1; // return the proposal identifier. Index of the proposal.
        emit ProposalRegistered(proposalId);
        return proposalId; 
    }

    // Vote for a specific proposal. The sender shloud be registered and the voting period should be started.
    function vote(uint votedProposalId) isRegister external {
        require(votingStatus == WorkflowStatus.VotingSessionStarted, "The voting status does not allow to vote.");
        require(!voters[msg.sender].hasVoted, "This address has already voted.");
        require(proposals[votedProposalId].exist, "This proposal don't exist.");
        voters[msg.sender].hasVoted = true;
        voters[msg.sender].votedProposalId = votedProposalId;
        proposals[votedProposalId].voteCount += 1;
        emit Voted(msg.sender , votedProposalId);
    }

    // Everybody can see the winner when the votes are tallied.
    function getWinner() external view returns (uint) {
        require(votingStatus == WorkflowStatus.VotesTallied, "The voting status does not allow to get the winner.");
        return winningProposalId;
    } 

    // Change the voting status by the owner.
    function _changeWorkflowStatus(WorkflowStatus updatedStatus) onlyOwner private {
        votingStatus = updatedStatus;
        emit WorkflowStatusChange(votingStatus, updatedStatus);
    }

    // Count the poposal winning the vode.
    function _countWinner() private {
        uint proposalWinnerId = 0;
        uint proposalId = 0;

        for (proposalId = 0; proposalId < proposals.length; proposalId++) 
        {
            if (proposals[proposalId].voteCount > proposals[proposalWinnerId].voteCount) {
                proposalWinnerId = proposalId;
            }
        }

        winningProposalId = proposalWinnerId;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./DaobiVoteContract.sol";

/// @custom:security-contact jennifer.dodgson@gmail.com
contract DAObiWithVoting is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, PausableUpgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    //additions to support on-chain election of chancellor: 
    address public chancellor; //the address of the current chancellor

    // the address of the voting contract
    //the voting contract should contain a mapping in which, given an address, the number of votes for that address (if any) can be found
    address public votingContract; 

    //events related to voting
    event ClaimAttempted(address _claimant, uint40 _votes);
    event ClaimSucceeded(address _claimant, uint40 _votes);
    event NewChancellor(address _newChanc);
    event VoteContractChange(address _newVoteScheme);
    event DaobiMinted(uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __ERC20_init("DAObiContract2", "DBT");
        __ERC20Burnable_init();
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _mint(msg.sender, 1000 * 10 ** decimals());
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
    }

    //THIS FUNCTION MUST BE EXECUTED IMMEDIATELY AFTER UPGRADEPROXY() TO POINT TO THE VOTE CONTRACT
    function retargetVoting(address _voteContract) public onlyRole(PAUSER_ROLE) {
        //pauses the contract to prevent minting and claiming after deployment until unpaused        
        votingContract = _voteContract;
        emit VoteContractChange(_voteContract);
        pause();
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function mint(address to, uint256 amount) public whenNotPaused onlyRole(MINTER_ROLE) {
        _mint(to, amount);
        emit DaobiMinted(amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    
    //require holding a voting token
    //check whether the claimant has a higher vote total than the current chancellor.  If they do, set them as current chancellor
    function makeClaim() whenNotPaused public {
        DaobiVoteContract dvc = DaobiVoteContract(votingContract);
        require (dvc.balanceOf(msg.sender) > 0, "Daobi: You don't even have a voting token!");
        require (dvc.checkStatus(msg.sender) == true, "Daobi: You have withdrawn from service!");
        require (dvc.assessVotes(msg.sender) > 0, "Daobi: You need AT LEAST one vote!");
        require (msg.sender != chancellor, "You are already Chancellor!");
        
        if (dvc.checkStatus(chancellor) == false) {
            emit ClaimSucceeded(msg.sender, dvc.assessVotes(msg.sender));
            assumeChancellorship(msg.sender);            
        }
        else if (dvc.assessVotes(msg.sender) > dvc.assessVotes(chancellor)) {
            emit ClaimSucceeded(msg.sender, dvc.assessVotes(msg.sender));
            assumeChancellorship(msg.sender); 
        }
        else {
            emit ClaimAttempted(msg.sender, dvc.assessVotes(msg.sender));
        }
        
    }

    function assumeChancellorship(address _newChancellor) private {
        _revokeRole(MINTER_ROLE, chancellor);
        chancellor = _newChancellor;
        _grantRole(MINTER_ROLE, chancellor);
        emit NewChancellor(chancellor);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(UPGRADER_ROLE)
        override
    {}

}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract DaobiVoteContract is Initializable, ERC20Upgradeable, PausableUpgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    //required information for each voter
    struct Voter {        
        bool serving; //bools are 8 bits, in the future bitmasks can be used to further compress information if needed
        address votedFor; //160 bits
        uint40 votesAccrued; //There should not be more than 2^40 players 
        bytes6 courtName; //six UTF-8 characters -- twice as many as Emperor Qin needed, should be more than enough       
    }

    //maps addresses to their Voter info
    mapping (address => Voter) public voterRegistry;



    //Basic idea: Once someone is verified, they are minted a voting token.  This allows them to (register to) vote, and qualifies them to receive votes.
    //They can vote for anyone, including themselves or 0x0 (i.e., abstain)
    //A voter can make a claim for the chancellorship.  If they have more votes than the current chancellor, this succeeds.
    //The "claiming" logic is done in the Daobi token contract itself.
    //They can choose to recluse (de-register).  A recluse always votes for 0x0 (i.e. nobody).
    //A recluse can still accrue votes.  However, they cannot claim the chancellorship.  
    //If a recluse holds the chancellorship for any reason (e.g. become chancellor, then recluse) then it can be claimed by anyone.
    //If someone burns their DBvt token, they automatically recluse.  They can't be voted for, and will have to re-register if they get a new token.  


    event NewToken(address newDBvt);
    event Registered(address regVoter, bytes6 nickname, address initVote);
    event Reclused(address reclVoter);
    event Voted(address voter, address votee);
    event Burnt(address burnee);
    event SelfBurnt(address burner);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}
    

    function initialize() initializer public {
        __ERC20_init("DaobiVotingToken", "DBvt");
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function mint(address to) public whenNotPaused onlyRole(MINTER_ROLE) {
        require(balanceOf(to) == 0, "DaobiVote: Account already has a token!");
        _mint(to, 1);
        emit NewToken(to);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(UPGRADER_ROLE)
        override
    {}

    //since users should only ever have 1 DBvt, don't use decimals
    function decimals() public view virtual override returns (uint8) {
        return 0;
    }

    //disable token transfers by making any call to transfer auto-revert
    function _transfer(address from, address to, uint256 amount) internal override pure {  
        require(1==0, "DaobiVote: Tokens Are Not Transferrable!");
    }

    //register, the "serve" flag is automatically set and votes are initialized at zero
    //votesAccrued is left alone -- initializes to zero by default
    function register(address _initialVote, bytes6 _name) whenNotPaused public {
        require(balanceOf(msg.sender) > 0, "DaobiVote: You must hold a token to register!");
        require(checkStatus(msg.sender) == false, "DaobiVote: You are already registered!");
        require(balanceOf(_initialVote) > 0 || _initialVote == 0x0000000000000000000000000000000000000000, "DaobiVote: Invalid candidate!");
        
        voterRegistry[msg.sender].serving = true;
        voterRegistry[msg.sender].votedFor = _initialVote;
        voterRegistry[_initialVote].votesAccrued++;
        voterRegistry[msg.sender].courtName = _name;

        emit Registered(msg.sender, _name, _initialVote);
    }


    function recluse() public {
        require(voterRegistry[msg.sender].serving == true, "DaobiVote: Already inactive!"); //bools initialize to false so if someone has never registered or has not token this will also catch them
        voterRegistry[msg.sender].serving = false;
        voterRegistry[voterRegistry[msg.sender].votedFor].votesAccrued--;
        voterRegistry[msg.sender].votedFor = 0x0000000000000000000000000000000000000000;
        emit Reclused(msg.sender);
    }

    function vote(address _voteFor) whenNotPaused public {
        require(balanceOf(msg.sender) > 0, "DaobiVote: You don't have a token!");
        require(voterRegistry[msg.sender].serving == true, "DaobiVote: You're not registered!");
        require(balanceOf(_voteFor) > 0 || _voteFor == 0x0000000000000000000000000000000000000000, "DaobiVote: Invalid candidate!");

        voterRegistry[voterRegistry[msg.sender].votedFor].votesAccrued--;
        voterRegistry[msg.sender].votedFor = _voteFor;
        voterRegistry[_voteFor].votesAccrued++; //it's fine to increment the null address -- will allow someone to see how many are abstaining!  But, I avoided doing so for inactive voters

        emit Voted(msg.sender, _voteFor);
    }
    
    //burning token recluses the burner
    //there should only ever be one token to burn, but just to be safe it deletes the entire balanceOf
    function burn(address _account) public onlyRole(BURNER_ROLE) {
        require(balanceOf(_account) > 0, "DaobiVote: There isn't a token to burn!");

        //replicates recluse() functionality minus event if they aren't already inactive
        if (voterRegistry[_account].serving = true) {
            voterRegistry[voterRegistry[_account].votedFor].votesAccrued--;
            voterRegistry[_account].votedFor = 0x0000000000000000000000000000000000000000;
            voterRegistry[_account].serving = false;
        }        

        //I wanted to set votesAccrued to zero but this was not feasible
        _burn(_account,balanceOf(_account));
        emit Burnt(_account);
    }

    //only someone with BURNER_ROLE can burn someone else's token.  You can always set yourself on fire though!
    function selfImmolate() public {
        require(balanceOf(msg.sender) > 0, "DaobiVote: You don't have a token to burn!");

        if (voterRegistry[msg.sender].serving = true) {
            voterRegistry[voterRegistry[msg.sender].votedFor].votesAccrued--;
            voterRegistry[msg.sender].votedFor = 0x0000000000000000000000000000000000000000;
            voterRegistry[msg.sender].serving = false;
        }

        _burn(msg.sender,balanceOf(msg.sender));
        emit SelfBurnt(msg.sender);
    }

    //convenience getters.  There's already a getter for the public voterRegistry map
    function assessVotes(address _voter) public view returns (uint40) {
        return voterRegistry[_voter].votesAccrued;
    }

    function seeBallot(address _voter) public view returns (address) {
        return voterRegistry[_voter].votedFor;
    }

    function checkStatus(address _voter) public view returns (bool) {
        return voterRegistry[_voter].serving;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "./IDAObi.sol";

contract DaobiVoteContract is Initializable, ERC721Upgradeable, ERC721URIStorageUpgradeable, PausableUpgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");//can pause contract
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE"); //can initiate new daobi voters
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE"); //contract admin (do not confuse with ADMIN_ROLE)
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");//can excommunicate daobi voters
    bytes32 public constant NFT_MANAGER = keccak256("NFT_MANAGER"); //manages NFT functionality

    //required information for each voter
    struct Voter {        
        address votedFor; //160 bits
        bool serving; //bools are 8 bits, in the future bitmasks can be used to further compress information if needed        
        uint160 votesAccrued; //There can't be more voters than the address space
        bytes32 courtName; //sixteen UTF-8 characters -- Emperor Qin needed 3, should be more than enough 
        uint32 voteDate; //block.timestamp of last vote cast
        uint256 voteBlock; // block number when vote was cast
        bytes19 __gap; //gap variable to use up rest of 256 bit block; may be used in future.  
    }

    //maps addresses to their Voter info
    mapping (address => Voter) public voterRegistry;

    //where the NFT metadata URI is located.  This should be a URL pointing to a JSON file in accordance with the OpenSea format (https://docs.opensea.io/docs/metadata-standards)
    string public URIaddr;

    //Basic idea: Once someone is verified, they are minted a voting token.  This allows them to (register to) vote, and qualifies them to receive votes.
    //They can vote for anyone, including themselves or 0x0 (i.e., abstain)
    //A voter can make a claim for the chancellorship.  If they have more votes than the current chancellor, this succeeds.
    //The "claiming" logic is done in the Daobi token contract itself.
    //They can choose to recluse (de-register).  A recluse always votes for 0x0 (i.e. nobody).
    //A recluse can still accrue votes.  However, they cannot claim the chancellorship.  
    //If a recluse holds the chancellorship for any reason (e.g. become chancellor, then recluse) then it can be claimed by anyone.
    //If someone burns their DBvt token, they automatically recluse.  They can't be voted for, and will have to re-register if they get a new token.  


    event NewToken(address indexed newDBvt);
    event Registered(address indexed regVoter, bytes32 nickname, address initVote);
    event Reclused(address indexed reclVoter);
    event Voted(address indexed voter, address indexed votee);
    event Burnt(address indexed burnee);
    event SelfBurnt(address indexed burner);
    event NFTRetarget(string newURI);
    event TokenStaked(address indexed staker, uint256 amount);
    event StakeReturned(address indexed staker, uint256 amount);
    event StakeForfeited(address indexed staker, address indexed claimer, uint256 amount);

    uint256 public propertyRequirement; //minimum number of tokens that must be held to vote.
    address payable public tokenContract;
    IDAObi daobi;

    bytes32 public constant VOTE_ADMIN_ROLE = keccak256("VOTE_ADMIN_ROLE");
    bytes32 public constant MINREQ_ROLE = keccak256("MINREQ_ROLE");

    // Add these state variables after the existing mappings
    mapping(address => address[]) public votersFor; // tracks who voted for each candidate
    mapping(address => uint256) public voterIndex; // tracks index in votersFor array for efficient removal

    uint256 public constant STAKE_AMOUNT = 100 * 10**18; // 100 DAOBI tokens
    mapping(address => uint256) public stakedAmount; // Track staked amounts

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}
    

    function initialize() initializer public {
        __ERC721_init("DAObi Voting Token", "DBvt");
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
        _grantRole(NFT_MANAGER, msg.sender);
        _grantRole(VOTE_ADMIN_ROLE, msg.sender);
        _grantRole(MINREQ_ROLE, msg.sender);
    }    

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function setURI(string memory newURI) public whenNotPaused onlyRole(NFT_MANAGER) {
        URIaddr = newURI;
        emit NFTRetarget(newURI);
    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721Upgradeable, ERC721URIStorageUpgradeable) returns (string memory) {
        require(_exists(tokenId), "ERC721URIStorage: URI query for nonexistent token");
        return URIaddr;
    }

    function refreshTokenURI() public whenNotPaused { //can be used to refresh token URI if it changes
        require(this.ownerOf(uint160(address(msg.sender))) == msg.sender, "You can only update your own vote token");
        _setTokenURI(uint160(address(msg.sender)), URIaddr);
    }

    function mint(address to) public whenNotPaused onlyRole(MINTER_ROLE) {
        require(balanceOf(to) == 0, "DaobiVote: Account already has a token!");
        require(daobi.transferFrom(to, address(this), STAKE_AMOUNT), "DaobiVote: Stake transfer failed");
        
        stakedAmount[to] = STAKE_AMOUNT;
        _safeMint(to, uint160(to)); //tokenID = address
        _setTokenURI(uint160(to), URIaddr);
        
        emit NewToken(to);
        emit TokenStaked(to, STAKE_AMOUNT);
    }

    function targetDaobi(address payable _daobi) public onlyRole(VOTE_ADMIN_ROLE) {
        tokenContract = _daobi;
        daobi = IDAObi(_daobi);
    }

    function setMinimumTokenReq(uint256 _minDB) public onlyRole(MINREQ_ROLE) {
        propertyRequirement = _minDB;
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(UPGRADER_ROLE)
        override
    {}

    //disable token transfers by making any call to transfer function auto-revert
    function _transfer(address from, address to, uint256 tokenId) internal override pure {  
        require(1==0, "DaobiVote: Tokens Are Not Transferrable!");
    }

    //register, the "serve" flag is automatically set and votes are initialized at zero
    //votesAccrued is left alone -- initializes to zero by default
    function register(address _initialVote, bytes32 _name) whenNotPaused public {
        require(balanceOf(msg.sender) > 0, "DaobiVote: You must hold a token to register!");
        require(checkStatus(msg.sender) == false, "DaobiVote: You are already registered!");
        require(balanceOf(_initialVote) > 0 || _initialVote == 0x0000000000000000000000000000000000000000, "DaobiVote: Invalid candidate!");
        require(daobi.balanceOf(msg.sender) >= propertyRequirement, "DaobiVote: You are too broke to register!");
        
        voterRegistry[msg.sender].serving = true;
        voterRegistry[msg.sender].votedFor = _initialVote;
        voterRegistry[msg.sender].voteDate = uint32(block.timestamp % 2**32);
        voterRegistry[msg.sender].voteBlock = block.number;
        voterRegistry[msg.sender].courtName = _name;

        if(_initialVote != address(0)) {
            voterIndex[msg.sender] = votersFor[_initialVote].length;
            votersFor[_initialVote].push(msg.sender);
            voterRegistry[_initialVote].votesAccrued++;
        }

        emit Registered(msg.sender, _name, _initialVote);
    }


    function recluse() public {
        require(voterRegistry[msg.sender].serving == true, "DaobiVote: Already inactive!");
        _removeVote(msg.sender);
        emit Reclused(msg.sender);
    }

    function vote(address _voteFor) whenNotPaused public {
        require(balanceOf(msg.sender) > 0, "DaobiVote: You don't have a token!");
        require(voterRegistry[msg.sender].serving == true, "DaobiVote: You're not registered!");
        require(_voteFor == 0x0000000000000000000000000000000000000000 || balanceOf(_voteFor) > 0, "DaobiVote: Invalid candidate!");
        require(daobi.balanceOf(msg.sender) >= propertyRequirement, "DaobiVote: You are too broke to vote!");

        // Remove old vote
        _removeVote(msg.sender);

        // Add new vote
        voterRegistry[msg.sender].serving = true;  // Reset to true since _removeVote sets it to false
        voterRegistry[msg.sender].votedFor = _voteFor;
        voterRegistry[msg.sender].voteDate = uint32(block.timestamp % 2**32);
        voterRegistry[msg.sender].voteBlock = block.number;
        
        if(_voteFor != address(0)) {
            voterIndex[msg.sender] = votersFor[_voteFor].length;
            votersFor[_voteFor].push(msg.sender);
            voterRegistry[_voteFor].votesAccrued++;
        }

        emit Voted(msg.sender, _voteFor);
    }
    
    //burning token recluses the burner
    //there should only ever be one token to burn, but just to be safe it deletes the entire balanceOf
    function burn(address _account) public onlyRole(BURNER_ROLE) {
        require(balanceOf(_account) > 0, "DaobiVote: There isn't a token to burn!");
        _removeVote(_account);
        _burn(uint160(_account));
        emit Burnt(_account);
    }

    //only someone with BURNER_ROLE can burn someone else's token.  You can always set yourself on fire though!
    function selfImmolate() public {
        require(balanceOf(msg.sender) > 0, "DaobiVote: You don't have a token to burn!");
        uint256 stake = stakedAmount[msg.sender];
        require(stake > 0, "DaobiVote: No stake to return");
        
        _removeVote(msg.sender);
        _burn(uint160(msg.sender));
        delete stakedAmount[msg.sender];
        
        require(daobi.transfer(msg.sender, stake), "DaobiVote: Stake return failed");
        
        emit SelfBurnt(msg.sender);
        emit StakeReturned(msg.sender, stake);
    }

    //convenience getters.  There's already a getter for the public voterRegistry map
    //APPARENTLY THERE IS NOT!  So you need these...
    function assessVotes(address _voter) public view returns (uint160) {
        uint160 validVotes = 0;
        address[] memory voters = votersFor[_voter];
        uint256 expiryBlock = block.number - 10000;
        
        for(uint i = 0; i < voters.length; i++) {
            address voter = voters[i];
            if(voterRegistry[voter].serving && 
               voterRegistry[voter].voteBlock > expiryBlock) {
                validVotes++;
            }
        }
        return validVotes;
    }

    function seeBallot(address _voter) public view returns (address) {
        return voterRegistry[_voter].votedFor;
    }

    function checkStatus(address _voter) public view returns (bool) {
        return voterRegistry[_voter].serving;
    }

    function getAlias(address _voter) public view returns (bytes32) {
        return voterRegistry[_voter].courtName;
    }

    function getVoteDate(address _voter) public view returns (uint32) {
        return voterRegistry[_voter].voteDate;
    }

    // Add this helper function to clean up expired votes (optional, but can help save gas long-term)
    function cleanupExpiredVotes(address _candidate) public {
        address[] storage voters = votersFor[_candidate];
        uint256 expiryBlock = block.number - 10000;
        
        for(uint i = 0; i < voters.length; /* i++ handled in loop */) {
            if(!voterRegistry[voters[i]].serving || 
               voterRegistry[voters[i]].voteBlock <= expiryBlock) {
                // Move the last element to current position and pop
                if(i < voters.length - 1) {
                    voters[i] = voters[voters.length - 1];
                    voterIndex[voters[i]] = i;
                }
                voters.pop();
                // Don't increment i since we just moved a new element to this position
            } else {
                i++;
            }
        }
    }

    //below are required by ERC721 standard

    function _burn(uint256 tokenId)
        internal
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    {
        super._burn(tokenId);
    }

    /*function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }*/

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _removeVote(address voter) private {
        if (voterRegistry[voter].serving == true) {
            address oldVote = voterRegistry[voter].votedFor;
            if(oldVote != address(0)) {
                uint256 index = voterIndex[voter];
                address[] storage voters = votersFor[oldVote];
                if(index < voters.length - 1) {
                    voters[index] = voters[voters.length - 1];
                    voterIndex[voters[index]] = index;
                }
                voters.pop();
                voterRegistry[oldVote].votesAccrued--;
            }
            voterRegistry[voter].serving = false;
            voterRegistry[voter].votedFor = address(0);
        }
    }

}
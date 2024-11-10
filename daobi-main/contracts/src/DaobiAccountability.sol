// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/Base64Upgradeable.sol";

import "./IDaobiVoteContract.sol";
import "./IDAObi.sol";
import "./IDaobiAccountabilityURIs.sol";

contract DaobiAccountability is Initializable, ERC721Upgradeable, ERC721URIStorageUpgradeable, ERC721EnumerableUpgradeable, PausableUpgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _tokenIdCounter;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");//can pause contract 
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");//admin role: can change contract settings
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE"); //contract admin (do not confuse with ADMIN_ROLE)

    uint public constant DAY_IN_SECONDS = 86400;    //ENSURE 86400 BEFORE PRODUCTION!!

    address public DAOvault; //recipient of handling fee
    uint8 public handlingFee; //should be an integer whose inverse gives the desired rate e.g. 1% = 100
    uint256 public cost; //how much it costs to make an accusation
    uint8 public idleDays; //how long someone must be idle before they can be accused of dereliction
    uint8 public responseDays; //how long someone accused has to refute an accusation
    uint8 public staleDays; //how long after responseDays have elapsed that an arbitrary user can terminate an accusation 
    uint16 public minSupporters; //how many supporters are NEEDED to kick someone off
    uint16 public maxSupporters; //how many supporters ARE ALLOWED to participate in an accusation.  Don't go overboard for memory management reasons.

    IDaobiVoteContract dbvote;
    IDAObi daobi;
    IDaobiAccountabilityURIs URIcontract;

    event DAORetargeted(address _newDAO);
    event VoteRetargeted(address _newVote);

    event AccusationMade(address indexed _accuser, address indexed _target);
    event AccusationJoined(address indexed _target, address supporter);
    event AccusationRefuted(address indexed _accuser, address indexed _target);
    event Banished(address indexed _accuser, address indexed _target);
    event SupporterReqChange(uint16 _min, uint16 _max);

    struct Accusation {
        address accuser; //160 bits
        uint32 accusationTime; //32 bits, timestamp of accusation
        uint256 accBalance; //how many tokens are involved in the accusation
        address[] supporters; //array of accusers
        bytes8 __gap; // leftover memory space
    }

    mapping (address => Accusation) public grudgeBook;
    mapping (address => address) public accusationTracker;

    bytes32[2] __gap;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() initializer public {
        __ERC721_init("DAObi Banishment Memorial", "DB BAN");
        __ERC721Enumerable_init();
        __ERC721URIStorage_init();        
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);

        //alchemy RPC wouldn't execute deployment command with these enabled
        /*handlingFee = 40;
        idleDays = 3;
        responseDays = 1;
        staleDays = 1;
        cost = 1000 * 10 ** daobi.decimals();
        minSupporters = 5;
        maxSupporters = 30; */

        //for debugging purposes, assigned separately during deployment for automation
        //DAOvault = 0x26bA3fb6F4b0c3394A001b0b09961663b2087d51;
        //daobi = IDAObi(0x07A8868cb63a85de48916E797B21424f0b5E5786);
        //dbvote = IDaobiVoteContract(0xDe0804D5ceC76595180d1F8EA00a815E82200Fd8);    
        //URIcontract = IDaobiAccountabilityURIs(0xd7d0151edA766ed78F84b4B3e926efff7b9cd393);        

    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    //need to add a check to prevent players from repeatedly making accusations as "supporters" -- will require another mapping.
    function makeAccusation(address _target) public whenNotPaused { //create accusation

        resetAccusationTracker(msg.sender); //slightly increases gas costs vs making users run themselves, but very convenient.

        require(dbvote.balanceOf(msg.sender) > 0, "DaobiAccountability: You don't have a vote token!"); //check the user has a vote token
        require(dbvote.balanceOf(_target) > 0, "DaobiAccountability: You can only accuse another courtier!"); //check that target has a vote token
        require(grudgeBook[_target].accuser != msg.sender, "DaobiAccountability: You already have an open accusation against this courtier!");        
        require(checkAccusation(msg.sender, _target) == true,"DaobiAccountability: You already have an active accusation!"); //check to avoid multiple votes per target
        require(uint32(block.timestamp % 2**32) - dbvote.getVoteDate(_target)  >= idleDays * DAY_IN_SECONDS, "DaobiAccountability: Target has not been idle!");  //check if target has not voted within specified time      
        require((grudgeBook[_target].accuser != address(0)) || (daobi.balanceOf(msg.sender) >= cost), "DaobiAccountability: You lack the funds to make an accusation"); //make sure they have enough tokens
        require(grudgeBook[_target].supporters.length < maxSupporters, "DaobiAccountability: Too many others have already joined in this accusation!");
        
        
        if (grudgeBook[_target].accuser == address(0)) {//if initial accuser
            grudgeBook[_target].accuser = msg.sender;
            grudgeBook[_target].accusationTime = uint32(block.timestamp % 2**32);          

            grudgeBook[_target].accBalance += cost;                  
            daobi.transferFrom(msg.sender, address(this), cost);

            emit AccusationMade(msg.sender, _target);

        }
        else {//if pile-on accuser
            grudgeBook[_target].supporters.push(msg.sender);
            emit AccusationJoined(_target, msg.sender);
        } 
    }    

    function refuteAccusation() public whenNotPaused {
        require(dbvote.balanceOf(msg.sender) != 0, "DaobiAccountability: You've already lost your court status!"); //can't refute if you're already banished
        require(grudgeBook[msg.sender].accuser != address(0), "DaobiAccountability: Nobody has made an accusation against you!"); //or if there is no accusation at all

        if (dbvote.getVoteDate(msg.sender) > grudgeBook[msg.sender].accusationTime) { //if the user HAS VOTED since the accusation is made, he gets the money
            uint feePay = grudgeBook[msg.sender].accBalance / handlingFee;
            uint wergild = grudgeBook[msg.sender].accBalance - feePay;

            emit AccusationRefuted(grudgeBook[msg.sender].accuser, msg.sender);
            delete grudgeBook[msg.sender];

            daobi.transfer(msg.sender, wergild);
            daobi.transfer(DAOvault, feePay);
        }
        else { //otherwise the accuser just gets his money back minus a small fee for inconvenience the bureaucracy
            uint feePay = grudgeBook[msg.sender].accBalance / handlingFee;
            uint wergild = grudgeBook[msg.sender].accBalance - feePay;
            address accuser = grudgeBook[msg.sender].accuser;

            emit AccusationRefuted(grudgeBook[msg.sender].accuser, msg.sender);
            delete grudgeBook[msg.sender];

            daobi.transfer(accuser, wergild);
            daobi.transfer(DAOvault, feePay);         
        }    
    }

    function thirdPartyRefute(address _refutee) public whenNotPaused { //allows anyone to terminate a stale accusation.  Tokens all go to the DAO, but the third party gets their vote back.
        require(msg.sender != _refutee, "DaobiAccountability: Use first-party refutation instead");
        require(dbvote.balanceOf(msg.sender) != 0, "DaobiAccountability: Only a courtier may terminate an accusation!!"); //third party must have a vote token
        require(grudgeBook[_refutee].accuser != address(0), "DaobiAccountability: There is no active accusation against them!"); //and there must be an accusation to refute
        require(block.timestamp > (grudgeBook[_refutee].accusationTime + (responseDays * DAY_IN_SECONDS) + (staleDays * DAY_IN_SECONDS)), "DaobiAccountability: You must wait until the accusation is eligible for action!");
    
        
        uint balance = grudgeBook[_refutee].accBalance;

        emit AccusationRefuted(grudgeBook[_refutee].accuser, _refutee);
        delete grudgeBook[_refutee];

        daobi.transfer(DAOvault, balance);        
    }

    function banish(address _target) public whenNotPaused {
        //if conditions are met (enough accusers AND enough time has elapsed)
        //burn target's token
        //mint NFT to user
        require(grudgeBook[_target].accuser == msg.sender, "DaobiAccountability: Only the ringleader can petition to have someone banished!");
        require(dbvote.balanceOf(msg.sender) > 0, "DaobiAccountability: You don't have a vote token!");
        require(grudgeBook[_target].supporters.length >= minSupporters, "DaobiAccountability: You haven't gathered enough backers!");
        require(dbvote.getVoteDate(_target) < (grudgeBook[_target].accusationTime + (responseDays * DAY_IN_SECONDS)), "DaobiAccountability: Target has not met idleness criteria!");

        //check whether the target has pre-emptively burned his token.  If he hasn't, his token is burned and the accuser gets his money back sans a handling fee.
        if (dbvote.balanceOf(_target) > 0) { 

            uint feePay = grudgeBook[_target].accBalance / handlingFee;
            uint wergild = grudgeBook[_target].accBalance - feePay;
            address accuser = grudgeBook[_target].accuser;
            
            daobi.transfer(accuser, wergild);
            daobi.transfer(DAOvault, feePay); 

            dbvote.burn(_target);
            mint(msg.sender, _target);

            delete grudgeBook[_target];
            emit Banished(msg.sender, _target);

        } else { //If so, the accuser's money is returned minus a handling fee and the accusation is deleted but nothing else happens

            uint feePay = grudgeBook[_target].accBalance / handlingFee;
            uint refund = grudgeBook[_target].accBalance - feePay;

            delete grudgeBook[_target];
            daobi.transfer(msg.sender, refund);
            daobi.transfer(DAOvault, feePay); 
            
        }      
    }

    function mint(address _to, address _target) private {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(_to, tokenId);
        address chanc = daobi.chancellor();
        _setTokenURI(tokenId,URIcontract.generateURI(_target, grudgeBook[_target].accuser, chanc, uint16(grudgeBook[_target].supporters.length), generateSupporterString(_target) ));
    }

    function generateSupporterString(address target) private view returns (string memory) { //create the list of supporters to display in metadata
        bytes memory supportersJSON; 
            for (uint i = 0; i < grudgeBook[target].supporters.length; i++) {
                supportersJSON = abi.encodePacked(supportersJSON, '{');
                supportersJSON = abi.encodePacked(supportersJSON, '"trait_type": Supporter #',StringsUpgradeable.toString(i+1) ,'"');
                supportersJSON = abi.encodePacked(supportersJSON, '"value": "', StringsUpgradeable.toHexString(grudgeBook[target].supporters[i]), '"');
                supportersJSON = abi.encodePacked(supportersJSON, '}');
            }

        return string(supportersJSON);            
    }   

    function contractURI() public view returns (string memory) { //returns on-chain contract-level metadata https://docs.opensea.io/docs/contract-level-metadata    
        return URIcontract.getContractURI();
    }   

    function retargetDAO(address _newVault) public onlyRole(MANAGER_ROLE){
        DAOvault = _newVault;
        emit DAORetargeted(_newVault);
    }

    function retargetVote(address _newVote) public onlyRole(MANAGER_ROLE){
        dbvote = IDaobiVoteContract(_newVote);
        emit VoteRetargeted(_newVote);
    }

    function retargetURIgen(address _newContract) public onlyRole(MANAGER_ROLE){
        URIcontract = IDaobiAccountabilityURIs(_newContract);
    }

    function retargetDAObi(address _daobi) public onlyRole (MANAGER_ROLE) {
        daobi = IDAObi(_daobi);
    }

    function currentURIContract() public view returns (address) {
        return address(URIcontract);
    }

    //adjustment function, determines rules for voting
    function adjust(uint16 _min, uint16 _max, uint8 _fee, uint256 _cost, uint8 _idle, uint8 _response, uint8 _stale) public onlyRole (MANAGER_ROLE) {
        require(_max >= _min, "DaobiAccountability: MaxSupporters cannot be smaller than MinSupporters.");
        
        if (_min != 0) {
            minSupporters = _min;
        }
        
        if (_max != 0) {
            maxSupporters = _max;
        }

        if (_fee != 0) {
            handlingFee = _fee;
        }

        if (_cost != 0) {
            cost = _cost * 10 ** 18;
        }

        if (_idle != 0) {
            idleDays = _idle;
        }

        if (_response != 0) {
            responseDays = _response;
        }

        if (_stale != 0) {
            staleDays = _stale;
        }
    }

    //getters for the Accusation structure

    function getAccuser(address _target) public view returns (address) {
        return grudgeBook[_target].accuser;
    }

    function getAccTime(address _target) public view returns (uint32) {
        return grudgeBook[_target].accusationTime;
    }

    function getAccBalance(address _target) public view returns (uint256) {
        return grudgeBook[_target].accBalance;
    }

    function getSupporters(address _target) public view returns (address[] memory) {
        return grudgeBook[_target].supporters;
    }

    function getNumSupporters(address _target) public view returns (uint) {
        return grudgeBook[_target].supporters.length;
    }     

    //functions to avoid duplicate accusations.  I don't think this is well optimized but it works
    function checkAccusation(address _user, address _target) private returns (bool) { //checks if the user's current accusation is no longer valid, and updates it to the target if it is not.
        if(accusationTracker[_user] == address(0)) { //user has never made an accusation before, or their accusation has been reset -- valid accusation, update
            accusationTracker[_user] = _target;
            return true;
        }

        else if (grudgeBook[accusationTracker[_user]].accuser == address(0)) { //user's current accusation has been resolved -- valid accusation, update.
            accusationTracker[_user] = _target;
            return true;
        }
        
        else if (accusationTracker[_user] == _target) { //user is attempting a duplicate accusation, invalid
            return false;
        }

        else { //remaining possibility is that user has an unresolved accusation i.e. grudgeBook[accusationTracker[_user]].accuser is nonzero.  This must be resolved.
            return false;
        }
    }

    function selfResetAccusationTracker() public whenNotPaused returns(bool) { //return TRUE if accusation is reset i.e. match not found
        if (grudgeBook[accusationTracker[msg.sender]].supporters.length == 0) {
            accusationTracker[msg.sender] = address(0);
            return true;
        }
        
        for (uint i = 0; i < grudgeBook[accusationTracker[msg.sender]].supporters.length; i++) {
            if (grudgeBook[accusationTracker[msg.sender]].supporters[i] == msg.sender) {
                return false;
            }            
        }       

        accusationTracker[msg.sender] = address(0);
        return false;
    }

    function resetAccusationTracker(address _user) private whenNotPaused returns(bool) { //return TRUE if accusation is reset i.e. match not found
        if (grudgeBook[accusationTracker[_user]].supporters.length == 0) {
            accusationTracker[_user] = address(0);
            return true;
        }
        
        for (uint i = 0; i < grudgeBook[accusationTracker[_user]].supporters.length; i++) {
            if (grudgeBook[accusationTracker[_user]].supporters[i] == _user) {
                return false;
            }            
        }       

        accusationTracker[_user] = address(0);
        return false;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(UPGRADER_ROLE)
        override
    {}


    //required overrides
    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "./DaobiVoteContract.sol";
import "./DaobiChancellorsSeal.sol";

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

/// @custom:security-contact jennifer.dodgson@gmail.com
contract DAObiContract3 is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, PausableUpgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant TREASURER_ROLE = keccak256("TREASURER_ROLE"); //controls contract admin functions
    bytes32 public constant CHANCELLOR_ROLE = keccak256("CHANCELLOR_ROLE"); //the chancellor
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE"); //the administrator (tho not same as ADMIN_ROLE)

    //additions to support on-chain election of chancellor: 
    address public chancellor; //the address of the current chancellor

    // the address of the voting contract
    //the voting contract should contain a mapping in which, given an address, the number of votes for that address (if any) can be found
    address public votingContract; 
    address public sealContract; //address of the Chancellor's Seal contract

    //events related to voting
    event ClaimAttempted(address indexed _claimant, uint40 _votes);
    event ClaimSucceeded(address indexed _claimant, uint40 _votes);
    event NewChancellor(address indexed _newChanc);
    event VoteContractChange(address _newVoteScheme);
    event DaobiMinted(uint256 indexed amount);

    //signals that the Chancellor's seal contract has been retargeted.  
    //The contract itself may send events internally; emits will be emitted from that address
    event SealContractChange(address _newSealAddr);

    //events and variables related to Uniswap/DAO integration
    address public DAOvault;
    ISwapRouter public constant uniswapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564); //swaprouter
    address private constant daobiToken = 0x68af95a6f932a372e88170e9c2a46094FAeFd5D4; //address of Token A, RinkDB
    address private constant chainToken = 0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889; //address of Token B, RinkWETH [not needed, can simply call]
    uint24 public swapFee; //uniswap pair swap fee, 3000 is standard (.3%)
    event DAORetargeted(address _newDAO);

    //chancellor salary functionality
    uint256 public chancellorSalary;
    uint256 public salaryInterval;
    uint256 public lastSalaryClaim; //last block timestamp at which chancellor salary was claimed.
    event chancellorPaid(address _chancellor);


    /// @custom:oz-upgrades-unsafe-allow constructor

    constructor() initializer {}

    function initialize() initializer public {
        __ERC20_init("DAObi", "DB");
        __ERC20Burnable_init();
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();


    }

    //execute this function to initialize new variables immediately after upgradeProxy()
    function updateContract() public onlyRole(UPGRADER_ROLE) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(TREASURER_ROLE, msg.sender); //TREASURER_ROLE is the contract "moderator"
        //_grantRole(CHANCELLOR_ROLE, msg.sender); //contract upgrade should not change chancellor
        _grantRole(UPGRADER_ROLE, msg.sender);

        //variable initialization
        DAOvault = 0x9f216b3644082530E6568755768786123DD56367;
        swapFee = 3000; //.3% swap fee, uniswap default
        chancellorSalary = 1000 * 10 ** decimals(); //default value of 1000 DB
        salaryInterval = 86400; //24 hours (+/- 900s)
        lastSalaryClaim = 0; //last block timestamp at which chancellor salary was claimed.
    }

    //THIS FUNCTION MUST BE EXECUTED IMMEDIATELY AFTER UPGRADEPROXY() TO POINT TO THE VOTE CONTRACT
    function retargetVoting(address _voteContract) public onlyRole(TREASURER_ROLE) {
        //pauses the contract to prevent minting and claiming after deployment until unpaused        
        votingContract = _voteContract;
        emit VoteContractChange(_voteContract);
        pause();
    }

    function retargetSeal(address _sealContract) public onlyRole(TREASURER_ROLE) {
        //pauses the contract to prevent minting and claiming after deployment until unpaused        
        sealContract = _sealContract;
        emit SealContractChange(_sealContract);
        pause();
    }

    function pause() public onlyRole(TREASURER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(TREASURER_ROLE) {
        _unpause();
    }

    function mint(uint256 amount) public payable whenNotPaused onlyRole(CHANCELLOR_ROLE) {
        require(amount > 0, "Must pass non 0 DB amount");    

        _mint(address(this), amount + swapFee); //mint tokens into contract
        _mint(DAOvault, amount / 20); //mint 5% extra tokens into DAO vault
        
        
        TransferHelper.safeApprove(daobiToken,address(uniswapRouter),amount); //approve uniswap transaction

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams(
            daobiToken, //input token
            chainToken, //output token
            swapFee,
            DAOvault, //eth from transaction sent to DAO
            block.timestamp + 120, //execute trade immediately
            amount,
            1, //trade will execute even if only 1 wei is received back
            0 //sqrtPriceLimitX96
        );

        uniswapRouter.exactInputSingle(params);

        emit DaobiMinted(amount);
    }

    function claimChancellorSalary() public whenNotPaused onlyRole(CHANCELLOR_ROLE) {
        require(block.timestamp > lastSalaryClaim + salaryInterval, "Not enough time has elapsed since last payment");

        lastSalaryClaim = block.timestamp + 15;
        _mint(msg.sender,chancellorSalary); //mint chancellor salary into chancellor's wallet

        emit chancellorPaid(msg.sender);

    }

    function adjustSalaryInterval(uint _newInterval) public onlyRole(TREASURER_ROLE) {
        salaryInterval = _newInterval;
    }

    function adjustSalaryAmount(uint _newSalary) public onlyRole(TREASURER_ROLE) {
        chancellorSalary = _newSalary;
    }

    function retargetDAO(address _newVault) public whenNotPaused onlyRole(TREASURER_ROLE){
        DAOvault = _newVault;
        emit DAORetargeted(_newVault);
    }

    function setSwapFee(uint24 _swapFee) public whenNotPaused onlyRole(TREASURER_ROLE){
        swapFee = _swapFee;
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

    //recover seal to chancellor if it's somehow missing
    function recoverSeal() public {
        require (msg.sender == chancellor, "Only the Chancellor can reclaim this Seal!");   

        DaobiChancellorsSeal seal = DaobiChancellorsSeal(sealContract); 
        require (seal.totalSupply() > 0, "The Seal doesn't currently exist");

        seal.approve(address(this), 1);
        seal.safeTransferFrom(seal.ownerOf(1), chancellor, 1);
    }

    function assumeChancellorship(address _newChancellor) private {
        //this will fail if the voting contract has not been assigned the VOTE_CONTRACT role
        DaobiChancellorsSeal seal = DaobiChancellorsSeal(sealContract); 
        seal.approve(address(this), 1);
        seal.transferFrom(seal.ownerOf(1), _newChancellor, 1);

        _revokeRole(CHANCELLOR_ROLE, chancellor);
        chancellor = _newChancellor;
        _grantRole(CHANCELLOR_ROLE, chancellor);

        emit NewChancellor(chancellor);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(UPGRADER_ROLE)
        override
    {}

    receive() payable external {}

}
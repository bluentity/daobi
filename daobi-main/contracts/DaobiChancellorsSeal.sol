// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract DaobiChancellorsSeal is Initializable, ERC721Upgradeable, ERC721URIStorageUpgradeable, ERC721EnumerableUpgradeable, PausableUpgradeable, AccessControlUpgradeable, UUPSUpgradeable {

    //the VOTE_CONTRACT role is the vote contract.  It, and only it, can transfer the seal around.
    //the SEAL_MANAGER can burn and mint the seal token.  This can be used to correct errors.  He can also retarget the seal's URI.
    //the VOTE_CONTRACT role must be assigned to the voting contract's address for the chancellor's seal feature to work.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant SEAL_MANAGER = keccak256("SEAL_MANAGER");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant DAOBI_CONTRACT = keccak256("DAOBI_CONTRACT");

    string public URIaddr; //address of the Seal's NFT metadata
    
    event SealURIRetarget(string newAddr); //emits URI of new seal if it is changed.
    event SealBurnt();
    event SealMinted(address indexed mintee);

    address public tokenContract;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}
    

    function initialize() initializer public {
        __ERC721_init("DAObi Chancellor's Seal", "DAOBI SEAL");
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(SEAL_MANAGER, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
    }    

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function targetDaobiContract(address _dbContract) public onlyRole(UPGRADER_ROLE)
    {
        _revokeRole(DAOBI_CONTRACT, tokenContract);
        tokenContract = _dbContract;
        _grantRole(DAOBI_CONTRACT, tokenContract);
    }

    function setURI(string memory newURI) public whenNotPaused onlyRole(SEAL_MANAGER) {
        URIaddr = newURI;
        emit SealURIRetarget(newURI);
    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721Upgradeable, ERC721URIStorageUpgradeable) returns (string memory) {
        require(_exists(tokenId), "ERC721URIStorage: URI query for nonexistent token");
        return URIaddr;
    }

    function mint(address to) public whenNotPaused onlyRole(SEAL_MANAGER) {
        require(totalSupply() == 0, "A Chancellor Seal Already Exists!");
        _safeMint(to, 1); //tokenID is always 1
        _setTokenURI(1,URIaddr);
        emit SealMinted(to);
    }

    //this is disabled
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal override virtual pure {
        require(1==0, "SetApprovalForAll disabled for the Chancellor's Seal");
    }

    function approve(address to, uint256 tokenId) public virtual override {
        require(hasRole(SEAL_MANAGER, msg.sender) || hasRole(DAOBI_CONTRACT, msg.sender), "Unauthorized Transfer Attempt");        
        address owner = ERC721Upgradeable.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");
        _approve(to, tokenId);
    }

    function _approve(address to, uint256 tokenId) internal virtual override {
        require(hasRole(SEAL_MANAGER, msg.sender) || hasRole(DAOBI_CONTRACT, msg.sender), "Unauthorized Transfer Attempt");
        ERC721Upgradeable._approve(to, tokenId);
        emit Approval(ERC721Upgradeable.ownerOf(tokenId), to, tokenId);
    }



    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override (ERC721EnumerableUpgradeable, ERC721Upgradeable)
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(UPGRADER_ROLE)
        override
    {}

    //only the voting contract can transfer tokens
    function _transfer(address from, address to, uint256 tokenId) internal override onlyRole(DAOBI_CONTRACT) {
        require(hasRole(SEAL_MANAGER, msg.sender) || hasRole(DAOBI_CONTRACT, msg.sender), "Unauthorized Transfer Attempt");         
        ERC721Upgradeable._transfer(from,to,tokenId);
    }   
    
    
    
    function burn() public onlyRole(SEAL_MANAGER) {
        require(totalSupply() > 0, "There isn't a seal to burn!");

        //I wanted to set votesAccrued to zero but this was not feasible
        _burn(1);
        emit SealBurnt();
    }

    //below are required by ERC721 standard

    function _burn(uint256 tokenId) onlyRole(SEAL_MANAGER)
        internal
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    {
        super._burn(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, AccessControlUpgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
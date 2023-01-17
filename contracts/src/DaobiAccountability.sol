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

import "./IDaobiVoteContract.sol";
import "./IDAObi.sol";

contract DaobiAccountability is Initializable, ERC721Upgradeable, ERC721URIStorageUpgradeable, ERC721EnumerableUpgradeable, PausableUpgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _tokenIdCounter;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");//can pause contract 
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");//admin role: can change contract settings
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE"); //contract admin (do not confuse with ADMIN_ROLE)

    address private constant daobiToken = 0x5988Bf243ADf1b42a2Ec2e9452D144A90b1FD9A9;
    uint constant DAY_IN_SECONDS = 86400;    

    address public DAOvault; //recipient of handling fee
    uint8 public handlingFee; //should be an integer whose inverse gives the desired rate e.g. 1% = 100
    uint256 public cost; //how much it costs to make an accusation
    uint8 public idleDays; //how long someone must be idle before they can be accused of dereliction
    uint8 public responseDays; //how long someone accused has to refute an accusation
    uint16 public minSupporters; //how many supporters are NEEDED to kick someone off
    uint16 public maxSupporters; //how many supporters ARE ALLOWED to participate in an accusation.  Don't go overboard for memory management reasons.

    DaobiVoteContract dbvote;
    DAObi daobi;

    event DAORetargeted(address _newDAO);
    event VoteRetargeted(address _newVote);

    event AccusationMade(address indexed _accuser, address indexed _target);
    event AccusationJoined(address indexed _target, address supporter);
    event AccusationRefuted(address indexed _accuser, address indexed _target);
    event Banished(address indexed _accuser, address indexed _target);

    struct Accusation {
        address accuser; //160 bits
        uint32 accusationTime; //32 bits, timestamp of accusation
        uint256 accBalance; //how many tokens are involved in the accusation
        address[] supporters; //array of accusers
        bytes8 blankGap; // leftover memory space
    }

    mapping (address => Accusation) public grudgeBook;

    bytes32 blank1;
    bytes32 blank2;

    constructor() {
        _disableInitializers();
    }

    function initialize() initializer public {
        __ERC721_init("DAObi Banishment Memorial", "DBb");
        __ERC721Enumerable_init();
        __ERC721URIStorage_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);

        DAOvault = 0x05cF4dc7e44e5560a2B5d999D675BC626C127f6E;
        handlingFee = 40;
        idleDays = 14;
        responseDays = 5;

        daobi = DAObi(daobiToken);
        dbvote = DaobiVoteContract(0xe8A858B29311652F7e2170118FbEaD34d097e88A);      
        cost = 1000 ** 10 ** daobi.decimals();
        minSupporters = 4;
        maxSupporters = 32;

    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function makeAccusation(address _target) public whenNotPaused { //create accusation
        //check if target has not voted within specified time
        require(dbvote.balanceOf(msg.sender) > 0, "DaobiAccountability: You don't have a vote token!");
        require(dbvote.balanceOf(_target) > 0, "DaobiAccountability: You can only accuse another courtier!");
        require(dbvote.getVoteDate(_target) - block.timestamp >= idleDays * DAY_IN_SECONDS, "DaobiAccountability: Target has not been idle!");
        require(grudgebook[_target].accuser != 0 || daobi.balanceOf(msg.sender) >= cost, "DaobiAccountability: You lack the funds to make an accusation");
        require(grudgebook[_target].supporters.length < maxSupporters, "DaobiAccountability: Too many others have already joined in this accusation!");
        
        if (grudgeBook[_target].accuser == 0) {//if initial accuser
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
        require(dbvote.balanceOf(msg.sender) != 0, "DaobiAccountability: You've already lost your court status!");
        require(grudgeBook[msg.sender].accuser != 0, "DaobiAccountability: Nobody has made an accusation against you!");

        if (dbvote.getVoteDate(msg.sender) > grudgeBook[msg.sender]) { //if the user HAS VOTED since the accusation is made, he gets the money
            uint feePay = grudgeBook[msg.sender].accBalance / handlingFee;
            uint wergild = grudgeBook[msg.sender].accBalance - feePay;
            delete grudgeBook[msg.sender];

            daobi.transfer(address(this), msg.sender, wergild);
            daobi.transfer(address(this), DAOvault, feePay);
        }
        else { //otherwise the accuser just gets his money back minus a small fee for inconvenience the bureaucracy
            uint feePay = grudgeBook[msg.sender].accBalance / handlingFee;
            uint wergild = grudgeBook[msg.sender].accBalance - feePay;
            address accuser = grudgeBook[msg.sender].accuser;
            delete grudgeBook[msg.sender];

            daobi.transfer(address(this), accuser, wergild);
            daobi.transfer(address(this), DAOvault, feePay); 
        }        
    }

    function banish(address _target) public whenNotPaused {
        //if conditions are met (enough accusers AND enough time has elapsed)
        //burn target's token
        //mint NFT to user
        require(grudgeBook[_target].accuser == msg.sender, "DaobiAccountability: Only the ringleader can petition to have someone banished!");
        require(dbvote.balanceOf(msg.sender) > 0, "DaobiAccountability: You don't have a vote token!");
        require(grudgeBook[_target].supporters.length >= minSupporters, "DaobiAccountability: You haven't gathered enough backers!");
        require(dbvote.getVoteDate(_target) < (grudgeBook[_target].accusationTime + (responseDays * DAY_IN_SECONDS)), "DaobiAccountability: Target has not met idleness criteria!");

        //check whether the target has pre-emptively burned his token.  If so, the accuser's money is returned and the accusation is deleted but nothing else happens
        if (dbvote.balanceOf(target) > 0) { 
            mint(msg.sender, _target);
        }

        uint refund = grudgeBook[_target].accBalance;
        delete grudgeBook[_target];
        daobi.transfer(address(this), msg.sender, refund);
    }

    function mint(address _to, address _target) private {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(_to, tokenId);
        _setTokenURI(tokenId,generateURI(_target));
    }

    function generateSVG(address target) private returns (string memory)//generate on-chain SVG for metadata
    {
        uint time = block.timestamp; //used for pseudorandomness, no security concern
        
        uint[3] outColor = [
            uint(time && 0x03),
            uint(time && 0x05),
            uint(time && 0x09)
        ];

        uint[3] inColor = [
            uint(time && 0x06),
            uint(time && 0x0A),
            uint(time && 0x0C)
        ];

        bytes memory imageSVG = abi.encodePacked(
            '<svg width="128" height="128" version="1.1" viewBox="0 0 33.867 33.867" xmlns="http://www.w3.org/2000/svg">',
            '<path transform="scale(.26458)" d="m61.011 95.267c-9.7636-0.94172-18.696-6.5597-23.835-14.991-3.3784-5.5427-5.0187-12.35-4.4839-18.61 1.0838-12.687 9.182-23.188 21.075-27.328 14.018-4.8793 29.565 0.8235 37.221 13.653 6.5406 10.961 5.7598 24.596-2.0026 34.972-6.4142 8.574-17.246 13.338-27.974 12.303z" fill="#',toString(outColor[0]), toString(outColor[1]), toString(outColor[2]), '" stroke-width=".16865"/>',
            '<path transform="scale(.26458)" d="m61.011 95.11c-10.827-1.1323-20.56-7.986-25.147-17.706-2.3546-4.9898-3.4324-10.555-3.0033-15.509 0.97815-11.292 7.2323-20.724 17.035-25.692 8.7457-4.4321 18.628-4.5556 27.508-0.34379 11.474 5.4421 18.767 17.888 17.731 30.26-1.2279 14.67-11.728 26.194-26.12 28.667-2.2619 0.38862-5.9566 0.53822-8.004 0.32408z" fill="#ff0000" stroke-width=".16865"/>  <rect width="33.867" height="33.867" fill="none" stroke-width=".26458"/>',
            '<path transform="scale(.26458)" d="m0.50594 64.002v-63.496h126.99v126.99h-126.99zm68.421 32.195c7.3217-1.0524 14.59-5.0069 19.475-10.596 4.1924-4.7964 6.8455-10.485 7.8314-16.792 0.37391-2.3921 0.37179-7.2264-0.0042-9.6474-1.7345-11.167-9.035-20.649-19.289-25.052-13.889-5.9646-29.971-1.7033-38.985 10.33-8.6019 11.483-8.7055 27.336-0.2536 38.805 5.8158 7.8914 14.417 12.567 24.445 13.288 1.4144 0.10166 4.9612-0.07364 6.7804-0.33512z" fill="#',toString(inColor[0]), toString(inColor[1]), toString(inColor[2]), '" stroke-width=".16865"/>',
            '</g>',
            '</svg>'
        );

        return string(
            abi.encodePacked(
                "data:image/svg+xml; base64,",
                Base64.encode(contractURI)
            )
        );

    }

    function generateSupporterString(address target) private returns (string memory) { //create the list of supporters to display in metadata
        bytes memory supportersJSON; 
            for (uint i = 0; i < grudgeBook[target].supporters.length; i++) {
                supportersJSON = abi.encodePacked(supportersJSON, '{');
                supportersJSON = abi.encodePacked(supportersJSON, '"trait_type": Supporter #',toString(i+1) ,'"');
                supportersJSON = abi.encodePacked(supportersJSON, '"value": "', toString(uint256(dbvote.getAlias([grudgeBook[target].supporters[i]]))), '"');
                supportersJSON = abi.encodePacked(supportersJSON, '}');
            }

        return string(supportersJSON);            
    }

    function generateURI(address target) private returns(string memory) { //generate on-chain metadata        
        
        bytes memory contractURI = abi.encodePacked(
            '{',
                '"name": "The Banishing of ', toString(uint256(dbvote.getAlias(target))),' by ', toString(uint256(dbvote.getAlias([grudgeBook[target].accuser]))), " and their ", grudgeBook[target].supporters.length,' supporters",',
                '"description": "Commemorates the banishment of a DAObi Courtier for excessive idleness",',
                '"image": "', generateSVG(target), '",',
                '"external_url": "https://www.daobi.org/",',
                '"attributes": [',
                    '{',
                        '"display_type": "date",',
                        '"trait_type": "Banishment Date",',
                        '"value": ', block.timestamp, 
                    '}',
                    '{',
                        '"trait_type": "Supporters",',
                        '"value": ', grudgeBook[target].supporters.length, 
                    '}',
                    generateSupporterString(target),                    
                ']'
            '}'
        );

        return string(
            abi.encodePacked(
                "data:image/svg+xml; base64,",
                Base64.encode(contractURI)
            )
        );
    }    

    function contractURI() public view returns (string memory) { //returns on-chain contract-level metadata https://docs.opensea.io/docs/contract-level-metadata
        bytes memory contractSVG = abi.encodePacked(            
            '<svg version="1.0" xmlns="http://www.w3.org/2000/svg" width="389.000000pt" height="389.000000pt" viewBox="0 0 389.000000 389.000000" preserveAspectRatio="xMidYMid meet">',
            '<g transform="translate(0.000000,389.000000) scale(0.100000,-0.100000)" fill="#000000" stroke="none">',
            '<path d="M1972 2631 c-22 -72 -8 -131 32 -131 14 0 81 -33 103 -52 9 -7 36 -13 61 -13 58 0 69 -16 56 -81 -9 -48 -9 -48 -68 -66 -78 -24 -86 -32 -86 -85 0 -56 -29 -88 -91 -98 -37 -6 -56 -19 -120 -81 -42 -41 -85 -74 -94 -74 -10 0 -40 -22 -67 -50 -27 -27 -53 -50 -59 -50 -5 0 -43 -30 -85 -66 -72 -63 -77 -65 -115 -59 -34 6 -45 3 -75 -20 -32 -24 -39 -26 -59 -15 -21 11 -28 10 -56 -14 -24 -21 -39 -26 -58 -22 -88 21 -109 19 -187 -18 l-76 -36 -66 17 c-94 23 -204 62 -222 78 -8 7 -52 16 -100 20 -56 5 -91 13 -104 24 -22 20 -114 20 -127 -1 -14 -22 -4 -33 29 -33 42 -1 104 -59 101 -95 -3 -52 -2 -53 49 -46 37 5 70 0 136 -19 47 -14 94 -25 104 -25 10 0 28 -7 41 -16 24 -17 112 -24 361 -28 122 -1 126 -1 173 27 46 28 50 29 93 17 84 -24 195 8 247 70 10 12 25 19 33 16 14 -5 90 40 114 69 9 11 25 13 59 9 54 -6 62 0 81 59 13 42 52 66 75 47 19 -15 55 9 55 36 0 12 13 41 30 65 16 24 30 49 30 55 0 14 72 27 96 17 13 -5 16 -3 11 10 -4 10 -2 17 5 17 6 0 32 20 59 45 l48 45 -24 19 c-23 17 -23 19 -7 33 34 29 92 57 97 47 11 -17 21 -9 43 36 12 24 33 52 47 61 24 16 33 16 92 4 48 -9 67 -10 76 -1 6 6 20 11 31 11 27 -1 97 -44 110 -68 24 -42 95 -112 114 -112 11 0 38 -19 61 -42 31 -32 41 -51 41 -75 0 -18 -3 -33 -8 -33 -11 0 -32 -75 -21 -78 11 -4 12 -42 1 -42 -4 0 -13 5 -20 12 -9 9 -19 5 -44 -19 -30 -28 -69 -53 -82 -53 -3 0 -6 12 -6 28 l0 27 -15 -29 c-10 -18 -13 -41 -9 -65 7 -43 -9 -63 -47 -59 -20 3 -24 -2 -24 -24 0 -14 -4 -30 -8 -35 -17 -16 -101 -12 -133 8 -48 29 -74 25 -74 -11 0 -30 -13 -40 -25 -20 -4 6 -23 17 -43 25 -35 15 -36 15 -58 -12 -20 -26 -23 -26 -45 -12 -36 23 -68 29 -98 17 -14 -6 -64 -12 -111 -13 -104 -2 -192 -28 -183 -53 6 -19 88 -100 127 -126 14 -9 26 -25 26 -36 0 -23 18 -27 26 -5 10 24 34 17 52 -15 17 -30 18 -30 112 -32 52 -1 147 -1 210 1 112 3 116 4 146 33 40 38 87 50 199 52 99 1 129 15 167 76 11 19 26 30 39 30 24 0 89 45 89 62 0 5 11 19 24 29 13 10 38 45 56 76 18 32 44 70 58 85 22 24 24 32 16 59 -8 28 -6 36 18 59 14 15 31 47 37 71 7 24 18 55 25 69 7 14 16 45 19 70 6 42 4 47 -22 65 -23 15 -27 22 -18 35 8 14 2 31 -27 81 -21 35 -41 71 -45 79 -5 9 -22 15 -42 15 -27 0 -36 6 -47 28 -12 24 -19 27 -61 27 -35 0 -58 7 -85 25 -26 18 -44 23 -62 19 -19 -5 -35 1 -64 25 -28 22 -49 31 -76 31 -26 0 -46 8 -71 30 -40 35 -47 36 -73 10 -17 -17 -28 -19 -87 -13 -75 6 -103 17 -103 38 0 23 -20 28 -40 10 -18 -16 -20 -16 -35 -1 -11 11 -34 16 -74 16 -45 0 -62 4 -76 20 -17 18 -31 20 -170 20 l-152 0 -11 -39z"/>',
            '</g>',
            '</svg>'
        );

        string contractImage = abi.encodePacked(
            "data:image/svg+xml; base64,",
            Base64.encode(svg)
        );
        
        bytes memory contractURI = abi.encodePacked(
            '{',
                '"name": "DAObi Banishment Memorial NFT",',
                '"description": "Commemorates the banishment of a DAObi Courtier for excessive idleness",',
                '"image":', contractImage, '"',
                '"external_link": "https://www.daobi.org/",'
            '}'
        );

        return string(
            abi.encodePacked(
                "data:image/svg+xml; base64,",
                Base64.encode(svg)
            )
        );
    }   

    function retargetDAO(address _newVault) public onlyRole(MANAGER_ROLE){
        DAOvault = _newVault;
        emit DAORetargeted(_newVault);
    }

    function retargetVote(address _newVote) public onlyRole(MANAGER_ROLE){
        dbvote = DaobiVoteContract(_newVote);
        emit VoteRetargeted(_newVote);
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
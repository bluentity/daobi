// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/Base64Upgradeable.sol";


contract DaobiAccountabilityURIs is Initializable, AccessControlUpgradeable, UUPSUpgradeable {

    bytes32 public constant USER_ROLE = keccak256("USER_ROLE");//can execute certain functions 
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE"); //contract admin (do not confuse with DEFAULT_ADMIN_ROLE)


    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() initializer public {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);      
        _grantRole(UPGRADER_ROLE, msg.sender);
        _grantRole(USER_ROLE, 0x0000000000000000000000000000000000000000);             
 
    } 

    function getContractURI() public view onlyRole(USER_ROLE) returns (string memory) { //returns on-chain contract-level metadata https://docs.opensea.io/docs/contract-level-metadata
        bytes memory URIdata = abi.encodePacked(
            '{',
                '"name": "DAObi Banishment Memorial NFT",',
                '"description": "Commemorates the banishing of a DAObi Courtier",',
                '"image": "', daobiLogo(), '",',
                '"external_link": "https://www.daobi.org/"'
            '}'
        );

        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64Upgradeable.encode(URIdata)
            )
        );
    }   

    function daobiLogo() public pure returns (string memory) { //returns an SVG of the Daobi logo
        bytes memory contractSVG = abi.encodePacked(            
            '<svg xmlns="http://www.w3.org/2000/svg" width="350" height="350" version = "1.0" viewBox="0 0 350 350" preserveAspectRatio="xMidYMid meet">',
            '<g transform="translate(0.000000,389.000000) scale(0.100000,-0.100000)" fill="#000000" stroke="none">',
            '<path d="M1972 2631 c-22 -72 -8 -131 32 -131 14 0 81 -33 103 -52 9 -7 36 -13 61 -13 58 0 69 -16 56 -81 -9 -48 -9 -48 -68 -66 -78 -24 -86 -32 -86 -85 0 -56 -29 -88 -91 -98 -37 -6 -56 -19 -120 -81 -42 -41 -85 -74 -94 -74 -10 0 -40 -22 -67 -50 -27 -27 -53 -50 -59 -50 -5 0 -43 -30 -85 -66 -72 -63 -77 -65 -115 -59 -34 6 -45 3 -75 -20 -32 -24 -39 -26 -59 -15 -21 11 -28 10 -56 -14 -24 -21 -39 -26 -58 -22 -88 21 -109 19 -187 -18 l-76 -36 -66 17 c-94 23 -204 62 -222 78 -8 7 -52 16 -100 20 -56 5 -91 13 -104 24 -22 20 -114 20 -127 -1 -14 -22 -4 -33 29 -33 42 -1 104 -59 101 -95 -3 -52 -2 -53 49 -46 37 5 70 0 136 -19 47 -14 94 -25 104 -25 10 0 28 -7 41 -16 24 -17 112 -24 361 -28 122 -1 126 -1 173 27 46 28 50 29 93 17 84 -24 195 8 247 70 10 12 25 19 33 16 14 -5 90 40 114 69 9 11 25 13 59 9 54 -6 62 0 81 59 13 42 52 66 75 47 19 -15 55 9 55 36 0 12 13 41 30 65 16 24 30 49 30 55 0 14 72 27 96 17 13 -5 16 -3 11 10 -4 10 -2 17 5 17 6 0 32 20 59 45 l48 45 -24 19 c-23 17 -23 19 -7 33 34 29 92 57 97 47 11 -17 21 -9 43 36 12 24 33 52 47 61 24 16 33 16 92 4 48 -9 67 -10 76 -1 6 6 20 11 31 11 27 -1 97 -44 110 -68 24 -42 95 -112 114 -112 11 0 38 -19 61 -42 31 -32 41 -51 41 -75 0 -18 -3 -33 -8 -33 -11 0 -32 -75 -21 -78 11 -4 12 -42 1 -42 -4 0 -13 5 -20 12 -9 9 -19 5 -44 -19 -30 -28 -69 -53 -82 -53 -3 0 -6 12 -6 28 l0 27 -15 -29 c-10 -18 -13 -41 -9 -65 7 -43 -9 -63 -47 -59 -20 3 -24 -2 -24 -24 0 -14 -4 -30 -8 -35 -17 -16 -101 -12 -133 8 -48 29 -74 25 -74 -11 0 -30 -13 -40 -25 -20 -4 6 -23 17 -43 25 -35 15 -36 15 -58 -12 -20 -26 -23 -26 -45 -12 -36 23 -68 29 -98 17 -14 -6 -64 -12 -111 -13 -104 -2 -192 -28 -183 -53 6 -19 88 -100 127 -126 14 -9 26 -25 26 -36 0 -23 18 -27 26 -5 10 24 34 17 52 -15 17 -30 18 -30 112 -32 52 -1 147 -1 210 1 112 3 116 4 146 33 40 38 87 50 199 52 99 1 129 15 167 76 11 19 26 30 39 30 24 0 89 45 89 62 0 5 11 19 24 29 13 10 38 45 56 76 18 32 44 70 58 85 22 24 24 32 16 59 -8 28 -6 36 18 59 14 15 31 47 37 71 7 24 18 55 25 69 7 14 16 45 19 70 6 42 4 47 -22 65 -23 15 -27 22 -18 35 8 14 2 31 -27 81 -21 35 -41 71 -45 79 -5 9 -22 15 -42 15 -27 0 -36 6 -47 28 -12 24 -19 27 -61 27 -35 0 -58 7 -85 25 -26 18 -44 23 -62 19 -19 -5 -35 1 -64 25 -28 22 -49 31 -76 31 -26 0 -46 8 -71 30 -40 35 -47 36 -73 10 -17 -17 -28 -19 -87 -13 -75 6 -103 17 -103 38 0 23 -20 28 -40 10 -18 -16 -20 -16 -35 -1 -11 11 -34 16 -74 16 -45 0 -62 4 -76 20 -17 18 -31 20 -170 20 l-152 0 -11 -39z"/>',
            '</g>',
            '</svg>'
        );

        return string(abi.encodePacked(
            "data:image/svg+xml;base64,",
            Base64Upgradeable.encode(contractSVG)
            )
        );
    }

    function generateSVG(address _target, address _accuser, address _chancellor, uint16 _numSupporters) private view returns (string memory)//generate on-chain SVG for metadata
    {       
        

        
        string[4] memory targetString;
        {
            targetString = sinifyAddress(_target);
        }
        string[4] memory accuserString;
        {
            accuserString = sinifyAddress(_accuser);
        }
        string[4] memory chancellorString;
        {
            chancellorString = sinifyAddress(_chancellor);
        }        
        string[2] memory dateString;
        {
            dateString = sinifyDate(block.timestamp);
        }

        string memory supportersHanja;
        {
            supportersHanja = numberToChinese(_numSupporters);
        }

        bytes memory svg = 
            bytes.concat(
                abi.encodePacked(  
                '<?xml version="1.0" encoding="UTF-8"?>',
                '<svg width="512" height="256" version="1.1" viewBox="0 0 135.47 67.733" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">',
                ' <defs>',
                '  <pattern id="pattern37489" patternTransform="matrix(.26994 0 0 .26033 17.198 4.2333)" xlink:href="#pattern36706"/>',
                '  <linearGradient id="linearGradient11609" x1="40" x2="63.568" y1="128" y2="127.81" gradientTransform="translate(-16.52 -13.98)" gradientUnits="userSpaceOnUse" spreadMethod="reflect">',
                '   <stop stop-color="#c8ab37" offset="0"/>',
                '   <stop stop-color="#71611f" offset="1"/>',
                '  </linearGradient>',
                '  <pattern id="pattern12163" width="47.048174" height="227.65577" patternTransform="translate(16.193 13.817)" patternUnits="userSpaceOnUse">',        
                '<path d="m12.343 227.15c-3.4282-0.28044-10.334-1.2352-11.599-1.6034-0.58952-0.17159-0.61588-5.7103-0.53121-111.62l0.089083-111.44 3.0102-0.60797c11.031-2.228 26.993-2.2711 39.487-0.10677 1.753 0.30368 3.3865 0.62358 3.6299 0.71088 0.35286 0.1265 0.44267 22.756 0.44267 111.54v111.38l-0.79681 0.17424c-7.373 1.6133-23.858 2.3831-33.732 1.575z" fill="url(#linearGradient11609)" stroke="#000" stroke-width=".35414"/>',
                '  </pattern>'
                ),
                abi.encodePacked(
                '  <pattern id="pattern36706" width="47.048176" height="227.65578" patternTransform="translate(16.193 13.817)" patternUnits="userSpaceOnUse">',
                '   <g transform="matrix(3.7795 0 0 3.7795 -16.193 -13.817)">',
                '    <rect transform="scale(.26458)" x="16.193" y="13.817" width="47.048" height="227.66" fill="url(#pattern12163)"/>',
                '    <circle cx="10.583" cy="12.171" r=".79375" fill="', timestampToRGB(), '" stroke="#000" stroke-linecap="round" stroke-width=".26458"/>',
                '    <path d="m10.051 12.171h-5.6905" fill="none" stroke="#000" stroke-width=".25585px"/>',
                '    <path d="m11.099 12.171 5.6339-2e-6" fill="none" stroke="#000" stroke-width=".25042px"/>',
                '    <circle cx="10.583" cy="55.562" r=".79375" fill="', timestampToRGB(), '" stroke="#000" stroke-linecap="round" stroke-width=".26458"/>',
                '    <path d="m10.051 55.563h-5.6884" fill="none" stroke="#000" stroke-width=".25581px"/>',
                '    <path d="m11.099 55.563 5.6339-2e-6" fill="none" stroke="#000" stroke-width=".25042px"/>',
                '   </g>',
                '  </pattern>'
                ),
                abi.encodePacked(
                ' </defs>',        
                '<g>',
                ' <rect width="135.47" height="67.733" fill="', timestampToRGB(), '" stroke="#000" stroke-width=".26458"/>',
                '</g>',
                '<rect x="4.4979" y="4.2333" width="127" height="59.267" ry="1.5385e-6" fill="url(#pattern37489)" stroke-width="0"/>',
                '<g fill="#000000" stroke="#000000" stroke-width="0" text-anchor="middle">',
                ' <text x="10.887571" y="32.662712" font-family="Arizonia" font-size="11.289px" text-align="center" writing-mode="tb-rl" style="text-orientation:upright" xml:space="preserve"><tspan x="10.887571" y="32.662712" font-family="MingLiU" font-size="11.289px" stroke-width="0">\u6d41\u653e\u4eea</tspan></text>',
                ' <g font-family="MingLiU" writing-mode="vertical-lr">',
                '  <text x="23.704588" y="18.88098" font-size="4.9389px" text-align="center" style="text-orientation:upright" xml:space="preserve"><tspan x="23.704588" y="18.88098" direction="rtl" font-size="4.9389px" stroke-width="0" writing-mode="vertical-lr">\u9010\u7e25</tspan></text>',
                '  <text x="21.637325" y="39.140129" direction="rtl" font-size="3.175px" text-align="center" style="text-orientation:upright" xml:space="preserve"><tspan x="21.637325" y="39.140129">', accuserString[0], '</tspan><tspan x="25.606075" y="39.140129">',accuserString[1], '</tspan></text>'                
                ),
                abi.encodePacked(
                '  <text x="34.178707" y="34.04089" direction="rtl" font-size="3.175px" text-align="center" style="text-orientation:upright" xml:space="preserve"><tspan x="34.178707" y="34.04089">', accuserString[2], '</tspan><tspan x="38.147457" y="34.04089">', accuserString[3], '</tspan></text>',
                '  <text x="48.925163" y="17.089352" direction="rtl" font-size="4.9389px" text-align="center" style="text-orientation:upright" xml:space="preserve"><tspan x="48.925163" y="17.089352" font-size="4.9389px" stroke-width="0">\u8a63</tspan></text>',
                '<text x="46.857906" y="36.383785" direction="rtl" font-size="3.175px" text-align="center" style="text-orientation:upright" xml:space="preserve"><tspan x="46.857906" y="36.383785">', targetString[0], '</tspan><tspan x="50.826656" y="36.383785">', targetString[1], '</tspan></text>'
                ),
                abi.encodePacked(
                '   <text x="59.674919" y="34.178707" direction="rtl" font-size="3.175px" text-align="center" style="text-orientation:upright" xml:space="preserve"><tspan x="59.674919" y="34.178707">', targetString[2], '</tspan><tspan x="63.643669" y="34.178707">', targetString[3], '</tspan></text>',                     
                '   <text x="74.283554" y="32.662716" direction="rtl" font-size="4.5861px" text-align="center" style="text-orientation:upright" xml:space="preserve"><tspan x="74.283554" y="32.662716" font-size="4px" stroke-width="0">\u548c', supportersHanja, '\u652f\u6301\u8005</tspan></text>', //supporters
                '   <text x="87.238396" y="18.74316" direction="rtl" font-size="4.9389px" text-align="center" style="text-orientation:upright" xml:space="preserve"><tspan x="87.238396" y="18.74316" font-size="4.9389px" stroke-width="0">\u65e5\u671f</tspan></text>'
                ),
                abi.encodePacked(
                '<text x="84.757675" y="36.383781" direction="rtl" font-size="3.5278px" text-align="center" style="text-orientation:upright" xml:space="preserve"><tspan x="84.757675" y="36.383781">',dateString[0], '</tspan><tspan x="89.167397" y="36.383781">', dateString[1], '</tspan></text>',
                '<text x="100.0554" y="44.928463" direction="rtl" font-size="9.1722px" text-align="center" style="text-orientation:upright" xml:space="preserve"><tspan x="100.0554" y="44.928463" font-size="9.1722px" stroke-width="0">\u76f8\u570b</tspan></text>',
                '<text x="110.11607" y="34.178707" direction="rtl" font-size="3.175px" text-align="center" style="text-orientation:upright" xml:space="preserve"><tspan x="110.11607" y="34.178707">', chancellorString[0], '</tspan><tspan x="114.08482" y="34.178707">', chancellorString[1], '</tspan></text>'
                ),
                abi.encodePacked(
                '<text x="123.20872" y="34.04089" direction="rtl" font-size="3.175px" text-align="center" style="text-orientation:upright" xml:space="preserve"><tspan x="123.20872" y="34.04089">', chancellorString[2], '</tspan><tspan x="127.17747" y="34.04089">', chancellorString[3], '</tspan></text>',
                    '</g>',
                    '</g>',
                    '<g fill="none" stroke="#c20000" stroke-linejoin="round" stroke-miterlimit="3.6">'
                ),
                abi.encodePacked(
                '<rect x="94.267" y="19.364" width="10.751" height="11.328" rx=".85988" ry="1.0687" stroke-width=".39166"/>',
                '<g stroke-width=".29375">',
                '<rect x="98.001" y="20.518" width="1.7935" height="5.7243" rx=".85988" ry="1.0687"/>',
                '<rect x="100.38" y="20.027" width="3.9554" height="10.22" rx="1.4249" ry=".55278"/>',
                '<rect x="101.19" y="23.663" width="1.1056" height="2.2848" rx=".52821" ry=".55278"/>',
                '<path d="m96.158 20.101v9.9254"/>',
                '<path d="m97.952 22.631 1.7689 0.09827"/>',
                '<path d="m98.099 24.375 1.818 0.04914"/>',
                '<path d="m94.912 28.747c-0.0869-2.102-0.22358-4.5599 0.72963-5.1248 0.9381-0.55591 1.0423-0.53854 1.494 0.52116 0.45881 1.0764 0.31269 4.7947 0.31269 4.7947"/>',
                '<path d="m95.207 20.755c0.27795 1.5809 0.1216 1.6156 0.90335 1.633 0.78174 0.01737 0.9037 0.06736 0.93809-0.13898l0.24321-1.4593"/>'
                ),
                abi.encodePacked(
                '<path d="m102.9 20.738c0.15635 3.7176 1.0771 7.3832 1.0771 7.3832"/>',
                '<path d="m102.96 21.45c0.67751-0.05212 1.0771-0.55591 1.0771-0.55591"/>',
                '<path d="m100.8 22.666c3.0054-0.24321 3.0922-0.19109 3.0922-0.19109"/>',
                '<path d="m103.62 23.917c-0.92072 2.7795-1.025 4.9684-1.025 4.9684"/>',
                '<path d="m100.97 27.34 1.7546-0.13898"/>',
                '</g>',
                '</g>',
                '</svg>'
                )
            );
        return string(
            abi.encodePacked(
                "data:image/svg+xml;base64,",
                Base64Upgradeable.encode(svg)
            )    
        );
         

    }    

    function generateURI(address _target, address _accuser, address _chancellor, uint16 _numSupporters, string memory _supporterList) public view onlyRole(USER_ROLE) returns(string memory) { //generate on-chain metadata        
                
        bytes memory dataURI = bytes.concat(
            abi.encodePacked(
                '{',
                    '"name": "The Banishing of ', StringsUpgradeable.toHexString(_target), '",', 
                    '"description": "Commemorates the banishment of', StringsUpgradeable.toHexString(_target), 'for excessive idleness",',
                    '"image": "', generateSVG(_target, _accuser, _chancellor, _numSupporters), '",',
                    '"external_url": "https://www.daobi.org/",'
            ),
            abi.encodePacked(
                    '"attributes": [',
                        '{',                            
                            '"trait_type": "Banished Courtier",',
                            '"value": "', StringsUpgradeable.toHexString(_target), '"',
                        '},',
                        '{',
                            '"display_type": "date",',
                            '"trait_type": "Banishment Date",',
                            '"value": "', StringsUpgradeable.toString(block.timestamp), '"',
                        '},'                        
            ),
            abi.encodePacked(            
                        '{',                            
                            '"trait_type": "Chief Accuser",',
                            '"value": "', StringsUpgradeable.toHexString(_accuser), '"',
                        '},',                        
                        '{',                            
                            '"trait_type": "DAObi Chancellor",',
                            '"value": "', StringsUpgradeable.toHexString(_chancellor), '"',
                        '},'
            ),
            abi.encodePacked(            
                        '{',
                            '"display_type": "number",',
                            '"trait_type": "Number of Supporters",',
                            '"value": "', StringsUpgradeable.toString(_numSupporters), '"',
                        '}',                                           
                    ']',
                '}'
            )
        );

        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64Upgradeable.encode(dataURI)
            )
        );


    }   

    //string utilities
    function sinifyAddress(address _address) public pure returns (string[4] memory) {
        string memory addressString = StringsUpgradeable.toHexString(_address);

        string[4] memory result;

        uint256 currentIndex = 0;

        //divisions needed for image format
        // Process the first nine characters
        result[0] = processSubstring(addressString, currentIndex, 9);
        currentIndex += 9;

        // Process the next nine characters
        result[1] = processSubstring(addressString, currentIndex, 9);
        currentIndex += 9;

        // Process the next twelve characters
        result[2] = processSubstring(addressString, currentIndex, 12);
        currentIndex += 12;

        // Process the remaining twelve characters
        result[3] = processSubstring(addressString, currentIndex, 12);

        return result;
    }

    function processSubstring(
        string memory str,
        uint256 startIndex,
        uint256 length
    ) private pure returns (string memory) {
        string memory result = "";
        for (uint256 i = startIndex; i < startIndex + length && i < bytes(str).length; i++) {
            bytes1 character = bytes(str)[i];
            string memory replacement = getReplacementCharacter(character);
            result = string(abi.encodePacked(result, replacement));
        }

        return result;
    }

    function getReplacementCharacter(bytes1 character) private pure returns (string memory) {
        if (character == "x" || character == "X") return "\u723B";
        else if (character == "0") return "\u7A7A";
        else if (character == "1") return "\u4E00";
        else if (character == "2") return "\u4E8C";
        else if (character == "3") return "\u4E09";
        else if (character == "4") return "\u56DB";
        else if (character == "5") return "\u4E94";
        else if (character == "6") return "\u516D";
        else if (character == "7") return "\u4E03";
        else if (character == "8") return "\u516B";
        else if (character == "9") return "\u4E5D";
        else if (character == "a" || character == "A") return "\u7532";
        else if (character == "b" || character == "B") return "\u4E59";
        else if (character == "c" || character == "C") return "\u4E19";
        else if (character == "d" || character == "D") return "\u4E01";
        else if (character == "e" || character == "E") return "\u620A";
        else if (character == "f" || character == "F") return "\u5DF1";
        else return "";
    }

    function sinifyDate(uint _number) public pure returns (string[2] memory) {
        string memory dateString = StringsUpgradeable.toString(_number);
        uint length = bytes(dateString).length;

        string[2] memory result;

        //divisions needed for image format
        // Process the first half
        result[0] = processSubstring(dateString, 0, (length/2));
        //result[0] = "probe";

        // Process the next half
        result[1] = processSubstring(dateString, (length/2), length);
        //result[1] = "test";

        return result;
    }

    function numberToChinese(uint256 number) public pure returns (string memory) {
        require(number >= 0 && number <= 65536, "Number should be between 0 and 65536.");

        if (number == 0) {
            return "";
        }

        string memory chineseValue;

        // Define the Chinese characters for digits
        string[10] memory digits = [
            "", "\u4E00", "\u4E8C", "\u4E09", "\u56DB", "\u4E94", "\u516D", "\u4E03", "\u516B", "\u4E5D"
        ];

        // Define the Chinese characters for powers of ten
        string[5] memory powersOfTen = [
            "", "\u5341", "\u767E", "\u5343", "\u4E07"
        ];

        uint256 num = number;

        // Process each digit from left to right
        for (uint256 i = 4; i > 0; i--) {
            uint256 divisor = 10 ** i;
            uint256 digit = num / divisor;
            num %= divisor;

            if (digit > 0) {
                // Add the digit and its corresponding power of ten
                chineseValue = string(abi.encodePacked(chineseValue, digits[digit], powersOfTen[i]));
            }
        }

        // Add the last digit if it's non-zero
        if (num > 0) {
            chineseValue = string(abi.encodePacked(chineseValue, digits[num]));
        }

        return chineseValue;
    }

    function timestampToRGB() public view returns (string memory) {
        bytes3 rgb = bytes3(uint24(block.timestamp % 2 ** 24));
        bytes16 hexChars = "0123456789ABCDEF";

        string memory result = "#";
        result = string(abi.encodePacked(result, hexChars[uint8(rgb[0] >> 4)], hexChars[uint8(rgb[0] & 0x0F)]));
        result = string(abi.encodePacked(result, hexChars[uint8(rgb[1] >> 4)], hexChars[uint8(rgb[1] & 0x0F)]));
        result = string(abi.encodePacked(result, hexChars[uint8(rgb[2] >> 4)], hexChars[uint8(rgb[2] & 0x0F)]));

        return result;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(UPGRADER_ROLE)
        override
    {}

}
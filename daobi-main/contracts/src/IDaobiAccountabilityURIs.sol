// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IDaobiAccountabilityURIs {
  function DEFAULT_ADMIN_ROLE (  ) external view returns ( bytes32 );
  function PAUSER_ROLE (  ) external view returns ( bytes32 );
  function UPGRADER_ROLE (  ) external view returns ( bytes32 );
  function USER_ROLE (  ) external view returns ( bytes32 );
  function daobiLogo (  ) external pure returns ( string memory);
  function generateURI ( address _target, address _accuser, address _chancellor, uint16 _numsupporters, string memory _supporterList) external view returns ( string memory );
  //function generateURI ( address _target, address _accuser, address _chancellor) external view returns ( string memory );
  function getContractURI (  ) external view returns ( string memory );
  function getRoleAdmin ( bytes32 role ) external view returns ( bytes32 );
  function grantRole ( bytes32 role, address account ) external;
  function hasRole ( bytes32 role, address account ) external view returns ( bool );
  function initialize (  ) external;
  function pause (  ) external;
  function paused (  ) external view returns ( bool );
  function proxiableUUID (  ) external view returns ( bytes32 );
  function renounceRole ( bytes32 role, address account ) external;
  function revokeRole ( bytes32 role, address account ) external;
  function supportsInterface ( bytes4 interfaceId ) external view returns ( bool );
  function unpause (  ) external;
  function upgradeTo ( address newImplementation ) external;
  function upgradeToAndCall ( address newImplementation, bytes memory data ) external;
}

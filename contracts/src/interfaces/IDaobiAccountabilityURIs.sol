// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IDaobiAccountabilityURIs {
  function generateURI(address _target, address _accuser, address _chancellor, uint16 _numsupporters, string memory _supporterList) external view returns (string memory);
  function getContractURI() external view returns (string memory);
}

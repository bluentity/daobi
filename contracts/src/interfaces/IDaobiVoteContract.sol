// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IDaobiVoteContract is IERC721 {
  function burn(address _target) external;
  function assessVotes(address _voter) external view returns (uint160);
  function checkStatus(address _voter) external view returns (bool);
  function getAlias(address _voter) external view returns (bytes32);
  function getVoteDate(address _voter) external view returns (uint32);
  function seeBallot(address _voter) external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IDAObi is IERC20 {
  function CHANCELLOR_ROLE() external view returns (bytes32);
  function DAOvault() external view returns (address);
  function chancellor() external view returns (address);
  function sealContract() external view returns (address);
  function swapFee() external view returns (uint24);
  function uniswapRouter() external view returns (address);
  function votingContract() external view returns (address);
}

#DAObi Contract Repository

# Overview

The current DAObi token contract is DAObiContract2.sol.  This is a basic ERC-20 contract.

The proposed feature upgrade consists of three contracts: DAObiContract3, DaobiVoteContract, and DaobiChancellorsSeal.  

DaobiVoteContract is a modified ERC-721 contract whose tokens (Daobi Voting Token, DBvt) enable a given wallet to cast votes for other token holders.  A wallet designated as a MINTER_ROLE can issue new voting tokens, while the BURNER_ROLE can destroy them.  Users can also burn their own tokens.  The tokens are non-transferable, and a given wallet can only hold a single token.  

In order to vote, a token holder must execute the register() function in the DaobiVoteContract, then execute the vote() function for their desired candidate.  A token holder can un-register by executing the recluse() function, but can re-register at any time as long as they do not burn their DBvt.  

DAObiContract3 is an upgrade (UUPS) of DAObiContract2.  It makes two major changes: it allows for wallets holding a Daobi Vote Token to make claims to the chancellorship (CHANCELLOR_ROLE) and it allows successful claimants to mint new Daobi tokens.

The mint() command is NOT the standard ERC-20 mint function.  Minting a given token amount does the following:
1. The specified amount of new Daobi tokens are created and assigned to the contract.
2. These tokens are naively traded for the native chain token (MATIC on Polygon) with the proceeds of the trade going to the DAObi DAO vault
3. 5% of this value of new Daobi tokens are also created and sent to the DAObi DAO vault.

Additionally, the chancellor can claim a salary in newly minted Daobi tokens every 24 hours (86400 seconds).  This value is adjustable by the TREASURER_ROLE of the token contract.  Reassigning the CHANCELLOR_ROLE does not alter the salary claim timer in any way.  The amount and interval of the salary is adjustable.

DaobiChancellorSeal is a modified ERC-721.  It is non-transferable except by a specified DAOBI_CONTRACT address, which...should be the address of the Daobi token contract.  When a wallet makes a successful claim for the Chancellorship, the DAObi contract transfers the NFT Seal.

# Deployment Instructions

1. Upload files and URIs for the Voting Token and Chancellor Seal NFTs.
2. Deploy DaobiVoteContract.sol using the ethers.deployProxy(kind: 'uups') command
3. Execute the setURI() command of the deployed DaobiVoteContract with the address of the voting token NFT as the argument.
4. Deploy DAObiContract3.sol using the ethers.upgradeProxy(kind: 'uups') command to upgrade the existing token contract.
5. Execute DAObiContract3.retargetVoting() with the address of DaobiVoteContract as an argument.
6. Execute DAobiVoteContract3.targetDaobi() with the address of the token contract as an argument.
7. Deploy DaobiChancellorsSeal.sol using the ethers.deployProxy(kind: 'uups') command
8. Execute the DaobiChancellorsSeal.setURI() function with the seal NFT URI address as the argument.
9. Execute the DaobiChancellorsSeal.targetDaobiContract function with the address of DAObiContract3 as the argument.
10. Execute the DAObiContract3.retargetSeal() function with the Daobi Chancellor Seal contract address as the argument.
11. Set the minimum token requirement to vote using the DaobiVoteContract.setMinimumTokenReq() command.  Remember the typical ERC-20 contract uses 18 decimals.
12. Run the DAObiContract3.updateContract() command to initialize the upgraded contract's remaining required values.
13. Use the DaobiChancellorSeal.mint() function to mint the seal to a valid non-zero address
14. Unpause the DAObiContract3 by executing its unpause() function.

Once all this is done, use the DaobiVoteContract.mint() function to add voters

# Rules

1. Holders of a Daobi Vote Token (DBvt) who have executed the register() function of the Daobi Vote Contract may vote for other registered DBvt holders, by executing the vote() command of that contract.
2. A DBvt holder may execute the makeClaim() function of the Daobi token contract.  If his vote total EXCEEDS the current Chancellor, he becomes the new Chancellor.
3. The Chancellor may mint DAObi tokens (DB) into the liquidity pool or claim their salary as described above.
4. While the Chancellor cannot directly abdicate, he may de-register by executing the recluse() function of the Daobi Vote Contract.  This effectively sets his vote total to zero, meaning anyone with at least one vote can successfully claim chancellorship from the Daobi Token Contract.
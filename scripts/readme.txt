Execute all "deploy" scripts using 

npx hardhat run

deploy_daobi and upgrade_daobi should be run first, after that it doesn't matter.  Ensure you note the PROXY address of each contract, it will be output to the console.

Once all contracts are deployed, input the proxy contract addresses into the declarations in daobi_initialize and execute.  Should re-check the NFT metadata URIs as well, although they currently point to *something*.

This script occasionally failed in testing because of timing issues with unpausing contracts, if this happens you can just re-run it.
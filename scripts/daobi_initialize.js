const { ethers } = require("hardhat");

async function main() {
    // Contract address - replace with your deployed contract address
    const DAOBI_CONTRACT_ADDRESS = "0x98C6203340F1A76eCF9b302c009aAa5d9C7f0603";
    const VOTE_CONTRACT_ADDRESS = "0x08501aD58B1522Cb529bEd0E9b02Cfd24403A744";
    const SEAL_CONTRACT_ADDRESS = "0x9E1b60C05188EC465Bf25408Cb6f78ea537CCb81";
    const ACCOUNTABILITY_CONTRACT_ADDRESS = "0x35c34f4b771a84ab53d2284dcf3DE61214D8f938";
    const ACCURI_CONTRACT_ADDRESS = "0x3a023650172ee453fBB29D27Ad0cF01DF8Bdd89A";

    const DAOBI_VAULT_ADDRESS = "0x05cF4dc7e44e5560a2B5d999D675BC626C127f6E"; //mainnet vault

    const VOTE_TOKEN_URI = "https://bafkreidzvfzwb5wlvfty5r6csvpbwglhybaokfccr7hoqlpmz5ze4aybie.ipfs.nftstorage.link/"; //"Courtier's Token", check for correctness.
    const SEAL_TOKEN_URI = "https://indigo-intellectual-bobcat-149.mypinata.cloud/ipfs/QmVgZeQuoCX7MBU8tBzHDAjynwYq3zXthkgXtFg9UPyB3T"; //check for correctness
    const PROPERTY_REQ = ethers.parseEther("10");

    const TREASURER_ROLE = "0x3496e2e73c4d42b75d702e60d9e48102720b8691234415963a5a857b86425d07";

    // Get contract instances
    const DAObi = await ethers.getContractFactory("DAObi");
    const daobi = DAObi.attach(DAOBI_CONTRACT_ADDRESS);

    const DaobiVotecontract = await ethers.getContractFactory("./contracts/src/DaobiVoteContract2.sol:DaobiVoteContract");
    const dbvote = DaobiVotecontract.attach(VOTE_CONTRACT_ADDRESS);

    const DaobiChancellorsSeal = await ethers.getContractFactory("DaobiChancellorsSeal");
    const dbseal = DaobiChancellorsSeal.attach(SEAL_CONTRACT_ADDRESS);

    const DaobiAccountability = await ethers.getContractFactory("DaobiAccountability");
    const dbacc = DaobiAccountability.attach(ACCOUNTABILITY_CONTRACT_ADDRESS);

    const DaobiAccountabilityURIs = await ethers.getContractFactory("DaobiAccountabilityURIs");
    const dburi = DaobiAccountabilityURIs.attach(ACCURI_CONTRACT_ADDRESS);

    const [signer] = await ethers.getSigners();
    const CALLER_ADDRESS = await signer.getAddress();
    console.log("Caller address:", CALLER_ADDRESS);

    async function unpauseContract(contract, name) {
        try {
            console.log(`Attempting to unpause ${name}...`);
            const unpauseTx = await contract.unpause();
            await unpauseTx.wait(2);
            console.log(`${name} unpaused successfully`);
        } catch (error) {
            if (error.message.includes("not paused")) {
                console.log(`${name} is already unpaused, continuing...`);
            } else {
                console.log(`Unexpected error unpausing ${name}:`, error.message);
            }
        }
     } 


    try {
        console.log("Executing functions...");  
        
        await unpauseContract(daobi, "DAObi");
        await unpauseContract(dbvote, "DBVote");
        await unpauseContract(dbseal, "DBSeal");
        await unpauseContract(dbacc, "DBAcc");
        await unpauseContract(dburi, "DBAccURI");

        // Grant Treasurer Role to signer (script caller)
        console.log("Granting DAObi treasurer role...");
        const tx0 = await daobi.grantRole(TREASURER_ROLE, CALLER_ADDRESS);
        console.log("Waiting for transaction to be mined...");
        await tx0.wait(2); // Wait for 2 block confirmations
        console.log("Role Granted - transaction mined");        
        
        // Link DAObi and Vote
        console.log("Targeting Vote Contract...");
        const tx1 = await daobi.retargetVoting(VOTE_CONTRACT_ADDRESS);
        await unpauseContract(daobi, "DAObi");
        console.log("Waiting for transaction to be mined...");
        await tx1.wait(1); // Wait for 2 block confirmations
        console.log("Vote contract linked successfully - transaction mined");

        // Link DAObi and Seal
        console.log("Targeting Seal Contract...");
        const tx2 = await daobi.retargetSeal(SEAL_CONTRACT_ADDRESS);
        await unpauseContract(daobi, "DAObi");
        console.log("Waiting for transaction to be mined...");
        await tx2.wait(1); // Wait for 2 block confirmations
        console.log("Seal contract linked successfully - transaction mined");

        // Link Vote and DAObi
        console.log("Targeting DAObi Token Contract to Vote...");
        const tx3 = await dbvote.targetDaobi(DAOBI_CONTRACT_ADDRESS);
        console.log("Waiting for transaction to be mined...");
        await tx3.wait(1); // Wait for 2 block confirmations
        console.log("Token contract linked successfully - transaction mined");

        //Set Vote Token URI
        console.log("Setting Vote Token URI...");
        const tx4 = await dbvote.setURI(VOTE_TOKEN_URI);
        console.log("Waiting for transaction to be mined...");
        await tx4.wait(1); // Wait for 2 block confirmations
        console.log("Vote URI - transaction mined");

        //Set Vote Token Minimum DAObi Token Req
        console.log("Setting Minimum Token Balance to Vote...");
        const tx5 = await dbvote.setMinimumTokenReq(PROPERTY_REQ);
        console.log("Waiting for transaction to be mined...");
        await tx5.wait(1); // Wait for 2 block confirmations
        console.log("Minimum Token Balance set successfully - transaction mined");

         //Target DAObi contract from Seal
         console.log("Targeting DAObi from Seal...");
         const tx6 = await dbseal.targetDaobiContract(DAOBI_CONTRACT_ADDRESS);
         console.log("Waiting for transaction to be mined...");
         await tx6.wait(1); // Wait for 2 block confirmations
         console.log("DAObi linked from seal contract - transaction mined");
         
         //Set Seal Token URI
         console.log("Setting Seal Token URI...");
         const tx7 = await dbseal.setURI(SEAL_TOKEN_URI);
         console.log("Waiting for transaction to be mined...");
         await tx7.wait(1); // Wait for 2 block confirmations
         console.log("Seal URI - transaction mined");    

        //Configure Accountability Contract
        console.log("Configuring Accountability Contract...");
        const tx8 = await dbacc.retargetDAO(DAOBI_VAULT_ADDRESS);
        const tx9 = await dbacc.retargetVote(VOTE_CONTRACT_ADDRESS);
        const tx10 = await dbacc.retargetURIgen(ACCURI_CONTRACT_ADDRESS);
        const tx11 = await dbacc.retargetDAObi(DAOBI_CONTRACT_ADDRESS);
        const tx12 = await dbacc.adjust(5, 30, 40, 1000 * 10 ** 18, 7, 3, 1); //adjust(uint16 _min, uint16 _max, uint8 _fee, uint256 _cost, uint8 _idle, uint8 _response, uint8 _stale), also see line 82 of Accountability contract
        console.log("Waiting for transaction to be mined...");
        await tx12.wait(1) //wait for 2 block confirmations
        console.log("Accountabiliyt Contact Configured - transaction mined")

        //should probably put some summary outputs down here but

    } catch (error) {
        console.error("Error executing functions:", error);
        if (error.transaction) {
            console.error("Failed transaction:", error.transaction);
        }
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
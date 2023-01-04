const hre = require("hardhat");
const { ethers } = require("hardhat"); 
const fs = require('fs');

const erc721ABI = JSON.parse(fs.readFileSync("./artifacts/contracts/test_contracts/TestERC721.sol/TestERC721.json")).abi; 

async function main()
{  
    const [signer] = await ethers.getSigners();

    const challengeToClaimAddress = "0xa758C748A6e9907A79456B0A5d9Ed67cd95073CC"; // mumbai
    const tokenAddress = "0x34a543c3f84Ea167DF84d5ed0a80A0Ce9916FF42"; // mumbai
    const to = signer.address;
    const amount = 5;

    const tokenContract = new ethers.Contract(tokenAddress, erc721ABI, signer); 
    await tokenContract.setApprovalForAll(challengeToClaimAddress, true);

    for(let i=0; i<amount; i++){  
        const mintTx = await tokenContract.mint(to); 
        const mintRc = await mintTx.wait();
        const [mintEv] = mintRc.events;
        const tokenId = mintEv.args.tokenId.toNumber();
        console.log("Minted tokenId:", tokenId);
    }
 
}
 
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

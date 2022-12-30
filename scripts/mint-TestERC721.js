const hre = require("hardhat");
const { ethers } = require("hardhat"); 
const fs = require('fs');

const erc721ABI = JSON.parse(fs.readFileSync("./artifacts/contracts/test_contracts/TestERC721.sol/TestERC721.json")).abi; 

async function main()
{  
    const [signer] = await ethers.getSigners();

    const tokenAddress = "0x8592848CFdA5E0D787C36294C17d10b88b2F1bd9"; // mumbai
    const to = signer.address;
    const amount = 5;

    const tokenContract = new ethers.Contract(tokenAddress, erc721ABI, signer); 
    
    for(let i=0; i<amount; i++){
        const mintTx = await tokenContract.mint(to); 
        const mintRc = await mintTx.wait();
        const [mintEv] = mintRc.events;
        const tokenId = mintEv.args.tokenId.toNumber();
        console.log("Minted tokenId:", tokenId);
    }
 
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

const hre = require("hardhat");
const { ethers } = require("hardhat"); 
const CTC = require("./ChallengeToClaim");
const fs = require('fs');
require('dotenv').config();
 
async function main()
{  
    const [signer] = await ethers.getSigners();

    const challengeToClaimAddress = "0xa758C748A6e9907A79456B0A5d9Ed67cd95073CC"; // mumbai
    const chainId = await hre.network.provider.send('net_version', []);
    const tokenAddress = "0x34a543c3f84Ea167DF84d5ed0a80A0Ce9916FF42"; // mumbai
    //const tokenId = 1;
    //const infoURL = "http://shorturl.at/pJNUY";
    //const secretKey = ethers.utils.formatBytes32String(process.env.SecretForERC21_1);
    //const tokenId = 2;
    //const infoURL = "";
    //const secretKey = ethers.utils.formatBytes32String("2");
    const tokenId = 3;
    const infoURL = "http://shorturl.at/pzHJK";
    const secretKey = ethers.utils.formatBytes32String(process.env.SecretForERC21_3);
 
    const signature = await CTC.makeChallengeERC721(challengeToClaimAddress, chainId, signer, tokenAddress, tokenId, infoURL, secretKey);
        
    console.log("Challenge created with signature:", signature, "and secret:", secretKey); 
}
 
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

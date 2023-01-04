const { ethers } = require("hardhat"); 
const CTC = require("./ChallengeToClaim");
require('dotenv').config();
 
async function main()
{  
    const [signer, account1] = await ethers.getSigners();

    const challengeToClaimAddress = "0xa758C748A6e9907A79456B0A5d9Ed67cd95073CC"; // mumbai
    const signature = "0x902b33c2193b033e97261c74b65a7350087cac52d8456a290d93c713b6763d647899014f3dfc4edcade8f434c9f5368018de49da925615d79d0dc14524f073771b";
    const secretKey = ethers.utils.formatBytes32String("2"); //"0x3200000000000000000000000000000000000000000000000000000000000000";
 
    await CTC.claim(challengeToClaimAddress, account1, secretKey, signature);
    
    await new Promise(res => setTimeout(() => res(null), 5000));
    
    const challenge = await CTC.getChallenge(challengeToClaimAddress, account1, signature);
 
    console.log(challenge);
}
 
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

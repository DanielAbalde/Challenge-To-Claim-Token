const { expect } = require("chai");
const { utils } = require("ethers");
const { ethers } = require("hardhat"); 
const fs = require('fs');

let account0, account1, account2, account3;
let challengeContract, erc721Contract, erc1155Contract, erc20Contract, signContract; 
let ERC712_DOMAIN_TYPE, CHALLENGE_DOMAIN_TYPE;
let tokens;
const erc721ABI = JSON.parse(fs.readFileSync("./artifacts/@openzeppelin/contracts/token/ERC721/IERC721.sol/IERC721.json")).abi; 
const erc1155ABI = JSON.parse(fs.readFileSync("./artifacts/@openzeppelin/contracts/token/ERC1155/IERC1155.sol/IERC1155.json")).abi; 
const erc20ABI = JSON.parse(fs.readFileSync("./artifacts/@openzeppelin/contracts/token/ERC20/IERC20.sol/IERC20.json")).abi; 

describe("ChallengeToClaim", function () {
  
  describe("Initialize", async function(){
    it("Deploy ", async function ()
    {
      [account0] = await ethers.getSigners();  
    
      account1 = ethers.Wallet.createRandom().connect(ethers.provider);
      await account0.sendTransaction({ to: account1.address, value: utils.parseUnits("1000", "ether") });
      account2 = ethers.Wallet.createRandom().connect(ethers.provider);
      await account0.sendTransaction({ to: account2.address, value: utils.parseUnits("1000", "ether") });
      account3 = ethers.Wallet.createRandom().connect(ethers.provider);
      await account0.sendTransaction({ to: account3.address, value: utils.parseUnits("1000", "ether") });

      const chainId = await hre.network.provider.send('net_version', []);
     
      erc721Contract = await deploy("TestERC721");
      erc1155Contract = await deploy("TestERC1155");
      erc20Contract = await deploy("TestERC20");
  
      challengeContract = await deploy("ChallengeToClaim");

      console.log("account0", account0.address);
      console.log("account1", account1.address);
      console.log("account2", account2.address);
      console.log("account3", account3.address);
      console.log("ChallengeToClaim", challengeContract.address);
      console.log("ERC721", erc721Contract.address);
      console.log("ERC1155", erc1155Contract.address);
      console.log("ERC20", erc20Contract.address);
      console.log("chainId", chainId);
      console.log();

      function logEvent(e, k){ console.log("          ?? " + e.event + "! (" + reduceAddress(k) +")"); }
      await challengeContract.on("NewChallenge", (challengeKey, event) => logEvent(event, challengeKey));
      await challengeContract.on("ChallengeSolved", (challengeKey, event) => logEvent(event, challengeKey));
  
      ERC712_DOMAIN_TYPE = {
        name: "ChallengeToClaim",
        version: "1",
        chainId: chainId,
        verifyingContract: challengeContract.address
      };
  
      CHALLENGE_DOMAIN_TYPE = [
        { name: 'owner', type: 'address' },
        { name: 'contractAddress', type: 'address' },
        { name: 'tokenId', type: 'uint256' },
        { name: 'amount', type: 'uint256' },
        { name: 'nonce', type: 'uint256' },
        { name: 'secretKey', type: 'bytes32' } 
      ];
     
      
      tokens = [];
      
      function logTransfer(standard, id, from, to){
        console.log("          ?? Transfered " + standard + "! id: " + id + ", from '" + getOwnerName(from) + "' to '" + getOwnerName(to) + "'");
      }
    
      await ethers.provider.on("block", async (blockNumber) => { 
        const transfer721Event = await erc721Contract.queryFilter("Transfer", blockNumber,  blockNumber); 
        for(let i=0; i<transfer721Event.length; i++){
          const transfer721Event0 = transfer721Event[i];
          if(transfer721Event0){
            const from = transfer721Event0.args.from; 
            if(from !== ethers.constants.AddressZero){
              const to = transfer721Event0.args.to;
              const id = transfer721Event0.args.tokenId;
              logTransfer("ERC721", id, from ,to); 
              const token = findTokenERC721(from, id);
              token.owner = getOwner(to);
            } 
          }
        }
      
        const approveEvent = await erc721Contract.queryFilter("Approval", blockNumber,  blockNumber); 
        for(let i=0; i<approveEvent.length; i++){
          const approveEvent0 = approveEvent[i];
          if(approveEvent0){
            const owner = approveEvent0.args.owner;
            const approved = approveEvent0.args.approved;
            const id = approveEvent0.args.tokenId;
            //console.log("Approval " + id + " owner " + owner + " approved " + approved);
          }
        }
        const transferSingle1155Event = await erc1155Contract.queryFilter("TransferSingle", blockNumber,  blockNumber); 
        for(let i=0; i<transferSingle1155Event.length; i++){
          const transferSingle1155Event0 = transferSingle1155Event[i];
          if(transferSingle1155Event0){
            const from = transferSingle1155Event0.args.from; 
            if(from !== co.ZERO_ADDRESS){
              const to = transferSingle1155Event0.args.to;
              const id = transferSingle1155Event0.args.id;
              logTransfer("ERC1155", id, from ,to); 
              const token = findTokenERC1155(from, id);
              token.owner = getOwner(to);
            } 
          }
        }

        const transfer20Event = await erc20Contract.queryFilter("Transfer", blockNumber,  blockNumber); 
        for(let i=0; i<transfer20Event.length; i++){
          const transfer20Event0 = transfer20Event[i];
          if(transfer20Event0){
            const from = transfer20Event0.args.from; 
            if(from !== co.ZERO_ADDRESS){
              const to = transfer20Event0.args.to;
              const value = transfer20Event0.args.value;
              logTransfer("ERC20", value, from ,to); 
              const token = findTokenERC20(from);
              token.owner = getOwner(to);
            } 
          }
        }
      });
   
    });
    
    it("Mint and approve ERC721", async function() {
    
      for(let i = 1; i <= 10; i++) { 
        const responseA = await erc721Contract.connect(account1).mint(account1.address);
        const receiptA = await responseA.wait();
        const [transferEventA] = receiptA.events; 
        const id = transferEventA.args.tokenId.toNumber();
        expect(id).to.equal(i); 
        const approveA = await erc721Contract.connect(account1).approve(challengeContract.address, id);
        await approveA.wait();
        tokens.push(tokenize(account1, erc721Contract, id, 1));
      }
      for(let i = 11; i <= 20; i++) { 
        const responseB = await erc721Contract.connect(account2).mint(account2.address);
        const receiptB = await responseB.wait();
        const [transferEventB] = receiptB.events; 
        const id = transferEventB.args.tokenId.toNumber();
        expect(id).to.equal(i); 
        const approveB = await erc721Contract.connect(account2).approve(challengeContract.address, id);
        await approveB.wait();
        tokens.push(tokenize(account2, erc721Contract, id, 1));
      }
    });
    
    it("Mint and approve ERC1155", async function() {
    
      for(let i = 1; i <= 10; i++) { 
        const amount = 10;
        const responseA = await erc1155Contract.connect(account1).mint(account1.address, amount);
        const receiptA = await responseA.wait();
        const [transferEventA] = receiptA.events;  
        const id = transferEventA.args.id.toNumber(); 
        expect(id).to.equal(i); 
        const approveA = await erc1155Contract.connect(account1).setApprovalForAll(challengeContract.address, true);
        await approveA.wait();
        tokens.push(tokenize(account1, erc1155Contract, id, amount));
      } 
      for(let i = 11; i <= 20; i++) { 
        const amount = 10;
        const responseB = await erc1155Contract.connect(account2).mint(account2.address, amount);
        const receiptB = await responseB.wait();
        const [transferEventB] = receiptB.events; 
        const id = transferEventB.args.id.toNumber();
        expect(id).to.equal(i); 
        const approveB = await erc1155Contract.connect(account2).setApprovalForAll(challengeContract.address, true);
        await approveB.wait();
        tokens.push(tokenize(account2, erc1155Contract, id, amount));
      }
    });
      
    it("Mint and approve ERC20", async function() {
    
      const addrs = [account0, account1, account2];
      const amount = 100;
  
      for(var i=0; i<addrs.length; i++){
        const sig = addrs[i];
        const add = sig.address;
        const tx = await erc20Contract.mint(add, amount);
        const re = await tx.wait();
        const ba = await erc20Contract.balanceOf(add);
        expect(ba.toNumber()).to.equal(amount);  
        const approve = await erc20Contract.connect(sig).approve(challengeContract.address, 999999999);
        await approve.wait(); 
        tokens.push(tokenize(sig, erc20Contract, 0, amount));
      }
   
    });
  
    after("Log", async function () { 
      await logAccount(account0);
      await logAccount(account1);
      await logAccount(account2);
      await logAccount(account3);
      console.log("");
    }); 
  });
 
  describe("Signing", async function(){ 
    it("Verify signature", async function() 
    { 
      const token = tokens[0];
      const secretKey = ethers.utils.randomBytes(32);
      const issuer = token.owner; 
      const signature = await signChallenge(issuer, token.address, token.tokenId, token.amount, secretKey); 

      const value = await challengeToSign(issuer, token.address, token.tokenId, token.amount, secretKey);
      const recoveredAddress = ethers.utils.verifyTypedData(ERC712_DOMAIN_TYPE, typesToSign(), value, signature);
      expect(recoveredAddress).to.be.equal(issuer.address);
    });
    it("Verify signature with different secretKey should fail", async function() 
    { 
      const token = tokens[1];
      const secretKey = stringToBytes32(":)"); 
      const issuer = token.owner; 
      const signature = await signChallenge(issuer, token.address, token.tokenId, token.amount, secretKey); 

      const secretKeyBad = stringToBytes32(":(");
      const value = await challengeToSign(issuer, token.address, token.tokenId, token.amount, secretKeyBad);
      const recoveredAddress = ethers.utils.verifyTypedData(ERC712_DOMAIN_TYPE, typesToSign(), value, signature);
      expect(recoveredAddress).to.not.equal(issuer.address);
    });
  });
 
  describe("Execute", async function(){
    let lastSecretKey;
    let lastChallengeSignature;

    describe("Single", async function()
    {
      
      it("Not an owner makes a challenge ERC721", async function() 
      { 
        const token = findTokens(account1.address, erc721Contract.address)[0];
        const secretKey = stringToBytes32("code to claim"); 
        const issuer = account0; 
        const signature = await signChallenge(issuer, token.address, token.tokenId, token.amount,  secretKey); 
   
        await expect(challengeContract.connect(issuer).makeSafeChallengeERC721(token.address, token.tokenId, "", signature)).
        to.be.revertedWith('ChallengeToClaim: not the owner');
     
        await new Promise(res => setTimeout(() => res(null), 5000));
      });
      
      
      it("Account1 make challenge ERC721", async function() 
      { 
        const token = findTokens(account1.address, erc721Contract.address)[0];
        const secretKey = stringToBytes32("code to claim"); 
        const issuer = token.owner;  
        const signature = await signChallenge(issuer, token.address, token.tokenId, token.amount, secretKey); 
  
        lastSecretKey = secretKey;
        lastChallengeSignature = signature;
  
        await challengeContract.connect(issuer).makeChallengeERC721(token.address, token.tokenId, "", signature);
        await expect(challengeContract.connect(issuer).claim(secretKey, signature))
              .to.be.revertedWith('ChallengeToClaim: Owner can not claim its own challenge');
  
        await new Promise(res => setTimeout(() => res(null), 5000));
      });
  
      it("Account3 claim previous challenge ERC721", async function() 
      {   
        const key = getChallengeKeyFromSignature(lastChallengeSignature);
  
        await expect(challengeContract.connect(account3).claim(lastSecretKey, lastChallengeSignature))
              .to.emit(challengeContract, 'ChallengeSolved').withArgs(key);
  
        const challenge = await challengeContract.getChallenge(key);
        expect(challenge.IsClaimed).to.be.true; 
  
        const tokenContract = new ethers.Contract(challenge.ContractAddress, erc721ABI, account3); 
        const newOwner = await tokenContract.ownerOf(challenge.TokenId);
        expect(newOwner).to.be.equal(account3.address);
        
        await new Promise(res => setTimeout(() => res(null), 5000)); 
      });
      
      
      it("Not an owner makes a challenge ERC1155", async function() 
      { 
        const token = findTokens(account1.address, erc1155Contract.address)[0];
        const secretKey = stringToBytes32("code to claim"); 
        const issuer = account0;
        const signature = await signChallenge(issuer, token.address, token.tokenId, token.amount, secretKey); 
   
        await expect(challengeContract.connect(issuer).makeSafeChallengeERC1155(token.address, token.tokenId, token.amount, "", signature)).
        to.be.revertedWith('ChallengeToClaim: not the owner');
     
        await new Promise(res => setTimeout(() => res(null), 5000));
      });
      
      
      it("Account1 make challenge ERC1155", async function() 
      { 
        const token = findTokens(account1.address, erc1155Contract.address)[0];
        const secretKey = stringToBytes32("code to claim"); 
        const issuer = token.owner; 
        const signature = await signChallenge(issuer, token.address, token.tokenId, token.amount, secretKey); 
  
        lastSecretKey = secretKey;
        lastChallengeSignature = signature;
  
        await challengeContract.connect(issuer).makeChallengeERC1155(token.address, token.tokenId, token.amount, "", signature);
        await expect(challengeContract.connect(issuer).claim(secretKey, signature))
              .to.be.revertedWith('ChallengeToClaim: Owner can not claim its own challenge');
  
        await new Promise(res => setTimeout(() => res(null), 5000));
      });
  
      it("Account3 claim previous challenge ERC1155", async function() 
      {   
        const key = getChallengeKeyFromSignature(lastChallengeSignature);
      
        await expect(challengeContract.connect(account3).claim(lastSecretKey, lastChallengeSignature))
              .to.emit(challengeContract, 'ChallengeSolved').withArgs(key);
  
        const challenge = await challengeContract.getChallenge(key);
        expect(challenge.IsClaimed).to.be.true; 
  
        const tokenContract = new ethers.Contract(challenge.ContractAddress, erc1155ABI, account3); 
        const balance = await tokenContract.balanceOf(account3.address, challenge.TokenId);
        expect(balance >= challenge.Amount).to.be.true;
        
        await new Promise(res => setTimeout(() => res(null), 5000)); 
      });
      
      
      it("Not an owner makes a challenge ERC20", async function() 
      { 
        const token = findTokens(account2.address, erc20Contract.address)[0];
        token.amount = 9999;
        const secretKey = stringToBytes32("code to claim"); 
        const issuer = account1; 
        const signature = await signChallenge(issuer, token.address, token.tokenId, token.amount, secretKey); 
   
        await expect(challengeContract.connect(issuer).makeSafeChallengeERC20(token.address, token.amount, "", signature)).
        to.be.revertedWith('ChallengeToClaim: not the owner');
     
        await new Promise(res => setTimeout(() => res(null), 5000));
      });
      
      
      it("Account1 make challenge ERC20", async function() 
      { 
        const token = findTokens(account1.address, erc20Contract.address)[0];
        const secretKey = stringToBytes32("code to claim"); 
        const issuer = token.owner; 
        const signature = await signChallenge(issuer, token.address, token.tokenId, token.amount,  secretKey); 
  
        lastSecretKey = secretKey;
        lastChallengeSignature = signature;
  
        await challengeContract.connect(issuer).makeChallengeERC20(token.address, token.amount, "", signature);
        await expect(challengeContract.connect(issuer).claim(secretKey, signature))
              .to.be.revertedWith('ChallengeToClaim: Owner can not claim its own challenge');
  
        await new Promise(res => setTimeout(() => res(null), 5000));
      });
  
      it("Account3 claim previous challenge ERC20", async function() 
      {   
        const key = getChallengeKeyFromSignature(lastChallengeSignature);
      
        await expect(challengeContract.connect(account3).claim(lastSecretKey, lastChallengeSignature))
              .to.emit(challengeContract, 'ChallengeSolved').withArgs(key);
  
        const challenge = await challengeContract.getChallenge(key);
        expect(challenge.IsClaimed).to.be.true; 
  
        const tokenContract = new ethers.Contract(challenge.ContractAddress, erc20ABI, account3); 
        const balance = await tokenContract.balanceOf(account3.address);
        expect(balance >= challenge.Amount).to.be.true;
        
        await new Promise(res => setTimeout(() => res(null), 5000)); 
      });

      it("Account2 make challenge ERC721 and remove it", async function() 
      {   
        const token = findTokens(account2.address, erc721Contract.address)[0];
        const secretKey = stringToBytes32("code to claim"); 
        const issuer = token.owner; 
        const signature = await signChallenge(issuer, token.address, token.tokenId, token.amount, secretKey); 
  
        lastSecretKey = secretKey;
        lastChallengeSignature = signature;
  
        const key = getChallengeKeyFromSignature(signature);
  
        await expect(challengeContract.connect(issuer).makeChallengeERC721(token.address, token.tokenId, "", signature))
              .to.emit(challengeContract, 'NewChallenge').withArgs(key);
        
        await expect(challengeContract.connect(account0).removeChallenge(signature))
              .to.be.revertedWith('ChallengeToClaim: Not the owner of this challange');
  
        await challengeContract.connect(issuer).removeChallenge(signature);
  
        const challenge = await challengeContract.getChallenge(key);
        expect(challenge.ContractAddress).to.be.equal(ethers.constants.AddressZero);
        expect(challenge.Owner).to.be.equal(ethers.constants.AddressZero);
  
        await new Promise(res => setTimeout(() => res(null), 5000)); 
      });
    });

    describe("Multiple", async function(){

    });


    after("Log", async function () { 
      await logAccount(account0);
      await logAccount(account1);
      await logAccount(account2);
      await logAccount(account3);
      console.log("");
    }); 
  }); 
});
async function challengeToSign(owner, contractAddress, tokenId, amount, secretKey){
  const nonce = (await challengeContract.connect(owner).getNonce()).toNumber(); 
  return { owner: owner.address, contractAddress: contractAddress, tokenId: tokenId, amount: amount, nonce: nonce, secretKey: secretKey };
}
function typesToSign(){
  return { Challenge: CHALLENGE_DOMAIN_TYPE };
}
async function signChallenge(owner, contractAddress, tokenId, amount, secretKey){  
  const nonce = (await challengeContract.connect(owner).getNonce()).toNumber(); 
  return await owner._signTypedData(
    ERC712_DOMAIN_TYPE, 
    { Challenge: CHALLENGE_DOMAIN_TYPE }, 
    { owner: owner.address, contractAddress: contractAddress, tokenId: tokenId, amount: amount, nonce: nonce, secretKey: secretKey });
}

function getChallengeKeyFromSignature(signature){
  return ethers.utils.solidityKeccak256(['bytes'], [signature]);
}

function tokenize(owner, contract, tokenId, amount){
  const t = {};
  t.owner = owner;
  t.contract = contract;
  t.address = contract.address;
  t.tokenId = tokenId;
  t.amount = amount; 
  return t;
}
function findTokenERC721(ownerAddress, tokenId){
  return tokens.filter(t => t.address == erc721Contract.address && t.owner.adress == ownerAddress && t.tokenId == tokenId);
}
function findTokenERC1155(ownerAddress, tokenId){
  return tokens.filter(t => t.address == erc1155Contract.address && t.owner.adress == ownerAddress && t.tokenId == tokenId);
}
function findTokenERC20(ownerAddress){
  return tokens.filter(t => t.address == erc20Contract.address && t.owner.adress == ownerAddress);
}
function findTokens(ownerAddress, contractAddress){
  return tokens.filter(t => t.address == contractAddress && t.owner.address == ownerAddress);
} 

async function getBalance(address){
  const balance = await ethers.provider.getBalance(address.address);
  const ether = +utils.formatEther(balance);
  const initial = address.address == account0.address ? 7000 : 1000;
  const spent = initial - ether; 
  return ether.toFixed(5) + ", spent: " + spent.toFixed(ether < 1000 ? 6 : 5);
}
async function getTokenBalance(contract, account){
  if(contract.address == erc721Contract.address){
    return await erc721Contract.balanceOf(account.address);
  }else if(contract.address == erc1155Contract.address){
    var sum = 0;
    for(let i=0; i<20; i++){
      const b = await erc1155Contract.balanceOf(account.address, i);
      sum += parseInt(b);
    }
    return sum;
  }else if(contract.address == erc20Contract.address){
    return await erc20Contract.balanceOf(account.address);
  }else{
    throw "Unknown contract address";
  }
 
}
function intToBytes32(int){
  return ethers.utils.hexZeroPad(ethers.utils.hexlify(int), 32);
}
function bytes32ToInt(bytes32){  
  return parseInt(bytes32);
} 
function bytes32ToString(bytes32){ 
  return ethers.utils.parseBytes32String(bytes32);
} 
function stringToBytes32(text){ 
  return ethers.utils.formatBytes32String(text);
} 
function reduceAddress(address, start=4, end=3){
  return address.substring(0,start+2) + "..." + address.substring(address.length-end,address.length);
}

function getOwnerName(address){
  if(address == account0.address) return "account0";
  if(address == account1.address) return "account1";
  if(address == account2.address) return "account2";
  if(address == account3.address) return "account3";
  return address;
}
function getOwner(address){
  if(address == account0.address) return account0;
  if(address == account1.address) return account1;
  if(address == account2.address) return account2;
  if(address == account3.address) return account3;
  return address;
}

async function logAccount(account){ 
  const m = [];
  m.push(getOwnerName(account.address) + ": " + reduceAddress(account.address));
  m.push("ETH: " + await getBalance(account));
  m.push("ERC721: " + await getTokenBalance(erc721Contract, account));
  m.push("ERC1155: " + await getTokenBalance(erc1155Contract, account));
  m.push("ERC20: " + await getTokenBalance(erc20Contract, account));
   
  console.log(m.join(" | "));
}

async function deploy(contractName){
  const factory = await hre.ethers.getContractFactory(contractName);
  const contract = await factory.deploy(); 
  await contract.deployed();
  return contract;
}
  
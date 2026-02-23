const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying with:", deployer.address);
  console.log("Balance:", hre.ethers.formatEther(await hre.ethers.provider.getBalance(deployer.address)), "ETH");

  const systemWallet = process.env.SYSTEM_WALLET || deployer.address;
  const founderWallet = process.env.FOUNDER_WALLET || deployer.address;

  // 1. Deploy SVG renderer
  console.log("\n1. Deploying HashRigSVG...");
  const SVG = await hre.ethers.getContractFactory("HashRigSVG");
  const svg = await SVG.deploy();
  await svg.waitForDeployment();
  const svgAddr = await svg.getAddress();
  console.log("   HashRigSVG deployed to:", svgAddr);

  // 2. Deploy main NFT contract
  console.log("\n2. Deploying HashRigNFT...");
  const NFT = await hre.ethers.getContractFactory("HashRigNFT");
  const nft = await NFT.deploy(systemWallet, founderWallet, svgAddr);
  await nft.waitForDeployment();
  const nftAddr = await nft.getAddress();
  console.log("   HashRigNFT deployed to:", nftAddr);

  console.log("\n--- DEPLOYMENT COMPLETE ---");
  console.log("SVG Renderer:", svgAddr);
  console.log("NFT Contract:", nftAddr);
  console.log("System Wallet:", systemWallet);
  console.log("Founder Wallet:", founderWallet);

  // 3. Verify on Basescan (skip for local)
  if (hre.network.name !== "hardhat" && hre.network.name !== "localhost") {
    console.log("\nWaiting 30s for block confirmations...");
    await new Promise(r => setTimeout(r, 30000));

    try {
      await hre.run("verify:verify", {
        address: svgAddr,
        constructorArguments: []
      });
      console.log("HashRigSVG verified");
    } catch (e) {
      console.log("SVG verification:", e.message);
    }

    try {
      await hre.run("verify:verify", {
        address: nftAddr,
        constructorArguments: [systemWallet, founderWallet, svgAddr]
      });
      console.log("HashRigNFT verified");
    } catch (e) {
      console.log("NFT verification:", e.message);
    }
  }
}

main().catch(function(e) {
  console.error(e);
  process.exitCode = 1;
});

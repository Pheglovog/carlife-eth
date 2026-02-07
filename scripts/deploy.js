const hre = require("hardhat");

async function main() {
  console.log("\n🚗 CarLife - 智能合约部署");
  console.log("=" .repeat(60));

  // 获取网络信息
  const network = await hre.ethers.provider.getNetwork();
  console.log(`🌐 网络: ${network.name} (Chain ID: ${network.chainId})\n`);

  // 获取部署者账户
  const [deployer] = await hre.ethers.getSigners();
  const balance = await hre.ethers.provider.getBalance(deployer.address);
  const balanceEth = hre.ethers.formatEther(balance);

  console.log(`👤 部署者地址: ${deployer.address}`);
  console.log(`💰 账户余额: ${balanceEth} ETH\n`);

  // 检查余额
  if (balanceEth < 0.01) {
    console.error("❌ 余额不足，至少需要 0.01 ETH");
    console.error("📝 获取测试币: https://sepoliafaucet.com");
    process.exit(1);
  }

  // 部署合约
  console.log("🚀 部署 CarNFT_Fixed 合约...");
  const CarNFT = await hre.ethers.getContractFactory("CarNFT_Fixed");
  const carNFT = await CarNFT.deploy();

  await carNFT.waitForDeployment();
  const address = await carNFT.getAddress();

  console.log(`✅ 合约部署成功!`);
  console.log(`📋 合约地址: ${address}\n`);

  // 验证基本功能
  console.log("🧪 验证合约功能...");
  const name = await carNFT.name();
  const symbol = await carNFT.symbol();
  const owner = await carNFT.owner();

  console.log(`📝 代币名称: ${name}`);
  console.log(`🔤 代币符号: ${symbol}`);
  console.log(`👤 合约所有者: ${owner}\n`);

  // 检查角色
  const ADMIN_ROLE = await carNFT.DEFAULT_ADMIN_ROLE();
  const PROVIDER_ROLE = await carNFT.PROVIDER_ROLE();

  console.log(`🔐 默认管理员角色: ${ADMIN_ROLE}`);
  console.log(`🔧 服务商角色: ${PROVIDER_ROLE}`);

  const isAdmin = await carNFT.hasRole(ADMIN_ROLE, deployer.address);
  console.log(`✅ 部署者是管理员: ${isAdmin}\n`);

  // 保存部署信息
  const deploymentInfo = {
    network: network.name,
    chainId: network.chainId.toString(),
    contractAddress: address,
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    transactionHash: carNFT.deploymentTransaction()?.hash || "N/A"
  };

  const fs = require("fs");
  fs.writeFileSync(
    "deployment.json",
    JSON.stringify(deploymentInfo, null, 2)
  );

  console.log("💾 部署信息已保存到 deployment.json");

  // Etherscan 验证提示
  if (network.name !== "hardhat" && network.name !== "localhost") {
    console.log("\n📝 验证合约 (可选):");
    console.log(`npx hardhat verify --network ${network.name} ${address}`);
  }

  console.log("\n" + "=".repeat(60));
  console.log("✅ 部署完成!");
  console.log("=".repeat(60) + "\n");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");
require("dotenv").config();

async function main() {
  console.log("========================================");
  console.log("开始部署 CarLife 项目");
  console.log("========================================");

  // 1. 验证环境变量
  const privateKey = process.env.PRIVATE_KEY;
  if (!privateKey) {
    console.error("❌ 错误：未设置 PRIVATE_KEY 环境变量");
    console.error("请在 .env 文件中设置 PRIVATE_KEY");
    process.exit(1);
  }

  const network = await ethers.provider.getNetwork();
  console.log(`📡 网络: ${network.name} (Chain ID: ${network.chainId})`);
  console.log();

  // 2. 部署 CarNFT_Fixed
  console.log("📦 部署 CarNFT_Fixed 合约...");
  const CarNFT_Fixed = await ethers.getContractFactory("CarNFT_Fixed");
  const carNFT = await CarNFT_Fixed.deploy();
  await carNFT.waitForDeployment();

  const carNFTAddress = await carNFT.getAddress();
  console.log(`✅ CarNFT_Fixed 部署成功`);
  console.log(`   地址: ${carNFTAddress}`);
  console.log();

  // 3. 等待确认
  console.log("⏳ 等待交易确认...");
  const deployTx = carNFT.deploymentTransaction();
  const receipt = await deployTx.wait();
  console.log(`✅ 交易已确认 (区块: ${receipt.blockNumber}, Gas: ${receipt.gasUsed.toString()})`);
  console.log();

  // 4. 验证基本功能
  console.log("🔍 验证合约基本功能...");
  try {
    const name = await carNFT.name();
    const symbol = await carNFT.symbol();
    const totalCars = await carNFT.totalCars();

    console.log(`✅ 代币名称: ${name}`);
    console.log(`✅ 代币符号: ${symbol}`);
    console.log(`✅ 总车辆数: ${totalCars.toString()}`);
    console.log();
  } catch (error) {
    console.error("❌ 验证失败:", error.message);
  }

  // 5. 保存部署信息
  const deploymentInfo = {
    network: network.name,
    chainId: network.chainId.toString(),
    deploymentTime: new Date().toISOString(),
    contracts: {
      CarNFT_Fixed: {
        address: carNFTAddress,
        transactionHash: deployTx.hash,
        blockNumber: receipt.blockNumber.toString(),
        gasUsed: receipt.gasUsed.toString(),
      }
    }
  };

  const deploymentsDir = path.join(__dirname, "deployments");
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }

  const deploymentFile = path.join(deploymentsDir, `deployment-${network.name}.json`);
  fs.writeFileSync(deploymentFile, JSON.stringify(deploymentInfo, null, 2));
  console.log(`📝 部署信息已保存到: ${deploymentFile}`);
  console.log();

  // 6. 更新 .env 文件
  const envFile = path.join(__dirname, ".env");
  let envContent = "";
  if (fs.existsSync(envFile)) {
    envContent = fs.readFileSync(envFile, "utf8");
  }

  // 更新或添加 CAR_NFT_ADDRESS
  const carNFTLine = `CAR_NFT_ADDRESS=${carNFTAddress}`;
  if (envContent.includes("CAR_NFT_ADDRESS=")) {
    envContent = envContent.replace(/CAR_NFT_ADDRESS=.*/, carNFTLine);
  } else {
    envContent += `\n${carNFTLine}\n`;
  }

  fs.writeFileSync(envFile, envContent);
  console.log(`📝 已更新 .env 文件中的 CAR_NFT_ADDRESS`);
  console.log();

  // 7. 自动验证（如果配置了 ETHERSCAN_API_KEY）
  const etherscanApiKey = process.env.ETHERSCAN_API_KEY;
  if (etherscanApiKey && etherscanApiKey !== "your_etherscan_api_key_here") {
    console.log("🔍 开始验证合约源代码...");
    try {
      await hre.run("verify:verify", {
        address: carNFTAddress,
        constructorArguments: [],
      });
      console.log("✅ 合约验证成功");
    } catch (error) {
      console.log("⚠️  合约验证失败或已验证:", error.message);
      console.log("   您可以稍后手动验证");
    }
    console.log();
  } else {
    console.log("⚠️  未配置 ETHERSCAN_API_KEY，跳过自动验证");
    console.log("   您可以手动验证合约: https://etherscan.io/verifyContract");
    console.log();
  }

  // 8. 显示下一步操作提示
  console.log("========================================");
  console.log("部署完成！");
  console.log("========================================");
  console.log();
  console.log("下一步操作:");
  console.log(`1. 查看合约: https://${network.name === 'sepolia' ? 'sepolia.' : ''}etherscan.io/address/${carNFTAddress}`);
  console.log(`2. 更新前端配置中的合约地址`);
  console.log(`3. 使用 mintCar() 函数铸造第一个 NFT`);
  console.log();
  console.log("合约信息:");
  console.log(`地址: ${carNFTAddress}`);
  console.log(`网络: ${network.name}`);
  console.log(`Chain ID: ${network.chainId}`);
  console.log();

  return deploymentInfo;
}

main()
  .then((deploymentInfo) => {
    process.exit(0);
  })
  .catch((error) => {
    console.error("❌ 部署失败:", error);
    process.exit(1);
  });

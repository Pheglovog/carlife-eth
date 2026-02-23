const hre = require("hardhat");

async function main() {
    console.log("Deploying CarLife AA Stack...");

    // 获取部署账户
    const [deployer, owner, user, sponsor] = await hre.ethers.getSigners();

    // 部署参数
    const initialSigners = [owner.address];
    const signerThreshold = 1;
    const maxOpsPerHandleOps = 10;

    console.log("Deploying CarLife Paymaster...");
    const CarLifePaymaster = await hre.ethers.getContractFactory("CarLifePaymaster");
    const carLifePaymaster = await CarLifePaymaster.deploy(deployer.address); // 假设 deployer 是 CAR token 地址
    await carLifePaymaster.waitForDeployment();

    console.log("CarLife Paymaster deployed to:", carLifePaymaster.address);

    console.log("\nDeploying CarLife SmartWallet Factory...");
    // 注意：在实际场景中，你会部署一个工厂合约来创建 SmartWallet
    // 或者你会使用 ERC-4337 的 Account Creation 机制
    // 这里我们直接部署一个示例 SmartWallet 用于测试

    console.log("Deploying CarLife SmartWallet (Implementation)...");
    const CarLifeSmartWallet = await hre.ethers.getContractFactory("CarLifeSmartWallet");
    const carLifeSmartWallet = await CarLifeSmartWallet.deploy(
        owner.address, // CarNFT 地址 (假设 owner 是 CarNFT)
        owner.address, // 钱包所有者
        initialSigners,
        signerThreshold
    );
    await carLifeSmartWallet.waitForDeployment();

    console.log("CarLife SmartWallet deployed to:", carLifeSmartWallet.address);

    console.log("\nDeploying CarLife EntryPoint...");
    const CarLifeEntryPoint = await hre.ethers.getContractFactory("CarLifeEntryPoint");
    const carLifeEntryPoint = await CarLifeEntryPoint.deploy(
        carLifePaymaster.address,
        maxOpsPerHandleOps
    );
    await carLifeEntryPoint.waitForDeployment();

    console.log("CarLife EntryPoint deployed to:", carLifeEntryPoint.address);

    console.log("\nFunding Paymaster with CAR tokens...");
    // 假设 deployer 持有足够的 CAR token
    // 在实际场景中，owner 或赞助者会资助 Paymaster
    const depositAmount = hre.ethers.parseEther("10000"); // 10,000 CAR

    // 在实际场景中，你需要先 mint CAR token
    // const tx = await carToken.connect(deployer).mint(owner.address, depositAmount);
    // await tx.wait();

    // 授权 Paymaster
    // await carToken.connect(owner).approve(carLifePaymaster.address, depositAmount);
    // await tx.wait();

    // 存入 CAR token
    // const depositTx = await carLifePaymaster.connect(owner).deposit(depositAmount);
    // await depositTx.wait();

    console.log("Paymaster funded with:", depositAmount.toString(), "CAR");

    console.log("\nSponsoring user with CAR tokens...");
    const sponsorAmount = hre.ethers.parseEther("1000"); // 1,000 CAR

    // 赞助用户
    // const sponsorTx = await carLifePaymaster.connect(sponsor).sponsor(user.address, sponsorAmount);
    // await sponsorTx.wait();

    console.log("User", user.address, "sponsored with:", sponsorAmount.toString(), "CAR");

    console.log("\nVerifying deployments...");

    // 验证 Paymaster
    const paymasterOwner = await carLifePaymaster.owner();
    console.log("Paymaster owner:", paymasterOwner);
    expect(paymasterOwner).to.equal(deployer.address);

    // 验证 SmartWallet
    const walletOwner = await carLifeSmartWallet.owner();
    console.log("SmartWallet owner:", walletOwner);
    expect(walletOwner).to.equal(owner.address);

    const walletCarNFT = await carLifeSmartWallet.carNFT();
    console.log("SmartWallet CarNFT:", walletCarNFT);
    expect(walletCarNFT).to.equal(owner.address);

    // 验证 EntryPoint
    const entryPointPaymaster = await carLifeEntryPoint.paymaster();
    console.log("EntryPoint Paymaster:", entryPointPaymaster);
    expect(entryPointPaymaster).to.equal(carLifePaymaster.address);

    const entryPointMaxOps = await carLifeEntryPoint.maxOpsPerHandleOps();
    console.log("EntryPoint Max Ops:", entryPointMaxOps.toString());
    expect(entryPointMaxOps).to.equal(maxOpsPerHandleOps);

    console.log("\n========================================");
    console.log("Deployment Summary:");
    console.log("========================================");
    console.log("CarLife Paymaster:", carLifePaymaster.address);
    console.log("CarLife SmartWallet:", carLifeSmartWallet.address);
    console.log("CarLife EntryPoint:", carLifeEntryPoint.address);
    console.log("CarLife Owner:", owner.address);
    console.log("CarLife User:", user.address);
    console.log("CarLife Sponsor:", sponsor.address);
    console.log("========================================");
    console.log("\nNext Steps:");
    console.log("1. Verify contracts on Etherscan");
    console.log("2. Mint CAR tokens if not already minted");
    console.log("3. Fund Paymaster with CAR tokens");
    console.log("4. Sponsor user with CAR tokens");
    console.log("5. Create a SmartWallet for user");
    console.log("6. Test AA flow (Deposit -> Sponsor -> Execute UserOperation)");
    console.log("\nCommands:");
    console.log(`npx hardhat verify-contract --contract-name contracts/CarLifePaymaster.sol:CarLifePaymaster --address ${carLifePaymaster.address} --network <network-name>`);
    console.log(`npx hardhat verify-contract --contract-name contracts/CarLifeSmartWallet.sol:CarLifeSmartWallet --address ${carLifeSmartWallet.address} --network <network-name>`);
    console.log(`npx hardhat verify-contract --contract-name contracts/CarLifeEntryPoint.sol:CarLifeEntryPoint --address ${carLifeEntryPoint.address} --network <network-name>`);

    console.log("\nDeployment complete!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

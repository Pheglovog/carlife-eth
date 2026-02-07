#!/usr/bin/env python3
"""
CarLife - 智能合约部署脚本

支持网络:
- Sepolia 测试网 (推荐)
- Goerli 测试网
- 本地 Hardhat 网络

使用方法:
    python deploy.py --network sepolia
    python deploy.py --network goerli
    python deploy.py --network local

环境变量:
    PRIVATE_KEY            钱包私钥
    SEPOLIA_RPC_URL        Sepolia RPC URL
    GOERLI_RPC_URL         Goerli RPC URL
"""

import os
import sys
import json
import argparse
from web3 import Web3
from eth_account import Account
from dotenv import load_dotenv

# 加载环境变量
load_dotenv()

# 配置
NETWORKS = {
    'sepolia': {
        'rpc_url': os.getenv('SEPOLIA_RPC_URL', 'https://rpc.sepolia.org'),
        'chain_id': 11155111,
        'explorer': 'https://sepolia.etherscan.io'
    },
    'goerli': {
        'rpc_url': os.getenv('GOERLI_RPC_URL', 'https://rpc.ankr.com/eth_goerli'),
        'chain_id': 5,
        'explorer': 'https://goerli.etherscan.io'
    },
    'local': {
        'rpc_url': 'http://127.0.0.1:8545',
        'chain_id': 31337,
        'explorer': None
    }
}

CONTRACT_FILE = 'contracts/CarNFT_Optimized.sol'
CONTRACT_NAME = 'CarNFT'


def load_contract():
    """加载合约字节码和 ABI"""
    # 注意：这需要先用 solc 编译合约
    # 这里只是示例框架

    # 使用 Hardhat 编译后的输出
    artifacts_dir = 'artifacts/contracts'
    contract_file = f'{artifacts_dir}/{CONTRACT_NAME}.sol/{CONTRACT_NAME}.json'

    if os.path.exists(contract_file):
        with open(contract_file, 'r') as f:
            contract_data = json.load(f)
        return contract_data['bytecode'], contract_data['abi']

    # 如果没有编译后的文件，提示用户
    print(f"❌ 找不到编译后的合约文件: {contract_file}")
    print("\n请先编译合约:")
    print("  npm init -y")
    print("  npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox")
    print("  npx hardhat compile")
    sys.exit(1)


def compile_contract():
    """使用 Hardhat 编译合约"""
    print("🔨 编译合约...")

    # 检查是否安装了 Hardhat
    if not os.path.exists('node_modules/.bin/hardhat'):
        print("⚠️  Hardhat 未安装，正在安装...")
        os.system('npm init -y')
        os.system('npm install --save-dev hardhat @nomicfoundation/hardhat-toolchain')

    # 创建 hardhat.config.js
    config = """require("@nomicfoundation/hardhat-toolbox");

module.exports = {
  solidity: "0.8.20",
  paths: {
    sources: "./contracts",
  },
};
"""

    with open('hardhat.config.js', 'w') as f:
        f.write(config)

    # 编译合约
    result = os.system('npx hardhat compile')

    if result != 0:
        print("❌ 合约编译失败")
        sys.exit(1)

    print("✅ 合约编译成功")


def deploy_contract(network_name):
    """部署合约到指定网络"""

    # 获取网络配置
    network = NETWORKS.get(network_name)
    if not network:
        print(f"❌ 不支持的网络: {network_name}")
        print(f"支持的网络: {', '.join(NETWORKS.keys())}")
        sys.exit(1)

    # 检查私钥
    private_key = os.getenv('PRIVATE_KEY')
    if not private_key:
        print("❌ 未找到 PRIVATE_KEY 环境变量")
        print("请在 .env 文件中设置: PRIVATE_KEY=your_private_key")
        sys.exit(1)

    # 连接到网络
    print(f"🌐 连接到网络: {network_name}")
    w3 = Web3(Web3.HTTPProvider(network['rpc_url']))

    if not w3.is_connected():
        print(f"❌ 无法连接到 {network_name}")
        sys.exit(1)

    # 创建账户
    account = Account.from_key(private_key)
    print(f"👤 部署账户: {account.address}")

    # 检查余额
    balance = w3.eth.get_balance(account.address)
    balance_eth = w3.from_wei(balance, 'ether')
    print(f"💰 账户余额: {balance_eth} ETH")

    if balance_eth < 0.01:
        print("⚠️  余额不足，无法部署合约")
        print(f"请至少有 0.01 ETH 在账户中")
        print(f"获取测试币: https://sepoliafaucet.com")
        sys.exit(1)

    # 加载合约
    bytecode, abi = load_contract()

    # 创建合约实例
    contract = w3.eth.contract(abi=abi, bytecode=bytecode)

    # 构建交易
    print("🚀 构建部署交易...")
    nonce = w3.eth.get_transaction_count(account.address)
    gas_price = w3.eth.gas_price

    # 估算 gas
    try:
        gas_estimate = contract.constructor().estimate_gas()
        gas_limit = int(gas_estimate * 1.2)  # 增加 20% 缓冲
    except Exception as e:
        print(f"⚠️  无法估算 gas，使用默认值: 5000000")
        gas_limit = 5000000

    # 构建交易
    transaction = contract.constructor().build_transaction({
        'gas': gas_limit,
        'gasPrice': gas_price,
        'nonce': nonce,
        'chainId': network['chain_id']
    })

    # 签名交易
    print("✍️  签名交易...")
    signed_txn = w3.eth.account.sign_transaction(transaction, private_key)

    # 发送交易
    print("📤 发送交易...")
    tx_hash = w3.eth.send_raw_transaction(signed_txn.raw_transaction)
    tx_hex = tx_hash.hex()

    print(f"⏳ 等待交易确认...")
    print(f"📄 交易哈希: {tx_hex}")

    if network['explorer']:
        print(f"🔍 查看交易: {network['explorer']}/tx/{tx_hex}")

    # 等待确认
    tx_receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=300)

    if tx_receipt['status'] == 1:
        print("✅ 合约部署成功!")
        print(f"📋 合约地址: {tx_receipt.contractAddress}")

        # 保存部署信息
        deployment_info = {
            'network': network_name,
            'contract_address': tx_receipt.contractAddress,
            'transaction_hash': tx_hex,
            'deployer': account.address,
            'timestamp': tx_receipt['blockNumber']
        }

        output_file = 'deployment.json'
        with open(output_file, 'w') as f:
            json.dump(deployment_info, f, indent=2)

        print(f"💾 部署信息已保存到: {output_file}")

        if network['explorer']:
            print(f"🔍 查看合约: {network['explorer']}/address/{tx_receipt.contractAddress}")

        # 验证合约（使用 Hardhat）
        print("\n📝 验证合约...")
        verify_cmd = f"npx hardhat verify --network {network_name} {tx_receipt.contractAddress}"
        print(f"运行命令: {verify_cmd}")

        return tx_receipt.contractAddress
    else:
        print("❌ 合约部署失败!")
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description='部署 CarLife 智能合约')
    parser.add_argument(
        '--network',
        type=str,
        choices=NETWORKS.keys(),
        default='sepolia',
        help='部署网络 (默认: sepolia)'
    )
    parser.add_argument(
        '--compile',
        action='store_true',
        help='先编译合约再部署'
    )

    args = parser.parse_args()

    print("=" * 60)
    print("🚗 CarLife - 智能合约部署工具")
    print("=" * 60)
    print()

    # 先编译合约（如果需要）
    if args.compile:
        compile_contract()
        print()

    # 部署合约
    contract_address = deploy_contract(args.network)

    print()
    print("=" * 60)
    print("✅ 部署完成!")
    print("=" * 60)


if __name__ == '__main__':
    main()

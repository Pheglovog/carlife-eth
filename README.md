# CarLife - 区块链汽车生活平台

一个基于区块链的汽车生活服务平台，连接车主、服务商和区块链生态。

## 🌟 核心特性

### 🚗 车辆 NFT 系统
- ✅ **车辆信息上链** - 不可篡改的所有权证明
- ✅ **VIN 验证** - 防止重复注册
- ✅ **里程记录** - 透明可信的里程管理
- ✅ **维修记录** - 完整的维修历史
- ✅ **NFT 转移** - 支持车辆所有权变更

### 📋 服务注册系统
- ✅ **服务商注册** - 去中心化的服务商认证
- ✅ **服务发布** - 透明的服务信息和报价
- ✅ **评价系统** - 不可删除的链上评价
- ✅ **评分机制** - 自动计算平均评分

### 💰 数据 Token 化
- ✅ **数据记录铸造** - 里程、维修、驾骋等数据上链
- ✅ **加密存储** - 保护用户隐私
- ✅ **数据交易** - 数据所有者可以安全交易
- ✅ **哈希验证** - 防止重复记录

## 🛠️ 技术栈

### 区块链
- **Solidity ^0.8.19** - 智能合约
- **OpenZeppelin** - ERC721、Ownable、Counters
- **Hardhat** - 开发框架
- **Ethers.js** - 区块链交互

### 后端
- **Go 1.21+** - 高性能后端服务
- **Gin** - Web 框架
- **GORM** - ORM
- **PostgreSQL** - 数据库

### 前端（开发中）
- **Vue 3** - 渐进式框架
- **TypeScript** - 类型安全
- **Element Plus** - UI 组件库
- **Vite** - 构建工具

## 📂 项目结构

```
CarLife/
├── contracts/           # 智能合约
│   ├── CarNFT.sol         # 车辆 NFT
│   ├── ServiceRegistry.sol  # 服务注册
│   ├── DataToken.sol        # 数据 Token
│   └── CarLife.sol         # 主合约
│
├── backend/              # 后端（Python 示例 + Go 框架）
│   ├── api.py              # FastAPI 示例
│   ├── models/             # 数据模型
│   ├── services/           # 业务逻辑
│   └── main.go             # Go 入口
│
├── frontend/             # 前端（开发中）
│   ├── index.html          # 入口
│   └── src/
│       ├── components/      # 组件
│       ├── views/          # 页面
│       └── router/          # 路由
│
└── docs/                # 文档
    ├── CONTRACTS.md       # 智能合约说明
    └── API.md             # API 文档
```

## 🚀 快速开始

### 1. 智能合约开发

```bash
cd contracts

# 安装依赖
npm install

# 编译
npx hardhat compile

# 部署到测试网络
npx hardhat run scripts/deploy.js --network localhost
```

### 2. 后端 API（Python 示例）

```bash
cd backend

# 安装依赖
pip install fastapi uvicorn

# 启动服务器
python api.py

# 访问 API 文档
# http://localhost:8000/docs
```

### 3. 前端（开发中）

```bash
cd frontend

# 安装依赖
npm install

# 开发模式
npm run dev
```

## 📋 智能合约功能

### CarLife 主合约
- ✅ **CarNFT 功能** - 车辆 NFT 铸造、里程更新
- ✅ **ServiceRegistry 功能** - 服务商注册、服务发布、评价
- ✅ **DataToken 功能** - 数据记录铸造、数据交易
- ✅ **统一管理** - 一个合约管理所有功能

### 核心方法

#### 车辆管理
```solidity
mintCar(to, vin, brand, model, year, color, mileage, uri)
updateMileage(tokenId, mileage)
getCarInfo(tokenId)
getUserCars(owner)
```

#### 服务管理
```solidity
registerProvider(name, serviceType, location)
addService(providerId, title, description, price, currency)
addReview(serviceId, rating, comment)
deactivateProvider(providerId)
```

#### 数据管理
```solidity
mintDataRecord(carTokenId, dataType, encryptedData, dataHash, price)
listForSale(recordId, price)
purchaseData(recordId)
```

## 📊 系统架构

```
┌─────────────────────────────────────┐
│         前端 (Vue 3)          │
└───────────────┬─────────────────┘
                │
         ┌──────▼──────┐
         │   后端 API  │
         └───────┬──────┘
                 │
         ┌───────▼───────┐
         │   智能合约   │
         │ (CarLife)     │
         │  (Ethereum)   │
         └───────────────┘
```

## 🔐 安全特性

### 智能合约安全
- ✅ OpenZeppelin 库 - 经过审计的代码
- ✅ 访问控制 - Ownable 权限管理
- ✅ 输入验证 - VIN 长度、年份范围
- ✅ 重入保护 - 防止重入攻击
- ✅ 哈希验证 - 防止重复数据

### 数据安全
- ✅ 加密存储 - 用户数据加密上链
- ✅ 所有权验证 - ERC721 标准
- ✅ 零知识证明 - 隐私保护

## 🎯 使用场景

### 场景 1: 车主
1. 铸造车辆 NFT
2. 更新里程记录
3. 记录维修信息
4. 交易车辆所有权
5. 出售数据权益

### 场景 2: 服务商
1. 注册服务商账号
2. 发布服务信息
3. 接收用户评价
4. 建立信誉评分

### 场景 3: 数据买家
1. 浏观数据市场
2. 购买数据权益
3. 验证数据完整性
4. 使用数据进行建模

## 📚 文档

### 智能合约
- [CONTRACTS.md](docs/CONTRACTS.md) - 智能合约详细说明

### API 文档
- [API.md](docs/API.md) - 后端 API 接口文档

## 🔑 配置

### 环境变量

创建 `.env` 文件：

```bash
# 区块链
ETHEREUM_RPC_URL=http://localhost:8545
PRIVATE_KEY=你的私钥

# 后端
DATABASE_URL=postgresql://localhost/carlife
REDIS_URL=redis://localhost:6379

# API
API_KEY=your_api_key
```

## 🎓 开发计划

### Phase 1: MVP ✅
- [x] 项目结构搭建
- [x] 智能合约开发
- [x] 后端 API 示例
- [x] 前端框架
- [ ] 集成测试

### Phase 2: 核心功能
- [ ] 车辆 NFT 系统
- [ ] 服务注册系统
- [ ] 数据 Token 化
- [ ] 用户认证

### Phase 3: 高级功能
- [ ] 移动端适配
- [ ] 多语言支持
- [ ] 高级数据分析
- [ ] 社区功能

## 📄 License

MIT

---

**开发者**: 上等兵•甘
**最后更新**: 2026-02-01 02:30

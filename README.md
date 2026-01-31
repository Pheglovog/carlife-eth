# CarLife - 区块链汽车生活平台

一个基于区块链的汽车生活服务平台，连接车主、服务商和区块链生态。

## 项目愿景

CarLife 致力于打造一个去中心化的汽车生活服务平台，通过区块链技术实现：
- ✅ 数据所有权回归车主
- ✅ 透明可信的服务记录
- ✅ 去中心化的服务评价
- ✅ 车辆数据的 Token 化

## 技术栈

### 后端
- **Go 1.21+** - 高性能后端服务
- **Gin** - Web 框架
- **GORM** - ORM
- **PostgreSQL** - 数据库

### 区块链
- **Solidity** - 智能合约
- **Hardhat** - 开发框架
- **Ethers.js** - 区块链交互

### 前端
- **Vue 3** - 渐进式框架
- **TypeScript** - 类型安全
- **Vite** - 构建工具
- **Element Plus** - UI 组件库

## 项目结构

```
CarLife/
├── backend/          # 后端
│   ├── api/        # API 接口
│   ├── models/     # 数据模型
│   ├── services/   # 业务逻辑
│   ├── blockchain/ # 区块链交互
│   └── main.go    # 入口
├── frontend/       # 前端
│   ├── src/
│   │   ├── components/
│   │   ├── views/
│   │   └── router/
│   └── package.json
├── contracts/     # 智能合约
│   ├── CarNFT.sol
│   └── ServiceRegistry.sol
└── docs/         # 文档
```

## 核心功能

### 1. 车辆 NFT (CarNFT)
- 车辆信息上链
- 不可篡改的所有权证明
- 车辆历史记录

### 2. 服务注册 (ServiceRegistry)
- 服务商注册
- 服务信息公开
- 去中心化验证

### 3. 评价系统
- 用户评价上链
- 不可删除的记录
- 透明的信誉评分

## 开发计划

### Phase 1: MVP (进行中）
- [x] 项目结构搭建
- [ ] 智能合约开发
- [ ] 后端 API 开发
- [ ] 前端基础页面

### Phase 2: 核心功能
- [ ] 车辆 NFT 系统
- [ ] 服务注册系统
- [ ] 评价系统
- [ ] 用户认证

### Phase 3: 高级功能
- [ ] 数据 Token 化
- [ ] 数据交易市场
- [ ] 移动端适配

## License

MIT

---

**开发者**: Pheglovog
**最后更新**: 2026-01-31

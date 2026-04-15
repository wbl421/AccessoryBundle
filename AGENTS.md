# AccessoryBundle - 会员配件套餐搭配管理App

## 项目概述
iOS 原生 App，用于管理配件商品和搭配套餐，主要面向 Apple 授权经销商门店。

## 技术栈
- Swift + SwiftUI
- iOS 16.0+
- 本地数据存储（UserDefaults + 自定义文件存储）
- Xcode 项目，依赖 CoreXLSX（用于解析Excel导入）

## 项目结构
```
App/
  AccessoryBundleApp.swift    - 入口，注入 DataManager、OnboardingManager
  ContentView.swift           - 主页：分类卡片网格、拖拽排序、编辑/删除、欢迎提示、自定义颜色选择器、自定义图标上传
Features/
  AccessoryListView.swift     - 配件管理列表
  BundleDetailView.swift      - 套餐详情（含图片轮播）
  BundleEditView.swift        - 套餐编辑
  CategoryView.swift          - 分类详情页
  DataManager.swift           - 数据管理（CRUD、排序、持久化）
  OnboardingManager.swift     - 首次启动提示状态管理
  BatchImport/
    BatchImportEntryView.swift  - 批量导入入口（模板下载+文件导入）
    ExcelParser.swift           - Excel解析器
    TemplateManager.swift       - 模板文件管理
    ParsedImportResult.swift    - 解析结果模型
Models/
  Accessory.swift             - 配件模型
  Bundle.swift                - 套餐模型
  Category.swift              - 分类模型（含 customIconPath、Hashable）
Resources/
  Assets.xcassets             - 资源文件
Info.plist                    - 配置（含屏幕方向支持）
```

## 已完成功能
1. 分类管理（添加/编辑/删除/自定义图标/自定义颜色）
2. 分类卡片拖拽排序（编辑模式下长按拖拽）
3. 套餐管理（创建/编辑/删除套餐，关联配件）
4. 配件管理（增删改查，缩略图保存）
5. 图片轮播（套餐详情页）
6. PS风格自定义颜色选择器（色相/亮度/饱和度条）
7. 自定义图标上传（PhotosPicker）
8. 首次启动引导（欢迎提示卡片 + 配件管理气泡）
9. 编辑模式下点击卡片可编辑分类，长按可拖拽排序
10. 非编辑模式下长按卡片弹出上下文菜单可编辑
11. 批量Excel导入配件（模板下载+文件导入双入口）

## 计划中的功能

### 一、VIP门店版功能设计

#### 1. 套餐分享海报
- **功能描述**：一键生成精美的套餐宣传海报，支持分享到微信、朋友圈等
- **海报内容**：套餐名称、配件列表、总价、优惠价、门店Logo、二维码
- **使用场景**：店员转发给客户、朋友圈营销、店内展示屏
- **实现要点**：使用 UIGraphicsImageRenderer 渲染，支持自定义模板

#### 2. 客户展示模式
- **功能描述**：面向客户的展示界面，隐藏成本和利润信息
- **核心特性**：
  - 只展示配件名称、图片、零售价
  - 隐藏进价、利润等敏感信息
  - 支持投屏/外接显示器
  - 防止误触返回（需要密码退出）
- **使用场景**：客户到店时展示套餐方案

#### 3. 数据导出
- **功能描述**：导出配件/套餐数据为Excel或PDF
- **导出内容**：
  - 配件库存清单
  - 套餐组合明细
  - 销售统计报表（未来）
- **注意**：已移除Excel导出功能（因文件过大问题），后续使用PDF导出方案

#### 4. 成本利润计算
- **功能描述**：为每个配件添加进价，自动计算套餐利润
- **数据模型扩展**：
  ```
  Accessory: + costPrice: Double
  Bundle: + calculatedProfit: Double
  ```
- **展示形式**：
  - 配件编辑页添加进价输入
  - 套餐详情显示成本汇总和利润率
  - 管理者视图可查看利润分析

#### 5. 定价策略建议
- **功能描述**：基于历史数据和行业标准给出定价建议
- **实现方式**：分析配件组合的市场行情，推荐最佳套餐价格

### 二、多门店企业管理功能设计

#### 1. 组织架构设计
```
Organization（企业/组织）
├── Stores[]（门店列表）
│   ├── Store（单个门店）
│   │   ├── name: String
│   │   ├── address: String
│   │   ├── managerId: String
│   │   └── quota: QuotaLimit
├── Users[]（用户列表）
│   ├── User
│   │   ├── role: UserRole (owner/admin/manager/staff)
│   │   ├── storeId: String?
│   │   └── permissions: [Permission]
└── Billing（账单）
    ├── plan: SubscriptionPlan
    ├── seats: Int
    └── billingCycle: Monthly/Yearly
```

#### 2. 角色权限体系
| 角色 | 权限范围 |
|------|----------|
| Owner（企业主） | 全局管理、账单管理、所有门店数据 |
| Admin（管理员） | 门店管理、用户管理、数据导出 |
| Manager（店长） | 本店配件管理、本店套餐管理、查看本店报表 |
| Staff（店员） | 查看配件、查看套餐、客户展示模式 |

#### 3. 配额管理
- **按门店数计费**：基础版含1个门店，增购门店按数量收费
- **按用户数计费**：基础版含3个账号，增购用户按数量收费
- **功能模块**：高级功能（利润分析、数据导出）作为增值模块

#### 4. 数据同步策略
- **门店数据隔离**：每个门店只能看到自己的配件和套餐
- **总部模板下发**：总部可创建标准套餐模板，推送到各门店
- **数据汇总**：Owner/Admin可查看全企业数据汇总报表
- **同步机制**：
  - 实时同步（WebSocket）：库存变动、价格调整
  - 定时同步：销售数据、统计报表

#### 5. 后端架构建议
- 服务端：Node.js / Python FastAPI
- 数据库：PostgreSQL（支持多租户架构）
- 缓存：Redis（会话管理、热点数据）
- 文件存储：OSS/S3（配件图片）
- 认证：JWT + OAuth2

### 三、已移除的功能

#### Excel导出功能（已移除）
- **移除原因**：导出的Excel文件体积过大，影响用户体验
- **移除时间**：批量导入功能整合时
- **替代方案**：计划使用PDF导出替代
- **相关文件**：ExcelExporter.swift 已删除

## 重要技术备注
- SF Symbol 名称注意平台差异：display(非desktopcomputer)、computermouse(非mouse)、airpodspro(非airpodpro)
- ForEach 中不能直接用 Range<Int>，需提取为独立 View 结构体并预计算数组
- ForEach 闭包内不能声明 var，需提取为辅助函数返回元组
- 新增 Swift 文件需手动添加到 project.pbxproj 的4个区段
- Git 代理配置：本机使用 127.0.0.1:7890 代理访问 GitHub
- GitHub 仓库：https://github.com/wbl421/AccessoryBundle

## App Store 信息
- Bundle ID: com.skanie.accessorybundle
- 暂定名称：配件套餐
- 暂定副标题：会员专属·套装搭配
- 目标：先上架免费版自用，后续开发门店版付费功能

# AccessoryBundle - 会员配件套餐搭配管理App

## 项目概述
iOS 原生 App，用于管理配件商品和搭配套餐，主要面向 Apple 授权经销商门店。

## 技术栈
- Swift + SwiftUI
- iOS 16.0+
- 本地数据存储（UserDefaults + 自定义文件存储）
- Xcode 项目，无第三方依赖

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

## 计划中的功能
- 门店版内购解锁（套餐分享海报、客户展示模式、数据导出、成本利润计算）
- 批量Excel导入配件（图片嵌入单元格方式）
- 连锁门店同步（总部管理账号 + 子门店账号，需后端）
- 免费版/门店版区分（免费版基础功能全开放，付费功能为帮门店赚钱的高级功能）

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

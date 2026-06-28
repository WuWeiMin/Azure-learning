<!-- 目标路径: README.md（仓库根目录，不需要建文件夹）-->

# Lucy's Dev Learning Repo

个人学习/实践笔记仓库，记录 Azure、Dynamics 365、C# 等技术学习过程，方便在公司用GitHub随时查看。

## 目录结构

```
.
├── README.md                          # 本文件
├── notes/                             # 学习笔记（Markdown）
│   └── azure/
│       └── service-bus-quickstart.md  # Service Bus 入门笔记
└── src/                                # 代码示例
    └── azure/
        ├── ServiceBusSenderDemo.cs    # 发送消息示例
        └── ServiceBusReceiverDemo.cs  # 接收消息示例
```

## 使用说明

1. 每个文件顶部有 `目标路径` 注释，标明这个文件应该放在仓库的哪个目录下
2. 在 GitHub App / 网页创建文件时，文件名直接输入完整路径（如 `notes/azure/service-bus-quickstart.md`），会自动建好对应文件夹
3. 内容会持续更新，新增主题时会同步更新本README的目录结构

## 学习主题进度

- [x] Service Bus 基础（Queue、发送/接收消息）
- [ ] Service Bus Topic + Subscription
- [ ] Managed Identity
- [ ] Dynamics 365 Plugin 开发
- [ ] Dead Letter Queue

---
*仓库创建: 2026-06-28*
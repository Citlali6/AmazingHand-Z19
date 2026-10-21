# 本机工程目录（2026-10-21）

负责人指定的比赛工作区是 `F:\嵌入式fpga比赛`。本机全部新工程开发集中到 `F:\嵌入式fpga比赛\工程project开发`，当前唯一开发入口为其下的 `VisionGrasp-Z19`。

```text
F:\嵌入式fpga比赛\
├── 工程project开发\
│   ├── VisionGrasp-Z19\       当前机械臂开发仓库
│   ├── 板卡基础工程\
│   │   ├── ARM\               Z19 PS Hello World / Vitis 历史工程
│   │   └── FPGA\              Z19 LED / Vivado 基础工程
│   └── 历史归档\
│       ├── 旧仓库\             旧主仓库、四个关联工作树、迁移前 clone
│       ├── 相机与HIL调试\       历史构建、诊断脚本、日志、产物
│       ├── 相机裸机验证\        相机早期裸机工程与记录
│       └── 仓库迁移记录\        更名/迁移审计资料
├── 相关资料\                   已有厂商资料、SD、比赛指南
└── 整理记录\2026-10-21\        迁移清单、哈希、验证结果、旧设计原文
```

## 开始新工作

```powershell
Set-Location -LiteralPath 'F:\嵌入式fpga比赛\工程project开发\VisionGrasp-Z19'
git status
git branch --show-current
git remote get-url origin
```

`origin` 必须为 `https://github.com/Citlali6/VisionGrasp-Z19.git`。按 [Git 工作流](../GIT_WORKFLOW.md)先处理现有状态，干净工作区才同步 main 并创建新分支。整理分支 `chore/workspace-cleanup-20261021` 单独通过 PR 交付，后续任务不得直接丢弃未提交工作或带到 main。

## 兼容路径与限制

- `F:\ARM`、`F:\FPGA` 是指向本目录内板卡基础工程的 Junction，用于保留既有工程的硬编码路径；不是独立工程副本。
- 当前聊天占用 `F:\Amazing_Hand`，其目录本身保留，子目录为归档目标的 Junction，根文件为硬链接。实际内容已归档；旧入口仅兼容当前聊天与历史路径，不作为新开发入口。
- 四个旧工作树的 Git 位置指针已随迁移修复，分支、提交、remote 保持原样。旧 Tom 仓库只读；原 clone 的旧仓库地址未被改写。
- 不把 `.venv` 等本地环境当作新项目环境复用。新 PC 环境按 [Anaconda 指南](ANACONDA_SETUP_WINDOWS.md)使用隔离的 `visiongrasp`。
- 本次只做本机目录/文档整理，没有运行 Vivado/Vitis 构建或连接硬件。新中文目录下的 Xilinx 工具兼容性尚未验证；历史工程保留上述英文兼容路径。
- F 盘其他科研项目、软件安装目录、系统目录和已有厂商资料保持原样；无法确认无用的工程产物归档保留。

迁移验证和每个旧路径对应的新路径见本机 `整理记录\2026-10-21\relocation-plan.json`、`relocation-validation.json`，不将本机环境/临时文件清单加入 Git。

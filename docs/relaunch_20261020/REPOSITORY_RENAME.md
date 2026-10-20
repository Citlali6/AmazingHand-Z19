# VisionGrasp-Z19 仓库更名及团队迁移指南

> 本文记录 2026-10-20 经负责人确认的仓库更名。**作品展示名**：FPGA辅助视觉抓取系统；**GitHub 仓库名**：`VisionGrasp-Z19`；**唯一研发目标**：`Citlali6/VisionGrasp-Z19`。此前仓库名为 `Citlali6/AmazingHand-Z19`，其代码、Issue、PR、历史提交、分支均属于同一个 GitHub 仓库；实测仓库 ID `1425473964` 不变。**旧 Tom-mr33 仓库不属于本次更名对象，不允许任何写操作。**

## 1. 当前统一标识

| 项目 | 正式值 | 备注 |
|---|---|---|
| 报名 / 演示 / 文档标题 | **FPGA辅助视觉抓取系统** | 正式对外作品名称 |
| 当前 GitHub URL | **https://github.com/Citlali6/VisionGrasp-Z19** | 唯一新开发仓库 |
| HTTPS 克隆地址 | `https://github.com/Citlali6/VisionGrasp-Z19.git` | 新团队与 Codex 应使用 |
| SSH 克隆地址 | `git@github.com:Citlali6/VisionGrasp-Z19.git` | 用户已配置 SSH 时使用 |
| 默认基线 | `main` | 工作分支 → PR → 根据仓库规则审查合并 |
| 原 GitHub 名称 | `Citlali6/AmazingHand-Z19` | 只用于迁移历史说明；不要为其新建另一个仓库 |
| 旧机械手资源 | `AmazingHand/`、旧 `sim/` 等 | 历史实物/仿真研究资产，**不改路径或许可证** |

GitHub 通常对旧仓库 URL 提供重定向，**但重定向不是长期依赖契约**。尤其一旦旧仓库名未来重新被创建，旧链接的解析可能改变。新开发必须显式使用新 URL，不要以旧 URL 还能访问作为测试通过。

## 2. 已克隆仓库的队友：只需要修改 Git remote（无需重新克隆）

PowerShell / Git Bash 在你原来克隆的本地仓库文件夹内执行（文件夹名可以仍然叫 `AmazingHand-Z19`，**不用搬动或重命名工作目录**）：

```bash
git status
git remote -v
git remote set-url origin https://github.com/Citlali6/VisionGrasp-Z19.git
git remote -v
git fetch origin
git branch --show-current
git status
```

**安全检查**：在 `git remote -v` 输出里，`origin` fetch/push 都必须指向 `Citlali6/VisionGrasp-Z19`；如果有尚未提交的本地改动，`git status` 先保留它们，不能 `reset --hard`、`clean -fd` 或强推。更新 remote 不会删除工作分支，也无需把本地目录强制改名。

如果原 remote 采用 SSH，执行：
```bash
git remote set-url origin git@github.com:Citlali6/VisionGrasp-Z19.git
```

## 3. 新加入的两位队友：从新地址克隆

```bash
git clone https://github.com/Citlali6/VisionGrasp-Z19.git
cd VisionGrasp-Z19
git remote -v
git branch --show-current
```

新建功能分支前阅读 `README.md`、`AGENTS.md`、`docs/relaunch_20261020/DEMO_FIRST_POLICY.md`，按照 Issue #14（官方 SDK）、#7（机械臂）、#8（PC 视觉）优先执行；#9 FPGA 为独立并行 P1、**不能阻断视觉抓放**。

## 4. Codex、VS Code、CI 和外部资料

- **Codex / ChatGPT GitHub 连接**：新的所有指令写为 `repository=Citlali6/VisionGrasp-Z19`。如果 Codex 保存了旧仓库的授权/工作区，重新从新的仓库位置选择；不能只改 README 就认为 Agent 一定自动更新。
- **VS Code**：在已有项目中运行 `git remote -v` 确认；GitHub Pull Requests 等扩展可以刷新仓库关联；存在旧固定路径的终端任务按实际文件夹位置调整。
- **CI / Webhook / 外部平台 / 徽章**：检查仓库 Settings 中 Actions、Webhook、GitHub Pages、第三方自动部署、Issue/PR 触发器的仓库路径。重命名通常保留仓库 Git 历史，但第三方绑定、脚本、硬编码 URL 可能需要手动更新；未检查的集成标 `NOT VERIFIED`。
- **合作成员**：旧仓库的 GitHub 仓库 ID 不变，仍需核对协作者访问；如果某个 GitHub 应用没有自动识别新仓库，在 GitHub/ChatGPT 中重新选择可访问的仓库，不要建立“空仓库”复制替代。
- **会议 PPT / 报名材料**：项目标题统一写「FPGA辅助视觉抓取系统」，仓库链接统一为新 URL；历史项目中真实的 AmazingHand 名称可以保留，不把过去的手部仿真称为本期 RoArm 仿真。

## 5. 收尾验收清单

- [ ] GitHub 页面显示 `Citlali6/VisionGrasp-Z19`，`main` 历史和仓库 ID 没变。
- [ ] 根 README、`AGENTS.md`、现行 `docs/` 和 #6–#14 的新任务链接已更新。
- [ ] 两位队友本地 `git remote -v` 显示新的 fetch/push 地址。
- [ ] Codex 在新仓库能读取 `AGENTS.md` 和 Issue，后续 PR 明确由新仓库创建。
- [ ] 旧项目代码、迁移证据、历史 Git SHA 和 GPL/AGPL/CC 归属完整保留。
- [ ] 外部 CI/网页/自动化的旧仓库 URL 若仍存在，已核对或标为待处理。
- [ ] **没有借更名之机直接合并旧功能 PR、重配 Z19、刷 ESP32 或真实运动机械臂。**

本文是仓库操作指引，不等于机械臂/FPGA 端到端功能已完成。项目当前仍采用 **PC+RoArm+USB 摄像头首先交付 R0/R1/R2，Z19/PL 并行 R3** 的开发优先级。

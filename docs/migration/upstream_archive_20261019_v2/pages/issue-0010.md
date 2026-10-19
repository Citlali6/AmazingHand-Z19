# #10: [P0][Codex] 打通 Host → MuJoCo 实时灵巧手控制

原作者：`Citlali6`；状态：`open`；创建时间：`2026-10-17T10:35:06Z`。

原链接：https://github.com/Tom-mr33/AmazingHand-based-on-FPGA/issues/10

**只读归档：保留原作者和时间，不代表在新仓库重新发布、审批或合并。**

## 目标

打通仓库现有 Host 控制层与 MuJoCo 手模型，交付一个可本机运行的实时交互 Demo。用户发出或选择张开、抓取、保持、释放、停止指令后，Host 必须把**当次输入**转换为控制状态/目标并驱动 MuJoCo；同时持续读取并展示仿真状态或反馈。固定预设动画、仅播放轨迹、mock 状态机空转都不算完成。

## 现有基础（先复用）

- Host 入口与状态机：`host/app/main.py`
- 后端抽象及仿真后端：`host/app/control/servo_base.py`、`backend_sim.py`、`scs_sim.py`
- 抓取策略：`host/app/strategy/grasp_selector.py`、`grasp_table.json`
- MuJoCo 场景与工具：`sim/ah_model/`、`sim/control_panel.py`、`sim/live_viewer.py`、`sim/showcase.py`
- 既有测试：`host/tests/smoke_test_control.py`、`smoke_test_backend.py`、`smoke_test_sim.py`

请先阅读 `AGENTS.md`、`docs/GIT_WORKFLOW.md`、`docs/design/architecture.md`、`docs/design/interface.md`、`docs/fpga/implementation_progress.md` 及以上实现，再决定最小必要改动。现有模拟/冒烟通过不等于实时 Demo 已完成。

## 需修改范围

优先只改 `host/app/`、`sim/` 与必要的 `host/tests/`，避免改 RTL、Linux SD/相机驱动、已验证 bit/XSA。沿用现有后端和状态机；若接口不够用，添加最小适配层并明确输入、输出、单位、状态与错误语义。Issue B 的 PL 联调应通过稳定的 Host 控制入口对接，双方避免同时编辑同一文件。

## 实际交付物

1. 一条可运行的实时链路：命令输入（键盘/现有命令入口即可）→ Host 状态机/抓取策略 → MuJoCo 控制 → 仿真反馈回 Host。
2. 清晰可见的实时 MuJoCo 窗口或控制面板，能观察手的状态与命令效果。
3. 支持张开、抓取（使用目标物/抓取策略）、保持、释放、停止；停止应立即进入安全状态并拒收继续运动命令，直到显式复位/重新使能（若当前架构有不同安全语义，需采用更保守且可解释的实现）。
4. 可复制的启动命令及极简使用说明；优先增强现有入口，不另起一套无关 Demo 框架。

## 验收（必要，避免重复冒烟）

- 从干净进程启动 Demo，至少一次实际操作序列：张开 → 抓取 → 保持 → 释放；停止操作也单独验证。
- 输入变化会引起仿真控制量/关节状态的**在线变化**，并能读取、显示当前状态/反馈；证明不是预置动画或只更新 UI 文本。
- 停止后控制输出归于安全值、不会继续执行旧目标；异常/超时路径至少有基本停机兜底。
- 运行与改动直接相关的现有测试，再做一次上述端到端演示；无需重复跑无关测试矩阵。PR 说明实际运行方式、验证结果及尚未完成的物理硬件项。

## 协作、依赖与禁止事项

- 与 Issue B 尽量并行：Issue A 负责 Host/MuJoCo；Issue B 负责 RTL、可复现 PS/PL 构建与通信桥接。先发布最小稳定控制/反馈接口，及时在两 Issue/PR 中同步字段和单位。
- 遵守仓库分支与 PR 规则：从最新 main 建独立分支，经 PR 和队友 Review；不要直接改 main、不要自行合并。
- 开发速度优先：不做无关重构、不重复冒烟、不写冗长文档；交付可运行功能和必要验收。
- 保留已有 Linux SD、相机驱动及已验证 bit/XSA；不得覆盖或把它们当成本任务临时输出目录。
- 接线、拨码、FMC、电平转换、供电或上板步骤若需要人工执行，集中整理成明确现场清单；不得声称未执行的实机验证已通过。
- 不把接口 v0.3 草案当成已实现功能；任何接口变更须先核对当前实现与设计约束并说明。


## 评论

## Review

## 行内评审

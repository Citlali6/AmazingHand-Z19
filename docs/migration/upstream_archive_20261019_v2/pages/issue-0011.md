# #11: [P0][Codex] Z19 FPGA 控制链构建 + MuJoCo 硬件在环联调

原作者：`Citlali6`；状态：`open`；创建时间：`2026-10-17T10:35:50Z`。

原链接：https://github.com/Tom-mr33/AmazingHand-based-on-FPGA/issues/11

**只读归档：保留原作者和时间，不代表在新仓库重新发布、审批或合并。**

## 目标

在现有 RTL 与 `fix/fpga-xsim-bringup` 有效修复基础上，交付可复现构建的 Z19 PS/PL 手控制工程和双向通信桥，再完成 **Z19 PL ↔ PC Host ↔ MuJoCo** 硬件在环控制。必须证明 PL 的控制逻辑实际影响 MuJoCo 手部状态并参与安全/反馈闭环；PS 只能做网络/串口传输与必要的数据搬运，不能绕过 PL、直接向电脑发送预制动画命令。

## 继承的现有实现与参考

- RTL：`fpga/rtl/{top,axi_lite_regs,grasp_fsm,servo_bus_ctrl,half_duplex_uart,scs_protocol,cdc_utils}.sv`
- RTL 仿真与黄金向量：`fpga/sim/`（含 `tb_grasp_fsm.sv`、`tb_servo_bus.sv`、`scs_slave_model.sv`、`golden_vectors.txt`）
- Python 协议参考及 Host 后端：`host/app/control/{scs_protocol,backend_fpga,servo_base}.py`
- 设计约束：`docs/design/interface.md`、`docs/fpga/interface_proposal.md`、`docs/fpga/technical_design.md`、`docs/fpga/implementation_guide.md`、`docs/fpga/verification_acceptance.md`
- 从 `fix/fpga-xsim-bringup` 分支 `97657ff` 起检查并选择性继承与 XSim/RTL bring-up 直接相关的有效修复；不要盲目合并整分支或覆盖 main 后续改动。PR #7 是现有 RTL/仿真骨架来源。

## 需修改范围

主要在 `fpga/rtl/`、`fpga/sim/` 及新建、隔离的 PS/PL 工程和通信桥目录（建议 `fpga/hand_control/`）；Host 侧仅增加必要的传输适配。开始前核实工作分支、main 和历史分支差异，并阅读 `AGENTS.md`、`docs/GIT_WORKFLOW.md`、`docs/design/interface.md`。建立工程优先用可重复 Tcl/源码配置，不把临时 Vivado/Vitis 输出当作唯一源文件。

## 实际交付物

1. 一个可重复构建的 Z19 PS/PL 控制工程，能实例化现有 RTL、完成综合/实现所需工程生成（若环境无 Vivado，提供可复现脚本并如实标明未做工具构建）。
2. PS 与 PL 之间可工作的命令/反馈寄存器或等效桥接；PC Host 到 PS 的双向传输。通信格式、字段、单位、心跳/序号、超时、错误码与复位语义必须和实际代码一致。
3. HIL 数据流：Host 命令进入 Z19 PS 后交给 PL 控制逻辑；PL 生成的目标/状态/故障遥测回 Host 并驱动 MuJoCo；MuJoCo 产生的虚拟关节/负载反馈经 PS 回灌 PL。提供可观察的 PL 寄存器/计数器/遥测证据，证明 PL 控制结果决定仿真动作。PS 不得直接生成并推送仿真动画轨迹来替代 PL 控制。
4. 可启动的 HIL 命令/最小界面，以及实际接线、拨码、FMC、电平转换、供电和上板步骤的**单份现场操作清单**。涉及未执行的人工操作须标注待现场完成。

## 验收（必要）

- RTL 仿真：运行与改动直接相关的 testbench/黄金向量，覆盖有效命令、抓取/保持/释放、停止或急停、通信超时/错误恢复等关键路径。避免重复跑无关测试。
- 工程构建：提供一个干净目录下的可复现构建入口；若可用 Vivado/Vitis，在 Z19 目标器件上构建并报告结果、工具版本和关键告警。工具或硬件不可用时，不得声称已通过。
- HIL 端到端：按真实双向链路启动，操作至少完成张开→抓取/保持→释放，并单独验证停止；MuJoCo 状态变化能追溯到 PL 遥测/控制输出，虚拟反馈能回到 PL。故障/超时应使 PL 进入定义的安全状态，停止后不得继续旧目标。
- 现场涉及用户执行的所有物理步骤集中列入一份清晰清单交给用户；不得假装已接线、拨码、上电或完成实板测试。PR 报告区分 XSim、工具构建、上板和 MuJoCo HIL 各自的证据。

## 并行协作、接口与禁止事项

- 与 Issue A 尽量并行：本任务负责 RTL/PL、工程与桥接；Issue A 负责 Host 状态机及 MuJoCo 实时 Demo。先通过 Issue/PR 评论约定最小 Host↔HIL 传输接口（命令、目标/反馈、状态、错误、单位、超时），尽量把修改限制在不同目录；如果必须共享 Host 文件，先协调后改。
- 接口 `v0.3` 仍是草案，不能视为已实现协议。先核对当前实现和 `docs/design/interface.md`，明确实际版本；需要变更时在 PR 中记录兼容方案与来源。
- 保留现有 Linux SD、相机驱动、已验证 bit/XSA、相机原 BD/XDC/IP 及其哈希归档。禁止覆盖、重命名、清理或将其作为手控制临时输出目录；如工程复用需新建隔离工程并保持原件只读。
- 读取 `fix/fpga-xsim-bringup` 后仅继承必要修复，保留现有工作和历史，不强推、不直接写 main；按团队规范新建工作分支并经 PR/队友 Review，不合并 PR。
- 开发速度优先：优先打通最小闭环和真实可运行交付，不做无关重构、不重复冒烟、不写冗长文档；但不能略过急停、基本安全检查和必要端到端验证。


## 评论

## Review

## 行内评审

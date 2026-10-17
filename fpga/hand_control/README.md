# Z19 手控制 HIL 工程（Issue #11）

这是独立的 **PS AXI → PL grasp_fsm → 遥测 → PC MuJoCo → 反馈 → PL** 工程。
PS Python 仅复制命令和反馈，不生成运动轨迹。没有板卡时不会回退成软件 PL。
不实例化相机 IP，也不驱动物理舵机/FMC；原相机 BD/XDC/bit/XSA 和 Linux SD 保持原样。

## 构建与检查

Vivado 2020.1、器件 `xczu19eg-ffvc1760-2-i`，重用仓库 ALINX PS preset。
Vivado 2020.1 的 BD module-reference 需要 Verilog shell，核心仍为 SystemVerilog。
PS `M_AXI_HPM0_LPD` 经 SmartConnect 接 4 KiB HIL 寄存器，基地址 `0x80000000`。
使用 PS `pl_clk0` 同一时钟域和 `proc_sys_reset`，没有外部 PL 时钟/IO约束。
preset 请求 100 MHz、工具实际生成 **96.968727 MHz**；脚本据此设置核心时基、500 ms 看门狗。

在仓库根目录运行，输出目录必须不存在，脚本拒绝覆盖：

```powershell
& F:/Xilinx/Vivado/2020.1/bin/vivado.bat -mode batch -source fpga/hand_control/build.tcl -tclargs F:/ah-hil-new-build impl
# 只生成工程/XSA（无bit）用 generate；只综合用 synth。
& ./fpga/hand_control/run_sim.ps1 -VivadoBin F:/Xilinx/Vivado/2020.1/bin -OutputDirectory F:/ah-hil-new-sim
python -m unittest discover -s fpga/hand_control/tests -v
```

`impl` 成功产物：`hand_hil.runs/impl_1/hand_hil_bd_wrapper.bit`、含 bit 的 `hand_hil.xsa`、
`timing_impl.rpt`、`drc_impl.rpt`。脚本在综合前也生成一个不含 bit 的 XSA，**仅见 XSA 不能证明实现完成**。
本次工具构建实测结果和路径见 `docs/log/2026-10-17-issue11.md`。
可远程复核的原始日志/报告及产物发布状态见 [证据归档](evidence/2026-10-17/README.md)。

选择性继承 `97657ff` 的 SCS 发包/解析、轮询、超时起点、事件槽和 FSM 事件脉冲修复，
及三个相关 TB；没有合并分支或改写历史。新 HIL 使用既有 `grasp_fsm`，增加显式 HOLD、
全状态停止/掉线保护和明确重置。三个旧 TB 加 HIL AXI TB 构成直接相关仿真。
字节级 SCS 黄金模型仍是未物理标定的旧 profile；**新 HIL 工程不代表物理舵机工程已验收**。
遗留 `top.sv`、`axi_lite_regs.sv` 和旧整板构建入口未冒充已修好的物理链路。

## 启动

先完成 [单份现场操作清单](FIELD_CHECKLIST.md)。只有匹配的新 PS/PL 平台已运行，才能执行：

```sh
# Z19 Linux，Python 3.7+，仅标准库。选择该板实际可信LAN地址；默认仅127.0.0.1。
python3 fpga/hand_control/ps/hil_server.py --bind <Z19_IP> --port 8765
```

PC 客户端由并行 Issue #10 提供；其更改在另一工作分支，本分支没有虚构该文件已存在。
集成后入口为 `python host/app/main.py --mujoco --hil <Z19_IP>:8765`。
启动先 hello/STOP；操作员显式 reset，再 open → grasp/hold → release；另测 STOP。
不需要 SCS 舵机、FMC 转接或电平转换器参与纯 MuJoCo HIL。

## 共同传输契约 amazinghand-hil/1

TCP 8765，逐行 UTF-8 JSON，每行最多 4096 B，PC 每 20 ms 一帧。
这份 **HIL schema 1 是独立的仿真传输契约**；不取代物理接口 `docs/design/interface.md` v0.2.2，
也不声称 v0.3 草案已经生效。双方在本次聊天确认，不代表已向 GitHub 发评论。

首先发送 `{"protocol":"amazinghand-hil/1","cmd":"hello"}`，读取 `accepted_seq`。
此后所有请求（包括 tick/reset/stop）必须含如下字段：

```json
{"protocol":"amazinghand-hil/1","seq":42,"heartbeat":42,"cmd":"grasp","target_raw":[2400,2400,2400,2400,2400,2400,2400,2400],"feedback":{"position_raw":[2048,2048,2048,2048,2048,2048,2048,2048],"load_raw":[0,0,0,0,0,0,0,0],"online_mask":255}}
```

`cmd` 为 `tick/reset/open/grasp/hold/release/stop`。
`seq` 从 hello 的 accepted_seq+1 开始，uint32、严格递增；`heartbeat=seq`。
不支持一个 PL 启动周期内序号回卷；达到 uint32 上限须停止并重新初始化匹配平台。
hello 只读，不刷新心跳、不清故障。每个普通请求把完整 8 路反馈原子提交给 PL。

响应为完整 PL 快照（由 PS 原样读回），例如：

```json
{"protocol":"amazinghand-hil/1","seq":42,"source":"pl","state":"CLOSING","torque_enabled":true,"fault":0,"pl_tick":9000000,"accepted_seq":42,"feedback_seq":42,"command_count":2,"feedback_count":42,"target_raw":[2400,2400,2400,2400,2400,2400,2400,2400],"position_raw":[2100,2100,2100,2100,2100,2100,2100,2100],"load_raw":[100,100,100,100,100,100,100,100]}
```

状态为 IDLE/PREGRASP/CLOSING/HOLD/RELEASING/PROTECT。
`pl_tick` 是按实际时钟递增的 uint32 周期计数（约44.3秒回卷），不是毫秒。
`command_count` 是 PL 接收非 tick 动作的计数（reset/stop独立处理，不计入），
`feedback_count` 是完整有效序号提交计数；两者模2³²。
它们和目标/反馈快照用于证明 PL 参与；仅连上 TCP 不代表通过 HIL 验收。

位置是旧黄金模型 **SIM raw 0..4095**，±π的线性编码，具体模型再按 actuator ctrlrange 限制；
这不是已校准实物角度。8路次序对应 ID1..8。
load_raw 0..1023 是 MuJoCo `abs(actuator_force)*100` 饱和的仿真量，不是 N 或 N·m。
接触阈值沿用 6×64=384，PREGRASP约0.3s、CLOSING上限约3s、RELEASING约0.5s。
达到负载阈值或显式 hold 时，**PL 锁存测量位置**为 HOLD 目标；tick不能重写动作目标。
open/grasp从IDLE接受；重复动作前先release或reset。release使用最近open快照；
reset后尚无open时，预张快照为reset时的新反馈位置。

故障位：1=500ms心跳超时，2=上电/STOP/断连，4=任一路离线，8=重复/倒序seq或心跳重复，16=非法命令。
任一故障锁存 PROTECT，torque_enabled=false，遥测目标变为当前反馈，旧目标不得继续执行。
reset要求8路online和新seq/反馈，只清锁存并设置新预张快照；**不恢复力矩或旧动作**。
PC再发新动作后才可使能。服务退出/断连立即写带外STOP，SIGTERM/Ctrl+C走清理；
PS进程崩溃或网络堵塞时由独立PL看门狗兜底。TCP读超时400ms；清理失败仍由PL500ms处理。
该通道仅面向可信实验LAN，没有认证或加密。

## HIL AXI schema 1（仅对应本目录核心）

所有偏移为32位小端、4字节对齐；不能用遗留 `backend_fpga.py` 直接访问本bank。

| 偏移 | 含义 |
|---|---|
| 0x00 / 0x04 | 只读 MAGIC=0x4148494c / schema=1，PS写任何数据前核验 |
| 0x08 / 0x0c | 命令shadow（tick0 reset1 open2 grasp3 hold4 release5 stop6）/ online_mask |
| 0x10 / 0x14 | seq shadow / heartbeat shadow |
| 0x18 | 写1原子提交命令、目标、8路反馈和seq |
| 0x1c | 写1锁存完整32-word遥测快照 |
| 0x20+i×4 | 8路目标shadow，低12位 |
| 0x40+i×4 / 0x60+i×4 | 8路测量位置 / load shadow |
| 0xf0 | 写bit0=1立即锁存STOP，不依赖序号 |
| 0x100..0x11c | state、torque、fault、pl_tick、accepted_seq、feedback_seq、command_count、feedback_count |
| 0x120+i×4 | PL控制目标快照（torque off时为测量位置） |
| 0x140+i×4 / 0x160+i×4 | PL实际接受的8路测量位置/load快照 |

AXI支持分离AW/W及响应背压、WSTRB；只支持一个未完成读和一个未完成写。
PS顺序写shadow，最后COMMIT，再SNAPSHOT；若反馈不合法或seq重放，锁存保护。
PC停止后仍可tick提交新反馈并观察保护，但只有reset能解除锁存。

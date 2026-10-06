# FPGA 第一版实施施工指南

状态：施工步骤草案；除 §2 明示的本轮只读检查之外，其余尚未执行。
应先读 [路线图](README.md)、[技术设计](technical_design.md) 与 [接口草案](interface_proposal.md)。
第一版目标是10-14完成真实抓取验收，不先开发DPU或迁移整套工具。

## 1. 每次施工前的统一要求

检查 `git status` 与 `git branch --show-current`，工作区有未经处理的变更先保留并报告。
从干净、更新的main新建任务分支，不在main写RTL/文档，不自动合并PR。
修改前读当日日志与唯一接口，明确本日工作包和输入依赖；每日在 `docs/log/` 记录真实完成/失败/待办。
本文“计划路径”不表示现有文件；命令里涉及它们的部分仅在后续实现落盘后执行。

## 2. 工具链检查与版本路线（10-06，G0）

### 2.1 本轮已有证据

本机已找到：

```text
F:/Xilinx/Vivado/2020.1/bin/vivado.bat
F:/Xilinx/Vitis/2020.1/bin/vitis.bat
```

Vivado在仓库外临时目录执行只读batch查询成功，输出：

```text
AMAZINGHAND_VIVADO_VERSION=2020.1
AMAZINGHAND_TARGET_PARTS=xczu19eg-ffvc1760-2-i
```

查询脚本逻辑如下，可在临时工作目录复核，禁止把查询成功当作综合许可/板卡已跑通：

```tcl
puts "AMAZINGHAND_VIVADO_VERSION=[version -short]"
set target_parts [get_parts -quiet xczu19eg-ffvc1760-2-i]
puts "AMAZINGHAND_TARGET_PARTS=$target_parts"
if {[llength $target_parts] != 1} {exit 2}
exit 0
```

后续若需复核，以实际保存路径调用；这不是本次跟踪的构建脚本：

```powershell
& 'F:/Xilinx/Vivado/2020.1/bin/vivado.bat' -mode batch -nolog -nojournal -source <已保存的检查脚本路径>
```

### 2.2 尚需执行的检查

| 检查 | 具体施工动作 | 通过证据 | 失败处置 |
|---|---|---|---|
| 器件/许可 | 对目标part构建最小LED工程，生成bit | synthesis/implementation/write_bitstream完整成功 | 区分器件包、许可、时序和代码；保留报错，不绕许可 |
| Z19官方工程 | 获取与实际板卡版本匹配的preset、XDC、示例与镜像说明 | 最小例程可本机重建，板端行为符合说明 | 不直接套ZCU102/KR260工程或未知来源preset |
| JTAG | 核对USB/JTAG驱动、Hardware Manager识别链 | 实际目标型号和链路记录 | 不按其他器件下载；排查线缆/驱动/供电 |
| Vitis/板端 | 确认BSP/XSA/FSBL流程是否本版需要；核对现有Linux状态 | 版本表、串口启动/网络/内核记录 | 不假定有Ubuntu；不在PC安装aarch64依赖 |
| XSim | 简单TB编译/展开/运行 | 正常退出、PASS与波形 | PATH缺失用完整路径；保留本版语法限制 |
| 构建空间 | 查看空闲空间、内存与输出目录 | 最小构建资源足够 | 不删除用户文件“腾空间”，安排合适目录 |

仓库竞赛指南 §3.3.3.1 推荐2026.1或2025.2，其他版本需报告说明和脚本可复现。
第一版优先2020.1：用户已安装且器件查询成功，兼容官方2020.1参考工程才继续。
若不兼容或许可不足，在10-06明确解决方案；不能把2020.1打开较新BD/IP后强行忽略升级错误。
版本迁移可后续另分支验证，不把“安装新版”设为第一版默认前置，也不自动安装工具。
公开依据：[AMD Vivado2020.1 UG973](https://docs.amd.com/v/u/2020.1-English/ug973-vivado-release-notes-install-license)。

## 3. 硬件交接与实物协议核验（10-06至10-07，G1）

### 3.1 现场交接清单

| 项目 | 必须确认/交付的内容 | 当前状态 |
|---|---|---|
| Z19 | 板卡/核心板版本、JTAG、串口、12V电源、散热、可启动介质 | 用户称配套齐全；未现场测试 |
| 舵机 | 完整型号后缀、固件、8路ID、连接器线序、单舵机是否可拆出 | 待队长确认 |
| 机械 | 左/右手、每路真实动作作用、中位/方向/安全范围 | 待队长交付；不照抄屈曲/外展假设 |
| 电气 | FMC转接板、排针映射、转换器型号/原理图/OE、J5实测1.8V | 待确认 |
| 电源 | 舵机额定电压、峰值电流、限流/保险/切断手段、共地 | 待确认；历史5V/2A不是通过证明 |
| 工具 | 示波器、合适探头、电脑、独立已验证舵机调试器/串口适配器 | 示波器可用；其他待确认 |

### 3.2 按顺序推进，禁止直接整手大角度测试

1. 断电核对端子和转接映射，检查地线、反接和短路；按板卡原理图确认bank电压与跳帽。
2. 先使能受控电源，测量1.8V与舵机侧电压；先不连接未知逻辑电平到PL。
3. 用已验证调试器连接单舵机，只读身份、固件、ID、反馈；不要按未核验地址改EEPROM。
4. 记录原始请求/回应字节和条件，确认字节序、反馈起点/长度、错误位、回复级别和回包时延。
5. 在队长给出的安全机械范围内，小幅移动、低速观察方向和负载；核验使能/卸力的真实写值和动作。
6. 使用示波器对比转换器A/B侧空闲、TX、RX、换向、电源纹波；检查PL收包期间输出已释放。
7. 将结果交成协议profile和标定表，修订Python参考模型/模拟器/测试；产生独立测试向量后才实现SCS字段。

单舵机通过后才连接2路、4路、8路；逐步测量总线波形、响应延时和电源压降，不能以1路通过推断8路通过。
未确定转换器稳定性时可以先用独立调试器验证舵机协议，但它不能替代PL接口最后上板验收。

建议标定表字段（计划放 `data/calibration/servo_map.json`，不是本轮已有文件）：

```text
schema_version, hand_side, servo_model, firmware, protocol_profile_version
channel_index, servo_id, mechanical_role, direction, middle_raw
min_safe_raw, max_safe_raw, degree_to_raw_mapping, allowed_speed_range
pregrasp_raw, grasp_raw, release_raw, contact_load_threshold
temperature_trip, feedback_age_limit, measured_at, measured_by, evidence
```

degree_to_raw_mapping可以是系数或分段表，但需标定来源和适用范围。
同一手指两舵机的耦合关系必须来自机械交接，不按旧文档默认“独立屈曲+外展”写控制算法。
没有实机标定的数据必须标为占位，不用于首版真实抓取。

## 4. 建立可复现PL工程（10-06起并行，G0/G4）

建议结构继承现有架构并补验证入口；以下目录/文件均为后续计划：

```text
fpga/
  rtl/       top.sv axi_lite_regs.sv half_duplex_uart.sv
             scs_protocol.sv servo_bus_ctrl.sv grasp_fsm.sv
             safety_ctrl.sv cdc_utils.sv
  sim/       tb_uart.sv tb_scs_protocol.sv tb_axi_lite_regs.sv
             scs_slave_model.sv tb_servo_bus.sv tb_grasp_fsm.sv
             tb_top.sv vectors/
  constr/    z19.xdc
  scripts/   build_project.tcl create_bd.tcl run_sim.tcl
  build/     构建生成目录（源码/IP配置不能只保存在这里）
data/metrics/  原始测量数据、实验元数据与结果汇总
```

`safety_ctrl.sv`可独立模块，也可先集成FSM/调度器；关键是保护路径优先级可验证。
不依赖手工GUI修改才能重建；GUI适合首次探索，确定配置后以Tcl/可追踪IP配置复现。

### 4.1 BD施工步骤

1. 明确part=`xczu19eg-ffvc1760-2-i`和官方Z19 PS preset来源/version，不从设计文档推测DDR/MIO参数。
2. 最小BD只保留PS、必要时钟复位、SmartConnect、自定义AXI控制IP；不加DPU/DMA/PL DDR。
3. 明确HPM端口、数据/地址宽度、频率和复位极性；采用单100MHz候选时，全链路实际配置一致。
4. 分配自定义IP地址，导出base与range供Host/设备树使用；不因旧设置写0x40000000就强行假定硬件一致。
5. 完成RTL顶层、IOBUF、LED/KEY与XDC；运行 `validate_bd_design`、生成输出、wrapper，再综合实现。
6. 加ILA仅探必要信号；记录调试版本和无ILA最终版本资源差异。

### 4.2 `build_project.tcl`后续应包含的内容

参数：项目名、输出目录、part、工具版本、是否加ILA、配置profile；相对脚本自身解析路径，避免依赖当前目录。
显式收集RTL/XDC，重建BD或导入可复现配置；检查所需IP版本和工具版不符即报错。
依次运行仿真入口、综合、实现、bit生成、XSA导出，失败非零退出。
保存 `report_timing_summary`、`report_utilization`、`report_drc`、`report_cdc`、时钟/方法学等报告，以及base/clock/IP列表。
记录生成产物的commit和hash，禁止只有“运行到write_bitstream”就称验收通过。

后续真实入口应类似以下命令；**本轮这些计划脚本尚不存在，不能现在执行**：

```powershell
& 'F:/Xilinx/Vivado/2020.1/bin/vivado.bat' -mode batch -source fpga/scripts/run_sim.tcl
& 'F:/Xilinx/Vivado/2020.1/bin/vivado.bat' -mode batch -source fpga/scripts/build_project.tcl
```

## 5. RTL施工顺序与调试重点（10-07至10-09，G2/G3）

| 顺序 | 开发动作 | 隔离验证办法 | 常见失败与定位 |
|---|---|---|---|
| UART | 整数位定时、中心采样、帧尾释放 | 纯字节TB、长帧/错误停止位/复位中断 | 停止位尚未发完就释放；FIFO空不等于帧结束 |
| SCS TX | 描述符→长度→payload→checksum | 独立Python/手算锚点逐字节对照 | endian错误、LEN错1、6B误写成4B |
| SCS RX | 增量解析、长度上限、预期ID、超时恢复 | 噪声/半帧/坏CS/迟到包/回波 | 错ID更新缓存；坏帧后无法重同步 |
| AXI | AW/W独立缓存、背压、WSTRB、shadow/active | 总线BFM，随机次序/背压与命令冲突 | 假设AW/W同拍；参数撕裂或重复提交 |
| 调度 | 绝对时隙、2路轮询、最坏预算 | 带线速/返回延时的从机模型 | 在理想零延时模型中“证明”500Hz/1kHz |
| FSM/保护 | 新鲜反馈门控、通道接触锁存、全状态保护 | 轨迹驱动，所有状态注入急停/掉线 | 空集合到位、超时当抓稳、只HOLD检查故障 |
| top | 完整PS主接口/总线/FSM集成 | 集成TB＋ILA触发 | 单模块通过但复位/启用顺序导致误动作 |

先做行为可测试的简单模块，再优化面积/频率。
模拟器物理常数不能进入真实RTL参数；参数必须来自标定或明确的设计上限。
原子提交和反馈失效逻辑在接整手前完成，不能作为“之后再完善”的附加功能。

## 6. 单舵机PL与Linux联调（10-10，G4）

### 6.1 首次加载

先备份/记录已可用板端环境的版本与加载方法，不覆盖启动介质或分区来试错。
根据现场状态选择已验证的JTAG调试或与现有Linux兼容的FPGA Manager/启动镜像流程；不要复制不匹配内核/器件的烧写命令。
PS初始化、PL时钟与AXI连通性必须随加载路径验证；仅JTAG下载PL bit不保证PS配置已就绪。
仓库项目框架要求烧写/分区/系统级命令前确认；本指南不授权执行这类操作。本轮仅编写文档，没有烧写或分区。

### 6.2 最小Host桥接

本人负责导出地址/ABI、提供寄存器读写测试；队长同步修改Host编解码与GraspPlan转换。
先无运动地读ABI、时间戳、快照、复位状态；再只读单舵机反馈；最后使能安全小幅目标。
`/dev/mem`是第一版候选访问方式，需Linux权限/内核策略允许；不放宽系统安全限制来隐藏访问失败。
若需中断，采用实际验证的UIO/驱动与设备树；Host轮询也可验收第一版，但文档明确没有中断应用链路。
不能通过PC的Windows环境打开 `/dev/mem` 或安装板端依赖模拟联调成功。

### 6.3 单舵机通过标准

真实PS→AXI提交→PL组包→舵机安全运动→真实回读→PS快照全部一致。
重复小幅位置、释放/卸力、掉线、急停、应用停止、PL复位实验，保存波形和原始日志。
确认drive_en、停止位、TX→RX、首字节时延和完整事务时长；正常/故障路径均在冻结时隙内。
检查温度/电压数据来源正确，避免错起点把负载当位置或把status当温度。

## 7. 8路整手与首次抓取（10-11，G5）

1. 队长确认左右手、8路ID对应、每路安全中位/方向/限位与线缆供电。
2. 逐步扩2/4/8路，先只读在线/位置/温度；确认ID唯一与全轮询年龄。
3. 先做受控预张，再做队长确认的空载安全闭合/释放，验证目标顺序和不会越界。
4. 选择低位、受支撑、不会造成伤害或损坏的验收对象；加载有依据的首版计划。
5. 由手动CLI触发抓取，记录PS计划序号、AXI ACK、FSM、真实位置/负载、接触锁存、保持和释放。
6. 观察是否稳定抓住、是否持续加力、是否顺利释放；失败样本照常保留，分析后再改一个参数。
7. 有效负载门限与过载报警分开，逐通道停指不造成其他指无期限继续闭合。

建议首版以一个已标定对象重复验证，再扩多个对象；15类×20次是后续完整项目指标，不能在十天首版里假设已经覆盖。
首次真实抓取在10-11未完成，应立即报告依赖/技术原因；后续只读自测不是满足原验收的替代结果。

## 8. 验收与冻结（10-12至10-14，G6-G8）

按 [验证清单](verification_acceptance.md) 执行所有P0项目，包括异常路径、数据有效性和独立复现。
修复后只重跑受影响项及必要集成回归，保留失败版本和修复说明，不能只交最后一张成功截图。
冻结后的包应能从干净源码重建；参考上游固定版本、协议profile、标定表、Host与bit必须配套。
使用 `.gitignore` 前审查哪些是源码、IP配置、项目配置和生成中间产物，不误忽略XDC/Tcl/BD/XCI。
大产物按团队约定归档，报告给出获取路径与校验hash；不把系统镜像或大量缓存无差别提交。
提交前检查每个改动和密钥，显式stage；经用户授权后commit、只推当前同名工作分支。
由另一名队员Review/Approve、用户/授权人员人工合并；Codex不创建本轮PR、不合并、不删除远程分支。

## 9. 每日施工记录模板

```text
日期/北京时间：
工作分支与commit：
今日工作包和前置依赖：
实际完成（实现/仿真/上板分开）：
工具/bit/ABI/协议profile/标定版本：
运行命令与结果、证据路径：
失败样本、问题原因、改动影响：
保护与机械安全观察：
未确认依赖及负责人/期限：
明日出口与风险：
```

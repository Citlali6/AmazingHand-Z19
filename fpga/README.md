# FPGA 当前开发入口

本目录含 RTL 源码和模块级仿真，整板 PS/AXI 集成与实物验证仍在开发中。
2026-10-06 使用 Vivado 2020.1 验证；规划文档中“无 RTL”的描述对应 10-05 历史基线。

## 运行仿真

在仓库根目录的 PowerShell 中执行（安装路径按本机调整）：

```powershell
& F:/Xilinx/Vivado/2020.1/bin/vivado.bat -mode batch -notrace -nolog -nojournal -source fpga/scripts/build_project.tcl -tclargs sim
if ($LASTEXITCODE -ne 0) { throw 'FPGA simulation failed' }
```

默认输出到 `fpga/build/out/<时间戳>/`，不会覆盖已有目录。可在 `sim` 后指定一个尚不存在的输出目录。
脚本逐个检查仿真日志和 `ALL PASS` 完成标记；断言失败或未完成时返回非零。
每个测试的日志保存为输出目录中的 `<测试名>.log`，生成工程与缓存不入库。

| 测试 | 覆盖内容 |
|---|---|
| `tb_scs_protocol` | READ #8 的完整 8B 帧、发送背压、8B 反馈载荷、坏校验和、解析恢复、ACK、短载荷、超长帧 |
| `tb_servo_bus` | 32B 同步位置帧、READ、8路轮询跨周期、回读字段、掉线恢复、速度与力矩事件广播 |
| `tb_grasp_fsm` | 预张、触力保持、释放、闭合超时、HOLD掉线保护、手动复位、运动中急停；事件计数 |

总线测试在字节级运行并缩短周期，状态机测试缩短节拍。它们不验证 UART 位时序、1kHz 实际总线预算、电气、真实负载或机械抓取。
测试沿用仓库现有小端/12bit/反馈0x3A profile，与实机是否一致仍须用现场原始回包核验。

## 下一步联调

1. 现场先通过临时 STM32 或已核验的总线适配器取得只读 PING/READ 原始报文，确认8路节点、端序、寄存器和响应延时。
   `origin/feature/sim-model-rtl@903b462` 中 STM32 固件使用长度前缀/PC端115200；该分支原始 `probe_servos.py` 使用无前缀SCS报文，不能直接配套运行。
2. FPGA继续补 UART 位级测试（当前RX位间隔与自回声屏蔽有缺口），修复 AXI 独立握手/背压及寄存器语义，再完成整板顶层、PS BD、时钟复位与官方 DDR 配置。
3. 确认实际供电、电平转换和约束后，先单舵机 PL 只读，再加载标定参数进行小幅动作，最后整手抓取。

目前脚本只开放 `sim`。原脚本没有实际建立其注释所称的 PS BD，直接综合原顶层无法获得可用的板端系统；本次明确返回未完成提示。
后续整板构建需补齐源配置后重新开放，不能将模块测试通过当作 bit/XSA 已完成。

仍待修复：单槽事件可能覆盖未发送事务、反馈有效性/年龄与舵机错误码未完整参与保护、全状态掉线/过温保护、PS心跳、角度编码、原子参数提交、16bit速度、反馈快照。
相关接口审查见 `docs/design/interface.md` 和 `docs/fpga/interface_proposal.md`。

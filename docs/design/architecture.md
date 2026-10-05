# 系统架构与代码组织

> 版本：v0.1（2026-09-30）· 后续设计变更记入 `docs/log/`

## 1. 顶层目录（对齐 3.3 赛道推荐提交结构，决赛时可直接提交）

```
amazing-hand-ai/                 # 仓库根（目录/文件名纯英文）
├── fpga/                        # PL 侧全部（RTL/仿真/约束/构建）
├── host/                        # PS 侧 Linux 应用（语音/视觉/策略/控制）
├── tools/                       # PC 侧离线工具（不依赖板子，缩短反馈环）
├── sim/                         # MuJoCo 数字孪生（抓取参数验证+对比渲染）
├── data/                        # 标定结果与实测指标（与代码分离）
├── skill/                       # 技能包（决赛交付）
├── report/                      # 设计报告（决赛交付）
└── docs/                        # framework / design / log
```

## 2. 完整文件树与职责

```
fpga/
├── rtl/
│   ├── top.sv                   # 顶层：Zynq PS + AXI 从接口 + 各模块互连
│   ├── axi_lite_regs.sv         # 寄存器映射（见 docs/design/interface.md）
│   ├── half_duplex_uart.sv      # 半双工 UART 收发 + 方向切换（1Mbps）
│   ├── scs_protocol.sv          # SCS 协议组包/解包/校验和
│   ├── servo_bus_ctrl.sv        # 8 路总线控制器（1kHz 轮询调度）
│   ├── grasp_fsm.sv             # 力控状态机：预张→闭合→停止→保持→释放→保护
│   └── cdc_utils.sv             # 时钟域同步等小工具
├── sim/
│   ├── scs_slave_model.sv       # 虚拟舵机从机模型（仿真中的"假舵机"）
│   ├── tb_servo_bus.sv          # 总线控制器 TB
│   └── tb_grasp_fsm.sv          # 状态机 TB（注入堵转/超温/掉线场景）
├── constr/
│   └── z19.xdc                  # 引脚与时钟约束
├── scripts/
│   ├── build_project.tcl        # 一键建工程+综合实现（复现性关键）
│   └── build_dpu.tcl            # DPU overlay 构建（Vitis AI 链路）
└── build/                       # 产物 .bit/.xsa/.hwh + 综合报告（大文件 gitignore）

host/
├── app/
│   ├── main.py                  # 主状态机：待命→识别→引导→抓取→释放
│   ├── voice/
│   │   └── kws.py               # Vosk 离线命令词识别 → 结构化指令
│   ├── vision/
│   │   ├── camera.py            # 相机采集抽象（OpenCV）
│   │   ├── detector.py          # 检测调度：按配置选择后端
│   │   ├── backends/
│   │   │   ├── ncnn_det.py      # NCNN INT8 YOLO（保底，A53 CPU）
│   │   │   └── dpu_det.py       # DPU YOLO（加速，可缺省）
│   │   ├── measure.py           # 俯视单目几何：bbox→物理尺寸
│   │   └── hand_guide.py        # ArUco 手位姿跟踪 + 就位判定 + 引导输出
│   ├── strategy/
│   │   ├── grasp_selector.py    # (类别,尺寸,朝向) → 抓取参数
│   │   └── grasp_table.json     # 参数表：标定+MuJoCo 验证的结果，带来源标注
│   ├── control/
│   │   ├── scs_protocol.py      # SCS 协议 golden model（组包/解包/校验和/寄存器表）
│   │   ├── scs_sim.py           # 虚拟舵机总线（帧进帧出 + 确定性 step，故障注入）
│   │   ├── servo_base.py        # 抽象基类：上层只认接口
│   │   ├── backend_sim.py       # 模拟后端（挂 scs_sim，PC 全链路空转）
│   │   ├── backend_serial.py    # 软件环后端（USB-TTL，对比基准）
│   │   └── backend_fpga.py      # RTL 环后端（AXI 寄存器读写）
│   └── ui/
│       └── guide_display.py     # 引导显示（方向/距离/就位状态）
├── config/
│   └── settings.yaml            # 串口/相机/阈值/类别表/后端选择
├── tests/
│   └── smoke_test_control.py    # 控制链路冒烟测试（无第三方依赖，pytest 兼容）
└── scripts/
    ├── setup_z19.sh             # 板端环境一键安装（复现性关键）
    └── run_app.sh               # 应用启动

tools/                           # PC 上跑，板子没好也不阻塞
├── calibrate_servo.py           # 8 舵机校准（基于官方脚本改）→ 输出 calibration/
├── calibrate_camera.py          # 相机 mm/pixel 标定 → 输出 calibration/
├── test_detect_pc.py            # PC 端 YOLO 验证（COCO 预训练直测）
└── verify_backends.py           # 软件环/RTL 环同一用例对比（抖动测量）

sim/
├── ah_model/                    # 官方 AHSimulation 的 MuJoCo XML+STL（引入不改）
├── verify_grasp.py              # 批量验证 grasp_table 每条参数（仿真包络判定）
└── render_compare.py            # 仿真/实物同角度并排渲染（演示素材）

data/
├── calibration/                 # 舵机校准表、相机内参、mm/pixel
└── metrics/                     # 成功率/延迟/抖动/资源 实测数据（metrics.csv）

docs/
├── project_framework.md         # 项目框架（做什么/不做什么）
├── design/                      # 设计文档（本目录，设计完成后入档）
└── log/                         # 开发日志（按日期，变更必记）
```

## 3. 模块化设计规则（写代码前必读）

1. **后端抽象模式**：`control` 与 `vision` 的硬件相关实现全部藏在 `backends/` 里，上层通过抽象基类调用。换硬件路线（NCNN↔DPU、串口↔RTL）只改 `settings.yaml` 一行。这也是"软件环 vs RTL 环"对比实验能自动化的原因：`verify_backends.py` 用同一用例跑两个后端。
2. **接口契约先行**：PS↔PL 的寄存器映射是 host 与 fpga 并行开发的唯一契约，定义在 `docs/design/interface.md`，改动必须走 log。
3. **PC 优先**：凡是不依赖板子能验证的（检测、几何、策略查表、TB 仿真），一律先在 PC 完成，上板只做最终确认。
4. **数据与代码分离**：所有可变参数进 `config/settings.yaml`，所有测量结果进 `data/`，代码里不出现魔数。
5. **一键可复现**：`build_project.tcl`（PL）与 `setup_z19.sh`（PS）保证从零复现，这是评分 15 分的硬指标。
6. **变更留痕**：任何文件增删/接口改动/参数定稿，当日写入 `docs/log/YYYY-MM-DD.md`，格式：时间 · 类型（结构/代码/文档/决策）· 内容 · 影响。

## 4. 数据流（一条指令的旅程）

```
麦克风 → kws.py → {action,target}
                         ↓
camera → detector → measure ──► grasp_selector ──► 8×(目标角度,力矩阈值)
              ↓                                        ↓
         hand_guide（ArUco 就位引导，循环至就位）   servo_base
                                                  ├── backend_serial（软件环）
                                                  └── backend_fpga → AXI → grasp_fsm → servo_bus_ctrl → 8×SCS0009
```

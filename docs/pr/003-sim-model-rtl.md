# PR — 数字孪生 + 模型链 + RTL 全套（第 3/4/5 步批量交付）

> **复制本文件内容到 GitHub PR 描述框即可创建 PR**（base：`main`）
> 分支：`feature/sim-model-rtl` · 前置：PR #3（协议层）/ #4（host 骨架与工作流）已合并
> 本 PR 额外包含第 2 步 host 骨架提交（若其独立 PR 未先行合并，则随本 PR 一并进入 main）
> 状态：Draft（可评审）

---

## 概述

无硬件阶段三轮开发的全部产出，按"PC 能做的全部做完、硬件到位只剩烧录/标定/实测"的目标推进：

- **第 3 步 数字孪生**：MuJoCo 验证/渲染链 + 碰撞简化体（v2）+ 演示与调参工具四件套；
- **第 4 步 模型链**：视觉（YOLOv8n→NCNN 实测推理正确 + 单目测尺寸 + ArUco 引导）与语音（Vosk 语法限词命令词）；
- **第 5 步 RTL 全套**：协议引擎/半双工 UART/1kHz 时隙调度/力控状态机/AXI 寄存器/top/xdc/一键构建 + 2 个 TB + 黄金向量。

**Python 冒烟 53/53 + sim 5/5 + 视觉 5/5 + 语音 6/6 全绿；CLI 全链路空转通过。**

## 提交清单（本轮 12 个）

| Commit | 内容 |
|---|---|
| `85d6903` | feat(sim): MuJoCo 数字孪生——抓取参数批量验证 + 对比渲染（第 3 步） |
| `7e86880` | feat(host): 视觉链 + 语音链（第 4 步，11/11 冒烟） |
| `cb9351d` | feat(fpga): RTL 全套 + TB×2 + golden vectors（第 5 步） |
| `c0d1ea8` | feat(sim): 数字孪生演示双形态（原生 viewer + 自绘干净窗口） |
| `998624f`/`d27aa0b` | fix(sim): 控制台面板裁剪/窗口自适应/鼠标坐标换算/X 退出/排版重排 |
| `da901a3` | feat(sim): 碰撞简化体注入 v1（MjSpec 胶囊+掌盒） |
| `69ef0c4`/`4069c4e`/`af185d2` | fix(sim): 初始嵌接触卡死/张开语义对齐模型零位/初始姿态沉降 |
| `9d9a110` | feat(sim): 碰撞体 v2——按壳体包围盒自动生成贴合胶囊（8/8 执行器精确响应） |
| `3193722` | feat(sim): 穿透监测警告 + 复位按钮（点击/R 键） |

继承提交（第 2 步）：`2a6579a`（host 骨架）、`53369e1`/`b649568`（PR 文档）、`60eb13b`/`c1fb07e`（main 同步）。

## 新增文件

```
sim/
├── ah_model/README.md          # 模型引用策略（上游引入不改）
├── verify_grasp.py             # grasp_table 批量验证 → JSON 报告
├── render_compare.py           # 三机位离屏渲染（仿真/实物对比素材）
├── collision_model.py          # 碰撞简化体 v2（壳体包围盒胶囊，MjSpec 注入）
├── live_viewer.py              # 原生 viewer 实时演示（工程师形态）
└── showcase.py                 # 自绘干净演示窗口（展示形态）
host/app/vision/                # 检测调度/NCNN后端/DPU占位/单目测尺寸/ArUco引导/相机抽象
host/app/voice/kws.py           # Vosk 语法限词命令词 + 板端麦克风适配
host/tests/smoke_test_sim.py / smoke_test_vision.py / smoke_test_voice.py
tools/export_yolo_ncnn.py / test_detect_pc.py / download_vosk_model.py / dump_golden_vectors.py
fpga/rtl/                       # cdc_utils / scs_protocol(tx+rx) / half_duplex_uart /
                                # servo_bus_ctrl / grasp_fsm / axi_lite_regs / top
fpga/sim/                       # scs_slave_model / tb_servo_bus / tb_grasp_fsm / golden_vectors.txt
fpga/constr/z19.xdc             # 引脚约束（Z19 实测引脚）
fpga/scripts/build_project.tcl  # 一键建工程+综合+bit+xsa+xsim
docs/refer/Z19_key_specs.md     # 手册重点摘录
```

## 第 3 步：MuJoCo 数字孪生

- 模型引用策略：上游 `AHSimulation/AH_Right/mjcf/scene.xml` **引用不复制**（单一事实源）；
- `verify_grasp.py`：8 关节角 → position 执行器 → 稳定收敛判定 + 可达性残差 + 指尖间距矩阵 + 自碰/限位统计 → JSON 报告。**全表 4/4 PASS**；
- `render_compare.py`：三机位渲染（帧缓冲运行时放大，不改上游 XML）；
- 执行器映射核实：`finger{i}_motor{j}` ×8 与舵机 ID 1-8 一一对应。

## 第 4 步：模型链

**视觉**（COCO 预训练零训练路线）：
- 导出链实测：YOLOv8n@416 → ONNX → pnnx → NCNN（IO=in0/out0，3549 anchors）；
- 板端后端 `ncnn_det.py`：ncnn 底层 API + letterbox + YOLOv8 头解码 + NMS，**bus.jpg 检测与 ultralytics 基线逐目标一致**（person 0.88/bus 0.85/0.76/0.71）；
- 单目测尺寸（mm/px 标定系数 + 类别高度先验）、ArUco 引导（合成帧全管线测试通过）；
- 15 类物品 ↔ COCO id 映射，非物品类检测自动过滤。

**语音**：
- Vosk `vosk-model-small-cn-0.22` + **SetGrammar 语法限词**（识别空间=命令词表，34 状态/66 arcs）；
- `parse_zh_command`：动作词优先 + 15 类物品映射；`transcribe_wav` 文件驱动（PC 无麦克风可测）；`MicVoiceSource` 板端适配（pyaudio 线程）。

**修复记录**（测试驱动，详见各 commit）：
1. ncnn.Mat 喂 transpose 非连续数组 → 错位读内存 → 检测全空（`ascontiguousarray`）；
2. ArUco `ids.tolist()` 嵌套 `[[0]]`，`0 in [[0]]`=False → 误判未检出（flatten）；
3. 合成帧灰底缺 quiet zone → 白底；
4. scs_sim 单字节写 16 位寄存器 IndexError → 支持部分写。

## 第 5 步：RTL 全套（作品核心，评分 25 分项）

| 模块 | 职责 | 对照基准 |
|---|---|---|
| `scs_protocol.sv` | 帧组包（SYNC_WRITE 32B / READ 7B / 广播 WRITE）/ 解析（容错+校验和） | `scs_protocol.py` 逐字节 |
| `half_duplex_uart.sv` | 1Mbps（BIT_CYC=100），RX 4× 过采样位中心采样，inout 三态 | 板端 ILA |
| `servo_bus_ctrl.sv` | 1kHz 时隙：t0 SYNC_WRITE→t1/t2 READ 轮转（每舵机 250Hz）+ 事件事务 + 超时掉线 | `scs_sim.transact` |
| `grasp_fsm.sv` | 六态力控：PREGRASP 0.3s→CLOSING（力阈值 level<<6）→HOLD 锁存→RELEASING→PROTECT | `backend_sim` 软件状态机 |
| `axi_lite_regs.sv` | AXI4-Lite + 寄存器文件 + IRQ（状态跳变/错误位图） | interface.md v0.2 |
| `top.sv` | MMCM 200→100MHz + 互连 | — |

- **预算修正（v0.2.1）**：速度改事件事务后时隙 820µs ✓（6B 连写 640µs 会超预算）；
- **黄金向量**：`tools/dump_golden_vectors.py` 生成 64+28 字节参照序列，TB 逐字节比对；
- **验证边界声明**：本机无 Vivado/仿真器（choco 无管理员权限），**RTL 未经编译/仿真**；验证材料已备齐——`build_project.tcl -tclargs sim` 一键 xsim。

## 数字孪生工具链（碰撞模型 v2 + 调参控制台）

**碰撞模型 v2**（`collision_model.py`，MjSpec 运行时注入，上游 XML 零改动）：
- 上游 AHSimulation 全部 geom `contype=0`（纯动画模型，无碰撞几何）→ 穿模根源；
- v2 扫描壳体 mesh（`proximal`/`distal`）顶点包围盒 → 同位姿生成贴合胶囊（近节 r6.5×58mm、远节 r4.3×45mm ×4 指 = 8 胶囊）；
- **验证**：张开位 0 初始嵌接触；抓取姿态数值稳定（max|qacc|≈1e-8）；**8/8 执行器精确响应 60°**（v1 的卡死/推飞全部消除）；中/无名指并拢 43° 被指间接触阻挡=正确行为。

**调参控制台**（`control_panel.py`，单窗口）：
- 8 滑块（限位=模型硬约束）+ 限速逼近（40/180°/s）+ 3D 视图（鼠标旋转/缩放，窗口自适应+坐标换算）；
- 机构应力灯（equality 残差）+ 接触/穿透实时显示（contact.dist）；
- **穿模警告**（穿透>2mm → 红色横幅闪烁）+ **全部复位按钮**（点击/R，180°/s 回归张开工位）；
- 参数出口：C=剪贴板 JSON、S=`data/calibration/manual_poses.json`、1-5 预设。

**演示双形态**：`showcase.py`（干净自绘窗口，中文标注，给人看）+ `live_viewer.py`（原生 viewer，调试用）。

## 测试与验证统计

| 套件 | 用例 | 结果 |
|---|---|---|
| `smoke_test_control.py` | 协议字节锚点/解析鲁棒/总线闭环/故障注入 | 27/27 |
| `smoke_test_backend.py` | 三后端契约/力控周期/超时语义/急停/掉线 | 10/10 |
| `smoke_test_sim.py` | 模型映射/收敛/闭合减距/全表报告/中位偏移 | 5/5 |
| `smoke_test_vision.py` | NCNN 检测/15类过滤/尺寸估计/ArUco 管线 | 5/5 |
| `smoke_test_voice.py` | 命令解析/语法词表/静音 wav 管线 | 6/6 |
| CLI 空转 | `--mock-voice "抓起香蕉,放下"` 全状态序列 | PASS |
| RTL | 未仿真（见已知限制） | 待 xsim |

## 已知限制（诚实声明）

1. **RTL 未经编译/仿真验证**——代码按保守可综合子集编写，验证材料齐备（golden vectors + 2 TB + 一键脚本），队友 Vivado 实证为本 PR 合并后的第一优先级；
2. **碰撞胶囊为凸近似**：指节壳凹形边缘存在小盲区，极端角度仍可能有 ≤3mm 视觉交叉（capsule 阻挡阈值≈视觉交叉阈值）；
3. **角度语义**：模型零位 ≠ 官方舵机校准中位——映射真值待实机标定（interface.md 待定项 1）；
4. 掌板碰撞体排除（其 mesh AABB 为多块板大包围盒，需要分块建模）；
5. DPU 后端为接口占位（板端 Vitis AI 链路调通后实现）。

## 硬件到位后待办（按优先级）

1. 队友：Vivado xsim 跑 `tb_servo_bus`/`tb_grasp_fsm`，对照 golden vectors 逐字节验证 RTL；
2. Z19 刷 ALINX Ubuntu 镜像 → `backend_serial` 真舵机冒烟；
3. 舵机校准（解决待定项 1/2）→ `manual_poses.json` 与实机对齐；
4. DPU 链路（`build_dpu.tcl` + vai_q 量化）；
5. ILA 实测：软件环 vs RTL 环 P99 抖动（F5 核心数据）。

## 评审要点

1. `grasp_fsm` 迁移条件与 golden model 的一致性（RTL 编码前最后修改窗口）；
2. RTL SYNC_WRITE 必须支持 0x2A 起 **6B 连写视图**（位置+Goal_Time+速度）；
3. interface.md v0.2.1 时隙预算（SYNC_WRITE 32B/320µs）是否认可；
4. 碰撞胶囊半径系数（0.85）是否符合你对"允许的视觉交叉"的容忍度；
5. 控制台交互流程是否满足"离线标定 → 仿真验证 → 实机复测"工作流。

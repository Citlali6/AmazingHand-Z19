# #33 首轮交付：READY FOR ONSITE CAMERA TEST

基线 `main@7b1163ed8ad734f5bf0ba31aaf4ac18291935273`，本轮同步 main 后建立
`feature/grid-calibration-issue33`，独立 `issue-33` 工作树。
唯一 Git 写目标为 `Citlali6/VisionGrasp-Z19`。未合并 main。

本轮没有打开相机或串口，没有电机、固件或 FPGA 操作。
实拍独立五点毫米误差、真实红蓝/空板/反光表现、三位置相机目标更新均 **NOT TESTED**。

## 已读现场成果和保护

- 相机主工作树：`feature/lab-camera-issue26`，有相机源码/测试/报告未提交成果。
- `issue-30`：`feature/roarm-r0b-r1-fixed-bench-issue31`，同样 HEAD `7b1163e`；
  robot serial/probe、bench/joint_bench、测试和 #31/#32 报告/JSONL 在本地未提交。
- 读取 #32 `ISSUE32_R0A_RETEST.md` 与 `issue32-usb-retest.jsonl`：一次 T105，返回 T1051，
  summary exit 0；仅证明此前只读查询通过。本轮没有重新查询硬件。
- 读取 #31 `ISSUE31_BASE_JOG30_RESULT.md`、日志和开发记录：底座变化约 27.8613°，
  目标偏差约 2.1387°；原始 summary exit 1 / R1 false。可见转动已有负责人确认，
  到位、肩肘、夹爪闭合、真实抓放未通过；本轮没有补偿/重发。
- 读取现有 robot diff，保留 `CARTESIAN_SPEED_UNVERIFIED`。#31/#32 没有被携带或提交到本 PR；
  机械臂分支仍是独立待审核合入依赖。
- 对原两工作树全部现有未提交/未跟踪文件建立本地 SHA256 manifest，前后相同：
  机械臂 38 文件、相机 7 文件。原 diff/JSONL/源码均保留，没有 stash/reset/clean/重写。
  清单及测试 stdout/stderr/exitcode 放在忽略目录 `output/pc/issue33/`，不上传设备资料。

## 已实现范围

复用 TableCalibrator/HSV/CameraProvider/FakeRobot，没有改 contracts、robot 或相机驱动。

1. `vision/measurement.py`：独立 ≥5 点检查、去重/拟合点隔离、中心/四边覆盖、逐点误差与 mean/RMS/max。
   保存真实物理定义、UTC、新 UUID；重载重新计算报告，不接受伪造通过字段。
2. `calibrate_table.py`：测量 JSON 与编号选点、ROI、重复点击拒绝；可现场显式相机取帧后关闭设备再点击。
   可显式保存原始 PNG，现有文件拒绝覆盖。检查失败留存报告并 exit 2。
3. 真实来源仅四点拟合不产生有效目标；独立检查失败也拒绝。GUI 复用标定需明确确认工位未变，
   再绑定新会话，来源/实际尺寸仍核对。改变工位必须退出重标；不能自动识别同尺寸的相机位移。
4. 原有 `demo.py --mode mock --camera live` 增加每帧目标日志（含空板）、ROI/网格点/目标 mm 叠加。
   FakeRobot 七阶段和原共享契约保持；UI 不提供 real 模式。
5. `vision/robot_base.py`：独立版本化平面 yaw/平移、表面 Z/物体高度/接触高度/工具偏移、误差预算、ROI/包络。
   非有限数、单位/帧/标定不一致、旧目标、未校准或超域均 BLOCKED；候选仅 PLAN PREVIEW，
   `robot_xyz_mm=None`、`motion_allowed=false`。没有实现 IK/整臂碰撞或真实动作。

## 打印包与现场输入

读取负责人提供的 `VisionGrasp_Z19_Grid_Print_Package` 中说明 TXT、原始 SVG，并查看 PNG。
外板设计 500×400 mm，标定区域 400×300 mm，四边 50 mm，网格 20×20 mm。
P1 原点；P2=(400,0)，P3=(400,300)，P4=(0,300)，+X 右、+Y 下。
这是设计坐标，尚无实物量尺值和真实板面照片。没有把 PNG 当精密实拍图或像素标定输入。

已预填 [设计模板](ISSUE33_BOARD_DESIGN_TEMPLATE.json)，`geometry_verified=false` 默认拒绝实测标定。
下一件现场输入：**横纵各连续五格标称 100 mm 的实际量尺值，并核对内部 400×300 mm**。
如果有打印缩放，修改所有实际点距。相机操作、独立五点和三位置记录见
[相机操作卡](ISSUE33_CAMERA_CARD.md)。缺现场测量不生成伪精度表。

基座转换还缺 XY/yaw、板面基座 Z、物块尺寸/抓取宽度、工具偏移与接近姿态、
独立可达点误差和真实净空；真实动作仍按 #31 → R1 → R2 逐次现场批准。
桌面 H 不恢复 Z，物块顶部视差需单独检查；没有自动畸变矫正。

## 本轮实际验证

沿用既有 Windows Conda `visiongrasp` / Python 3.10.22，未安装或修改环境。

| 执行范围 | 实际结果 |
| --- | --- |
| 原 `issue-30`，`python -m pytest -c pc/pyproject.toml pc/tests -q` | **286 passed in 7.53s；exit 0**，本轮独立重跑 |
| 本 #33 分支，同一全量命令 | **190 passed in 4.62s；exit 0** |
| 忽略目录隔离副本：#31 当前 pc + 本次 pc 修改 + 原台架离线 JSONL fixture；同一全量命令 | **329 passed in 7.61s；exit 0**，仅兼容性测试，不代表合入 |
| synthetic + Fake 原演示 headless / auto-run | 七阶段完成、IDLE、XYZ null；exit 0 |
| measured synthetic 界面渲染 | 已查看 PNG，网格/ROI/像素/桌面 mm/PLAN PREVIEW 正常；不是实拍 |
| `git diff --check` | exit 0 |

本次新增 **43 项**检查，包括四点残差不能替代独立误差、伪设计不能冒充实测、检查点重用/重复/非有限数、
独立误差/覆盖失败、篡改持久化报告、三位置不同候选与 Fake 七阶段、空板、失效标定/时戳/预算/域、
模拟选点和 PNG 原图保存、注入 live 来源元数据的 GUI 绑定日志。所有 pytest 禁止真实相机/串口 I/O。
带 LIVE 标签的注入测试仍属 synthetic fixture，不计入真实相机验收。

兼容副本首次收集失败是未复制台架所需的已有 R0-A 离线 JSONL；补齐该 fixture 后通过，
没有因此修改机械臂代码。控制台曾遇 GBK 输出编码错误，完整子进程字节仍保存，随后使用 UTF-8。

官方 SDK/固定固件接口与两条限速路线、当前阻塞见 [运动审计](ISSUE33_MOTION_AUDIT.md)。
本 PR 仅交付离线能力和现场操作卡，后续实物成功率/精度不能用本表替代。

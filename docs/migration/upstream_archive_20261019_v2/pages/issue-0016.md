# #16: [Citlali6][P0][Codex][10-18] Z19 Linux IMX214 实时 AI 识别：苹果/香蕉/瓶子 + 检测框

原作者：`Citlali6`；状态：`open`；创建时间：`2026-10-18T03:51:11Z`。

原链接：https://github.com/Tom-mr33/AmazingHand-based-on-FPGA/issues/16

**只读归档：保留原作者和时间，不代表在新仓库重新发布、审批或合并。**

> **适用范围**：仅属于 `Citlali6` 个人 Codex 工作流，不给其他协作者安排任务，不改变团队规范、他人分支/工作区/进度。Codex 可在本任务个人分支开发、必要检查、commit/push并建Draft PR；不得改/推main、自动合并、删除远端分支、覆盖已验证相机文件或进行未获批准的风险硬件操作。

## 目标与现状
真实 IMX214 Linux 驱动为 `/dev/ah_camera0`，现有采集服务通过 `/frame.jpg`、`/status.json`、`/stream.mjpg` 发布真实图像；但 `host/app/vision/camera.py` 默认读取 `cv2.VideoCapture(0)` / `/dev/video0`，两者尚未接通。现有 `ncnn_det.py` 有 YOLOv8n 后处理，但尚无证据证明模型已在 Z19 A53 CPU 上运行或处理真实相机帧。**不可用 PC GPU 推理冒充板端推理。**

实现一份可运行的 Z19 Linux 实时摄像头识别 Demo：真实相机识别苹果、香蕉、瓶子并在电脑显示由板端返回的检测框。Linux 1080p采集和PC MJPEG预览已验收；Linux 5.4.0-xilinx-v2020.2、ARM64、Python 3.7.6、OpenCV 3.4.3；板端 NCNN/YOLO 尚未验收。相机 PL 与 HIL PL 当前互斥；共用 Z19 前核实实时状态，不盲用历史 IP `192.28.14.152/.153`。

## 代码范围
- `host/camera_linux/{preview_server.py,camera_preview.c,start_preview.py}`
- `host/app/vision/{camera.py,detector.py,backends/ncnn_det.py}`
- `tools/export_yolo_ncnn.py`
- `host/config/settings.yaml`、`docs/fpga/camera_quickstart.md`、`host/tests/`

## 必须交付
1. 复用现有 Linux 相机服务，不重写 MIPI、DMA、驱动或原预览接口；实现可靠 `CameraSource` 适配器，从当前设备 `/frame.jpg` + `/status.json` 取得 BGR 帧、序号、发布时间/帧龄和错误状态。重复、过期、无帧必须明确失败，不能拿旧帧产生新检测。
2. 优先复用 YOLOv8n + NCNN 导出、后处理及类别映射，先支持 `apple/banana/bottle`，结构可扩展 COCO 类别。先确认 AArch64 NCNN/Python3.7 兼容性；不兼容则优先隔离 ARM64 NCNN C++ 推理进程并用 JSON 桥接，不强制替换系统 Python 或已验收 OpenCV。修复实测会导致推理失败的张量、颜色、坐标问题。
3. 提供可复现启动、停止、清理方式及模型来源/许可证/产物哈希/部署说明。板端输出 `frame_seq, age_ms, category, confidence, bbox_xyxy, inference_ms, backend`；PC 只绘制 Z19 返回的框和状态，不二次推理。
4. 用最新帧队列/丢弃旧帧避免推理阻塞预览。若与组合 PL 任务共用 Z19，先协调板端时间，不得擅自重载 PL。帧过期/丢失、低置信度或模型故障必须标记“自主抓取禁止”；本任务不发动作命令。
5. 当天先完成可运行视觉链、部署脚本和PC同图校验，尽力至少完成一次真实 Z19 IMX214 + ARM 推理 + 画框；记录真实 FPS、单帧时延、CPU、内存。若板被占用/依赖阻断，提交软件和准确阻断清单，不得伪称实测。

## 验收与约束
- 板端日志/进程可证明推理在 Z19 运行；禁止 PC Ultralytics 框冒充板端结果。
- 不覆盖已验收相机 PL、Linux SD、驱动；不得随意 apt upgrade、覆盖系统 Python 或 pip 卸载系统包。系统级变更须先征得 Citlali6 确认并保留回退。
- 本 Issue 不做 DPU、VLM/LLM、模型训练、真实舵机。YOLOv8n CPU 若确有阻断/性能不足，可报告 NanoDet-Plus 备选；不要无依据同时维护多个框架。
- 只做必要端到端演示及少量相关检查，优先让功能真实跑通；保留急停/基本安全检查。
- 开工前读 `AGENTS.md`、`docs/GIT_WORKFLOW.md` 和个人规范；从更新后的 main、干净工作区创建个人独立分支 `feature/citlali6-z19-live-vision-20261018`（仅在分支不存在时创建，不复用他人分支）。提交、推送并建 Draft PR。回报实际 base/完整 HEAD SHA、命令、现场结果、未完成项及复现入口；不碰他人分支、不自动合并。

## 现场边界
如需用户接线、拨码、检查 FMC/电平转换、供电、安装/卸载系统依赖或上板测试，整理成清晰现场操作清单交给 Citlali6；不要假装物理操作已完成。

## 评论

### Citlali6 · 2026-10-18T05:52:37Z · 

### 【Citlali6 下一轮 / P0】降低 Z19 视觉推理对相机预览的影响，保留真实检测与防旧帧机制

> 本评论只用于 **Citlali6 本人**委托的 Codex 下一轮开发，不代表团队强制安排，也不干涉其他成员。沿用 Issue #16 与 Draft PR #19，不再另建重复 Issue。现有交付应当**保留**，不是推倒重来。

**已确认基线**：PR #19 HEAD `5892628c3accb812b56f8a3ad11b5a785d4a0add`；Z19 AArch64/Linux 5.4/系统 Python3.7 + OpenCV3.4 上运行 NCNN C++ YOLOv8n 416 FP32，真实 IMX214 检测 `car` 成功；约 `1.92 FPS`，总耗时中位 `514 ms`，检测结果帧龄中位约 `992 ms`，AI 同跑时原相机预览降至约 `6.46 FPS`，AI 服务与桥的 RSS 约 `203 MiB`。`apple/banana/bottle` 目前**只支持代码映射，未完成真实物体验收**。PC 页面只绘制板端结果，禁止自主抓取。

### 本轮要完成的真实功能
1. **找出性能瓶颈并改善“边预览边识别”体验**：用当前原生 NCNN 桥接、`host/camera_linux/{live_vision.py,preview_server.py,camera_preview.c}` 与 `host/app/vision/`，记录独立相机预览、相机+AI同时运行的真实结果；测量 JPEG 生成/读取、BGR 解码、缩放/预处理、NCNN 前向/后处理、Python/原生桥接、每核 CPU/内存消耗。辨明 CPU 竞争、内存带宽和相机输出频率，**不要未经实测就断言**。
2. 在**不重装 Linux/系统 Python/OpenCV、不改原驱动/DMA/原相机 bit、不引入大型软件环境**的前提下，选择最少改动的优化：例如分辨率 `320` 对比 `416` 的精度/时延、NCNN线程数1/2/3、限制推理调度与预览资源争夺、重复 JPEG 解码/复制消耗控制，必要时独立服务间限速；不能只靠调高 nice，因为上轮 nice=5 导致检测降为约1.33FPS、STALE增多。
3. **保留现有可靠性契约**：`frame_seq/session/jpeg_sha256`与检测框对应；相机断流、重复/超时/过期帧不产生有效检测；绝不放宽现有800ms输入源上限、1600ms结果上限来伪造FPS；绝不启用自动动作。不以 PC 的GPU推理冒充板端结果。
4. 继续使用当前真实车模完成一轮可复现的性能/同框识别测量；若现场有苹果/香蕉/瓶子且 Citlali6 同意，再验收它们。不要因找不到这三件物品而阻断性能优化，也不要拿手遮挡的 `apple=0.3618` 误检当成果。

### 验收
- 对照同一真实 Z19、同一相机原有配置，至少记录 **基线与最优可回退方案** 的真实预览FPS、检测FPS、总耗时中位/P95、结果帧龄中位/P95、CPU、RSS、模型输入尺度；有实际画框证据和启动/恢复步骤。
- 目标是尽量让预览恢复到**约 15 FPS 或更高**且检测尽量**不低于约 1 FPS**，两项只是优化目标而非没有实测就承诺；如达不到，诚实说明性能权衡，交付实测最优稳定配置，不虚报。
- 只执行必要的相关对照/端到端实测；避免数十轮冗余测试、无关重构、重复构建。不得损伤真实摄像头链路；若必须切换PL、安装系统依赖或中断另一任务，先获得本人现场批准。

### Git 交付
继续原独立分支 `feature/citlali6-z19-live-vision-20261018`，在干净工作树上核对已合并进 main 的 #12/#13/#14、原 PR #19 的改动及 `docs/log/2026-10-18.md`；不擅自 merge/rebase/reset/强推其他历史。获本人的当前执行授权后可以在**自己任务分支** commit/push 并更新 Draft PR #19。回传真实 HEAD、性能对照、日志/代码路径、尚未验证项；不修改 main、不自动合并。

### Citlali6 · 2026-10-18T06:54:17Z · 

### 【Citlali6 下一轮 / P1】板端视觉优化阶段结论：真实物体补验、整理 PR #19 给团队审查

> **个人范围**：仅限 Citlali6 的个人任务，沿用 [Issue #16](issue-0016.md) / [Draft PR #19](pr-0019.md)。此评论不向队长或其他协作者强制分配工作，正常 Review/Approve 和人工合并由团队决定。

#### 当前已真实通过的阶段成果

PR #19 最新已推送 HEAD `b996ac5de444e0c158546b2f7ca95bcee91f0f76`。真实 Z19 A53/IMX214/YOLOv8n-NCNN C++ + PC 浏览器同图结果已形成可复现的板端视觉演示；已通过的物体是**红色车模 car**，**不是**苹果、香蕉或瓶子。相机预览中位 `7.38 → 14.89 FPS`，完成推理约 `2.10 FPS`，总推理中位 `462 ms`、P95 `504 ms`；最终预览最低约 `10.93 FPS`，**不承诺持续≥15FPS**。

关键优化是 JPEG 直通、取消重复 BGR/BMP 中间管道、两线程 NCNN 和适当采集轮询；保留 `frame_seq` / `camera_session` / `jpeg_sha256` 的同帧绑定、超时/旧帧清框及 `autonomous_grasp_allowed=false`。这里 **2.10 FPS 为 processed 统计，浏览器观测到的有效不同结果约 1.86 FPS**，请保留口径区别。

本轮新的工作**不再强制做大规模性能优化**，优先把已实现且已实测的 PR 形成团队可审查的交付：

1. **代码审查准备**：在现有 PR #19 上整理最简复现步骤、原版与优化版指标、依赖/模型许可、实际板端推理证据、重要已知限制（前端帧龄与延迟、低置信度误检、自主抓取保持禁止）。审查 #12/#13/#14 已进入 main 后的集成差异和同名 `docs/log/2026-10-18.md` 的潜在冲突。**只做确有必要的小修复**，不重写相机或模型，不修改别人的分支，不替队友 Approve。
2. **真实物体补验（条件允许时）**：Citlali6 手边有苹果、香蕉、瓶子且明确授权使用当前相机板端时，利用已稳定的模型和预览服务做各类至少一次有效真实识别及误检/漏检观察，保持 800ms/1600ms 帧新鲜度契约、真实板端 A53 推理、同帧 JPEG 验证。没有对应实物则保留 `NOT VERIFIED`，绝不拿车模或旧“手误判 apple=0.3618”代替；**不要求等物体齐全才开始代码审查**。
3. **保持可回退、安全和版本兼容**：系统 Python3.7/OpenCV3.4、Linux/SD、相机固件、DMA/驱动不动；不要安装新版开发软件，不要求重新导出模型、重新构建 NCNN 大型依赖或更改全局 Ultralytics 设置。原先一次导出修改过配置/缓存的历史副作用已记录，不要编造恢复成功。
4. **协调共享板卡**：现在只有一块 Z19。#17 在离线修复组合工程期间不得抢占相机实测。若需重加载 PL、停驱动、重启 Linux，必须先获得本人的当前明确许可；此 P1 任务不自动授权任何硬件变更。

**验收**：已有优化结果保持可复现；能交给队长 Review 的清晰 PR 描述和证据齐备；有实物则加真实物体检测结果，没有就明确待测。只做必要补充检查和真实展示，不追加与本轮目的无关的测试。若有必要代码改动，可在自己原分支 commit/push、更新 Draft PR #19；不修改 main、不自动合并、不关闭 Issue。

**回执**：新 HEAD（若无新提交则如实保持）、PR URL、真实物体验收清单及实际结果、已整理审查入口、等待团队审查的事项，不得声称真实物体已验收或 PR 已获得团队批准。

### Citlali6 · 2026-10-18T08:30:34Z · 

【Citlali6 / 10-18 紧急 P0】苹果/瓶子漏检：先做板端原始类别对照，再修正确实存在的根因
仅限 Citlali6 个人 Codex 任务。沿用 Issue #16 / Draft PR #19，不开重复 Issue，不修改 main、不替他人 Review/Approve、不合并 PR。不启动 Issue #20。本次允许原个人分支必要代码修改、测试、commit/push、更新 Draft PR。真实相机服务只在已有现场授权范围内使用；涉及 PL 重配置、驱动卸载、系统依赖安装、重启板卡等必须另外征得用户同意。

1. 经核查的事实，不得混淆
- PR #19 当前 HEAD b726968359d4a676ed440a8516eb8817894e8f0f。真实板端当前仍运行之前的优化部署 b996ac5de444e0c158546b2f7ca95bcee91f0f76，最新前端清屏/状态小修尚未部署。已验证的车模 car、浏览器同帧证据和性能对比继续保留：预览中位 14.89 FPS、processed 推理约 2.10 FPS，结果帧龄与旧帧保护未放宽。
- 真实红苹果已完整入镜，恢复正常到期的采集服务后 17 个不同有效结果均 NO_TARGET；该结果不是 CAMERA_ERROR。真实白色保温瓶也补验未识别；香蕉无实物验收；只有红车模 car 通过。任何“苹果通过”“瓶子通过”必须基于真实 Z19 检测，不能使用 PC 检测冒充。
- 同一张 JPEG 做的 PC CPU/同权重参考 YOLOv8n（416 FP32/rect=False，诊断阈值0.01）在苹果处预测 orange，置信度 0.657752，没有 apple。这是类别混淆线索，不是板端 NCNN 原始输出的证明。
- 源码 host/camera_linux/live_vision.py 中 DISPLAY_CLASSES + selected = ... if DISPLAY_CLASSES.get(cid) in self.categories，当前只保留 apple/banana/bottle/car；如果原始模型预测 orange，展示层会返回 NO_TARGET。原生 ncnn_bridge/main.cpp 对 COCO80 每候选取最大类分数，按 conf/NMS 后返回，故要检查类别选择/预处理/展示过滤三个阶段。
2. 今日优先实施“诊断 → 定位 → 可验证的最小修复”
P0-A：同一真实 JPEG 的板端/PC 原始结果逐层对齐
1. 在现有 native NCNN 进程及 Python 桥加入默认关闭的只读诊断模式：记录原始 COCO id、类名、置信度、坐标、NMS 前后候选（仅必要 top-k/指定目标 ROI），与展示白名单过滤前/后结果分开；保持 NO_TARGET 的生产接口、安全限制及 autonomous_grasp_allowed=false 不变。敏感图像仅本地使用，不上传人脸/私密原图；日志限量并可关闭，不能拖垮相机或消耗大量存储。
2. 用同一 SHA256 的真实原始 JPEG 和相同权重/model SHA，在 Z19 ARM64 NCNN 与 PC CPU Ultralytics 做逐步对照：BGR/RGB、letterbox/缩放/padding、输入归一化、输出张量布局、COCO id 映射、class score/NMS/阈值。分别报告“NCNN 原始预测、白名单过滤后的有效类、PC 同图参考输出”。此前 PC 的 orange0.658 不能直接当作板端结果。
3. 用实际 apple 场景和 bottle 场景的最小样本做排查，同时保留已通过的 car 正样本、空背景及手部/橙子等负样本；明确 apple47、orange49、bottle39、car2 等 COCO id，避免越界/映射错误。严禁简单把 orange 改名为 apple、把低置信误检当成功、盲目放宽 0.35 阈值、改 800/1600ms TTL 或用 PC/GPU 推理伪装为 Z19 实测。
P0-B：按根因选择最小整改
- 若 NCNN 与同图 PC 原模型显著不一致：修复输入预处理/模型导出/张量维度/类别评分/NMS 或坐标映射的真实错误；以板端与 PC 同图类别/置信度/框的可解释一致性为验收，并用 car 回归，必要时重新导出模型必须先保留原权重与可回退产物，不能修改全局 Ultralytics 配置。
- 若两者一致地预测为 orange，或保温瓶属于模型域外物体：这属于模型能力/场景问题，不得虚报“软件 bug 修好”。在不安装大型新环境、不重训大模型的前提下，可评估最小、可回退的光照/尺度/目标区域、已有预训练轻量模型或人手确认辅助方案；任何“apple”成功必须在真实苹果与真实橙子/空场景负样本上验证，不能用 orange→apple 规则凑数。若候选模型需要未获授权的数据、下载、训练或显著修改部署架构，先说明成本和所需条件并征求用户批准，别无限循环尝试。
- 保留并校验现有 JPEG 直通优化、约 15 FPS 预览、单槽丢旧帧、frame_seq/session/JPEG SHA 严格绑定、错误清框及完全禁止自主抓取；别为修正单类识别让整体实时性倒退而不报告。
P0-C：真实验收与当晚回执
- 在得到现场物体/相机使用授权时对苹果、瓶子分别做实际 Z19 检测，记录同图 SHA、源与结果帧龄、原始类别 top-k、有效检测及漏/误检；对于可见且可用的物体，要有代表性正例及明确负例，不能用“出现一次 apple”就声称可靠。保持 car 已有回归效果和过期帧拒绝。
- 如果当日无法得到能可靠区分苹果/橙子并有效识别目标的模型，需如实提交已证实的模型能力阻断，保留严格 NO_TARGET/人工确认/自主抓取禁止，提出最少标注数据量/模型选择/验证条件作为后续工作，不造假“今天已经把苹果识别修好”。
- 给出两条独立结论：管线正确性（NCNN↔PC 同图对照、JPEG/TTL/安全）和 目标识别成功率（真实正负样本）；附复现命令、原始有限日志/匿名截图、实际装载 runtime HEAD、PR 源 HEAD、模型和 ELF SHA，以及前后 FPS/时延对照。
3. Git 和交付边界
继续 feature/citlali6-z19-live-vision-20261018，先读 AGENTS.md、docs/GIT_WORKFLOW.md、已有 PR/README、main 最新变化；保护已验收 Linux IMX214、驱动/SD/相机 bit、系统 Python3.7/OpenCV3.4、NCNN 旧稳定包，不安装 Vivado 2020.2，不改 PS 时钟、PL 或其它协作者内容。必要 commit/push 更新现有 Draft PR #19，回报真实 HEAD、实际修复/未解决的根因证据、最新部署是否更新（没更新直说）、安全回退命令和剩余真实物体测试。

## Review

## 行内评审

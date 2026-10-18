# PR #19 团队审查入口（Issue #16 / P1）

本交付是独立板端视觉演示：Z19 A53/IMX214 → YOLOv8n@416 FP32 / NCNN →
PC浏览器同图画框。没有将结果接入主状态机、PL控制或MuJoCo；自主抓取始终禁止。
此材料供团队Review，不代表其他队员Approve或合并许可。

## 最简复现与代码入口

当前已运行环境可只读打开 `http://127.0.0.1:8768/`，或查看
`http://127.0.0.1:8768/result.json`。检查 `architecture=aarch64`、
`inference_host=zu19eg_mipi`、`input_transport=jpeg`、
`autonomous_grasp_allowed=false` 和状态/帧号/会话/JPEG SHA。
地址和服务存活需当场核实；入口关闭不意味着可以自动加载PL或重启服务。

PC无推理的同图校验入口（使用一个全新本地输出目录）：

```sh
python tools/collect_live_vision.py --seconds 2 --output tmp/review-read-new
```

该只读工具验证原JPEG SHA及ARM64标识，原始图片只留本地。退出1可能只是
没有保存到含目标的帧，应查 `summary.json` 状态，不能当成功识别。
已有环境的完整启动/停止、private bridge构建及回退命令见
[LIVE_VISION.md](LIVE_VISION.md#start-view-stop)。本轮无需重复构建NCNN、导出模型、
安装依赖或重新跑性能对比；任何PL/driver/系统操作仍须当前明确授权。

建议按以下顺序读代码：

1. [preview_server.py](preview_server.py)：同一锁内原子JPEG/seq/session/geometry。
2. [camera.py](../app/vision/camera.py)：新鲜度、重复/倒序拒绝、单图元数据。
3. [live_vision.py](live_vision.py)：单槽丢旧帧、800/1600ms TTL、错误清框、纯显示API。
4. [ncnn_cpp.py](../app/vision/backends/ncnn_cpp.py) 与
   [main.cpp](ncnn_bridge/main.cpp)：原JPEG IPC、实际解码/尺寸检查、forward前deadline。
5. [针对性Python检查](../tests/test_live_vision.py) 与
   [前端离线检查](../tests/test_live_vision_ui.js)：
   `python host/tests/test_live_vision.py` / `node host/tests/test_live_vision_ui.js`。

`host/config/settings.yaml`保留第一轮通用BGR工厂兼容参数，独立demo不读取它；
优化profile以live_vision CLI的416/JPEG/2T/poll200为准。

## 已验收物体与性能口径

| 目标 | 实物结论 | 证据/限制 |
| --- | --- | --- |
| 红车模 `car` | VERIFIED（既有实板同图演示） | [真实浏览器JSON](../../docs/fpga/evidence/live_vision_opt_20261018/z19-opt-fresh-browser-proof.json)，置信度0.9262；car仅演示映射，未加入抓取表 |
| `apple` | NOT VERIFIED | 无对应实物；旧手部apple0.3618是误检 |
| `banana` | NOT VERIFIED | 无对应实物 |
| `bottle` | NOT VERIFIED（已补验、未识别） | 本轮白色保温瓶两次约10秒观察各19个不同结果，无bottle；包括NO_TARGET和其他标签，非召回率基准 |

瓶子补验使用现运行模型/阈值.35/TTL，不调参、不重启。用户调整一次后仍未检出，
如实记录漏检，不以car框、热水瓶外形推断或空场景代替有效bottle检测。
[本轮无图原始记录及运行指纹](../../docs/fpga/evidence/live_vision_review_20261018/review.json)。

既有性能结果属于部署版本 `b996ac5de444e0c158546b2f7ca95bcee91f0f76`：
预览中位7.38→14.89FPS，最终最低10.93；约15FPS，不保证持续≥15。
`processed`完成推理约2.099/s；.5s采样观察到的不同有效结果1.862/s。
总推理中位462.4/p95504.1ms；观察帧龄中位899.3/p951201.6ms。
总推理不包含producer轮询/等待，帧龄是板端monotonic估计加保守传输界，
不是传感器曝光到PC屏幕的完整测量。不能将两个FPS口径或推理耗时与端到端延迟混称。
[原始对照、每核CPU/RSS及方法](../../docs/fpga/evidence/live_vision_opt_20261018/validation.json)。

前端以请求开始时的本地performance时钟计算保守过期deadline，并在解码后及
50ms watchdog检查；网络失败/过期清框。本P1小修让统计区同时变为
CONNECTION_ERROR/STALE、清detections及图像身份，避免画布空了却保留旧LIVE。
该小修通过两项离线内联JS检查，**未部署到当前服务、未声称实板验证新UI**。
原实板源码/ELF指纹和历史证据保持原样；新PR HEAD包含这项源代码小修。

## 依赖、权重与许可证

| 组件/来源 | 审查依据 |
| --- | --- |
| YOLOv8n权重与导出 | [manifest](../../docs/fpga/evidence/live_vision_20261018/model_manifest.json)记录weights/param/bin/pnnx SHA和版本；原输入为existing_local_weights，上游URL是expected source，哈希不等同于独立验证下载来源 |
| Ultralytics8.3.6 / YOLO模型 | [固定版本AGPL-3.0文本](https://github.com/ultralytics/ultralytics/blob/v8.3.6/LICENSE)；[上游模型/Enterprise说明](https://www.ultralytics.com/license) |
| NCNN20250503 | [BSD-3-Clause及列出的第三方例外](https://github.com/Tencent/ncnn/blob/20250503/LICENSE.txt)；C++静态链接，不使用PC CUDA/DPU |
| 系统OpenCV3.4.3 | [该版本3-clause BSD及第三方版权](https://github.com/opencv/opencv/blob/3.4.3/LICENSE)，原系统包未替换 |
| GCC9.2私有OpenMP头/libgomp | [原模板GPLv3-or-later及GCC Runtime Library Exception3.1](https://github.com/gcc-mirror/gcc/blob/releases/gcc-9.2.0/libgomp/omp.h.in)；生成器保留声明，链接原系统libgomp |

根目录Apache-2.0不替代上述第三方许可；转为NCNN格式不声明权重已重新许可。
本PR不包含模型param/bin或新增预编译bridge。此处记录组件来源和上游声明，
没有认定整套组合发布已完成许可合规审查；团队仍需决定权重来源确认、适用的
开源/Enterprise路径及分发时对应notice/source材料。本轮未改根LICENSE、购买许可、
重新导出模型或操作用户全局Ultralytics设置；历史配置副作用仍保留在开发日志。

## 与main和同日开发日志的关系

只读核查main：`6b1c90094e9979d1729a331896954a12821c7ae2`。
共同分支点为 `ee52f09ae78d7163067d627eeae0d627ea92855c`，没有merge/rebase main。
按 `git diff --name-only ee52f09 origin/main` 与本分支路径集合比较，交集为空；
这仅说明没有已知同路径编辑冲突，**不等同于执行过合并后的集成测试**。

| 已进入main的PR | 本视觉交付的边界 |
| --- | --- |
| #12，`b45d54e` | host/app/main.py新增MuJoCo入口，默认仍MockVision；本PR不改该文件、不将识别结果接入主状态机 |
| #13，`47ac04e` | HIL控制工程/服务与RTL独立；camera和旧HIL的PL配置互斥，不同时重配或假定合一；本PR不动其协议/RTL |
| #14，`6b1c900` | 个人协作流程文档，不改变本演示接口/团队审批；本轮依用户明确授权继续原分支 |

PR #18尚独立修改同名`docs/log/2026-10-18.md`。后续人工合并应将本日志的
Codex A段与其Codex B段都保留，不用一方覆盖另一方；当前不吸收B分支。
主程序的旧Python/AXI示例问题不由视觉演示证明已修复，不在本P1扩大改动。

待团队审查：同图/过期/失败契约、模型及分发许可范围、相机/HIL共享板卡边界、
实际未识别的保温瓶及未验收的苹果/香蕉、同日日志人工合并，以及新UI小修未来部署验证。
PR继续Draft；未发review request、未替队友Approve、未合并/关闭Issue，也未启动Issue #20。

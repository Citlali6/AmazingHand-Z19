# Issue #16 P0：同图诊断与模型能力边界

结论分两部分：**所测图像的NCNN管线与固定输入PC参考一致；真实苹果和白色保温瓶仍未识别成功。**
没有发现解释这次漏检的apple映射、RGB、导出或NMS错误，未把orange改名apple、降阈值或换模型。
原始有限JSON及指纹见[本轮验证](../../docs/fpga/evidence/live_vision_diagnostic_20261018/validation.json)。

## 同一JPEG逐层对照

原JPEG SHA、权重/模型SHA固定；Z19 ARM64实际运行原模型NCNN，PC仅离线参考。
四张历史样本和两张本轮实时苹果/保温瓶图像，1920×1080→416×234、上下padding91，
RGB字节FNV完全相同，归一化1/255 FP32，输出84×3549。FNV用于中间字节比较，
原JPEG/模型/ELF/源码仍用SHA256标识。COCO80每类最大分数差不超过5.88e-6。
四张历史图的.35/.01两档pre/post NMS计数、top结果类别均一致，框最大差约0.003像素。
.01只用于离线诊断，服务生产阈值始终.35、IoU.45。

| 同图样本 | Z19原始结果（.35前/后NMS） | 生产白名单结果 |
| --- | --- | --- |
| 历史真实苹果 | orange49最高.509370；apple47最高.105223 | NO_TARGET |
| 历史白保温瓶 | bottle39最高.004910；无.35候选 | NO_TARGET |
| 已验红车模 | car2=.929280 | car |
| 旧手遮挡负例 | apple47=.361835（模型误检；背景同时有车模） | 假apple，不能算成功 |
| 本轮真实苹果seq24 | orange=.540380；apple最高.089797；NMS后orange框 | NO_TARGET |
| 本轮白保温瓶seq3730 | bottle最高.053064；无.35候选 | NO_TARGET |

本轮两类各21个不同有效实时结果均NO_TARGET，分别仅前5帧附诊断，此后自动关闭。
前景空桌面再观察20个不同结果均NO_TARGET；已view确认前景苹果/保温瓶移开，
背景键盘旁仍有小车模，不能称整幅无目标。没有真实橙子可用，香蕉未验，不能建立
apple/orange特异性或可靠召回率。历史car验收保留；本轮car只做同图回归。

**参考方法修正**：此前Ultralytics8.3.6的`predict(path,imgsz=416,rect=False)`
实际hook输入为`1×3×256×416`；该版本`pre_transform`对单图使用`auto=True`，
没有采纳rect参数。故旧PC orange.657752不是固定416×416对照。
新参考工具显式生成416×416张量，检查与`LetterBox(auto=False)`逐像素一致后直接前向，
保留旧原始记录并提供输入形状更正，未改变板端模型来凑旧数值。
C++round与Python ties-to-even在其他尺寸的.5边界可能不同；本轮所有固定尺寸已经
实际RGB字节对齐，不把此结论推广到任意分辨率。

## 默认关闭、限量、可复现

`live_vision.py --diagnostic-frames 0`为默认。显式开启时最多20帧、每阶段top-k最多20；
本轮只用5帧/top10。native提供COCO80类max、每anchor argmax的阈值前top、
四目标类别各自pre-NMS top、阈值后pre/post NMS top和预处理字段。
Python加类名并分别记录`before_display`与`after_display`，与同JPEG SHA绑定。
这些是调试数据，不进入动作策略；过期/相机错误会清diagnostic和有效框。
非法类别、非有限行明确失败，不把id=-1映射为最后一个COCO类。

新副本位于`/home/root/ah-vision-diagnostic-20261018`，旧`/opt`包不覆盖。
只重链小bridge、复用旧静态NCNN，无系统安装。前5帧诊断会增加处理耗时，
不能用开启诊断的时延宣传正常性能；预算耗尽后回复/日志不再包含diagnostic。

已有相机设备/采集服务运行时，前台复现（先确认没有另一个自有AI占用9100）：

```sh
D=/home/root/ah-vision-diagnostic-20261018
OLD=/opt/amazinghand/live-vision-20261018
python3 "$D/host/camera_linux/live_vision.py" --model-dir "$OLD/models" \
  --bridge "$D/native/ah_ncnn_bridge" --diagnostic-frames 5 --diagnostic-top-k 10
```

仅旧图片对照必须标为OFFLINE_DIAGNOSTIC，不能绕过TTL冒充实时。将以下工具随
`host/app/vision`复制到新部署的`tools/`后执行（输出文件须新建）：

```sh
python3 "$D/tools/diagnose_ncnn_image.py" --image /private/same-frame.jpg \
  --model-dir "$OLD/models" --bridge "$D/native/ah_ncnn_bridge" --output /private/new-result.json
```

PC用现有隔离导出venv和可信旧权重，不需下载、导出或安装：

```powershell
tmp/vision-export-venv/Scripts/python.exe tools/compare_vision_reference.py `
  --image <same-original-JPEG> --weights tmp/vision-20261018/export416-pinned/yolov8n.pt `
  --output tmp/reference-new
```

工具在import前设新输出内的YOLO_CONFIG_DIR，不碰用户全局配置。输出完整COCO
诊断分数而不是只展示4类，PC结果只用于排错，不作为Z19验收。

## 当前实板、性能与回退

本P0已部署private工作副本，之前P1的前端清统计修复现在也在运行；不再是旧b996 UI。
最终服务PID10126，原preview PID27170保持，生产诊断预算已耗尽。
部署源码SHA见`deployment.json`，最终提交与这些文件逐一校验；原生ELF SHA256：
`b176841a20772a230272499e9f6b195d07377a552021b8cb08307c9fe506cbed`。
模型param/bin仍为原416FP32，SHA和原`model_manifest.json`一致；未重导出/改权重。
板端时钟仍旧日期，帧龄/时延使用monotonic。

诊断关闭后的唯一30.03秒检查：预览中位15.44FPS、最低9.49，processed2.135/s，
有效不同结果观察1.865/s；推理464.6/p95514.6ms，观察帧龄933.7/p951201.6ms；
AI RSS170580KiB（166.6MiB）。之前14.89FPS/2.099/s/462.4ms结果仍保留，
不同场景的短时检查不能证明性能改善，也不能承诺持续≥15。800/1600ms未放宽。

```sh
D=/home/root/ah-vision-diagnostic-20261018
# 身份核查后仅停止本任务新AI；等待status STOPPED。
python3 "$D/host/camera_linux/vision_control.py" stop --state-dir "$D/state"
python3 "$D/host/camera_linux/vision_control.py" status --state-dir "$D/state"
# 恢复第二轮原优化副本，原camera采集仍保持，不加载PL/卸driver。
OLD=/opt/amazinghand/live-vision-opt-20261018
python3 "$OLD/host/camera_linux/vision_control.py" start \
  --model-dir /opt/amazinghand/live-vision-20261018/models --bridge "$OLD/native/ah_ncnn_bridge"
```

保持当前新副本而仅重启AI时，用同样的新controller/state/log目录，省略diagnostic参数即默认关闭。
电脑入口`http://127.0.0.1:8768/`已恢复为仅SSH转发，不运行模型。原相机一小时到期
只在当前使用授权及进程/设备核实后正常`/start`；任何PL/driver/system变化仍另行授权。

## 模型阻断与最小下一步

一次固定中心70%宽/全高ROI的PC可行性检查仍把苹果判orange.6133，保温瓶bottle仅.1926；
car .8664、另一个手负例未检出。该ROI不同时解决两类，不进入生产，不继续扫参数。
不能把“管线一致”写成“目标识别成功”，当前需人工确认且自主抓取永远false。

后续建议从小型标注试验开始：每类apple/真实orange/实际保温瓶各30–50个独立视角，
另30–50个手/前景空/其他物体负例，覆盖至少3次不同光照/距离会话，按独立会话留出验证集。
这是试验起点，不是足够数据量或准确率保证；先报每类漏检/误检、apple↔orange混淆及板端时延。
在橙子负例缺失时不能声称区分可靠。换模型、下载/训练、扩大架构须先说明体积/许可/内存与成本
并获授权，保留原包回退。当前未下载/训练/引入新模型，也未开始Issue #20。

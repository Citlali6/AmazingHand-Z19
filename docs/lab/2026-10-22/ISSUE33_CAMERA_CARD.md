# #33 相机标定操作卡：READY FOR ONSITE CAMERA TEST

本卡只打开相机，随后使用 FakeRobot；没有串口参数或真实运动入口。
本轮没有采集现场相机，没有实拍毫米误差表，也没有真实三位置验收。
先由负责人同意相机采集、确认画面无隐私，关闭占用相机的软件。
在本 #33 工作树根目录、既有 Conda `visiongrasp` 环境执行。

已读负责人提供的打印包说明、SVG 和 PNG 预览：外板设计 **500×400 mm**，
内部标定区 **400×300 mm**、四边各 50 mm，网格 **20×20 mm**；
P1 左上为原点，P2=(400,0)、P3=(400,300)、P4=(0,300)，+X 右、+Y 下。
这些是设计数据。原说明也要求验收成品横纵 100 mm，PNG 不能作精密打印依据。
`ISSUE33_BOARD_DESIGN_TEMPLATE.json` 已预填此设计和五个独立网格检查位置，
`geometry_verified=false` 会拒绝生成实测标定；它不包含现场照片/像素坐标。

1. 固定相机和亚克力板。用尺/卡尺实测 X/Y 网格间距、有效区域宽高，标明原点、+X/+Y。
   记录镜头/支架位置、分辨率、裁切、旋转、焦距和曝光。不得由照片或型号推断 mm。
   优先实测横纵各连续五格的 100 mm 跨度，将真实读数及测量方法写入 `physical_scale_check`。
   同时核实内部 400×300 mm 和所选点距；若打印有缩放，以真实点距修订所有 XY/网格参数。
   核验后才把 `geometry_verified` 设为 true，不能仅凭设计文件确认。
2. 将本目录 `ISSUE33_MEASUREMENTS_TEMPLATE.json` 复制到忽略目录
   `output/pc/issue33/measurements.json`，填完全部 null/空字符串；本块板可改复制已预填的设计模板。
   `table_points` 是至少四个拟合点的真实 XY，依次点击与每项对应的位置，推荐按板面四角环绕排序。
   `checks.table_points` 至少五项，必须是**未参与拟合的不同标记**：中心及四个靠近边缘的象限各一点。
   程序按拟合 XY 包围盒检查：中心在 35–65%，四外象限分别在 <35% / >65%；不满足则报告失败。
   像素点相距须至少 1 px，测量点至少 0.1 mm；检查点不能与拟合点重合。
3. `camera_mount_crop_focus` 写相机固定条件；`distortion_assessment` 写直线弯曲/边缘误差观察。
   程序目前不执行镜头畸变矫正；若边缘误差系统性偏大，停止使用并另做相机内参标定，不能仅加拟合点掩盖。
   `object_height_parallax` 写实测物块高度及顶部中心如何对应接触投影。
   桌面 H 只适用于桌面平面；有高度的顶部中心可能产生视差，需在工作高度另做独立检查/预算。
4. 用已由现场确认的 USB 相机索引替换下例 `1`。1280×720 是请求值，保存尺寸取自实际帧。

```powershell
conda activate visiongrasp
python pc/scripts/calibrate_table.py --live-index 1 --backend dshow --width 1280 --height 720 --measurements output/pc/issue33/measurements.json --snapshot output/pc/issue33/board-01.png --output output/pc/issue33/table-01.json
```

工具取一张可用帧后关闭相机，再显示冻结画面，不让点击期间的相机运动改变点位。
逐项看窗口顶部的 `FIT/CHECK` 和真实 XY 再点击；编号、ROI 轮廓持续显示；R 全部重选，ESC 取消。
ENTER 只在点数完整时生效。窗口分辨率为原图，点击坐标对应实际像素。
遮挡角标不能猜；移动线缆或调整光线后重新开始。

保存文件包括新 UUID、UTC 时间、来源/尺寸/会话、物理定义、拟合点、独立检查点，
每点像素/真实 XY/预测 XY/欧氏误差、mean/RMS/max 和覆盖结果。
拟合残差与检查误差分开；默认 mean ≤5 mm / max ≤10 mm 是初始建议，须按夹爪/物块容差收紧。
检查失败仍保存失败报告，exit 2；通过 exit 0。旧文件禁止覆盖，重测用 `table-02.json`。
上例 `--snapshot` 显式保存原始冻结帧到本地忽略目录，仅在现场同意后执行；不需留图时去掉该项。
已有原图拒绝覆盖，不上传隐私画面。

也可在已同意的本地图像上选点（不打开任何设备）：

```powershell
python pc/scripts/calibrate_table.py --image output/pc/issue33/board.png --source LIVE_PC_UVC --measurements output/pc/issue33/measurements.json --output output/pc/issue33/table-02.json
```

`--source LIVE_PC_UVC` 仅用于真实 USB 图像；合成图必须 `SYNTHETIC`，其他图用 `IMAGE_TEST`。
直接点对 JSON 用 `--points`，需额外填 `image_points/frame_wh_px/source/checks.image_points`。
程序无法从填写的 JSON 证明物理测量真实，现场证据必须由操作者保留。

独立检查通过后，检查相机、板面、裁切、焦距均未改变，显式确认本次复用，启动原有演示：

```powershell
python pc/scripts/demo.py --mode mock --camera live --camera-index 1 --backend dshow --width 1280 --height 720 --calibration output/pc/issue33/table-01.json --confirm-calibration-setup --frames 0 --output output/pc/issue33/demo
```

新相机会话只有显式确认才重新绑定；新来源/尺寸仍拒绝。更换会话发生在运行中则废弃标定。
同一尺寸下相机/板面移动无法自动判断，操作者须退出重标定；不要再次确认旧工位。
GUI 的旧四角按钮只建立拟合，真实相机需要本卡的独立检查文件才能启动 Fake 七阶段。
保持 `LIVE_PC_UVC + MOCK ROBOT`。点红/蓝目标，再点 `CONFIRM & RUN MOCK`，每个阶段仍无机器人 XYZ/运动许可。

按下面项目现场逐项记录，本轮状态均为 **NOT TESTED**：

| 场景 | 记录内容与判据 |
| --- | --- |
| 空板 | 无有效目标；点击/回车不能发出新阶段 |
| 单红、单蓝、多目标 | 像素中心、桌面 mm、标签和有效性；不要把相似颜色反光当物块 |
| 三位置 | 每次移动后等新帧，重新选择并确认；三个位置的 mm 分别更新；保留独立量尺真值 |
| 阴影/反光/模糊/边缘/遮挡 | 记录误检和拒绝；HSV 无法证明所有遮挡不误检，可靠性不够就不进入抓取 |
| 占用/断线/黑屏/重复与过期帧 | 不产生可执行目标；停止后续阶段，恢复后重新检查工位 |
| 同一目标移动/重复点击 | 运行中拒绝重复启动；超选择容差移动会停止后续阶段 |

每个新帧的 `VISION_FRAME` JSONL 保存完整 VisionTarget 字段，空板也记录，无默认图像上传。
STOP 只禁止后续阶段，不是电机急停；此流程始终 FakeRobot。

桌面→基座还缺：实测 XY 平移/yaw、板面 Z、物块尺寸/抓取高度、官方末端到接触点偏移及
对应姿态、独立未拟合的可达点误差、误差预算、有效 ROI 和安全包络。
参数不齐就不传 `--base-calibration`，界面显示 BLOCKED。完整配置格式见 `BaseCalibration`，
`--base-calibration <本地实测JSON>` 仅显示 PLAN PREVIEW，不提供执行许可，不验证 IK/碰撞。

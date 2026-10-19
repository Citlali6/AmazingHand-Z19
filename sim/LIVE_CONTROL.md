# Host → MuJoCo 实时控制（Issue #10）

复用 `GraspSelector`、`SimBackend` 抓取状态机及协议总线，替换原来的线性模拟动力学，
实际调用 `mujoco.mj_step`，从 `qpos` / `actuator_force` 返回反馈。输入来自当次按键、
按钮或本地 API，没有自动播放序列。选择 banana/apple/bottle 使用仓库同名抓取策略；
当前展示手部姿态控制，场景未放置可抓物体，不声称物体已被抓稳。

## 启动

从仓库根目录运行（Windows / Python 3.12）：

```powershell
python tools/check_migration.py
uv venv --python 3.12 .venv
uv pip install --python .venv/Scripts/python.exe -r sim/requirements-live.txt
.venv/Scripts/python.exe host/app/main.py --mujoco
```

迁移分支已将原 gitlink `3e824107` 的模型和资产直接保存到 `AmazingHand/`，无需子模块下载；逐文件 hash 见 `docs/migration/model-snapshot.json`，不改上游 XML。
没有 uv 时可用 `py -3.12 -m venv .venv` 和 `.venv/Scripts/python.exe -m pip install -r sim/requirements-live.txt`。
不需要安装整个板端 `requirements.txt`。

按 **1/2/3** 选择香蕉/苹果/瓶子；**O** 张开、**G** 抓取、**H** 保持当前位置、
**R** 释放、**S** 停止、**E** 显式复位，**Q/Esc** 或窗口 X 退出。鼠标按钮也可操作；
拖动场景旋转，滚轮缩放。初始保持不动，只有输入命令才开始运动。

面板显示控制状态、实测角度、实际执行器控制量和仿真负载。
STOP 清除旧目标、禁用执行器并暂停物理状态，拒绝运动命令直到复位；复位不重放旧目标。
主循环超期 500 ms 或物理步进异常会停止。关窗/正常结束会关闭后端，SIGINT/SIGTERM 请求退出。
此处停机是模拟器语义，不代表物理机械手断力矩已验收。

## 在线输入与验收

窗口运行时，另一个 PowerShell 可发送指令、读取实际反馈：

```powershell
Invoke-RestMethod http://127.0.0.1:8767/command -Method Post -ContentType application/json -Body '{"action":"grasp","category":"apple"}'
Invoke-RestMethod http://127.0.0.1:8767/state
```

API 仅绑定 loopback，返回 202 代表已入队；实际接受/拒绝结果见 `/state` 的 `events`。
可用 `--headless` 运行相同真实物理/API而不显示窗口；`--duration 20 --snapshot tmp/panel.png`
可限时退出并保存末帧（snapshot 仅 GUI）。后台 API 不应暴露给局域网。

本机验证：5 项真实 MuJoCo 控制测试、原 backend 10 项和 sim 5 项通过；
独立 GUI 进程通过 API 完成张开→抓取→保持→释放及停止/拒绝运动/复位，
末轮实测关节变化约 48.2°、停止后位置不变且执行器输出为零，正常退出码 0。
证据在本地 `tmp/mujoco-live-20261017/acceptance.json` 和 `live-panel.png`。
GitHub交付归档见 [原始运行记录与本轮检查](../docs/evidence/2026-10-17/issue10/README.md)。

```powershell
.venv/Scripts/python.exe host/tests/test_mujoco_live.py
.venv/Scripts/python.exe host/tests/test_hil_wire.py
```

角度按模型零位/弧度驱动，显示度；只在 SIM 适配中将预张开角改成模型零位，原抓取表不变。
raw 沿用旧 golden profile（±π 映射 0..4095），负载 `abs(actuator_force)*100` 饱和至 1023，
速度 raw3 在此演示为 60°/s。以上均非 SCS0009 实物标定或 v0.3 ABI。

## 与 Issue #11 对接

同一面板可使用独立 HIL 工程服务器：

```powershell
.venv/Scripts/python.exe host/app/main.py --mujoco --hil 192.28.14.153:8765
```

这需要 #11 分支的 `fpga/hand_control/ps/hil_server.py` 与配套 AHIL PL profile；
不兼容现有相机 bit 或旧 Host FPGA 寄存器。没有板卡时会失败，不回退软件状态机。
连接后先 E 复位，再 O/G 等操作。HIL 的新 open/grasp 只在 IDLE 接受，重复动作前先释放或复位。
尚未声称已执行实板 HIL。

`amazinghand-hil/1` 使用 TCP NDJSON，50 Hz；先 `hello` 读取 accepted_seq，然后发送严格递增的
seq/heartbeat（相等）、cmd、八路 target_raw 和 feedback(position_raw/load_raw/online_mask)。
只有来自 PL 的 target_raw/torque_enabled 驱动物理；MuJoCo 实测反馈回灌 PL。
回复必须含 source=pl、匹配的 seq/accepted_seq/feedback_seq、state/fault/pl_tick 和
command_count/feedback_count。客户端超时 250 ms、PL watchdog 500 ms，失败即暂停本机物理；
需记录板端计数器/波形才可验收硬件闭环，wire 测试不代替这项证据。

# Issue #10 本地运行证据

本目录归档上一轮独立 MuJoCo GUI 进程的原始 JSON、截图及 stdout/stderr，并附本轮交付前执行的
5 项真实物理控制测试和 4 项 HIL 帧校验测试输出。`manifest.json` 记录原文件路径、大小、SHA256和检查命令。

- `acceptance.json`：通过 loopback HTTP 在线发送 open/grasp/hold/release/stop/reset；实测最大关节变化
  48.23280287381772°，停止后位置不变、执行器输出0、后续运动被拒绝、进程正常退出。
- `live-panel.png`：MuJoCo 渲染的实际控制面板，不是摄像头照片；场景未放入被抓物体。
- `gui.stdout.txt` / `gui.stderr.txt`：保留原始输出；stderr为空。
- `mujoco-tests.txt` / `wire-tests.txt`：交付前重新执行的直接相关检查；wire校验不是实板HIL。

这是 PC 仿真证据，不包含 Z19 上板、物理舵机、真实物体抓取或 PL 参与的硬件闭环。
GUI证据产生后新增的掉线停止检查已包含在 `mujoco-tests.txt`；本轮没有重复运行整个GUI或昂贵构建。
启动命令和共同HIL契约见 [实时操作说明](../../../../sim/LIVE_CONTROL.md)。

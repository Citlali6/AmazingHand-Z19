# 2026-10-19 迁移副本的 PC 验证

- Python 3.12.14 / Windows x64，独立 `.venv`；完整版本见 `pc-environment.txt`。
- `backend.txt` 10/10，`control.txt` 27/27，`sim.txt` 5/5，`mujoco-live.txt` 5 项，`hil-wire.txt` 4 项，`hil-server.txt` 4 项；合计 55 项全部通过。没有在本次迁移重新运行 FPGA 构建或上板测试。
- `gui-control.json`：新迁移目录实际 GUI、独立 loopback 端口 18768，本机 API 复位/抓取/保持，25 个采样，关节最大变化约 89.8335°，正常退出 0。
- `pc-control-panel.png` 是上述软件仿真末帧，`pc-panel.png` 是首次界面启动。首次渲染超期可触发停止锁存，需要显式复位；原保护未禁用。
- HIL wire/server 检查的是本机协议和映射行为，不是实际 FPGA 运行。当前包中的实板记录来自 2026-10-18，不能把它与这次 PC 检查混为同一轮验收。

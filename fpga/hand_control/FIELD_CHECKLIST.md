# Z19 ↔ MuJoCo HIL 现场操作清单

沿用已验收的相机 Linux、SSH、网线和 PS 初始化，使用 README 的 `linux-sd` 加载包。
原 `standalone` 的 LPD/0x80000000 bit 不适用此流程。实际执行结果见当日 Issue #11 日志。

1. **当前无需重接。** 已验证板端 `192.28.14.153` 的 SSH 可用，PC 为 `192.28.14.152`。
   保持供电、散热、启动拨码和 SD 原状。无需 JTAG 或串口登录，COM7 可保持关闭。
   不接 FMC、电平转换器或物理舵机，不给真实机械手供电。
2. **相机须空闲。** 若有预览/采集、`ah_camera0`、`mipi_cam` 或 PL 平台驱动，先按原流程
   停止采集并卸载驱动。加载器会拒绝活动驱动，不会强制卸载。全量 HIL bit 暂时取代相机 PL，
   两者不能同时运行；原相机文件保持原样。
3. **核对包。** 独立目录构建 `impl linux-sd`，用 `package_linux.py` 打包；核对 manifest、
   bit/XSA 一致性、实测 200703980Hz 周期下的时序和 DRC。禁止在运行中的 Linux 执行
   此 XSA 的 psu_init/FSBL，禁止改 PS PLL。它是 PL 热加载平台，不是新 SD 启动镜像。
4. **RAM 部署。** 用既有 SSH 身份将 tar 传至 `/run`，拒绝覆盖非空包目录，解包后执行
   `sh hil-service.sh preflight` → `load` → `start --bind 192.28.14.153`。
   预期 FPGA Manager 为 operating、MAGIC=0x4148494c/schema1、首次 PROTECT/torque off、
   TCP8765 可读出 `source=pl`。失败时不启动 PC，也不盲读未配置的 PL 地址。
5. **PC 实时闭环。** 用 PR #12 的 `--mujoco --hil 192.28.14.153:8765`，显式 reset 后
   open → grasp → hold → release → stop。保存关节位置和 PL ACK、pl_tick、command/feedback
   计数器、PL 接受的位置/load，确认双向变化。STOP 后力矩关闭、仿真输出为零、旧动作拒绝；
   reset 仍不恢复力矩，须再发新动作。可用 `check_hil.py --gui` 完成一次联合检查。
6. **独立看门狗。** 软件暂停属于本包的 PS 桥进程，在不刷新 COMMIT 的情况下观察 PL；
   约500ms 后应锁存超时/torque off。保留真实采样，不能用 TCP 断开代替独立看门狗证据。
   恢复桥后继续保持停止；重新开始须显式 reset。
7. **收尾/恢复。** PC 退出后 `sh hil-service.sh stop`；需要相机 PL 时运行
   `sh hil-service.sh restore-camera`，核对原镜像固定哈希后加载，不修改镜像、不自动启动相机。
   再按原相机文档启动原驱动/预览。`/run` 包和日志在掉电后消失；SD 启动配置、相机 bit/XSA
   和安装目录保持原样。下次原 SD 启动后重新上传/加载即可。

只有 SSH 无法连通时才需要用户现场操作：确认网线接原 PS 网口、供电正常，再用 PS UART
（已识别 COM7，115200/8N1/无流控）查看启动状态。不要求重新安装 Linux，不凭通用说明改 SW1。

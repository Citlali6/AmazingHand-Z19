# 真实 Z19 ↔ MuJoCo HIL，2026-10-17

本目录是新增 **linux-sd / HPM0 FPD / 0xA1000000 / 200703980Hz** 配置的真实证据。
前一个 `2026-10-17` 目录仍是 standalone 构建/XSim记录。本轮没有重复执行 XSim。
`manifest.json` 记录本目录每份原始文件的路径、大小和SHA256，`.gitattributes` 保留原始字节。

| 层级 | 实际结果 | 文件 |
|---|---|---|
| Vivado2020.1 | 新配置生成bit及含bit XSA；4.982ns下WNS+1.856ns、WHS+0.002ns、TNS/THS0、DRC0 | build.txt、timing_impl.rpt、drc_impl.rpt |
| 打包 | Bootgen2020.1生成bin；核对BD、bit/XSA内容一致和源码/运行文件哈希 | deployment-manifest.json |
| 板端 | Linux5.4.0-xilinx-v2020.2，PS位宽/复位/时钟读取匹配，FPGA Manager operating，真实AHIL寄存器 | board-loaded.json、board-final.json |
| GUI闭环 | PR #12原HEAD583abe1；85次采样，关节最大变化49.20068°；动作、双向反馈、STOP/复位通过 | hil-result.json、hil-samples.json、hil-panel.png、hil-app.txt |
| 独立PL看门狗 | SIGSTOP真实PS桥，未刷新COMMIT；480.4ms仍正常，540.1ms已PROTECT/fault1/torque off | watchdog-probe.py、watchdog-result.json |

GUI闭环使用真实 MuJoCo 物理反馈；单独看门狗检查使用固定合法仿真反馈，二者分别记录。
全程没有物理舵机。GUI截图是运行结束前STOP状态；fault2表示显式停止，不是运行故障。
PS桥日志中一次Connection reset来自首次检查脚本在GUI首帧发布前退出，之后正式联合检查正常退出0。

恢复流程也实际执行过：停止服务 → 加载原相机bin，得到`CAMERA_PL_RESTORED`（脚本已核验operating）
→ 再加载同一HIL包并启动服务。只验证相机PL配置恢复，没有重启相机采集/预览。
最终仍为HIL服务PID964、PL停止/力矩关闭，等待PC客户端；重新加载后计数器归零，
所以board-final与GUI记录的计数器属于不同的配置运行周期。

板端RTC落后于PC；未为本任务更改板端时间，以PC日期及单调时钟间隔为准。
原相机工程、镜像、Linux启动/安装文件未改动，无新增接线/拨码/重启。
HIL与相机共享PL，不能同时运行；恢复相机采集仍需按原流程启动原模块和预览。

## 实际部署产物

二进制留在独立PC目录，不把本机路径冒充远程下载链接。可按README从源码重建：

- 构建：`F:/ah-hil-deploy-20261017/linux_sd_run01`。
- 包目录：`F:/ah-hil-deploy-20261017/amazinghand-hil-20261017-v2`，含bit、XSA、bin、manifest和服务脚本。
- 板端运行归档：`F:/ah-hil-deploy-20261017/amazinghand-hil-20261017-v2.tar`（36372480B），
  SHA256 `2e697f5ca24eed0832b985a8a3214b2ac797256493f52686d193e2c098be33d1`。
- 已上传板端 `/run/amazinghand-hil-20261017-v2`；仅tmpfs文件，断电后须重新上传/加载。
- bit SHA256 `6cc2212fa360b75b2390d67f2bddb44144066c2aa6f893f331dc4334789940cb`。
- XSA SHA256 `2fd10e2954d0c3a41f7c422ca5685c24c14cc8c7b4d9fcd7da85038e76ccfcfb`。
- bin SHA256 `72f8aff4795ae11bd2d8788e866f010953dd6602aeea7198356aaed141274f04`。

本包复用正在运行的相机Linux及已初始化PS，不提供新SD启动镜像；禁止执行此XSA的PS初始化。
下一步无需现场硬件操作即可再次打开PC界面。物理舵机、电气/供电、实物标定与比赛工具版本要求仍待后续验收。

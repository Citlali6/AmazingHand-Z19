# xiaomi-he-only：迁移与启动

新仓库：[xiaomi-he-only/AmazingHand-Z19](https://github.com/xiaomi-he-only/AmazingHand-Z19)。
它是原公开仓库的 Fork，拥有者是 xiaomi-he-only，保留上游关系及版权声明。原仓库和原有同名私库均保留。

## 保存了什么

- 原仓库的 18 个分支及其全部提交历史，迁移时分支 SHA 逐一匹配，见 [清单](source-refs-20261019.json)。源仓库当时没有标签或 Release；没有 Git LFS 文件。
- `feature/migration-ready-20261019`：以最新 main 为基线，复制已上传的麦克风工作，补齐模型和本机 MJC1 交付物。本分支作为新仓库下载入口；原 main 未改动，未合并 PR。
- `AmazingHand/`：原模型 gitlink 固定版本 `3e8241074df3436a3044ced4881e3bb2133aa725` 的 196 个文件，直接随普通下载保存，不再依赖子模块初始化。[来源和逐文件 hash](model-snapshot.json)。保留原 Apache/CC-BY 许可和归属；未修改模型 XML/STL。
- [麦克风离线包](../../deliverables/voice_usb/README.md)：中文模型、15 个 AArch64/Python 3.7 离线依赖和语音源码。
- [MJC1 R2 固件包](../../deliverables/mjc1_fpd/README.md)：本机 2026-10-18 已验证 bit/bin/XSA、报告与回传记录，SHA 与原 manifest 匹配。源码在 `fpga/mjc1_fpd/`。
- [本地未提交源码快照](../../deliverables/local_sources/README.md)：原 RTL、早期桥接、相机/MJC1 集成的源码及差异。它们单独保存，没有作为已通过的集成功能接入。原工作区未提交、未删除、未清理。

源码历史中的旧路径和旧仓库地址属于历史记录。迁移分支的 Git 工作流目标已经改为新仓库；旧分支仍保存原样。

## 在这台电脑打开虚拟手

本机迁移目录：`D:/Vitis/project_1/amazinghand_migration_20261019`。

双击根目录 **`start_virtual_hand.bat`**。这是 PC 交互仿真，不需要板卡，初始保持不动。
按 `O` 张开、`G` 抓取、`H` 保持、`R` 释放、`S` 停止、`E` 复位；关闭窗口退出。
首次渲染若触发超期保护，界面会显示 STOP LATCHED；先按 `E` 复位，再输入动作。
完整操作见 [实时控制说明](../../sim/LIVE_CONTROL.md)。

其他电脑使用时，安装 Python 3.12，下载本分支并解压，双击 **`setup_pc.bat`** 安装独立 PC 依赖，然后运行上述入口。
首次安装需要联网；不得把 PC 依赖环境复制到 Z19。不要安装根目录混合了 ARM/视觉组件的 `requirements.txt`。

```powershell
git clone --branch feature/migration-ready-20261019 https://github.com/xiaomi-he-only/AmazingHand-Z19.git
cd AmazingHand-Z19
setup_pc.bat
start_virtual_hand.bat
```

仅核对下载完整性可运行 `python tools/check_migration.py`；使用 PC 独立环境追加 `--runtime` 可实际加载八执行器模型，不接触板卡。

## 继续由 FPGA 控制虚拟手

两套已存在的协议必须选用相匹配的固件和程序：

| 入口 | 对应固件/地址 | 说明 |
|---|---|---|
| `start_mjc1_observer.bat` | **MJC1 R2 / 0xA0000000 / v1.1** | 本机之前的“只观察”闭环；源码、固件及恢复步骤见 MJC1 交付说明 |
| `start_virtual_hand.bat --hil BOARD_IP:8765` | **AHIL / 0xA1000000** | 原仓库另一套 HIL；使用 `fpga/hand_control/` 与其匹配固件，不能换成 MJC1 bin |

本次迁移不重新加载 FPGA、不重启板卡、不探测 MMIO、不改变相机/虚拟手连接。
已在板端运行的程序可继续使用；重启后需要按实际 profile 的部署说明恢复。账号、密码、SSH 私钥、SD 系统镜像不上传。

MJC1-only 和相机-only 会替换整片 PL，不能同时加载。相机+控制集成源码在原功能分支和本地快照中保留，不能把它当成已通过时序/并发验收的固件。

## 功能边界

PC 八执行器模型加载、55 项现有测试和实际 GUI 动作检查通过，见 [迁移日志](../log/2026-10-19.md) 与 [界面](evidence/pc-control-panel.png)。本次没有重新验证上板闭环或相机并发，麦克风仍待到货联调；既有 SD 镜像、板端驱动、端口和时钟配置仍是使用条件。

后续修改继续使用工作分支与人工审查流程，不直接开发/推送/合并 main。

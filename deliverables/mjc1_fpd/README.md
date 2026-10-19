# 已验证的 MJC1 FPD R2 包

[下载 ZIP](mjc1_fpd_r2_20261018.zip) · [SHA256](mjc1_fpd_r2_20261018.zip.sha256)

此包来自本机 2026-10-18 的 MJC1-only R2 验证目录，约 2 MiB 压缩大小，包含 bit、原始 FPGA Manager bin、XSA、原 manifest、时序/DRC 报告、反馈记录和截图。将 ZIP **解压到仓库根目录**，得到 `fpga/mjc1_fpd/out/`。

- Z19 / XCZU19EG，Linux `5.4.0-xilinx-v2020.2`，HPM0_FPD 128，基地址 `0xA0000000`，PL ID `MJC1`，版本 `1.1`。
- 只使用带 `_r2` 的固件；之前复位错误的版本未收录。
- bin SHA256：`8e8b6566a3cdbe0e276852956b1d4c60b4fd74c8e4828e149509527ee0a4a8d4`。
- 没有物理舵机输出。该配置占用整片 PL，需要停用相机 profile；不适用于 AHIL 地址/客户端。
- 原证据显示至少 17 个闭环周期及反馈 ACK 匹配；这是历史实板验证，本次迁移未再次上板。

## 已在运行时

迁移无需重新加载板卡。PC 双击 `start_mjc1_observer.bat`，它监听本机 `127.0.0.1:8765` 等待真实 PL 数据。板端既有 SSH 反向转发应把 `127.0.0.1:18765` 转到这个监听器。
没有真实板端数据时显示等待，不生成假的 PL 指令。迁移后的观察入口已改为仓库相对路径。

## 板卡重启后的恢复

先阅读 [原验证目录说明](../../fpga/mjc1_fpd/README.md)。确认同一 Linux/PS 基线、唯一 PL 使用者、相机已停止且驱动卸载；不得盲探其他地址。

1. 将 `out/mjc1_fpd_r2.bit.bin` 上传到板端固件目录，文件名为 `/lib/firmware/amazinghand-mjc1-fpd-20261018-r2.bin`，核对 SHA256。
2. 在板端版本目录放入 `load_mjc1_r2.sh`、`mmio.c`、`board_loop_native32.py`。运行带前置检查的 loader，参数为上面的 bin SHA256。
3. 在板端编译原生库/诊断程序，并先逐寄存器诊断；步骤见原验证说明。**不能使用 Python buffer 的旧 MMIO 桥。**
4. PC 打开观察窗口；用自己的 SSH 认证建立反向转发，再启动板端原生客户端。原客户端默认一小时内重复动作。

SSH 转发示例（替换自己的 SSH 别名）：

```powershell
ssh -N -R 127.0.0.1:18765:127.0.0.1:8765 YOUR_BOARD_ALIAS
```

此目录不保存登录凭据、不提供 SD 镜像、不自动改变板端配置。源代码不等于可在任意内核/PS 初始化状态下加载的通用固件。

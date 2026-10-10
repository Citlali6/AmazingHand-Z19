# Z19 相机快速操作

2026-10-10 定版：第一路 IMX214，真实 **1920×1080** MJPEG，当前实景电脑端约 **25 fps**。
用户已确认预览可用。画面未做识别或手控制；焦距、雾感和标定仍需后续处理。

## 当前直接观看

打开 **http://127.0.0.1:8766/**，刷新页面后可点“全屏”。
“启动/停止”控制相机采集；焦距为 0～1023 手动位置，不是自动对焦。
单次采集最多一小时，结束后再点“启动”。

网络保持电脑网口直连 Z19 PS 网口：PC `192.28.14.152`，板卡 `192.28.14.153`。
本地入口解决 Windows 代理绕行问题，不需要路由器；Wi-Fi 和系统代理沿用原配置。

## 电脑预览入口关闭后

在电脑 PowerShell 执行，保持该终端运行：

```powershell
python F:\Amazing_Hand\host\camera_linux\view_camera.py
```

然后打开 `http://127.0.0.1:8766/`。Ctrl+C 只停止电脑入口，板端服务继续运行。
若端口已被当前预览入口占用，直接打开页面，勿重复启动。

## 板端服务停止后

相机 PL/驱动仍已加载时，从电脑启动板端服务：

```powershell
ssh -F F:/Amazing_Hand/tmp/z19-ssh-rsa-config-20261010 z19-direct 'export PATH=/usr/sbin:/usr/bin:/sbin:/bin; python3 /opt/amazinghand/camera0-linux-hd-20261010/start_preview.py'
```

SSH 配置和专用私钥只保存在本机被忽略的 `tmp`，不要提交或分享私钥。
启动 helper 打印 PID/日志路径，SSH 退出后继续运行，已有 server 时拒绝重复启动。
仅采集停止时直接在页面点“启动”，无需重启 server。

## 板卡重新通电后

当前 SD 仍加载原基线 PL，**相机没有设置开机自动加载**。
先通过上面的 SSH 配置登录，在板端执行：

```sh
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
cd /opt/amazinghand/camera0-linux-hd-20261010
sh /opt/amazinghand/bin/load_z19_camera0.sh \
  /lib/firmware/amazinghand-camera-28e1e3e7-20261010.bin ./ah_camera0.ko
python3 start_preview.py
```

这套加载步骤只用于重启后、当前没有相机 module/采集用户时。
运行中不要再次编程 PL；loader 会检查配套 hash、时钟、PS 接口和占用。
若任何检查失败，保留输出诊断，不跳过保护条件。

## 资料入口

- GitHub 工程/功能与复现入口：[相机交付清单](camera_delivery_20261010.md)。
- 配套 bit/XSA、BD/XDC/IP 和版本限制：[硬件归档](../../fpga/camera_hw/README.md)。
- 源码、编译与生命周期：[camera_linux/README](../../host/camera_linux/README.md)。
- 采集、流畅度、故障测试和限制：[相机验收记录](linux_camera0_bringup.md)。
- 已完成阶段与后续工作：[实施状态](implementation_progress.md)。
- 本机测试原图、raw、JSON 和日志：`F:/Amazing_Hand/tmp/z19-linux-camera-20261010`。
- 板端原始记录：`/var/lib/amazinghand/log`；当前应用包：`/opt/amazinghand/camera0-linux-hd-20261010`。

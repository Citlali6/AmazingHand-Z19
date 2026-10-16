# 已验证 Linux 相机二进制

`capture_camera0` 和 `ah_camera0.ko` 从最终板端高清包读取并再次核对 SHA256，供配套系统复现。
不包含账号、私钥、照片或系统镜像。

| 文件 | 平台 | SHA256 |
|---|---|---|
| `capture_camera0` | AArch64，glibc 2.30，libjpeg-turbo 2.0.3 | `fdb6ed7b6c3fd7961a2e089fff9cd392baae74453d01085a0f292c95874b4ce2` |
| `ah_camera0.ko` | AArch64，Linux 5.4.0-xilinx-v2020.2 | `56bc43d3153ed861a598293ea7d38920806107c1ec8eaac4b70eeb87f62fe368` |

模块仅用于这套内核/配置/硬件 profile；换内核时按上一级 README 重新编译并另行验收。
复制到板端应用目录后为 `capture_camera0` 设置执行权限，勿将文件误当 PC 程序运行。
先执行带保护检查的 loader；运行采集时不能重复加载 PL。
配套源码 hash、测试及限制见 [部署证据](../../../docs/fpga/evidence/2026-10-10/linux-camera-deployment.json)。

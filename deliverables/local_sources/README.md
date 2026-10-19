# 本地未提交工作：迁移快照

三份工作区 ZIP 保存本机原有代码和 Git 差异，另有一份旧 FPGA 生成源码/工程配置归档，用于保留此前工作；**没有把它们混入已验证的运行入口**。

- `rtl-worktree-20261019.zip`：原 RTL 工作区的修改及桥接 wrapper。
- `mjc1-bridge-worktree-20261019.zip`：早期 MJC1 桥接源码。历史默认地址/MMIO 方式不能用于当前 R2 板端运行。
- `camera-mjc1-worktree-20261019.zip`：相机与 MJC1 集成源码，固件/时序仍待完成，不能直接加载。
- `rtl-generated-configs-20261019.zip`：补充核查发现的 586 个旧 FPGA 源码/生成源码、Tcl、BD/XCI/XPR、约束、硬件描述与内存初始化文件，含被旧 `.gitignore` 忽略的项目资料。[压缩包校验记录](legacy-configs-manifest.json)。其中可能保留旧绝对路径、失败实验或供应方代码；保留原许可声明，不作为当前可直接运行的工程或已验证固件。

[清单](snapshots.json) 记录原分支、基线提交、每份源码和 ZIP 的 SHA256。包内有 `source/` 文件快照和 `changes.patch`。查看后在独立分支上选择性恢复，不自动套用到当前分支。

未收录日志、编译检查点、旧失败固件、账号/密钥或系统镜像；必要的旧源码和工程配置已另存上述补充包。已验证固件另见 `deliverables/mjc1_fpd/`。原目录保留原状。

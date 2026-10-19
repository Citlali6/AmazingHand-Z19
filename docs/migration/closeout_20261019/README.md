# Issue #1：Citlali6 迁移收尾证据（2026-10-19）

本轮完成可审查的迁移入口，当前仍 **WAITING FOR HUMAN**。迁移 [Draft PR #2](https://github.com/Citlali6/AmazingHand-Z19/pull/2) 已创建，尚未获得审批/合并；独立文档 PR 依赖它先合入 main。旧成果保持原样，没有重启研发。

## 基线与授权

- 唯一写入目标：`Citlali6/AmazingHand-Z19`；独立副本 `F:/AmazingHand-Z19`。原 `F:/Amazing_Hand` 干净，原工作分支与 origin 均未更改，旧 Tom 仓库只读。
- main：`6b1c90094e9979d1729a331896954a12821c7ae2`；默认/冻结检查点：`feature/migration-ready-20261019`，HEAD `71d8bb14d43c67e63f744f506a972bd4cd769d1a`。
- 迁移差异：ahead 5 / behind 0，434 文件，257520 新增 / 101 删除。五个完整提交见 [commits.log](commits.log)，完整文件统计见 [diff-stat.log](diff-stat.log)。本轮没有向检查点追加提交。
- 已完整阅读 Issue、AGENTS、Git 工作流、README、迁移完整性审计、来源 refs、开发日志、源码快照说明和相关归档；读取三个实际工作分支的源码/审查入口及证据，另用实时只读 API 比较旧 #6/#16/#17/#20、旧 PR #15/#18/#19 的正文/状态/评论，均与已读归档一致。
- main 已在本副本按 ff-only 同步；随后 Citlali6 在当前聊天明确回复“同意从检查点起独立文档分支并创建 Draft PR”。因此仅本轮文档分支 `docs/citlali6-migration-closeout-20261019` 从冻结检查点起步，目标 main，等待迁移先合并。此例外不是后续任务的通用授权。

## 十八条历史分支

保存清单、实时旧 Tom 只读 `ls-remote`、新仓库实时 API 及本轮 fetch 四者 SHA 一致。起点共有 19 分支（18 历史 + 迁移检查点）；随后只新增自己的文档分支。[机器可读对照](ref-comparison.json)、[实时来源 refs](source-live-refs.log)。

| 历史分支 | 完整 SHA | 四方对照 |
|---|---|---|
| `chore/dev-workflow-setup` | `f6b51abe7d0adb92d2e8dc6ab588e9a57d826f92` | 一致 |
| `docs/citlali6-ai-workflow-20261017` | `08a90e64a63665f6736a0bde453f5dcd9fcc48f3` | 一致 |
| `docs/fpga-implementation-roadmap` | `0e2cf0bb7808321bc40825a11080025d06941a98` | 一致 |
| `feat/board-bringup` | `a39ed7f3d92fa7b3b4138478f1e5ed283b21d58a` | 一致 |
| `feat/host-skeleton` | `b6495680b395736da65152693dca0693512bc3e0` | 一致 |
| `feat/scs-protocol-golden-model` | `53369e11af436777f822b3b7f12539195e1c97a2` | 一致 |
| `feature/camera-sd-bringup-20261010` | `40dc3f4c8a48f4b9d6e369c4054b1a1aa12cdf57` | 一致 |
| `feature/citlali6-camera-hil-unified-20261018` | `db7e0f5a9859d11d556e2d7dc9d85d299ccf94ef` | 一致 |
| `feature/citlali6-z19-live-vision-20261018` | `b5706959111d96b8e93d7b65177ca212abb5bde5` | 一致 |
| `feature/host-mujoco-live-20261017` | `583abe105eb2035f3f272556229f66b1530b742f` | 一致 |
| `feature/sim-model-rtl` | `903b46235009e6a7f4a37428ae491dab7f2431e1` | 一致 |
| `feature/usb-voice-foundation-20261018` | `72522e87f7e2a420e95758605790a66acac0bfbb` | 一致 |
| `feature/z19-camera-baremetal` | `eaed60b9539ac460c93c27b7533c1238b85b8b33` | 一致 |
| `feature/z19-mujoco-hil-20261017` | `caa84a5ddb541cd60ebd2e07869b83671ca8a1e2` | 一致 |
| `fix/fpga-xsim-bringup` | `97657ff9361699865269dafba6f506a9610af6cf` | 一致 |
| `fix/host-failsafe-20261017` | `372500a0a4f2069cead464901c3ff713bb43215e` | 一致 |
| `main` | `6b1c90094e9979d1729a331896954a12821c7ae2` | 一致 |
| `plan` | `e625341676c83495b3fb225b31064b3fcf1fbb18` | 一致 |

## 本轮 PC 核查

所有脚本均只做 PC 文件/静态核查。执行命令、退出码、时间戳、日志 hash 见 [commands.json](commands.json)；只读 API 命令见 [live-api-commands.json](live-api-commands.json)。原样执行的脚本保存为 [executed-scripts/](executed-scripts/)，扩展名 `.txt` 表示证据副本；原执行路径为 `F:/AmazingHand-Z19-closeout-20261019/`。不将这些脚本误称为原项目测试。

| 本轮命令 | 退出码 / 实际结果 | 证据 |
|---|---|---|
| `python tools/check_migration.py` | 0；模型 196、离线 ZIP 2、讨论记录 20、源码 ZIP 4、历史配置 586 | [assets.log](assets.log) |
| `git fsck --full` | 0，输出为空 | [fsck.log](fsck.log) |
| `git rev-list --objects --all --missing=print`，并检查 shallow / alternates | 1822 个可达对象，缺失 0、无 shallow/alternates | [extra-checks.json](extra-checks.json) |
| `git bundle verify docs/migration/upstream_archive_20261019_v2/pull-merge-previews.bundle` | 0；3 个预览 ref，前置提交齐备；未应用 bundle | [bundle.log](bundle.log) |
| `python F:/AmazingHand-Z19-closeout-20261019/extra_checks.py` | 0；语音包内部 40 项 SHA、15 wheels；12 个 Python AST；FPGA 52 项归档报告 / 视觉 5 项源码 hash；1283 个候选文本无高置信凭据模式匹配 | [完整静态结果](extra-checks.json) |
| `git diff --check origin/main...origin/feature/migration-ready-20261019` | **2，不通过**；仅模型与只读归档/补丁路径的空白告警 | [告警路径摘要](extra-checks.json)，完整原始日志本地 `F:/AmazingHand-Z19-closeout-20261019/diff-check.log`，SHA256 `a0d18c3ff8dbfad6ff7a40b57a29c3ff36c67f429cd9cb56578bd5d90335932b` |
| `python F:/AmazingHand-Z19-closeout-20261019/capture_live.py` | 首次 1：Windows 默认 GBK 读取 UTF-8 归档失败；显式 UTF-8 后重跑 0，7 条旧记录正文/评论一致 | [最终 API 读取](live-state-v2.log) |

历史迁移的 PC 55 项、MuJoCo GUI / 八执行器加载、旧 Host 55 项及 FPGA / 视觉实板记录均只作历史证据，**本轮未重跑这些功能或 GUI/模型运行测试**。本轮未安装依赖、未运行 Vivado、未连接或操作实板。

### 网络取数的真实边界

完整 clone 直连失败（443 连接失败），代理完整传输也多次 early EOF / TLS 中断。最终使用过滤的 no-checkout clone，只读复用原对象并 `--dissociate`，再从本仓库固定 SHA 的 raw HTTPS 按 Content-Range 分段取数：24 blob、209468554 B、65 段，逐段长度和完整 Git blob SHA 校验后补齐。最后无缺失对象、无原对象目录依赖；没有把过滤克隆的 promisor 机制当成数据已齐的证明。[完整对象 hash](hydrated.json)、[实际 Range 命令及每段 hash](range-downloads.json)。未覆盖非空目标；失败目录由 Git 自身退出清理，没有执行删除/移动用户目录。

### 文件、许可及安全边界

- 检查点 754 个普通文件，337388850 B。最大文件 `deliverables/local_sources/rtl-generated-configs-20261019.zip` 为 67187846 B（约 64.08 MiB）；没有超过 100 MiB 的文件。它超过 [GitHub 50 MiB 告警阈值](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github)，保留既有内容，不重写历史或重新迁 LFS。
- 模型固定来源 `pollen-robotics/AmazingHand@3e8241074df3436a3044ced4881e3bb2133aa725`，196 文件 SHA 全通过；原声明、作者、CC-BY / Apache 文本、供应方 IP 与内核 GPL 声明保持。源码快照含历史失败实验和旧路径，不能视为已验收固件。
- **许可材料缺口待团队审查**：15 wheels 中 14 个含 license/copying/notice 文件；`vosk-0.3.45` wheel 没有独立许可文本，其 metadata `License=UNKNOWN`，只有 Apache classifier。中文模型 README 也没有许可条款；来源 manifest 明确 `publisher_digest_verified=false`。本轮只验证保存内容的 hash，没有独立重验下载来源或认定模型/组合分发许可完备。应在批准分发前确认对应模型/版本授权并补齐适用声明材料，不能用根 Apache 代替。
- 凭据检查只覆盖候选文本和 ZIP 内适量文本的高置信模式，跳过大文件/二进制；未发现匹配不代表完整安全审计。没有发布凭据、用户完整实景照片或新硬件产物。
- `git diff --check` 的归档空白告警保持原样，以免破坏 hash/provenance。自己的文档/工具修正将单独做 diff 检查。

## 实时 GitHub 设置

[API 快照](live-state.json) 于 `2026-10-19T15:26:36Z` 完成（客户端时区同日 23:26）。认证 CLI 的当前用户为 Citlali6；该仓库权限 admin/push 均 true。未用历史 xiaomi 设置记录代替实时核验。

| 项目 | 当前读取结果 |
|---|---|
| Issues | 已启用；当时原生 Issue 只有 #1，另有本轮 PR #2 |
| main | protected=true；至少 1 approval；dismiss_stale_reviews=true；enforce_admins=true |
| 强推 / 删除 / 未解决讨论 | 强推 false；删除 false；必须解决讨论 |
| Code owner / last-push approval | false / false；不额外声称已配置 |
| Rulesets | 空列表；经典 main branch protection 有效；不能把空 rulesets 当成无保护 |
| 状态检查 | 保护回读没有 required_status_checks 配置；PR 当时检查列表为空，不能称 CI 通过 |
| 默认分支 | 仍 feature/migration-ready-20261019；**等待迁移 PR 实际审批合并后，才由 Citlali6 审批管理变更并回读** |
| Fork | true，parent/source 仍 Tom；关系保留，没有解绑或删除 upstream |

已能读取上述配置，故这些字段不需伪装成“待网页确认”；未读取/复制成员授权、Secrets 或集成权限，未来需要时由 Citlali6 另行核实。Fork 允许本仓库管理独立分支/Issue/PR，但仍处于上游网络，不等于所有内容与权限完全隔离；[GitHub 官方说明](https://docs.github.com/en/pull-requests/reference/forks)。本轮不改任何管理设置或旧 Tom 仓库。

## 任务映射草案：未创建新研发 Issue / PR

以下链接均使用新仓库固定提交。新编号暂缺，因为 P1 需等迁移真实合并及 Citlali6 对最少发布入口的确认；不能把旧档案编号当作本仓库原生编号。旧审批不能转移。

| 原 Issue / PR | 保留分支 / HEAD | 新入口与状态 / 证据 |
|---|---|---|
| #17 / PR #18，P0 FPGA | feature/citlali6-camera-hil-unified-20261018 / db7e0f5a9859d11d556e2d7dc9d85d299ccf94ef | 新编号未建；[已建模 timing/CDC 历史结果](https://github.com/Citlali6/AmazingHand-Z19/blob/db7e0f5a9859d11d556e2d7dc9d85d299ccf94ef/fpga/camera_hil/evidence/cdc-2020.1/README.md)。RTSTAT-10、20 input/8 output 外部依据、reset 方法学/完整帧协议、严格打包及同 bit 实板并发未闭环，**UNSAFE / NOT DEPLOYABLE**；只用既有 2020.1，不安装 2020.2、不加载 bit |
| #16 / PR #19，P1 视觉 | feature/citlali6-z19-live-vision-20261018 / b5706959111d96b8e93d7b65177ca212abb5bde5 | 新编号未建；[诊断与同图证据](https://github.com/Citlali6/AmazingHand-Z19/blob/b5706959111d96b8e93d7b65177ca212abb5bde5/host/camera_linux/DIAGNOSTICS.md)。保留 car 历史成功、JPEG/seq/session/TTL；apple 错为 orange、白保温瓶漏检，apple/banana/bottle **NOT VERIFIED**；不运行相机、换模型或训练 |
| #6 / PR #15，Host 兜底 | fix/host-failsafe-20261017 / 372500a0a4f2069cead464901c3ff713bb43215e | 新编号未建；[历史 18+10+27=55 项 PC 与边界](https://github.com/Citlali6/AmazingHand-Z19/blob/372500a0a4f2069cead464901c3ff713bb43215e/docs/fpga/host_failsafe.md)。Linux 信号/物理急停及断力矩未验收；等待新团队审查与集成方案 |
| #20，端到端 | 尚未开工，不创建执行分支 | 新编号未建；只保留 BACKLOG / HOLD；迁移任务不启动、不做实验、不占 Z19 |
| 既往 PR #12/#13/#14 | 已在 main 历史中 | 不重开、不换名重做 |

### 逐文件冲突预检与最小人工集成方案

只把共同修改文件的三个版本导出到独立临时目录，用 `git merge-file --stdout` 检查；**没有执行 git merge/rebase、写分支引用或合并后的测试**。详细退出码见 [integration_preview](extra-checks.json)。

| 分支 | 当前 main | 迁移检查点（预期迁移后 main 的内容） | 最少处理 |
|---|---|---|---|
| Host 兜底 | host/app/main.py；docs/log/2026-10-17.md 均文本冲突 | 相同两文件冲突 | 后续由获授权集成人员保留 MuJoCo 分流、语音基础 sim 限制和资源清理/信号退出语义；合并两段日志，再运行对应 PC 检查；不覆盖整个 main.py |
| FPGA 组合 | 没有共同改动路径 | docs/log/2026-10-18.md 文本冲突 | 保留迁移语音日志、FPGA B 段及之后的视觉 A 段，按任务分节合并，不取一方覆盖 |
| 视觉 | 没有共同改动路径 | docs/log/2026-10-18.md 文本冲突 | 同上；内容可合并不代表应用/硬件集成通过 |

## 最少人工接续

1. 其他队员审查迁移 PR #2，确认资源、许可证材料缺口、归档空白和后续边界；实际 Approve 后由获授权人类决定合并。Codex 不 Approve/merge/auto-merge。
2. 审查本独立文档 PR；它包含五个继承提交和一个收尾提交，目标 main，必须等 #2 先合入。若 #2 用 squash/rebase 使祖先关系不保留，先重新核对文档 PR 差异，由 Citlali6 授权最小后续集成；不强推/重写任何既有分支。
3. 迁移真实合并后，Citlali6 另行审批默认分支切回 main，回读核验，再让各成员自行核对 origin 和 ff-only 同步。
4. Citlali6 确认映射草案及最少新任务/Review 入口后，才发布对应 P1 入口；涉及功能开发、模型或硬件的执行另行授权。端到端继续 HOLD。

Issue #1 保持打开。没有替别人 Approve、合并 PR、启用 auto-merge、删除远端分支、改变真实 FPGA 或旧仓库。

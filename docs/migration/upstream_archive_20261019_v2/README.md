# 原仓库 Issue / PR 只读归档

原仓库改为私有或删除后，可直接在此查阅当时的正文、讨论和评审；原链接保留用于出处。

保存 6 个 Issue、14 个 PR、8 条评论、4 条 Review、0 条行内评审。

完整 JSON、提交列表、变更文件元数据见 `items/`；附件下载结果见 `attachments.json`。

GitHub 的身份、审批效力、通知、星标和关注关系不会通过文件归档重新建立。

| 编号 | 类型 | 状态 | 标题 |
|---|---|---|---|
| #1 | PR | closed | [项目初期计划安排](pages/pr-0001.md) |
| #2 | PR | closed | [SCS 协议 golden model + 虚拟舵机总线 + 冒烟测试](pages/pr-0002.md) |
| #3 | PR | closed | [Host 应用骨架：三后端抽象 + 主状态机 + 抓取策略](pages/pr-0003.md) |
| #4 | PR | closed | [Chore/dev workflow setup](pages/pr-0004.md) |
| #5 | PR | closed | [docs: plan FPGA implementation and October 14 hardware acceptance](pages/pr-0005.md) |
| #6 | Issue | open | [目前代码均通过冒烟测试，还未进行实机测试，并且没有添加兜底机制，若代码出现异常能否正常退出](pages/issue-0006.md) |
| #7 | PR | closed | [数字孪生 + 模型链 + RTL 全套（第 3/4/5 步批量交付）](pages/pr-0007.md) |
| #8 | PR | closed | [Feat/board bringup](pages/pr-0008.md) |
| #9 | PR | closed | [feat(camera): deliver verified Z19 Linux 1080p capture and live preview](pages/pr-0009.md) |
| #10 | Issue | open | [[P0][Codex] 打通 Host → MuJoCo 实时灵巧手控制](pages/issue-0010.md) |
| #11 | Issue | open | [[P0][Codex] Z19 FPGA 控制链构建 + MuJoCo 硬件在环联调](pages/issue-0011.md) |
| #12 | PR | closed | [feat(host): interactive MuJoCo control and evidence (Refs #10)](pages/pr-0012.md) |
| #13 | PR | closed | [feat(fpga): deploy Z19 Linux HIL and verify real MuJoCo loop (Refs #11)](pages/pr-0013.md) |
| #14 | PR | closed | [docs: add Citlali6 personal AI collaboration workflow](pages/pr-0014.md) |
| #15 | PR | open | [fix(host): preserve cleanup on failures and termination (Refs #6)](pages/pr-0015.md) |
| #16 | Issue | open | [[Citlali6][P0][Codex][10-18] Z19 Linux IMX214 实时 AI 识别：苹果/香蕉/瓶子 + 检测框](pages/issue-0016.md) |
| #17 | Issue | open | [[Citlali6][P0][Codex][10-18] 统一 Z19 相机与 HIL PL：同一 bit 实时采集 + MuJoCo 控制](pages/issue-0017.md) |
| #18 | PR | open | [fix(fpga): close CSI CDC and modeled timing; external signoff remains (Refs #17)](pages/pr-0018.md) |
| #19 | PR | open | [feat: Z19 NCNN 实时视觉与原始类别诊断（Citlali6 #16）](pages/pr-0019.md) |
| #20 | Issue | open | [[Citlali6][P1][Codex] 真实视觉识别 → 抓取决策 → Z19 PL → MuJoCo：无人手实物的端到端联动](pages/issue-0020.md) |

## 变更与完整性

14 个 PR 均保存了本地重建的 `changes.patch`，对应页面有下载入口。[Git 历史覆盖核对](git-coverage.json) 确认全部 base/head 已在新仓库保存。

[逐文件校验清单](archive_manifest.json) 用于复核全部原始记录、可读页面与补丁。原 PR 的审批状态保留为历史记录，不作为新仓库的审批。

本次没有可下载附件、Wiki、Discussions、Release、Actions 运行或产物；API 原始结果也已保存。认证凭据和仓库 Secrets 不在归档中。

## GitHub PR 内部引用补充

再次核查保留了全部 17 个 PR 内部引用：[引用清单](pull-refs.json)。14 个 PR head 已在新仓库分支历史中；另将 3 个自动合并预览提交保存为 [增量 Git bundle](pull-merge-previews.bundle)。

预览是 GitHub 为未合并 PR 生成的历史计算结果，不表示已经审批或合并。bundle 的前置提交均在已迁移历史中；在完整 Git 克隆内可用 `git bundle verify` 检查，不自动应用到工作分支。

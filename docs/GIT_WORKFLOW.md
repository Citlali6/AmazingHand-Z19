# AmazingHand 团队 Git 工作流

## 当前工程路线与历史隔离（2026-10-20 生效）

**现行项目是 RoArm-M2-S 桌面机械臂 + Z19 PS/PL + 实验室 USB 摄像头**，十天实物展示优先。正式设计与开发依据：[项目总入口](relaunch_20261020/README.md)、[权威文档与旧路线隔离](relaunch_20261020/DOC_STATUS_AND_RULES.md)、[总控 Issue #6](https://github.com/Citlali6/AmazingHand-Z19/issues/6)。旧可穿戴八舵机、FMC 1.8V/5V 适配、旧队长分工和旧 10-14 时间表为历史，不再依据它们发新的 Codex/采购任务。旧实验结论与负结果仍保留可追溯。

开发优先顺序：#7 RoArm 串口、#8 UVC/标定、#9 PL 授权，之后 #10 真机联调、#11 安全验收；#12 语音 HOLD。两个队员先在总控认领，互不覆盖工作区。文档提到历史 Issue/PR 的旧编号均需映射到新仓库真实任务。**每条 Codex 执行、上板写入、机械臂运动及 PR 合并须具备该轮明确授权**。无硬件证据只能报告代码/仿真通过，不能声称实际 RoArm 或系统已验收。


适用仓库：`Citlali6/AmazingHand-Z19`。所有成员与 Codex 均遵守：
**本期 2026-10-20 用户最终决定：**先完成 PC+RoArm 官方 SDK 和 USB 摄像头的真实抓放演示，FPGA 并行研发不得成为 #10 的前置条件；现行优先级见 [DEMO_FIRST_POLICY.md](relaunch_20261020/DEMO_FIRST_POLICY.md)。历史技术计划不能覆盖该决定。
**最新 main → 独立分支 → 开发与验证 → 提交 → 推送当前分支 → PR → 有写入权限的成员自行决定合并。**

**2026-10-19 仓库所有者决定：**不再强制其他队员 Review / Approve。仓库所有者 Citlali6 具有最终项目管理决策权；拥有 Write/Maintain/Admin 权限的队友也可直接合并 PR（包括自己的 PR），无需额外审批。可自愿 Review，但不得将不存在的审批记作已完成。规则仍须在 GitHub Settings 实际调整后才生效。

## 唯一仓库与防误投规则（2026-10-20 起长期执行）

**唯一允许写入的开发仓库：`Citlali6/AmazingHand-Z19`；默认开发分支：`main`。**
迁移 PR #2、#3 已于 2026-10-20 正式合并，默认分支已恢复为 main。
`feature/migration-ready-20261019` 只作为历史迁移检查点保留，不再作为新任务起点。

**旧 `Tom-mr33/AmazingHand-based-on-FPGA` 永久只读。** 只能查阅历史 Issue、PR、提交和实验记录；
禁止向旧仓库创建/编辑/评论/关闭/标记 Issue 或 PR，禁止 Push、Merge、标签、Release、修改权限/设置，
也不能在那里部署或执行新的 Codex 任务。即使旧任务链接、迁移档案或历史指令指向 Tom 仓库，
仍必须先映射到此新仓库的实际 Issue/PR，再继续；不得对旧链接执行写操作。

**每次发 GitHub 任务、执行 Codex 或 Git 写操作前必须校验目标。**
工具调用的 repository 必须显式为 `Citlali6/AmazingHand-Z19`；本地先核对：

```sh
git remote get-url origin
git branch --show-current
git status
```

`origin` 必须准确指向新仓库的 HTTPS 或 SSH 地址；如不符或无法判定，立刻停止，
保留现有工作区并报告，不自动重写其他人的 remote，也不借助重定向向旧仓库写入。
若配置了 `upstream` 指向原 Tom 仓库，仅允许 fetch/读取。
任何旧编号（例如旧 Issue #16/#17/#20、PR #18/#19）只用作历史溯源；
在新仓库继续执行时应引用新编号，不能误认为原生迁移了旧评论或审批。

正常开发继续：同步最新 `main` → 独立工作分支 → 必要测试 → 当前仓库 PR →
有写权限成员自行决定是否合并。**不强制其他成员 Approve**；
但不改变不直接推送 main、不强推、不删分支、不过度声称硬件验收的规则。
Codex 只有收到 Citlali6 当轮明确授权才能提交、推送、创建或合并 PR。
旧仓库贡献归属和历史 URL 在归档中保留，不做机械替换。

## 1. 首次获取项目

先检查目标目录；只在目录不存在或为空时 clone，非空目录不得删除、覆盖或移动。

```powershell
git clone https://github.com/Citlali6/AmazingHand-Z19.git F:\AmazingHand-Z19
Set-Location F:\AmazingHand-Z19
git status
git remote -v
git branch -a
```

origin 必须是 `https://github.com/Citlali6/AmazingHand-Z19.git`。
认证失败时完成自己的 GitHub 身份认证，不更换地址、不借用他人的 Token。

本规范文件经过 PR 合并后，每位队员在各自 clone 中执行：

```sh
git branch --show-current
git config --local core.hooksPath .githooks
git config --get core.hooksPath
```

最后一条应输出 `.githooks`。此设置不会随 clone 自动继承，也不会修改全局配置。
在 Linux/macOS 上还需确认 hook 有执行权限，必要时在工作分支执行
`chmod +x .githooks/pre-push`。脚本使用 LF、无 BOM，兼容 Windows Git Bash。

### 当前 Windows 主机的代理

浏览器的系统代理不等于 Git 已配置代理。此次恢复下载使用系统现有 HTTP 代理
`http://127.0.0.1:7897`；仅当前仓库保存了 `http.proxy`，没有更改全局 Git 配置。
该地址是本机配置，不要求其他成员照抄。代理软件必须运行；更换端口时先核实，
再在确认当前分支后更新当前仓库配置。不要在命令、日志或文档中写入代理密码或 Token。

首次 clone 如需代理，可使用仅本次命令生效的配置（端口须以自己的配置为准）：

```powershell
git -c http.proxy=http://127.0.0.1:7897 clone https://github.com/Citlali6/AmazingHand-Z19.git F:\AmazingHand-Z19
```

## 2. 每次开始工作

先查看现有状态；有未提交改动时保留现场，不直接切换 main，不自动 stash、提交或丢弃。
确认工作区干净后执行：

```sh
git status
git branch --show-current
git checkout main
git branch --show-current
git pull --ff-only origin main
```

必须使用 `--ff-only`。如果失败、分叉或无法快进，停止并完整报告，不自行 merge、
rebase、reset。每次 Git 写操作之前都必须确认当前分支。

## 3. 创建工作分支

从刚同步的 main 创建一个分支，例如：

```sh
git branch --show-current
git checkout -b feature/servo-calibration
git branch --show-current
```

命名使用 `feature/<功能名称>`、`fix/<问题名称>`、`docs/<文档名称>` 或
`chore/<维护名称>`，建议用英文短横线命名。确认已离开 main 后才能编辑文件。
本次规范建立分支为 `chore/dev-workflow-setup`。

## 4. 开发

修改前执行 `git status`、`git branch --show-current`，阅读已有实现、`AGENTS.md`
与相关设计文档，说明修改目的，只做当前任务范围内的改动。结构、接口、代码和参数
变更记入当日 `docs/log/`。不要盲改 Vivado/Vitis 生成文件，不误忽略源码、XDC、TCL、
BD、IP 或关键配置，不擅自删除硬件工程文件。

## 5. 本地检查与提交

运行项目已有且适用于改动的测试、仿真或构建；没有可执行检查时说明原因，不声称通过。
提交前检查所有改动和未跟踪文件，排除临时产物与密钥：

```sh
git status
git branch --show-current
git diff
# 下面的路径仅是示例；逐项替换为本次审核过的真实文件。
git add docs/GIT_WORKFLOW.md
git diff --cached
git branch --show-current
git commit -m "docs: document team git workflow"
```

功能提交可以使用 `feat: xxx`，修复使用 `fix: xxx`，维护使用 `chore: xxx`。
优先 `git add <明确的文件>`，不要无脑 `git add .`。
**Codex 只有获得用户当前任务的明确提交授权后才能执行 add/commit；本规范本身不构成授权。**

## 6. 只推送当前工作分支

推送前检查分支、状态、origin、hook 配置及将推送的提交。首次推送可查看相对 main
的提交；已有上游时查看相对该上游的未推送提交：

```sh
git branch --show-current
git status
git remote -v
git config --get core.hooksPath
git log --oneline origin/main..HEAD
# 已有上游时可用：git log --oneline "@{upstream}..HEAD"
```

只有当前确实位于示例分支时才执行以下命令；使用自己的真实分支名替换示例：

```sh
git branch --show-current
git push -u origin feature/servo-calibration
```

**Codex 只有获得用户当前任务的明确推送授权后才能 push；本规范本身不构成授权。**
不推送其他分支，不使用 `--all`、`--mirror`、`--no-verify` 或绕过 hook 的配置。

## 7. Pull Request、Review 与合并

1. 在 GitHub 创建 PR：base 为 `main`，compare 为自己的工作分支。
2. 说明问题、改动、验证结果、限制及相关硬件影响。
3. 自己检查 diff、冲突状态、合适的自动/手工测试证据及安全边界；必要时可邀请队友自愿 Review。
4. **不强制其他队员 Approve**；不要求 PR 作者以外的人审批。
5. Citlali6 或具有 Write/Maintain/Admin 权限的协作者可按自己的职责决定直接合并 PR；无需额外审批。其他人的 Issue/PR 不得被无关任务擅自改写。
6. Codex 仅在 Citlali6 当前任务明确授权时可执行 PR merge/auto-merge；不得伪造 Review、绕过 GitHub 当前规则、强推或自动删除远端分支。

仅在用户当前任务明确授权的范围内创建 PR；本规范本身不构成授权。

## 8. 合并后与下一项任务

确认本地改动已妥善处理，再同步 main，然后为新任务创建新分支：

```sh
git status
git branch --show-current
git checkout main
git branch --show-current
git pull --ff-only origin main
git branch --show-current
git checkout -b feature/next-task
```

不要继续在已经合并的旧分支上开发新功能；Codex 不自行删除远程分支。

## 9. 明确禁止的操作

禁止直接推送 main，包括：

```sh
git push origin main
git push --force origin main
git push origin HEAD:main
```

禁止直接在 main 开发、提交或绕过 PR。独立 Approve 并非强制条件；应遵守当前 GitHub 实际保护规则。
未经明确授权，不执行 `git reset --hard`、`git clean -fd`、`git clean -fdx`、
`git push --force`、`git push --force-with-lease`、rebase 后强推等破坏历史或现场的操作。

## 10. 本地 hook 与 GitHub 保护

`.githooks/pre-push` 检查推送输入的**远程目标 ref**，任何指向 `refs/heads/main`
的更新均拒绝，包含从别的分支推往 main 以及删除 main。正常工作分支可以通过此项检查。
拒绝时提示：

```text
ERROR: Direct push to main is forbidden.
Please push a feature branch and create a Pull Request.
```

不要为了测试而真正向 main push。检查脚本内容、LF 格式、shell 语法和
`core.hooksPath` 即可。

本地 hook 只防误操作，不能强制其他 clone 或 GitHub 网页上的 Review。建议仓库
管理员按所有者的新策略配置 main 的分支保护或 Ruleset：使用 PR 合并、**不强制 Approve（0 required approvals）**、禁止
强推及删除；有 Write/Maintain/Admin 权限的成员可直接合并 PR。远程规则需以当前账号的实际 API 回读或网页核验为准；本规范不授权修改 GitHub 设置。

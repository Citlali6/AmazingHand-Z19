# Host 异常退出兜底（Issue #6）

2026-10-17 从 `ee52f09` 开始，在 `fix/host-failsafe-20261017` 实现。
对应队长发起、指派给 Citlali6 和 Tom-mr33 的
[Issue #6](https://github.com/Tom-mr33/AmazingHand-based-on-FPGA/issues/6)。
本次完成软件资源清理路径；Issue 的实机验收仍待完成。

## 行为

- 用 `with backend:` 管理生命周期。正常结束或主流程抛异常，均先尝试
  `emergency_stop()`，再尝试 `close()`。急停失败不能跳过关闭。
- `open()` 中途失败也会尝试 `close()`；初始化错误原样向上传播。
- 清理报错写入 stderr 日志，保留主流程原始异常。主流程正常而清理失败时抛出错误，
  CLI 返回失败，不能把未确认的硬件停止报告为成功。
- FPGA 后端急停出错后仍尝试关闭 mmap 和 fd；mmap 创建失败关闭已获取的 fd，
  mmap 关闭失败也继续尝试关闭 fd。串口关闭后清除对象引用，重复关闭不重用旧句柄。
- 串口增加与配置响应超时相同的 `write_timeout`，使写入超时可以进入错误处理。
- CLI 在主线程临时处理 SIGINT/SIGTERM，让 Python 栈展开经过后端清理；
  首次信号后忽略重复的这两类信号，退出时恢复原处理器。
  普通异常退出码 1，Ctrl+C 为 130，SIGTERM 为 143；参数解析仍沿用 argparse。

`run(deps)` 本身不拥有资源。直接调用的工具或测试仍需在外层使用
`with deps.backend:`；显式调用 `open()` 的调用方应自行保证 `finally: close()`。
本次没有修改抓取状态机、PS/PL 字段、RTL、传感器参数或已验证相机服务。

## PC 验证

```powershell
python host/tests/smoke_test_failsafe.py
python host/tests/smoke_test_backend.py
python host/tests/smoke_test_control.py
```

2026-10-17，Windows / Python 3.13.5：18 + 10 + 27 = **55 项通过**。
新增测试使用模拟总线和替代串口/寄存器对象，不打开实际设备：

- 主循环 tick、语音、目标检测、引导、策略选择、开始抓取、状态回读、释放抛异常；
- 正常结束及抓取中达到循环上限后关闭力矩；
- 初始化失败、急停失败、关闭失败及多个错误同时出现，保留最初错误；
- CLI 错误退出码、运行中/关闭中信号回调栈展开、清理及信号处理器恢复；
- 串口错误后的关闭、mmap 失败后 fd 清理、FPGA 初始化/急停错误后的资源释放。

Windows 信号测试直接调用已安装的 Python 回调；没有声称完成 Linux 进程信号投递实测。

## 后续验收与边界

当前板端 Python 3.7 与 Host 代码所需环境不匹配；真实主流程仍用 MockVision，
PS/PL 还有基地址配置、estop 位、角度 ABI 等已知冲突（见
[实施状态](implementation_progress.md)）。因此不能直接把当前控制程序部署为整手控制。

先解决接口/协议、标定和运行环境，再在隔离的单舵机场景验收：

1. 分别在抓取、保持、释放时注入输入/通信异常，检查原错误、非零退出和资源释放。
2. 在 Linux 投递 SIGINT/SIGTERM，记录退出耗时与实测断力矩结果；检查退出后能重新打开设备。
3. 断开通信，确认软件没有把“尝试急停”记录成实物已停止，使用独立硬件保护完成处置。
4. 完成全状态语音停止、保持/释放故障检测和超时检查，再进入整手联调。

SIGKILL、进程崩溃、断电、底层 I/O 永久阻塞无法靠 Python 栈清理兜底。
`write_timeout` 不构成 `flush()`、驱动或 AXI 访问的总耗时保证；异常发生时也可能只有部分
舵机收到断力矩请求。本次没有实现独立 watchdog 或验证物理急停，不据此关闭 Issue #6。

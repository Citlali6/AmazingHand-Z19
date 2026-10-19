> [!CAUTION]
> **2026-10-20 路线变更标识｜历史资料，非当前任务说明。** 该旧 SCS 八舵机接口草案未冻结成当前 RoArm ABI；现行控制合同仍需在新仓库 #9 依据真实 MJC1 源码审计和仿真建立。
> **当前主线：** [RoArm-M2-S + Z19 十天交付](../relaunch_20261020/README.md) · [当前架构/ABI 草案](../relaunch_20261020/SYSTEM_ARCHITECTURE.md) · [项目总控 #6](https://github.com/Citlali6/AmazingHand-Z19/issues/6)。以下原文保留用于审计和历史追溯；不要按其中的旧截止日期、人员分工和旧电气方案启动 Codex 或现场接线。

---

# PS↔PL 接口 v0.3 修订草案

状态：**待双方评审的设计提案，尚未实现，尚未替代 v0.2.x**。
日期：2026-10-05。冻结建议期限：10-08前。
本文件具体偏移便于评审，但不能直接让现有 `FpgaBackend` 访问按本草案构建的硬件。
双方冻结后应更新 `docs/design/interface.md`、Host、RTL、TB、配置和当日日志，并统一提升版本。

## 1. 为什么需要一次明确的不兼容迁移

现有Host目标是相对机械中位的有符号角度，v0.2只定义12位无符号0.1°；`-35°`经当前截位变成3746，若按无符号解码为374.6°。
预张目标没有寄存器；速度raw为16位而TIMING只传8位；错误位图、反馈标志和时间戳未统一；直接模式逐寄存器修改可能跨周期撕裂。
把旧字段悄悄换含义会使旧Host驱动错误动作，因此需要版本检查和整体迁移。

推荐候选：**PS完成机械角度→原始位置的标定换算，PL接收raw位置并再次检查安全raw范围**。
这样不用在PL内实现浮点/除法或含糊的有符号角度换算；PS仍给上层提供degrees接口。
协议字节序由SCS模块按已核验的舵机类型处理，与AXI32位寄存器的小端Host访问分开。
Host负责左右手、中位、方向和非线性校准；PL不猜测默认中位或将越界数值取模。
若双方选择保留角度编码，需另行定义有符号范围、偏置、饱和与标定查表，不能继续沿用当前截位。

## 2. 总线与访问规则

- AXI4-Lite 32位，字节寻址；基地址由实际BD导出并同步Host/设备树，`0x40000000`仅旧配置占位。
- 下表offset均相对实际基地址；32位对齐访问，LOAD两路打包到一字，支持Host按对齐32位读再截取。
- RO不能写，保留位写0；未知地址、非法命令/参数返回确定的SLVERR和全局原因码，不导致总线挂起。
- WSTRB逐字节合并；要求完整字段的提交/命令寄存器仅接受完整32位写，部分写返回SLVERR；普通影子参数允许部分写，提交时统一验证。
- 上电控制禁用、plan_valid=0；首次使能须已加载全部必需行程/阈值等字段，不能依赖未初始化RAM。
- 所有运动参数为shadow；提交时整体校验/锁存active并给ACK；急停、heartbeat和安全卸力为即时高优先级路径。
- 一个执行上下文，第一版不设计深命令队列；并发Host访问需应用锁。CMD busy时拒绝重复提交，不覆盖正在处理的命令。
- CMD接收busy与机械动作STATUS.busy分开；动作期间仍可请求快照，急停/卸力可抢占，不能因机械busy拒绝所有诊断。
- RESET/身份码等值在冻结时产生，版本字段未一致则Host禁止使能。

## 3. 控制与配置区（候选偏移）

| offset | 名称 | 权限/字段 | 候选语义 |
|---|---|---|---|
| 0x00 | CTRL | RW：[0]enable，[1]mode，[2]estop | mode=0直接目标，1抓取FSM；estop置1立即锁存保护，写0不清保护 |
| 0x04 | CMD | WO：[7:0]cmd，[15:8]arg | 见命令表；完成写握手只表示命令已接收，不表示动作完成 |
| 0x08 | ABI_VERSION | RO：major/minor | 0.3草案定稿后编码；Host匹配检查 |
| 0x0C | FEATURES | RO | 声明是否有快照/IRQ/时间记录等，未支持功能不可盲读 |
| 0x10+i×4 | TARGET_i | RW：[15:0]pos_raw，[23:16]id | i=0..7；固定顺序/唯一ID；在安全raw范围内 |
| 0x30 | TORQUE_LIM | RW：每4位一个等级 | 保留上层策略等级，仅元数据；不能直接当舵机寄存器或物理力矩 |
| 0x34 | TIMING | RW：[15:0]speed_raw，[31:16]period_us | 保留完整16位速度；周期单位1µs，500Hz候选2000；提交前预算检查 |
| 0x38 | HEARTBEAT | WO：任意完整32位序号 | 只有实际应用写才刷新看门狗，普通访问不刷新 |
| 0x3C | WATCHDOG_US | RW：32位超时 | 使能时必须为经过评审的非零值；不能使能后写0禁用保护 |
| 0x40 | IRQ_MASK | RW：原因位mask | 第一版轮询可全0；不影响保护本身 |
| 0x44 | IRQ_STATUS | RO/W1C：sticky原因 | 新事件优先于清除；触发至PS的电平IRQ |
| 0x48 | ACTION_TIMEOUT_US | RW：32位 | 第一版统一阶段上限；PREGRASP/CLOSING/RELEASING都必须有界 |
| 0x4C | MAX_FEEDBACK_AGE_US | RW：32位 | 使用反馈前检查；需≥计划最坏轮询年龄且满足安全要求 |
| 0x50 | REQUIRED_MASK | RW：[7:0] | 到位必需通道；第一版整手建议0xFF，不能配置为空 |
| 0x54 | CONTACT_POLICY | RW：[7:0]contact_mask，[15:8]consecutive_samples | 接触必需通道和连续样本数；第一版采用mask内全满足的候选规则，机械可行性待队长确认 |
| 0x58 | CMD_SEQ | RW：32位 | PS提交前写递增序号；禁止复用上一次序号进行运动 |
| 0x5C | CMD_ACK_SEQ | RO：32位 | PL接受或拒绝后更新；搭配结果码读取，不当作机械动作完成 |

是否增加逐通道速度、预张/释放独立速度和分别阶段超时，第一版评审时决定。
第一版若使用统一速度/超时，必须选队长确认的最保守组合，报告不能说已实现逐通道自适应速度。
`TORQUE_LIM`的等级应由PS按固定校准表转成 `LOAD_THRESH_i`，两者同时归档；不承诺写入舵机内部力矩限制。

## 4. 状态与诊断区（候选偏移）

| offset | 名称 | 权限/字段 | 说明 |
|---|---|---|---|
| 0x80 | STATUS | RO：[0]busy，[1]grasped，[2]timeout，[3]fault，[4]plan_valid，[5]snapshot_valid | busy仅指PREGRASP/CLOSING/RELEASING；fault另看，PROTECT不报动作busy |
| 0x84 | FSM_STATE | RO：[7:0] | 沿用IDLE0/PREGRASP1/CLOSING2/HOLD3/RELEASING4/PROTECT5 |
| 0x88 | CONTACT_BITMAP | RO：[7:0] | 当前计划锁存的接触通道，不等同于错误 |
| 0x8C | VALID_BITMAP | RO：[7:0] | 本次快照有效且足够新鲜的数据，初始为0 |
| 0x90+i×4 | MEAS_i | RO：[15:0]pos_raw，[23:16]flags，[31:24]id | i=0..7；保留真实raw，不冒充degree |
| 0xB0+i×2 | LOAD_i | RO：16位 | 原始反馈负载编码；Host按确认协议解码，不将方向位当阈值 |
| 0xC0 | CMD_RESULT | RO：结果码 | 0无结果、1接受、2拒绝配置、3拒绝状态、4重复序号，候选枚举 |
| 0xC4 | OVERRUN_COUNT | RO：32位 | 固定时隙超限次数，第一版验收正常运行应为0 |
| 0xC8 | RX_ERROR_COUNT | RO：32位 | 校验/长度/帧错误总计，细分可放调试区 |
| 0xCC | RX_TIMEOUT_COUNT | RO：32位 | 事务截止，包含无响应/半帧；不与错误位图混用 |
| 0xD0 | TEMP | RO：[7:0]channel_index，[15:8]max_temp_c | index为0..7，不是servo ID；仅有效反馈，全部无效由VALID_BITMAP表达 |
| 0xD4 | SNAP_TIME_LO | RO：32位 | 原子快照的64位1µs时间戳低字 |
| 0xD8 | SNAP_TIME_HI | RO：32位 | 同一快照高字；不能独立读取自由计数高/低造成撕裂 |
| 0xDC | CYCLE_SEQ | RO：32位 | 控制周期完成计数，回绕；不能单独用于P99抖动 |
| 0xE0 | ERR_BITMAP | RO：[23:0] | 每通道3位：bit(3i)=过载，bit(3i+1)=掉线/过期，bit(3i+2)=过温 |
| 0xE4 | SNAP_SEQ | RO：32位 | 原子快照序号，获取新快照后递增 |
| 0xE8 | FAULT_CODE | RO：全局枚举 | 急停/看门狗/配置/调度等，不能塞进8通道错误布局 |
| 0xEC | CYCLE_INTERVAL_US | RO：32位 | 最近一个周期起点差；供单次诊断，长时P99需记录流 |
| 0xF0 | TIMESTAMP | RO：低32位1µs时间 | 明确单位；约71.6分钟回绕，差值按uint32处理 |
| 0xF4 | CYCLE_MIN_US | RO：32位 | 观测窗口内最小周期；需明确定义清零时机 |
| 0xF8 | CYCLE_MAX_US | RO：32位 | 观测窗口内最大周期 |
| 0xFC | EVENT_SEQ | RO：32位 | 保护/动作事件序号，关联ILA与PS日志 |

MEAS.flags候选：bit0 invalid/过期，bit1 overload，bit2 overheat，bit3协议错误；其余保留。
ERR_BITMAP为锁存故障；VALID与flags反映当时数据有效性，两者恢复规则不同。
SCS原始ERROR字段需独立记录或映射到详细诊断，不能丢弃未知报警位后仍当反馈正常。
本表是可实现的最小诊断提案，最终计数器/快照区边界须在RTL实现前统一。

## 5. 扩展参数区（候选偏移）

| offset | 名称 | 字段 | 说明 |
|---|---|---|---|
| 0x100+i×4 | PREGRASP_i | [15:0]pos_raw | 8路预张/第一版释放目标；默认值无效，必须来自标定 |
| 0x120+i×4 | LOAD_THRESH_i | [15:0]load_magnitude_limit | 非零有效阈值，含义是接触门限，不是过载报警的替代 |
| 0x140+i×4 | POS_LIMIT_i | [15:0]min_raw，[31:16]max_raw | 8路机械安全范围；min<max；所有目标须在区间内 |
| 0x160+i×4 | FEEDBACK_AGE_i | RO：32位µs | 每路last_good年龄，失效不返回0；未采样可饱和为全1 |
| 0x180/0x184 | TEMP_PACKED_0/1 | RO：每字4路温度字节 | 配合VALID_BITMAP使用，避免非最高温通道假0°C |
| 0x188/0x18C | VOLT_PACKED_0/1 | RO：每字4路电压字节 | 单位由已核验舵机反馈定义，不预设模型值 |
| 0x190 | RX_START_TIMEOUT_US | RW：32位 | 请求尾到首字节上限，测量后定值 |
| 0x194 | RX_INTERBYTE_TIMEOUT_US | RW：32位 | 包内字节间等待上限 |
| 0x198 | RX_TRANSACTION_TIMEOUT_US | RW：32位 | 完整请求/响应事务期限，定义起点并纳入时隙预算 |
| 0x19C | TURNAROUND_US | RW：32位 | 主机方向切换与恢复窗口基准，实际需双方时序允许 |
| 0x1A0 | TEMP_LIMITS | RW：[7:0]warn_c，[15:8]trip_c | 必须来自真实型号额定值/标定安全边界，不能用模拟温度常数 |

上述空间最多0x1A4字节，现有一页映射容量可容纳，但必须按系统页对齐的实际物理基地址正确mmap。
当前 `AxilRegs.open()` 对非页对齐base的处理需另修，不能以容量够为理由跳过地址验证。
预张与释放共用位置是第一版简化；若安全释放与预张不同，冻结前增加独立释放数组。

## 6. 命令表与恢复语义

| cmd | 含义 | 候选条件/效果 |
|---|---|---|
| 0x01 | START_GRASP | IDLE、enable、mode=1、反馈新鲜、全计划合法；提交并进入PREGRASP |
| 0x02 | RELEASE | CLOSING/HOLD允许，使用active预张/释放目标；进入RELEASING |
| 0x03 | PREGRASP_ONLY | IDLE、enable、计划合法且反馈新鲜时执行预张；到位返回IDLE，不能默认继续闭合 |
| 0x04 | SET_TORQUE | arg=1使能、0卸力；线上实际写值由W1核验；卸力可抢占普通动作 |
| 0x05 | COMMIT_DIRECT | mode=0、状态允许；原子锁存8路目标与速度，不立即跨帧修改payload |
| 0x06 | SNAPSHOT | 在有界时间锁存一致反馈/状态/时间；ACK且SNAP_SEQ更新后读快照 |
| 0x07 | CLEAR_FAULT | enable=0、输入急停已解除、无活动故障且反馈重新验证；只回禁用IDLE |
| 0x10 | HOME | **第一版保留且返回不支持**；没有标定HOME数组不能擅自回中 |

CLEAR_FAULT不自动使能；使能也不自动发送运动目标。ESTOP与卸力不被普通命令队列busy阻挡。
RELEASE/卸力/HOME不能混为同一动作；释放是受控张开，卸力是关闭舵机驱动，HOME需机械定义。
PREGRASP_ONLY完成后返回IDLE，动作到位和抓住物体分开表示。
CMD0x02如被用于中止闭合，需保持轨迹安全；保护锁存时拒绝释放运动，除非另有双方批准的受限恢复流程。

## 7. Host施工顺序

1. 在enable=0状态读ABI_VERSION/FEATURES，检查实际base、器件bit版本；不匹配即停止。
2. 加载队长提供的机械标定、ID顺序和安全范围，PS换算目标raw并预检查；PL再次检查。
3. 写完整影子参数、时序与看门狗；后台定期heartbeat，周期与超时关系经批准。
4. 获取有效反馈，确认所有必需通道在线且年龄合格；初次联调用只读/PING验证。
5. 写CMD_SEQ，发合法使能/提交命令，读CMD_ACK_SEQ和CMD_RESULT；必要时平台适配层执行IO顺序保证/读回。
6. 动作期间只读受控快照/IRQ与日志；重配置需新的原子提交，不直接改active。
7. 结束/异常：走明确安全处置；clear_fault须现场确认后再执行，不能只清UI状态。

示例逻辑仅作调用约定，暂不提供可直接驱动实物的脚本：

```text
read ABI -> validate calibration -> write shadow -> get fresh feedback
-> write CMD_SEQ -> write START_GRASP -> wait ACK / inspect RESULT
-> request SNAPSHOT -> wait new SNAP_SEQ -> read coherent state
-> RELEASE -> confirmed release -> disable / safe exit
```

现有backend_fpga未传pregrasp、仅8位speed且先enable再逐目标写；需要整体适配。
现有sim/serial的timeout/grasped/保护与帧序列也需对齐，接口相同不表示实现已经等价。

使能前检查完整shadow配置，运动提交后形成active；从未提交过有效计划时不得用旧active或默认目标开始运动。
CTRL.enable清0应禁止继续提交运动并触发已冻结的安全处置；使能上升沿不自动执行上一次目标。温度/时序/阈值配置需验证且在明确边界原子生效。
首版冻结还须补全IRQ_STATUS原因位、全局FAULT_CODE枚举、配置生效/清计数规则、卸力抢占响应和快照ACK顺序。
连续性能记录流的FIFO深度、读取/清空地址与drop计数尚未定义，不能把诊断寄存器表当作已具备长时P99采集。

## 8. 冻结与一致性审查表

- [ ] 硬件基地址、时钟/复位来源、period和两个READ最坏预算已签收。
- [ ] 位置raw/字节序、ID顺序、方向/中位和机械限位有实机依据。
- [ ] 速度单位、速度0含义与首版允许范围已确认。
- [ ] 负载门限、过载/过温、接触组合和反馈年龄有明确来源。
- [ ] 卸力码、物理急停、PS失效和总线故障处置已验证。
- [ ] ACK、序号、原子提交、snapshot、IRQ和错误写入行为TB可测。
- [ ] Host、RTL、TB、文档和配置同一版本；旧Host拒绝新bit，新Host拒绝旧bit。
- [ ] v0.3冻结后更新唯一接口文件及日志，本提案标注已被哪个版本替代。

这些勾选项目前全部未完成；本轮没有冻结或实现该接口。

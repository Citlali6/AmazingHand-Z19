# Z19 ↔ MuJoCo HIL 现场操作清单

**状态：本清单尚未执行；本轮没有接线、拨码、上电、下载bit、改SD或验证实板HIL。**
适用独立 `hand_control` 工程，不适用相机平台上的原地覆盖，不用于驱动真实舵机。

1. **保留已有成果。** 保持 Linux SD、相机启动包、bit/XSA、原 BD/XDC/IP 和已有SHA256归档原样；
   手控制构建和部署使用独立输出/独立启动介质或经人工确认的临时JTAG环境。本轮没有生成兼容新XSA的Linux启动包。
2. **用户核对硬件。** 确认铭牌ALINX Z19、XCZU19EG及板卡版本；断电时检查板卡原配供电、散热和网口。
   本HIL没有物理舵机输出，真实机械手不供电、不接入本测试链路。
3. **FMC与电平。** 纯HIL不使用FMC、SCS DATA或电平转换模块，保持它们与手控制试验隔离。
   不把1.8V FMC接到5V舵机。将来真实舵机联调另按已审核引脚、电平、外部供电和急停方案执行。
4. **连接PC。** 用户接板卡PS UART调试线（核对本次实际COM/tty，勿沿用历史COM7假设）、网线；
   临时JTAG路线再接JTAG线。记录当前启动拨码；本轮未核对当前拨码，**不要凭通用Zynq位置更改**。
   选择JTAG/SD的具体开关组合由用户按该板版本Z19手册实物核对后记录。
5. **匹配平台再启动。** 先核对构建日志、bit/XSA哈希和时钟；用独立XSA派生匹配的PS初始化/FSBL及系统。
   不能直接把新bit加载到仍启用相机VDMA/CSI驱动的旧Linux上；旧设备树的PL外设和地址不再有效。
   若选Linux路线，需先准备匹配XSA且不探测相机PL节点的独立系统；若选JTAG路线，
   先核对该平台PS初始化与OS接管方式。**这些部署步骤尚未实测，不提供猜测的下载命令。**
6. **上电后只读核验。** 记录UART启动日志、PS时钟、Linux版本、IP与/dev/mem权限；确认AHIL schema1
   位于0x80000000，且相机驱动不会访问已移除的PL。未匹配则不启动控制服务。
7. **启动软件。** 板端运行README的 `python3 .../hil_server.py --bind <板IP> --port 8765`；
   PC使用集成Issue #10的 `python host/app/main.py --mujoco --hil <板IP>:8765`。
   首次连入必须PROTECT/torque off；按客户端显式reset后再发open。
8. **动作证据。** 记录 open → grasp → HOLD → release，MuJoCo关节实时变化；同时保存每帧
   `seq/accepted_seq/feedback_seq/pl_tick/command_count/feedback_count/target_raw/position_raw/load_raw`。
   确认HOLD目标来自MuJoCo反馈，release目标来自PL预张快照；PS源码没有生成动画。
9. **单独验证停止。** 运动中STOP后观察torque=false/PROTECT，旧目标不再施加；再次grasp被锁存阻止；
   reset后torque仍off，只有新的动作才能启动。分别断网、结束PS服务和模拟online_mask缺一通道，
   记录PL保护结果和不超过500ms看门狗边界；需要复位时保持仿真执行器禁用。
10. **收尾。** 停止PC和板端服务，保存操作/遥测日志与现场拨码记录；临时JTAG恢复按已记录方案执行。
    没完成第5—9项前，Issue #11维持未验收，不能把XSim或工具生成bit写成硬件HIL成功。

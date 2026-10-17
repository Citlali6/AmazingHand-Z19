# Issue #11 XSim / Vivado 构建证据

这些文件从最终构建 `F:/ah-hil-build-20261017/vivado_run04` 和
`F:/ah-hil-build-20261017/sim_final` 原样归档，`manifest.json` 记录每份原文件的路径、大小和SHA256。
本轮已再次核对 `evidence.json` 中所有构建输入/产物的实际哈希，并解包核对XSA内部bit一致性；
没有重复执行昂贵的综合/实现。
本目录 `.gitattributes` 保留原始报告的换行和工具输出空白，确保远端blob仍可按manifest核验。

- 四份 `tb_*.txt`：XSim 2020.1 的实际PASS输出。
- `synthesis.txt` / `implementation.txt`：原 `runme.log` 的字节副本，改用可入库的明确文本归档名；
  保留实际警告，不是生成缓存或新编造的摘要。
- `timing_impl.rpt` / `drc_impl.rpt` / `utilization_synth.rpt`：最终工具原始报告。
- `evidence.json`：工具、器件、有效时钟、源码/产物SHA256、时序、DRC及未上板标记。
- `transport-tests.txt`：本轮执行的4项Python桥检查输出，普通文件mmap/socketpair不是硬件。

最终时序：WNS +6.113ns / TNS0，WHS +0.003ns / THS0；DRC违规0。
目标 `xczu19eg-ffvc1760-2-i`，Vivado2020.1，有效PL时钟96968727Hz。

## 产物发布状态

**本PR不发布bit/XSA本体，也不包含Vivado缓存。** 它们仍保存在：

- bit：`F:/ah-hil-build-20261017/vivado_run04/hand_hil.runs/impl_1/hand_hil_bd_wrapper.bit`
  （36343237B），SHA256 `9a7e402793947ed641e274ba5b1dfc003770d3106a1c1db2e893b68bcb281d01`。
- XSA：`F:/ah-hil-build-20261017/vivado_run04/hand_hil.xsa`（915720B），
  SHA256 `63e6a81b2a93558b4a9f575ed2234883fb2be7d70d86662fdb32c69128414871`。

上述本地路径不是远程下载链接。其他成员按 [构建入口](../../README.md) 在新目录重建，
重新生成bit可能因工具/环境差异而哈希不同。原相机bit/XSA、BD/XDC/IP和SD未修改。

**真实Z19↔MuJoCo HIL未执行**；尚缺匹配新XSA的板端运行环境及现场操作。
部署与验收统一见 [现场清单](../../FIELD_CHECKLIST.md)。

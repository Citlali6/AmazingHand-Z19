# sim/ah_model — 官方 MuJoCo 手部模型（引用不复制）

上游模型位于 [`../../AmazingHand/Demo/AHSimulation/`](../../AmazingHand/Demo/AHSimulation/)：

```
AmazingHand/Demo/AHSimulation/
├── AHSimulation/AH_Right/mjcf/scene.xml   # 右手场景（本项目主用）
├── AHSimulation/AH_Left/mjcf/scene.xml    # 左手
└── pyproject.toml                          # 上游依赖（mink/dora——本项目不引入）
```

**单一事实源原则**：模型与 STL 资产不复制进本目录，`sim/verify_grasp.py`
直接引用上游相对路径（仓库内随 Git 分发）。理由：

1. 上游许可 Apache-2.0（代码）/CC-BY 4.0（机械），引用保持归属清晰；
2. 避免大体积 STL 双份入库；
3. 上游模型更新时 `git pull` 即同步。

模型要点（已核对 `joints_properties.xml` / `robot.xml`）：

- 8 个 **position 执行器** `finger{1..4}_motor{1,2}`，顺序与舵机 ID 1-8
  （食/中/无名/拇指 × 屈曲/外展）一一对应；
- 关节行程 ±90°（`range="-1.5708 1.5708"`），并联指骨联动由 `equality/connect` 表达；
- 指尖 site：`tip1..tip4`（FK 读取点）；
- 执行器默认类 `mjcf`：`kp=10, forcerange=±10`（理想执行器，非 SCS0009 真实参数——
  抓取力分析仅供定性参考，见 verify_grasp 输出的 caveat）。

本项目**不改上游 XML**（"引入不改"）。若需加物体/传感器，在 `sim/` 内用
MuJoCo Python API 程序化扩展或另存派生 XML 并注明来源。

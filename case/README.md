# OpenFOAM 12 旋转圆球流-固耦合传热算例模板

这个算例用于 **OpenFOAM v12**，目标是模拟（按你要求先采用层流/DNS思路，不启用 RANS 湍流模型）：
- 外部流体绕流；
- 实心圆球内部导热；
- 流固界面的共轭传热（CHT）；
- 圆球表面切向速度表示自转效应。

> 说明：这里的“流固耦合传热”按 CHT（流体+固体能量方程耦合）实现；
> 不包含结构变形求解。如果你后续要做真实 FSI（形变+热耦合），建议在此模板基础上接 preCICE + 结构求解器。

## 求解器

- `chtMultiRegionFoam`
- 流动模型：`laminar`（不启用湍流模型）

## 区域划分

- `fluid`：外部空气区域
- `solid`：球体实体区域

通过 `snappyHexMesh` 生成球体 `cellZone`，再用 `splitMeshRegions -cellZones` 切分区域网格。

## 运行方式

```bash
cd case
./Allrun
```

## 典型可调参数

1. 球半径、计算域尺寸：`system/blockMeshDict`, `system/snappyHexMeshDict`
2. 转速：`0/fluid/U` 中 `omega`（rad/s）
3. 来流速度与温度：`0/fluid/U`, `0/fluid/T`
4. 固体初始温度：`0/solid/T`
5. 材料属性：`constant/fluid/thermophysicalProperties`, `constant/solid/thermophysicalProperties`


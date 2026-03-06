# OpenFOAM 12 旋转圆球流-固耦合传热算例模板

这个算例用于 **OpenFOAM v12**，目标是模拟（按你要求采用不可压缩 + 层流/DNS 思路）：
- 外部流体绕流；
- 实心圆球内部导热；
- 流固界面的共轭传热（CHT）；
- 圆球表面切向速度表示自转效应。

> 说明：这里的“流固耦合传热”按 CHT（流体+固体能量方程耦合）实现；
> 不包含结构变形求解。如果你后续要做真实 FSI（形变+热耦合），建议在此模板基础上接 preCICE + 结构求解器。

## 求解器

- `chtMultiRegionFoam`
- 流动模型：`laminar`（不启用湍流模型）
- 密度模型：`rhoConst`（常密度，不可压缩近似）

## 区域划分

几何文件位置：`constant/triSurface/rotatingSphere.stl`（供 `snappyHexMesh` 读取）。

- `fluid`：外部空气区域
- `solid`：球体实体区域

通过 `snappyHexMesh` 生成球体 `cellZone`，再用 `splitMeshRegions -cellZones` 切分区域网格。

## 运行方式

```bash
cd case
./Allrun
```

`Allrun` 已按 OpenFOAM `RunFunctions` 风格改写：
- 首次运行自动执行网格、区域切分、初始化、`decomposePar -allRegions`；
- 后续若存在 `log.decomposePar`，会跳过预处理直接并行求解；
- 初始场由 `0.orig` 自动恢复到 `0`，便于重复计算。
- `setFields` 仅对 `solid` 执行（`setFields -region solid`），避免在 `fluid` 上触发 `cannot find file "points" in directory "fluid/polyMesh"`；
- 即使有 `log.decomposePar`，若检测到 `polyMesh/points` 缺失也会自动重建，避免 `cannot find file "points" in directory "fluid/polyMesh"`。
- 多区域 `setFields -region solid` 会读取 `system/solid/setFieldsDict`；该文件已提供。
- `0/solid/T` 与 `0.orig/solid/T` 同时提供 `solid_to_fluid` 和 `solid_to_region1` 边界项，兼容 `splitMeshRegions` 不同命名结果。
- 已补充并修正 `constant/fluid/physicalProperties`（包含 `thermoType`/`mixture`），避免求解器报 `cannot find file .../physicalProperties` 或 `keyword thermoType is undefined`。
- `0/fluid/*` 与 `0.orig/fluid/*` 同时提供 `fluid_to_solid`、`region1_to_solid` 和 `fluid_to_region1` 边界项，兼容 `splitMeshRegions` 的不同命名。
- 已为 `0/*` 与 `0.orig/*` 增加 `"procBoundary.*"`（并保留 `"proBoundary.*"`）`type processor` 通配边界，兼容 `procBoundary0to1/1to0/2to0/...` 等命名。
- 已补充 `0/fluid/p` 与 `0.orig/fluid/p`，避免并行后报 `cannot find file .../processor0/0/fluid/p`。
- `system/controlDict` 已包含 `regionSolvers`，避免 `decomposePar` 报 `keyword regionSolvers is undefined`。
- 已补充 `system/fluid/{fvSchemes,fvSolution}` 与 `system/solid/{fvSchemes,fvSolution}`，避免求解器报 `cannot find file case/system/<region>/fvSchemes`。
- `controlDict/regionSolvers` 需使用 primitive 写法：`fluid fluid; solid solid;`（不是子字典，也不是 `chtMultiRegionFoam`），可避免 IO/FATAL 与 `solvers table is empty`。
- `splitMeshRegions` 若把外部区域命名成 `region0/region1/...`，`Allrun` 会自动识别并映射为 `fluid`，避免 `decomposePar` 报 `cannot find file "points" in directory "fluid/polyMesh"`。
- `Allrun` 在 region 映射时仅移动 `polyMesh` 到 `constant/fluid/polyMesh`，不会覆盖 `constant/fluid/physicalProperties` 等物性字典。

- 固体 `thermoType` 使用 OF12 支持组合：`transport constIsoSolid` + `thermo eConst` + `energy sensibleInternalEnergy`（不是 `constIso`/`hConst`/`sensibleEnthalpy`），避免 `Unknown transport type constIso`、`Unknown thermo type hConst` 与 `Unknown energy type sensibleEnthalpy`。


## 提交前自检（减少反复迭代）

新增 `Allcheck`，用于在运行 `Allrun` 前快速检查常见缺文件/配置不兼容问题：

```bash
./Allcheck
```

它会重点检查：
- `system/fluid`、`system/solid` 的 region 级 `fvSchemes/fvSolution` 是否齐全；
- `regionSolvers` 是否是 OF12 兼容写法（`fluid fluid;`、`solid solid;`）；
- 固体热物性是否为 OF12 兼容组合（`constIsoSolid + eConst + sensibleInternalEnergy`）；
- `0/` 与 `0.orig/` 关键初值文件和并行 `procBoundary.*` 通配边界是否存在。
- 若已存在 `processor*` 目录，会额外检查 `processor*/0/solid/T` 中是否有显式 `procBoundaryXtoY` 条目（避免并行启动时报 `Cannot find patchField entry for procBoundary...`）。

## 典型可调参数

1. 球半径、计算域尺寸：`system/blockMeshDict`, `system/snappyHexMeshDict`
2. 转速：`0/fluid/U` 中 `omega`（rad/s）
3. 来流速度、温度与压力：`0/fluid/U`, `0/fluid/T`, `0/fluid/p`
4. 固体初始温度：`0/solid/T`
5. 材料属性与常密度设置：`constant/fluid/thermophysicalProperties`, `constant/fluid/physicalProperties`, `constant/solid/thermophysicalProperties`


- `Allrun` 现已直接使用 `runParallel foamMultiRun`（不再调用 `chtMultiRegionFoam` 包装入口），避免重复 superseded 提示。
- `system/fluid/fvSchemes` 已显式补充 `div(phi,K)`，避免启动后报 `Cannot find scheme for div(phi,K)`。

- `splitMeshRegions` 后若目录被映射为 `fluid`，`Allrun` 会同步把 `polyMesh/boundary` 中残留的 `sampleRegion/neighbourRegion/nbrRegion region1` 重写为 `fluid`，避免 `request for fvMesh region1` 报错。

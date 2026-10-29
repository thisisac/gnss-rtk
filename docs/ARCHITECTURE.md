# RTK Architecture / RTK 程序架构

## 1. Scope / 范围

This document explains the RTK pipeline implemented by the supplied source tree. It distinguishes the active `rtkpos()` path from the older `RTKEKF.cpp` path that is retained for reference.

本文档以当前源码为准，区分实际由 `main.cpp` 调用的 `rtkpos()` 路径和保留用于研究的旧版 `RTKEKF.cpp` 路径。

## 2. End-to-End Pipeline / 端到端流程

```text
Base input + Rover input
        |
        v
SynRTKObs() / SynRTKObs_Sock()
        |
        v
time-matched RAWDATA
        |
        +--> Base OEM7 decode --> Base SPP --> ResB
        |
        +--> Rover OEM7 decode -> Rover SPP -> ResR
        |
        v
GF/MW outlier and continuity checks
        |
        v
single-difference / double-difference construction
        |
        +--> rtkpos_lsq()
        |
        +--> rtkpos_ekf()
        |
        v
float state -> ambiguity validation/fixing -> FIX or FLOAT
        |
        v
RTKRES + write2rtkplot() + console/log output
```

中文概括：

```text
基准站与流动站输入 -> 历元同步 -> 两站解码和 SPP 初值
-> GF/MW 粗差探测 -> 单差/双差构造
-> LSQ 或 EKF -> 浮点解与模糊度固定
-> FIX/FLOAT 状态、基线和精度输出
```

## 3. Input and Synchronization / 输入与同步

`SynRTKObs` reads two binary files and `SynRTKObs_Sock` reads two sockets. Both paths try to pair Base and Rover epochs by GPS time. `syn_tol` controls the accepted time difference. A failed synchronization does not enter the RTK estimator.

`SynRTKObs` 读取两个二进制文件，`SynRTKObs_Sock` 读取两个 Socket。两条路径都按 GPS 时间配对基准站和流动站历元，`syn_tol` 控制允许的时间差。同步失败时不会进入 RTK 解算器。

The synchronized record is stored in `RAWDATA`, which contains the two epoch observations plus single-difference and double-difference working structures. `SD_EPOCHOBSDATA` stores satellite-level single-difference records, and `DD_OBSDATA` stores reference-satellite indices, double-difference observations, ambiguity count, ratio, and baseline information.

同步后的数据保存在 `RAWDATA` 中，其中包含两站历元观测以及单差、双差工作结构。`SD_EPOCHOBSDATA` 保存卫星级单差数据，`DD_OBSDATA` 保存参考星索引、双差观测值、模糊度数量、ratio 和基线信息。

## 4. SPP Initialization / SPP 初值

Before RTK differencing, the Base and Rover measurements are decoded and solved independently by the shared SPP functions. This provides approximate station coordinates, satellite PVT, and the geometry required by the differential model.

构造差分观测前，基准站和流动站分别使用共享的 SPP 函数解码和定位，得到测站近似坐标、卫星 PVT 以及差分模型所需的几何信息。

## 5. Outlier Detection / 粗差探测

The detector uses the Melbourne-Wübbena combination for code/carrier consistency and the Geometry-Free combination for carrier-phase behavior. It keeps per-satellite history across continuous epochs. A time gap, missing dual-frequency observation, or threshold violation clears the corresponding continuity state.

粗差探测使用 Melbourne-Wübbena 组合检查码观测与载波观测的一致性，使用 Geometry-Free 组合检查载波相位变化。模块按卫星保存连续历元历史；出现时间间隔过大、缺少双频观测或超过阈值时清理相应连续性状态。

## 6. Differential Observation Model / 差分观测模型

The implementation selects reference satellites independently for GPS and BDS when possible. It then forms single and double differences, which reduce common satellite and receiver errors. Carrier-phase ambiguities remain as integer state variables.

程序尽可能分别为 GPS 和 BDS 选择参考卫星，再构造单差和双差观测，以削弱卫星钟差、接收机钟差等公共误差。载波相位模糊度作为整数状态保留。

For stations `b` (base) and `r` (rover), a single difference removes much of the satellite-common error:

```text
SD = observation_rover - observation_base
```

For rover satellite `s` and reference satellite `q`, the double difference is:

```text
DD(s,q) = SD(s) - SD(q)
```

The carrier-phase DD retains an integer ambiguity term. The code stores the satellite/reference mapping in `DD_OBSDATA` so the estimator and ambiguity fixer use the same state ordering.

对基准站 `b` 和流动站 `r`，单差可写为：

```text
SD = 流动站观测值 - 基准站观测值
```

对流动站卫星 `s` 和参考卫星 `q`，双差可写为：

```text
DD(s,q) = SD(s) - SD(q)
```

载波相位双差仍包含整数模糊度。程序将卫星与参考星的对应关系保存在 `DD_OBSDATA` 中，使差分解算和模糊度固定使用一致的状态顺序。

The resulting `DD_OBSDATA` is consumed by the LSQ or EKF path. The baseline vector is derived from rover and base positions and is written together with the solution quality.

## 7. LSQ Path / 最小二乘路径

`rtkpos_lsq()` solves the differential model directly for the current synchronized epoch. It produces float parameters, covariance information, ambiguity candidates, a ratio value, and a fixed solution when validation succeeds.

`rtkpos_lsq()` 对当前同步历元直接求解差分模型，生成浮点参数、协方差信息、模糊度候选值和 ratio；通过验证后输出固定解。

## 8. EKF Path / 卡尔曼滤波路径

`rtkpos_ekf()` maintains position and ambiguity states across epochs. The filter path uses process-noise settings such as `pos_Q` and `amb_Q`, performs time and measurement updates, and can call ambiguity fixing after the measurement update.

`rtkpos_ekf()` 在历元之间维护位置和模糊度状态。滤波路径使用 `pos_Q`、`amb_Q` 等过程噪声参数，执行时间更新和量测更新，并可在量测更新后进行模糊度固定。

The separate `RTKEKF.cpp` file contains an older EKF framework with symbols such as `RTKMainEKF`, `RTKTimeUpdate`, and `RTKMeasUpdate`. It includes headers not supplied in this repository, so it should be treated as historical/reference code until those dependencies are restored.

单独的 `RTKEKF.cpp` 包含旧版 EKF 框架，例如 `RTKMainEKF`、`RTKTimeUpdate` 和 `RTKMeasUpdate`。它引用当前仓库未提供的头文件，因此在补齐依赖前应视为历史/参考代码。

The outlier stage uses the two combinations below as continuity indicators:

```text
MW = (f1*phi1 - f2*phi2)/(f1-f2)
     - (f1*P1 + f2*P2)/(f1+f2)

GF = phi1 - (f1/f2)*phi2
```

这里 `P1/P2` 是双频伪距，`phi1/phi2` 是双频载波相位，`f1/f2` 是对应频率。程序将当前值与历史记录比较，超过 `dMWLimit` 或 `dGFLimit` 时清除该卫星的连续性状态。

## 9. Ambiguity Fixing and Quality / 模糊度固定与质量指标

`lambda.cpp` contains the integer ambiguity reduction/search routines used by the fixing stage. The ratio is compared with `ratio_threshold`; the result state is represented as FIX or FLOAT in the output records.

`lambda.cpp` 提供固定阶段使用的整数模糊度降相关和搜索流程。ratio 与 `ratio_threshold` 比较，最终状态在结果中表示为 FIX 或 FLOAT。

`RTKRES` stores position uncertainty and covariance-related values. `write2rtkplot()` converts ECEF covariance to ENU form and writes time, latitude, longitude, height, quality flag, satellite count, standard deviations, ratio, and baseline length.

`RTKRES` 保存位置不确定度和协方差相关结果。`write2rtkplot()` 将 ECEF 协方差转换到 ENU，并输出时间、纬度、经度、高程、质量标志、卫星数、标准差、ratio 和基线长度。

## 10. Known Build Boundaries / 构建边界

1. The active entry point is `src/main.cpp`; it calls `load_rtk_config()`, `rtkpos()`, and `write2rtkplot()`.
2. `RTKstructs.cpp` is the main current implementation for synchronization and RTK solving.
3. `RTKEKF.cpp` is retained but has missing `Structs.h` and `vector_matrix.h` dependencies.
4. The code is Windows/MSVC-specific and needs Winsock.
5. No original Base/Rover binary files are distributed.

1. 当前入口是 `src/main.cpp`，它调用 `load_rtk_config()`、`rtkpos()` 和 `write2rtkplot()`。
2. 当前同步和 RTK 解算主体位于 `RTKstructs.cpp`。
3. `RTKEKF.cpp` 仍被保留，但缺少 `Structs.h` 和 `vector_matrix.h`。
4. 代码面向 Windows/MSVC，并需要 Winsock。
5. 原始基准站/流动站二进制数据未发布。

# GNSS RTK / 双频 GNSS 实时动态定位

一个在 SPP 基础上开发的双频 GPS/BDS 实时动态定位（Real-Time Kinematic, RTK）程序。项目包含基准站/流动站同步、粗差探测、单差与双差观测值、浮点解、模糊度固定、LSQ/EKF 处理路径以及结果绘图材料。

This repository contains a dual-frequency GPS/BDS Real-Time Kinematic (RTK) program developed on top of the SPP project. It includes base/rover synchronization, outlier detection, single- and double-difference observations, float solutions, ambiguity fixing, LSQ/EKF processing paths, and result-analysis materials.

## 1. 项目能力 / Capabilities

### 中文

- 从本地文件或 Windows Socket 接收两路 NovAtel OEM7 数据；
- 对基准站和流动站观测历元进行时间同步；
- 调用 SPP 为两站提供位置初值；
- 使用 GF/MW 组合进行连续性检查和粗差剔除；
- 选择参考卫星并构造单差、双差伪距和载波相位观测值；
- 使用最小二乘（LSQ）或扩展卡尔曼滤波（EKF）进行 RTK 解算；
- 使用 LAMBDA 相关流程进行整数模糊度固定；
- 根据 ratio threshold 输出 FIX 或 FLOAT 状态；
- 输出基线向量、基准站/流动站位置、卫星数量、ratio、协方差和精度；
- 生成与 RTKLIB `rtkplot` 兼容的文本结果，并提供 LSQ/EKF 实验图表。

### English

- Receive two NovAtel OEM7 streams from local files or Windows sockets;
- Synchronize base-station and rover epochs by GPS time;
- Run SPP to obtain initial positions for both stations;
- Detect discontinuities and outliers with GF/MW combinations;
- Select reference satellites and build single- and double-difference pseudorange/carrier-phase observations;
- Solve RTK with either least squares (LSQ) or an extended Kalman filter (EKF);
- Apply the LAMBDA-related integer ambiguity-fixing path;
- Classify solutions as FIX or FLOAT using the configured ratio threshold;
- Export baseline, base/rover positions, satellite counts, ratio, covariance, and quality indicators;
- Generate RTKLIB-`rtkplot` compatible output and provide LSQ/EKF analysis artifacts.

## 2. 总体架构 / System Architecture

```text
Base file/socket                  Rover file/socket
       |                                  |
       +------------> SynRTKObs* <--------+
                         |
                         v
                 RAWDATA / epochs
                         |
             +-----------+-----------+
             |                       |
             v                       v
          Base SPP                Rover SPP
             |                       |
             +-----------+-----------+
                         |
                 SD/ DD construction
             reference satellite selection
                         |
                 +-------+-------+
                 |               |
                 v               v
              rtkpos_lsq()   rtkpos_ekf()
                 |               |
                 +-------+-------+
                         |
                 float / LAMBDA fix
                         |
                         v
                 RtkResult / RTKRES
                         |
                         v
             write2rtkplot() + log output
```

The code is divided into the following layers:

| 模块 / Module | 主要职责 / Responsibility |
|---|---|
| `main.cpp` | Loads configuration, opens Base/Rover sources, selects file or Socket mode, runs the epoch loop, and prints status. |
| `Config.cpp` | Parses `rtk.conf`, stores processing parameters, writes RTKLIB-compatible headers, and formats solution records. |
| `RTKstructs.cpp` | Synchronizes observations, performs SPP initialization, builds SD/DD measurements, runs LSQ/EKF dispatch, and manages RTK solution state. |
| `RTKEKF.cpp` | Contains an older EKF implementation and an alternate processing entry path retained from the course materials. |
| `lambda.cpp` | Provides the integer ambiguity search/reduction routines used by ambiguity fixing. |
| `SatEphCalculate.cpp` | Shared satellite PVT, observation decoding, corrections, and SPP functions inherited from the SPP project. |
| `CoordConvert.cpp` / `TimeConvert.cpp` | Shared coordinate and time transformations. |
| `Matrix.h` / `Martix.cpp` | Matrix operations for LSQ, covariance, and filter updates. |
| `rtklib.h` | Shared RTK/SPP types, configuration, constants, and function declarations. |

详细设计见 [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) / See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the detailed design.

## 3. 配置接口 / Configuration Interface

程序启动时读取工作目录下的 `rtk.conf`；不存在时使用 `src/rtklib.h` 中的默认值。可复制 `rtk.conf.example`：

At startup, the program reads `rtk.conf` from the working directory. If it is absent, defaults in `src/rtklib.h` are used. Start from `rtk.conf.example`:

```ini
sigP=0.3
sigL=0.01
pos_Q=25
amb_Q=1e-10
base_file=data/base.bin
rover_file=data/rover.bin
output_file=results/rtk_result.txt
isPort=1
rtk_mode=2
syn_tol=0.10
ratio_threshold=3.0
elev_threshold=10.0
```

| 参数 / Parameter | 含义 / Meaning |
|---|---|
| `sigP` | Pseudorange standard deviation used in stochastic modeling. |
| `sigL` | Carrier-phase standard deviation used in stochastic modeling. |
| `pos_Q` | Position-process noise for the filter path. |
| `amb_Q` | Ambiguity-process noise for the filter path. |
| `base_file`, `rover_file` | Base and rover OEM7 binary input files. |
| `output_file` | Main RTK result file. |
| `isPort` | `1` for file input, `2` for Socket input. |
| `rtk_mode` | `1` for EKF, `2` for LSQ. |
| `syn_tol` | Base/rover time-synchronization tolerance in seconds. |
| `ratio_threshold` | Minimum ambiguity ratio for a FIX decision. |
| `elev_threshold` | Elevation mask for reference/usable satellites. |

## 4. 算法流程 / Algorithmic Flow

### 中文

1. `SynRTKObs` 或 `SynRTKObs_Sock` 从 Base/Rover 两路输入取得可配对历元；
2. 两站分别解码观测、星历并调用 SPP 得到初始位置；
3. `OutlierDetector` 根据 GF/MW 历史记录检查连续性和异常观测；
4. 选择 GPS/BDS 参考卫星，构造单差和双差观测；
5. `rtk_mode=2` 时进入 LSQ；`rtk_mode=1` 时进入 EKF；
6. 根据浮点解和协方差执行模糊度固定，计算 ratio；
7. 生成基线向量、FIX/FLOAT 状态和 `rtkplot` 兼容结果。

### English

1. `SynRTKObs` or `SynRTKObs_Sock` obtains a time-matched epoch from Base and Rover;
2. Both stations decode observations/ephemerides and run SPP for initial positions;
3. `OutlierDetector` checks continuity and abnormal measurements using GF/MW history;
4. GPS/BDS reference satellites are selected and SD/DD observations are formed;
5. `rtk_mode=2` enters LSQ; `rtk_mode=1` enters EKF;
6. Ambiguities are validated/fixed from the float solution and covariance, producing a ratio;
7. Baseline, FIX/FLOAT status, and RTKLIB-compatible output are generated.

## 5. 安装 / Installation

本项目没有预编译安装包。安装方式是克隆仓库、准备 Visual Studio/MSVC 和 Windows SDK，然后按下面的构建说明建立本地程序。

There is no prebuilt installer. Clone the repository, install Visual Studio/MSVC and the Windows SDK, then follow the build instructions below.

## 6. 构建 / Build

源码面向 Windows/MSVC，使用 `windows.h`、Winsock 和 `fopen_s`。建议使用 Visual Studio 2019 或更高版本、C++17，并链接 `Ws2_32.lib`。

The source targets Windows/MSVC and uses `windows.h`, Winsock, and `fopen_s`. Use Visual Studio 2019 or later with C++17 and link `Ws2_32.lib`.

## 7. 使用 / Usage

1. Copy `rtk.conf.example` to `rtk.conf`.
2. Set authorized Base/Rover input paths and choose file mode with `isPort=1`.
3. Select `rtk_mode=2` for LSQ or `rtk_mode=1` for the available EKF path.
4. Build and run from the directory containing `rtk.conf`.
5. Inspect `output_file`, console FIX/FLOAT status, ratio, and baseline length.

中文步骤：复制配置模板、填写基准站和流动站文件路径、选择 LSQ/EKF 模式、在包含 `rtk.conf` 的工作目录运行，并检查输出文件和 FIX/FLOAT 结果。

## 8. 已知限制 / Known Limitations

材料目录中的 `src/RTKEKF.cpp` 是较早的 EKF 实现，它引用当前材料中没有提供的 `Structs.h` 和 `vector_matrix.h`。当前 `main.cpp` 主要通过 `RTKstructs.cpp` 中的 `rtkpos()` 路径处理，因此不能声称旧版 `RTKEKF.cpp` 在当前仓库中可以直接单独编译。

`src/RTKEKF.cpp` is an older EKF implementation that includes `Structs.h` and `vector_matrix.h`, neither of which is present in the supplied materials. The current `main.cpp` primarily uses the `rtkpos()` path in `RTKstructs.cpp`; therefore the older EKF file is preserved for study but is not claimed to compile independently from this repository.

其他限制 / Other limitations:

- 原始 Base/Rover 二进制数据未发布；
- Socket 地址仍需在代码或配置中替换为用户自己的数据源；
- 没有跨平台构建系统和自动化数值回归测试；
- 报告中的厘米级结果依赖特定数据、基线、参考坐标和参数；
- Some experiment outputs are archived results rather than guaranteed reference outputs.

## 9. 报告与结果 / Reports and Results

- `docs/RTK-course-report.pdf`：RTK 算法和程序设计报告；
- `docs/SPP-background-report.pdf`：RTK 所依赖的 SPP 报告；
- `docs/Run-guide.pdf`：原始运行说明；
- `results/LSQ/`、`results/EKF/`：不同处理路径和数据集的结果；
- `results/**/myRTKDRAW.m`：MATLAB 绘图脚本。

The same materials are retained for English-speaking readers; the original reports are Chinese course documents, while this repository documentation is bilingual.

## 10. 许可证 / License

MIT License，详见 [`LICENSE`](LICENSE)。发布前请将版权主体替换为你的姓名或组织，并确认报告、图片、数据和第三方代码拥有公开许可。

MIT License. See [`LICENSE`](LICENSE). Replace the copyright holder before publication and confirm that reports, figures, data, and third-party code are redistributable.

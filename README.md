# GNSS RTK

一个基于 C++ 的双频 GPS/BDS 实时动态定位（Real-Time Kinematic, RTK）程序。
该项目在 SPP 基础上增加了基准站/流动站同步、单差/双差观测值、浮点解、模糊度固定以及 LSQ/EKF 处理流程。

## 功能

- 从本地文件或网络 Socket 接收 NovAtel OEM7 数据；
- 同步基准站（Base）和流动站（Rover）观测历元；
- 使用 Geometry-Free 和 Melbourne-Wübbena 组合进行粗差检测；
- 先进行 SPP 初值解算，再构造单差和双差观测值；
- 支持 LSQ 和 EKF 两种 RTK 处理路径（由配置选择）；
- 使用 LAMBDA 相关流程进行整数模糊度固定；
- 输出 FIX/FLOAT 状态、ratio、基线向量和精度统计量；
- 提供 MATLAB 绘图脚本和课程实验结果。

## 目录

```text
src/       C++ 源码
results/   示例结果、绘图脚本和实验输出
docs/      RTK 报告、SPP 背景报告和运行说明
```

## 配置

程序启动时读取工作目录下的 `rtk.conf`；不存在时使用 `src/rtklib.h` 中的默认值。可从下面的模板开始：

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

`isPort=1` 表示文件输入，`isPort=2` 表示 Socket 输入；`rtk_mode=1` 选择 EKF，`rtk_mode=2` 选择 LSQ。Socket 地址仍在 `src/main.cpp` 中配置，发布前请替换为自己的数据源。

## 构建状态

源码面向 Windows/MSVC，使用 Winsock、`windows.h` 和 `fopen_s`。建议在 Visual Studio 中以 C++17 或更高标准建立项目，并链接 `Ws2_32.lib`。

材料目录中的 `src/RTKEKF.cpp` 是一份较早的 EKF 实现，引用了当前材料中没有提供的 `Structs.h` 和 `vector_matrix.h`。因此本仓库完整保留该文件供研究，但不能声称它在当前材料下可以直接编译。当前 `main.cpp` 使用的是 `RTKstructs.cpp` 中的 `rtkpos()` 路径；若要启用旧版 EKF 文件，请补齐这两个头文件并重新整理接口。

## 结果与报告

- `docs/RTK-course-report.pdf`：RTK 程序设计、算法和结果分析报告；
- `docs/SPP-background-report.pdf`：RTK 所依赖的 SPP 背景实现报告；
- `docs/Run-guide.pdf`：原始运行说明；
- `results/`：LSQ/EKF、不同数据集和绘图脚本的实验产物。

报告中的厘米级精度、固定率和误差统计与特定观测文件、基准站坐标及配置有关，不应解释为对任意数据集的保证。原始 GNSS 二进制数据未包含在仓库中，请仅使用有权处理的数据。

## 许可证

仓库附带 MIT License 模板。正式公开前，请将 `LICENSE` 中的版权主体替换为你的姓名或组织，并确认报告图片、第三方算法实现和数据均具备公开许可。

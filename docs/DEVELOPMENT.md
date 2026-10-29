# Development / 开发说明

## 中文

开发环境建议为 Windows 10/11、Visual Studio 2019 或更高版本、C++17 和 MATLAB（仅用于绘图）。将 `src/` 文件加入 Visual Studio 项目，链接 `Ws2_32.lib`。先使用 `isPort=1` 文件模式验证 Base/Rover 历元同步，再尝试 Socket 模式。调试时记录 `rtk_mode`、`ratio_threshold`、参考卫星、FIX/FLOAT 状态和基线结果。

当前没有自动化单元测试或数值回归测试；旧版 `RTKEKF.cpp` 还缺少 `Structs.h` 和 `vector_matrix.h`。

## English

The recommended environment is Windows 10/11, Visual Studio 2019 or later, C++17, and MATLAB for plotting. Add the files under `src/` to a Visual Studio project and link `Ws2_32.lib`. Validate Base/Rover epoch synchronization in file mode (`isPort=1`) before trying Socket mode. Record `rtk_mode`, `ratio_threshold`, reference satellites, FIX/FLOAT status, and baseline results while debugging.

There is no automated unit-test or numerical-regression suite yet. The older `RTKEKF.cpp` path also requires the missing `Structs.h` and `vector_matrix.h` headers.

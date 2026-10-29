# 复现实验说明

1. 在 Visual Studio 中建立 C++17 项目并加入 `src/` 中的源文件，链接 `Ws2_32.lib`。
2. 将 `rtk.conf.example` 复制为工作目录下的 `rtk.conf`，填入有权限使用的 Base/Rover OEM7 二进制文件路径。
3. 先使用 `isPort=1` 文件模式验证解码和同步，再根据需要配置 Socket 模式。
4. 检查 `output_file` 指定的结果文件，再用 `results/` 下的 MATLAB 脚本绘图。

个人课程报告未随仓库发布。当前材料没有提供原始输入数据，也缺少 `RTKEKF.cpp` 所引用的两个旧版头文件，因此不能在此环境中声称历史结果可以完整复现。

# Contributing / 参与贡献

## 中文

欢迎围绕 OEM7 解码、Base/Rover 同步、差分观测、LSQ、EKF、模糊度固定、结果分析和文档提交改进。

1. 先搜索已有 issue，避免重复工作。
2. 对新功能或 bug 修复创建独立分支，例如 `feature/reference-satellite` 或 `fix/epoch-sync`。
3. 保持修改聚焦，不要在同一个 PR 中混入无关格式化。
4. 更新与配置、算法或输出格式相关的 README 或 `docs/` 文档。
5. 提交 PR 时说明 Base/Rover 数据格式、参数、运行模式、测试环境和 FIX/FLOAT 结果。
6. 不要提交原始 GNSS 数据、密钥、私有 Socket 地址或未经授权的第三方材料。

当前仓库没有完整的自动化构建和数值回归测试；请在 Windows/MSVC 环境中记录手工验证步骤，并明确旧版 `RTKEKF.cpp` 依赖缺失的影响。

## English

Contributions are welcome for OEM7 decoding, Base/Rover synchronization, differential observations, LSQ, EKF, ambiguity fixing, result analysis, and documentation.

1. Search existing issues before starting duplicate work.
2. Create a focused branch such as `feature/reference-satellite` or `fix/epoch-sync`.
3. Keep each pull request focused and avoid unrelated formatting changes.
4. Update the README or `docs/` when configuration, algorithms, or output formats change.
5. Describe Base/Rover format, parameters, processing mode, test environment, and FIX/FLOAT results in the pull request.
6. Never commit raw GNSS data, credentials, private Socket endpoints, or unlicensed third-party material.

The repository does not yet provide a complete automated build or numerical regression suite. Record manual Windows/MSVC verification and clearly state the impact of the missing dependencies in the older `RTKEKF.cpp` path.

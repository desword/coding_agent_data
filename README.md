# Codex 多 Agent 通信实验

Android 真实应用实验：[候选应用与优先级](android实验/候选应用与优先级.md)；首个案例 [Now in Android 一键测试](android实验/01-NowInAndroid/README.md)。该案例预设项目与任务，无需选择项目。真实端到端结果待实测。

## 双击开始

在 Mac 上下载 [一键启动多Agent实验.command](一键启动多Agent实验.command)，双击打开，然后按窗口提示完成登录、选择 Git 项目并开始测试。只下载这一个文件即可，首次运行需要联网安装所需组件。

选择 **只读分析** 可以先验证环境；选择 **开发任务** 会允许 Agent 修改所选项目，请使用项目副本。结果生成后会自动打开结果文件夹，主要查看 `实验统计报告.docx`、`消息明细.csv` 和 `调用耗时.csv`。任务可能持续较长时间，完成前不要关闭窗口。

如果 macOS 提示无法打开，可在 Finder 中右键该文件并选择“打开”。如果提示没有执行权限，在终端执行 `chmod +x`，再将该文件拖进终端并按回车，然后重新双击。程序需要 macOS、Git、Python 3.9 以上和可用的 Codex 账户；缺少 Codex 时会尝试通过 npm 安装，缺少 Python 或 Node.js 时会打开下载页面。登录过程由 Codex 官方程序引导完成。

消息字节数只统计日志中可识别的正文；调用耗时包括等待和执行，不等于网络传输延迟。遇到错误时，查看结果目录中的 `codex-stderr.log`。测试记录可能包含项目内容，分享前请检查。

提供给需要深入研究和二次开发的用户：[详细说明](agent_communication_kit/README.md)、[实验设计](agent_communication_kit/设计说明与操作手册.md)。

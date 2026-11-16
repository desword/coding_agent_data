# Android 多 Agent 通信实验

在 Mac 上双击根目录的 [一键启动多Agent实验.command](一键启动多Agent实验.command)。脚本会自动下载固定版本的 Google **Now in Android** 应用和公开测试工作流，准备两个模拟器，然后启动 Codex 多 Agent 测试。**不需要选择项目或填写项目路径。**

首次运行前，请按 [运行说明](android实验/01-NowInAndroid/README.md) 安装 Android Studio、Android SDK、JDK 和 Node.js；若未登录 Codex，启动后根据提示登录。脚本会自动下载其余依赖、应用和模拟器镜像。首次下载可能需要较长时间和数 GB 空间。

运行结束后查看 `~/codex-agent-experiments/android01-时间戳/实验报告.html`。报告记录可识别的协作消息正文大小、内容与调用耗时；只有 Codex 提供可配对的发送和接收事件时，才能计算对应的投递耗时。正文大小不等于网络流量，工具等待时间也不等于网络延迟。

[候选应用与优先级](android实验/候选应用与优先级.md) 中列出了后续案例。目前首个案例已准备脚本，但尚未在具备 Android 模拟器和可用 Codex 模型权限的环境中完成真实端到端测试。

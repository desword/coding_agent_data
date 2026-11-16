# 01：Now in Android 多 Agent 测试

双击 [一键启动多Agent实验.command](../../一键启动多Agent实验.command) 启动；不需要选择项目。脚本固定下载 Google 的 [Now in Android](https://github.com/android/nowinandroid) 和公开的 [Android Bug Priority Tree](https://github.com/ChrisThoma/android-bug-priority-tree) 流程，构建应用并启动两个独立 Android 模拟器，再让 Codex Leader 分派真实的设备测试、问题确认、修复及验证任务。应用与公开流程的组合、两台设备和任务分工是本实验配置；不能说公开项目已经验证过这个组合，也不能假定 Codex 一定会遵守所有分工。

## 运行前

- macOS 可直接双击；Linux 可执行 `python3 一键启动多Agent实验.command`。需要联网、Git、Python 3.9+、JDK 21+ 和 Node.js 20+（包含 npm）。若没有 Codex CLI，脚本会在本次实验目录中安装；未登录时按屏幕提示登录。使用有相应模型权限的账号，运行可能产生模型使用费用。
- 先安装 Android Studio 和 Android SDK，并在 SDK Manager 安装 Android SDK Platform-Tools、Android Emulator、Android SDK Command-line Tools (latest)。设置 `ANDROID_HOME` 或 `ANDROID_SDK_ROOT`；macOS 和 Linux 常用默认路径会自动识别。
- 计算机需要能够启动 **两台**启用了硬件加速的 Android 模拟器，并有足够内存与磁盘空间。首次运行可能下载多个 GB：脚本会安装 API 36 平台和 API 34 Google APIs 系统镜像，出现 SDK 许可协议时按窗口提示操作。截图缩放依赖 macOS 自带 `sips` 或 Linux 的 ImageMagick `magick`。
- 首次构建、设备测试和 Agent 开发可能耗时较长。Agent 阶段最多运行两小时。请保持窗口打开；按 Ctrl+C 中断。

脚本只操作新下载的独立应用副本，并为本次运行单独创建模拟器与结果目录；运行结束会关闭它启动的模拟器。它不会推送应用代码。设备工具使用固定版本 Mobile MCP，Codex 的模型和账号沿用本机配置。Agent 使用可写工作区沙箱，并允许网络访问以连接本机设备和获取构建依赖。

## 结果在哪里

每次运行都在 `~/codex-agent-experiments/android01-时间戳/` 生成结果。Mac 上结束时会尝试自动打开 `实验报告.html`。失败或中断也会保留报告和已经产生的日志，报告会显示未完成原因。

- `实验报告.html`：执行阶段、可识别消息条数和正文 UTF-8 字节数、方向、消息摘录、工具调用耗时、可配对的发送—接收时间、设备和证据说明。
- `记录/消息明细.csv` 和 `记录/sessions/`：可识别的协作消息和原始会话；`记录/调用耗时.csv` 是工具调用到返回的时间。
- `投递时间明细.csv`：仅在原始诊断日志提供可匹配的通信 ID、发送与接收事件时才有有效样本；如为空或不可配对，无法得知投递耗时。
- `设备资源.csv`、设备和基线测试日志、`准备过程.log`：用于检查设备启动、基线测试和资源情况。

**解读限制：**正文 UTF-8 字节数不是网络链路流量，未包含协议开销、模型请求、共享上下文或文件内容；解析器也可能漏掉未支持格式。发送到接收的时间包括本地调度，不能当作纯网络时延。`wait` 包括 Agent 工作与模型耗时，不能当作通信耗时。设备已启动、基线测试通过、子会话存在都不证明 Worker 按要求完成了设备测试，需要核对原始会话及其设备操作记录。缺少有效投递样本或对照时，不能判断通信是否为主要瓶颈。报告、日志和会话可能包含源代码、任务内容与敏感数据，分享前请检查。

目前已完成的验证是采集器已有测试、模拟依赖的流程测试及 Mobile MCP 的启动和工具列表检查；尚未在具备 Android 模拟器和可用 Codex 模型权限的机器上完成真实端到端运行。若运行失败，请先看报告和 `准备过程.log`。

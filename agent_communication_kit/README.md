# 本地运行指南

需要 macOS 或 Linux、Python 3.9+、Git，以及已经安装并登录、可使用多 Agent 的 Codex CLI。模型在现有账户配置的服务端运行；本工具不会提供模型或凭据。CLI 版本需支持 `codex exec --json --enable multi_agent` 和可持久化的会话记录。`CODEX_HOME` 必须可写；默认使用 `~/.codex`。首次运行会在工具目录创建 `.venv` 并从 PyPI 安装 `python-docx`。

从任意目录运行（将路径替换为实际路径）：

```bash
codex --version
codex features list | grep multi_agent
cd /path/to/target-git-project
bash /path/to/coding_agent_data/agent_communication_kit/run_test.sh --project "$PWD"
```

默认是只读任务，要求三个子 Agent 分析目标项目；Agent 的实际行为以原始日志为准。结果默认写入 `~/codex-agent-experiments/` 下新目录。建议在有实际源码的项目上测试，并使用项目副本进行写入实验。可用 `--output /path/to/new-directory` 指定尚不存在的结果目录；建议放在项目之外。

真实开发实验使用 `--mode write`，允许 Agent 修改目标工作区；先检查工作区，并使用独立项目副本。可替换提示词以固定任务与验收条件：

```bash
bash /path/to/coding_agent_data/agent_communication_kit/run_test.sh \
  --project "$PWD" --mode write \
  --prompt /path/to/coding_agent_data/agent_communication_kit/prompts/development.txt \
  --timeout 3600 --model YOUR_MODEL
```

`--model` 可省略，使用现有配置；`--prompt` 接受 UTF-8 文件，`--timeout` 单位为秒，默认 1800。超时会终止启动的进程组，退出码为 124，并尽量保留记录。此工具不会自动提交或推送。查看 `git status`、`git diff` 和目标项目的测试结果。

主要结果：`消息明细.csv` 中每条正文的 UTF-8 字节数；`调用耗时.csv` 中按同一会话的 call ID 配对的协作工具调用耗时（毫秒），并记录原始文件和行号；`实验信息.json` 中包括单调时钟测得的整体运行秒数、退出码及采集状态；还有 Word 报告、进程资源、原始事件流及关联会话。`measurement_status` 为 `invalid_timestamp` 或 `missing_output` 时耗时为空。按工具类型自行汇总这些数据时应单独保留失败或缺失值。

**测量边界：** 工具耗时是会话日志中调用与输出时间戳之差，可能包括排队、等待 Agent 工作和框架处理；尤其 `wait_agent` 的耗时是等待时间，不能称作消息单程、往返或网络延迟。该工具不测网络包和模型 API 流量，也不能证明消息成功送达。正文统计只包括解析器识别到的调用参数和明确 completed 返回结果；继承上下文、文件读取、通知及未识别格式不计入。会话文件和日志可能包含项目代码与敏感信息，分享前应检查。

检查 `实验信息.json` 的 root ID、退出码与会话数，抽查 CSV 的来源文件和行号，并核对子 Agent 实际完成的任务。零条消息不代表零通信。工具版本或日志格式变化可能造成漏计。若失败，检查 `codex-stderr.log`；Codex 必须具有工作区及其会话目录所需权限。

重新分析已保存的原始记录（会覆盖同目录的报告和 CSV）：

```bash
bash /path/to/coding_agent_data/agent_communication_kit/run_test.sh --analyze /path/to/run-directory
```

验证解析器及模拟运行：

```bash
cd /path/to/coding_agent_data/agent_communication_kit
./.venv/bin/python -m unittest discover -s tests -v
```

模拟测试不调用模型，不代表真实 Agent 或账号权限已验证。

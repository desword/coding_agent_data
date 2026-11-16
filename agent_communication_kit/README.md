# 采集器源码与自动化检查

此目录保存一键 Android 实验使用的会话分析器源码及其测试，不是另一个需要选择项目的实验入口。开始实验请双击 [首个应用的脚本](../android实验/01-NowInAndroid/一键测试.command)。该单文件脚本内嵌采集器，可以单独下载运行；修改采集器时需要同步更新内嵌版本并运行测试。

开发者可在本目录执行自动化检查：

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python -m unittest discover -s tests -v
```

检查包含模拟设备和模拟 Codex 的流水线，不代表真实 Android 设备或模型调用已经验证。实验结果的采集口径和限制见 [Android 案例说明](../android实验/01-NowInAndroid/README.md)。

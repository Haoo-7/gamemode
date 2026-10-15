# 22 模式请求交接回归

在 `gamemode` 仓库根目录运行：

```text
lua5.4 tests/2v2_request_lifecycle.lua
qmltestrunner -input tests/qml
```

Lua 测试加载实际 `2v2.lua` 中的小游戏封装，使用隔离房间验证四人及一控二的请求结果、正常完成/超时、清理顺序和临时数据释放，不启动游戏服、不访问账号数据库。

QML 测试使用 QtQuick、QtTest，验证当前界面必须调用请求模型、旧界面的兼容路径，以及旁观者只关闭窗口且不回复。现代请求模型使用接口替身，完整联网对局仍需在实际客户端复测。

22 的禁将、备选和最终选将共用 `qml/RequestLifecycle.js`；当前界面通过 `room.dataModel.replyToServer` 收尾，旧界面保留 `notactive` 状态切换。服务器在小游戏请求结束后补发 `CancelRequest`，覆盖客户端未主动收尾的超时情况，并确保旧界面在下一个技能请求之前清理。

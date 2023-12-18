这个库通过让skynet向其他服务传递消息时额外传递栈帧信息，以实现跨服的堆杖打印，方便开发进行调试。
* 注意，本库会在每次消息传递时带来一定的额外开销. 只推荐在开发和测试环境下使用，生产环境下应该关闭此库。

# 如何使用？

1. 将cross_tracter.lua复制到skynet的lualib目录下
2. 在skynet配置中启用perload配置，如：
```lua
preload = "./examples/preload.lua"
```
3. 在perload的lua文件中引入本文件并进行patch操作
```lua
-- This file will execute before every lua service start
-- See config

print("PRELOAD", ...)
local cross_tracter = require "cross_tracter"
cross_tracter()
```

* 现在, 你便可在任意服务中使用cross_tracter了
```lua
    skynet.printCrossTrace()    -- 直接打印跨服堆栈的字符串
    skynet.getCrossArLists()    -- 获取跨服信息的栈帧列表
```
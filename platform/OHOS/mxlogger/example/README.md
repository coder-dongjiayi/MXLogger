# MXLogger ArkTS example

本目录包含可运行的原生 ArkUI 页面，覆盖初始化、五级日志、自定义 name / tag、静态 token 写入、
共享实例、等级和开关设置、保留时长 / 大小、flush、过期清理、文件读取与销毁。

## 运行

1. 在 DevEco Studio 创建 **Empty Ability** 工程（ArkTS / Stage 模型）。
2. 在业务模块 `entry/` 目录安装中心仓 SDK：

   ```sh
   ohpm install @djy/mxlogger
   ```

3. 将本目录的 `Index.ets` 复制到工程的 `entry/src/main/ets/pages/Index.ets`，替换模板页面。
   保持 `main_pages.json` 注册 `pages/Index`，由 `EntryAbility` 加载该页面。
4. 配置工程自己的调试签名，运行到鸿蒙设备或模拟器。

页面启动时自动创建 `com.example.mxlogger` 实例，使用按天分片和 AES-CFB-128。
初始化后会写入启动日志并读回检查；成功时显示 `PASS` 和实例状态。
点击操作按钮后，下方会展示调用结果、配置或解码后的日志。无需申请额外系统权限。

`cryptKey` / `iv` 使用与原生 Demo 相同的演示值，实际应用应替换为自己的参数。
日志数据存放在应用的 `filesDir/com.mxlog.LoggerCache/com.example.mxlogger/`。
重开已有加密目录时须使用一致的 key / IV，`destroy()` 保留磁盘数据。

## 生命周期

页面离开组件生命周期时会显式销毁示例会话，同一会话的别名也会失效。
实际业务中应由共享会话的所有者决定销毁时机；Worker 获取 token 后不应提前销毁 UI 仍在使用的会话。

源码工程声明最低 API 12，当前已验证 API 26 / ARM64；x86_64 仅完成构建。

完整的四种策略切换、文件分页查看及 Worker 并发演示见仓库中的
[原生 Demo](https://github.com/coder-dongjiayi/MXLogger/tree/main/platform/OHOS)。

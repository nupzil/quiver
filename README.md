<p align="center">
  <img src="./Quiver/Assets.xcassets/AppIcon.appiconset/icon-128.png" width="128" alt="Quiver 图标">
</p>

<h1 align="center">Quiver</h1>

<p align="center">
  轻量级 macOS 状态栏应用，帮助您一键管理和控制常用脚本与服务命令。
</p>

---

## 功能特点

- ⚡️ 一键启停 - 通过状态栏菜单快速控制您的脚本
- 🔧 灵活配置 - 自定义命令、工作目录和环境变量
- 📊 日志记录 - 自动保存命令输出，随时查看执行结果
- 🔄 后台运行 - 无需保持终端窗口打开
- 🍎 系统兼容 - 支持 macOS 14.6 及更高版本

## 适用场景

Quiver 特别适合以下场景：

- 您有多个经常使用的脚本或服务
- 您不需要实时查看命令输出（可以在需要时查看日志文件）
- 您觉得每次打开终端、切换目录并运行命令太麻烦
- 您希望有一个简单的方式来启动/停止这些命令

## 安装

1. 从 [Releases](https://github.com/nupzil/quiver/releases) 下载最新版本
2. 拖动 Quiver.app 至应用程序文件夹
3. 启动应用，图标将显示在菜单栏

## 注意事项

- 首次启动应用时，将在默认路径中自动生成一个示例配置文件
- 命令的输出将自动保存到日志文件中，最多保存最近 50 个日志文件
- 程序退出时，所有正在运行的命令将被强制停止
- 命令终止时类似 `ctrl + C`，所以您可以监听信号进行优雅退出操作

## 配置

Quiver 使用 YAML 配置文件定义命令，路径：`~/.quiver/configure.yml`。

首次启动应用时，将自动生成一个示例配置文件。您可以根据需要进行修改。

### 配置文件示例

```yaml
# Quiver 配置文件示例
# 可以定义多个命令，每个命令包含以下属性：
# - name: 命令名称
# - script: 要执行的shell命令
# - working_dir: 工作目录
# - env: 环境变量 (可选)

- name: Echo Example
  script: echo "[$mode] Hello from Quiver!"
  working_dir: ~/
  env:
    - mode: debug

- name: open release dir
  script: open "$(find ~/Library/Developer/Xcode/DerivedData -name 'Quiver-*' -type d | head -n 1)/Build/Products"
  working_dir: ~/
```

## 系统要求

- macOS 14.6 或更高版本

## 许可证

本项目使用 [MIT License](./LICENSE) 授权。

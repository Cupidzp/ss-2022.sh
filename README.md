# Shadowsocks Rust + ShadowTLS Alpine 一键安装

在 **Alpine Linux 3.21、3.22 或 3.23** 上以 root 执行下面这一行。命令会安装启动所需的 Bash 和 curl、下载脚本并启动交互安装器；脚本会继续通过 `apk` 安装运行依赖，并在安装过程中询问是否自动管理本机防火墙规则。

```sh
apk add --no-cache bash curl && bash -c 'curl -fsSL https://raw.githubusercontent.com/Cupidzp/ss-2022.sh/main/ss-2022.sh -o /tmp/ss-2022.sh && exec bash /tmp/ss-2022.sh'
```

进入菜单后选择 **1. 安装 Shadowsocks Rust**，端口提示处可直接输入端口号，例如 `30123`。安装时可选择由脚本自动管理本机 iptables 规则，或跳过并自行确保网络侧放行 SS 使用的 TCP 和 UDP 端口；选择会保存并用于后续 SS/ShadowTLS 管理操作。

## 系统要求

- 仅支持 Alpine Linux 3.21、3.22、3.23（x86_64、aarch64，以及脚本支持的 musl 架构）
- 需要 OpenRC；LXC 容器应提供可用的 `rc-service` / `rc-update`
- 需要 root 权限和可访问 Alpine 软件源、GitHub 的网络连接

## Alpine 注意事项

服务由 OpenRC 管理，可使用 `rc-service ss-rust status|start|stop|restart` 查看和控制，使用 `rc-update` 查看开机自启。多端口 SS、ShadowTLS 和大陆屏蔽恢复也使用 OpenRC 服务。

二维码和大陆 IP 屏蔽功能需要启用 Alpine `community` 仓库；对应包为 `libqrencode-tools` 和 `py3-maxminddb`。

Snell、PSM 流量管理和 VLESS Reality 依赖仓库外的 systemd 项目，不属于此 Alpine 版本的支持范围；菜单会显示提示并返回。Alpine 官方仓库未提供 `simple-obfs`，混淆插件仅在已自行安装 `obfs-server` 时可用。

如需非交互跳过防火墙管理，可在运行安装器前设置 `SS_SKIP_FIREWALL=1`；设置会写入 `/etc/ss-rust/firewall-disabled` 并在后续 SS/ShadowTLS 管理操作中持续生效。中国大陆 IP 屏蔽是独立的防火墙功能，不受此选项控制。

## 主要功能

### Shadowsocks Rust 功能
1. 安装 Shadowsocks Rust
2. 更新 Shadowsocks Rust
3. 卸载 Shadowsocks Rust
4. 启动/停止/重启服务
5. 修改配置信息
6. 查看配置信息
7. 查看运行状态
8. 安装 ShadowTLS

### ShadowTLS 功能
1. 安装 ShadowTLS
2. 卸载 ShadowTLS
3. 查看配置

## 支持的加密方式

### Shadowsocks Rust 加密方式
- aes-128-gcm (默认)
- aes-256-gcm (推荐)
- chacha20-ietf-poly1305
- 2022-blake3-aes-128-gcm (推荐)
- 2022-blake3-aes-256-gcm (推荐)
- 2022-blake3-chacha20-poly1305
- 2022-blake3-chacha8-poly1305
- 其他更多加密方式...

## 客户端配置

脚本支持生成多种客户端配置格式：

### Surge 配置
自动生成 Surge 配置格式，包含：
- 服务器地址
- 端口
- 加密方式
- 密码
- ShadowTLS 配置

### Shadowrocket 配置
提供完整的 Shadowrocket 配置说明，包括：
- Shadowsocks 节点配置
- ShadowTLS 节点配置
- 自动生成的配置二维码

### Clash Meta 配置
生成完整的 Clash Meta 配置，包含：
- 代理配置
- ShadowTLS 插件配置

## 分享功能

- 生成 SS + ShadowTLS 合并链接
- 生成配置二维码
- 支持 IPv4/IPv6 地址

## 注意事项

1. 安装 ShadowTLS 之前需要先安装 Shadowsocks Rust
2. 配置文件会自动备份
3. 更新脚本前建议先备份配置
4. 请确保安装过程中网络连接稳定

## 问题排查

如果遇到问题，可以：
1. 查看 SS 状态和日志：`rc-service ss-rust status`、`tail -n 50 /var/log/ss-rust.log`
2. 查看 ShadowTLS：`rc-service shadowtls-ss status`，日志位置可从 `/etc/init.d/shadowtls-ss` 的 `output_log` 字段确认

## 更新日志

### v1.3.0
- 添加 ShadowTLS 支持
- 优化配置生成逻辑
- 改进错误处理

### v1.0.0
- 初始发布
- 支持 Shadowsocks Rust 基本功能

## 作者信息

- 作者：jinqians
- 网站：https://jinqians.com

#!/bin/bash
if [ -z "${BASH_VERSION:-}" ]; then
    echo "此脚本需要 Bash；Alpine 请先运行 apk add bash curl，然后使用 bash 启动脚本。" >&2
    exit 1
fi

# =========================================
# 作者: jinqians
# 日期: 2026年7月
# 网站：jinqians.com
# 描述: 这个脚本用于统一管理 Snell、SS-Rust 和 ShadowTLS（将逐步和snell管理菜单分开）
# =========================================

# 定义颜色代码
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# 当前版本号
current_version="4.5"

REPO_RAW_BASE="${REPO_RAW_BASE:-https://raw.githubusercontent.com/Cupidzp/ss-2022.sh/main}"
SERVICE_DIR="/etc/init.d"

require_supported_alpine() {
    local os_id os_version
    [ -f /etc/os-release ] || { echo -e "${RED}仅支持 Alpine Linux 3.21、3.22、3.23、3.24${RESET}" >&2; exit 1; }
    . /etc/os-release
    os_id=${ID:-}
    os_version=${VERSION_ID:-$(cat /etc/alpine-release 2>/dev/null)}
    [ "${os_id}" = "alpine" ] || { echo -e "${RED}仅支持 Alpine Linux 3.21、3.22、3.23、3.24${RESET}" >&2; exit 1; }
    case "${os_version}" in
        3.21|3.21.*|3.22|3.22.*|3.23|3.23.*|3.24|3.24.*) ;;
        *) echo -e "${RED}仅支持 Alpine Linux 3.21、3.22、3.23、3.24${RESET}" >&2; exit 1 ;;
    esac
}

service_path() {
    echo "${SERVICE_DIR}/$1"
}

service_name_from_path() {
    local name
    name=$(basename "$1")
    echo "${name%.service}"
}

service_start() {
    rc-service "$1" start
}

service_stop() {
    rc-service "$1" stop
}

service_restart() {
    if rc-service "$1" status >/dev/null 2>&1; then rc-service "$1" restart; else rc-service "$1" start; fi
}

service_active() {
    rc-service "$1" status >/dev/null 2>&1
}

service_enable() {
    rc-update add "$1" default
}

service_disable() {
    rc-update del "$1" default
}

service_reload() {
    :
}

# 中国大陆屏蔽脚本仓库地址
MAINLAND_BLOCK_URL="${REPO_RAW_BASE}/block-mainland.sh"
MAINLAND_EXTRACT_URL="${REPO_RAW_BASE}/extract-cn-ip-from-mmdb.py"
MAINLAND_SCRIPT_DIR="/usr/local/share/ss-2022"

# 安装全局命令
install_global_command() {
    echo -e "${CYAN}正在安装全局命令...${RESET}"
    
    # 下载脚本到 /usr/local/bin
    curl -fsSL "${REPO_RAW_BASE}/menu.sh" -o "/usr/local/bin/menu.sh"
    chmod +x "/usr/local/bin/menu.sh"
    
    # 创建软链接
    if [ -f "/usr/local/bin/menu" ]; then
        rm -f "/usr/local/bin/menu"
    fi
    ln -s "/usr/local/bin/menu.sh" "/usr/local/bin/menu"
    
    echo -e "${GREEN}安装成功！现在您可以在任何位置使用 'menu' 命令来启动管理脚本${RESET}"
}

# 检查并安装依赖
check_dependencies() {
    echo -e "${CYAN}正在检查依赖...${RESET}"
    apk add --no-cache bash busybox-openrc coreutils curl iproute2 iptables jq openrc || {
        echo -e "${RED}Alpine 依赖安装失败，请检查 apk 仓库配置和网络${RESET}"
        exit 1
    }

    echo -e "${GREEN}所有依赖已满足${RESET}"
}

# 检查是否以 root 权限运行
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}请以 root 权限运行此脚本${RESET}"
        exit 1
    fi
}

# 检查服务状态并显示
check_and_show_status() {
    echo -e "\n${CYAN}=== 服务状态检查 (OpenRC) ===${RESET}"
    echo -e "${YELLOW}Snell / PSM / VLESS Reality 外部集成在 Alpine 暂不支持${RESET}"
    if [ -x /usr/local/bin/ss-rust ]; then
        if service_active ss-rust; then
            echo -e "${GREEN}SS-2022 已安装且运行中${RESET}"
        else
            echo -e "${YELLOW}SS-2022 已安装但未运行${RESET}"
        fi
        if [ -d /etc/ss-rust/ports ]; then
            local node_file node_port
            for node_file in /etc/ss-rust/ports/*.json; do
                [ -f "${node_file}" ] || continue
                node_port=$(jq -r '.server_port' "${node_file}" 2>/dev/null)
                if service_active "ss-rust-${node_port}"; then
                    echo -e "${GREEN}SS-2022 端口 ${node_port} 运行中${RESET}"
                else
                    echo -e "${YELLOW}SS-2022 端口 ${node_port} 未运行${RESET}"
                fi
            done
        fi
    else
        echo -e "${YELLOW}SS-2022 未安装${RESET}"
    fi
    local service_file service_name
    for service_file in "${SERVICE_DIR}"/shadowtls-*; do
        [ -f "${service_file}" ] || continue
        case "$(basename "${service_file}")" in shadowtls-snell-*) continue ;; esac
        service_name=$(service_name_from_path "${service_file}")
        if service_active "${service_name}"; then
            echo -e "${GREEN}${service_name} 运行中${RESET}"
        else
            echo -e "${YELLOW}${service_name} 未运行${RESET}"
        fi
    done
    echo -e "${CYAN}====================${RESET}\n"
}

# 更新脚本
update_script() {
    echo -e "${CYAN}正在检查脚本更新...${RESET}"
    
    # 创建临时文件
    TMP_SCRIPT=$(mktemp)
    
    # 下载最新版本
    if curl -fsSL "${REPO_RAW_BASE}/menu.sh" -o "$TMP_SCRIPT"; then
        # 获取新版本号
        new_version=$(grep "current_version=" "$TMP_SCRIPT" | cut -d'"' -f2)
        
        if [ -z "$new_version" ]; then
            echo -e "${RED}无法获取新版本信息${RESET}"
            rm -f "$TMP_SCRIPT"
            return 1
        fi
        
        echo -e "${YELLOW}当前版本：${current_version}${RESET}"
        echo -e "${YELLOW}最新版本：${new_version}${RESET}"
        
        # 比较版本号
        if [ "$new_version" != "$current_version" ]; then
            echo -e "${CYAN}是否更新到新版本？[y/N]${RESET}"
            read -r choice
            if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
                # 获取当前脚本的完整路径
                SCRIPT_PATH=$(readlink -f "$0")
                
                # 备份当前脚本
                cp "$SCRIPT_PATH" "${SCRIPT_PATH}.backup"
                
                # 更新脚本
                mv "$TMP_SCRIPT" "$SCRIPT_PATH"
                chmod +x "$SCRIPT_PATH"
                
                echo -e "${GREEN}脚本已更新到最新版本${RESET}"
                echo -e "${YELLOW}已备份原脚本到：${SCRIPT_PATH}.backup${RESET}"
                echo -e "${CYAN}请重新运行脚本以使用新版本${RESET}"
                exit 0
            else
                echo -e "${YELLOW}已取消更新${RESET}"
                rm -f "$TMP_SCRIPT"
            fi
        else
            echo -e "${GREEN}当前已是最新版本${RESET}"
            rm -f "$TMP_SCRIPT"
        fi
    else
        echo -e "${RED}下载新版本失败，请检查网络连接${RESET}"
        rm -f "$TMP_SCRIPT"
    fi
}

# 安装/管理 Snell
manage_snell() {
    echo -e "${YELLOW}Snell 安装/管理依赖仓库外的 systemd 脚本，Alpine 暂不支持。${RESET}"
}

# 安装/管理 SS-2022
manage_ss_rust() {
    bash <(curl -sL "${REPO_RAW_BASE}/ss-2022.sh")
}

# 管理中国大陆IP屏蔽
manage_mainland_block() {
    echo -e "${CYAN}正在从仓库获取大陆IP屏蔽脚本...${RESET}"

    mkdir -p "${MAINLAND_SCRIPT_DIR}"

    if ! curl -fL -s "${MAINLAND_BLOCK_URL}" -o "${MAINLAND_SCRIPT_DIR}/block-mainland.sh"; then
        echo -e "${RED}下载 block-mainland.sh 失败${RESET}"
        return 1
    fi

    if ! curl -fL -s "${MAINLAND_EXTRACT_URL}" -o "${MAINLAND_SCRIPT_DIR}/extract-cn-ip-from-mmdb.py"; then
        echo -e "${RED}下载 extract-cn-ip-from-mmdb.py 失败${RESET}"
        return 1
    fi

    chmod +x "${MAINLAND_SCRIPT_DIR}/block-mainland.sh" "${MAINLAND_SCRIPT_DIR}/extract-cn-ip-from-mmdb.py"
    PYTHONIOENCODING=UTF-8 bash "${MAINLAND_SCRIPT_DIR}/block-mainland.sh"
}

# 安装/管理 ShadowTLS
manage_shadowtls() {
    bash <(curl -sL "${REPO_RAW_BASE}/shadowtls.sh")
}

# 安装/管理 VLESS Reality（已整合到 PSM）
manage_vless() {
    echo -e "${YELLOW}VLESS Reality/PSM 来自仓库外的 systemd 项目，Alpine 暂不支持。${RESET}"
}

close_port() {
    local port=$1
    if [ "${SS_SKIP_FIREWALL:-0}" = "1" ] || [ -f /etc/ss-rust/firewall-disabled ]; then
        return 0
    fi
    local ports_file="/etc/ss-rust/firewall-ports"
    if [ -f "/etc/ss-rust/firewall-chain-managed" ] && [ -f "${ports_file}" ]; then
        iptables -D SS2022_ALLOW -p tcp --dport "$port" -j ACCEPT 2>/dev/null || true
        iptables -D SS2022_ALLOW -p udp --dport "$port" -j ACCEPT 2>/dev/null || true
        local tmp_file="${ports_file}.tmp"
        grep -vxF "$port" "$ports_file" > "$tmp_file" || true
        mv "$tmp_file" "$ports_file"
        if [ ! -s "$ports_file" ]; then
            rc-service ss-rust-firewall stop >/dev/null 2>&1 || true
            rc-update del ss-rust-firewall default >/dev/null 2>&1 || true
            rm -f "$ports_file" "/etc/ss-rust/firewall-chain-managed" /etc/init.d/ss-rust-firewall
        fi
    fi
}

# 卸载 Snell
uninstall_snell() {
    echo -e "${YELLOW}Snell 安装/管理依赖仓库外的 systemd 配置，Alpine 暂不支持。${RESET}"
}

# 卸载 SS-2022
uninstall_ss_rust() {
    echo -e "${CYAN}正在卸载 SS-2022...${RESET}"

    # 获取主服务端口，用于关闭防火墙
    local main_port=""
    if [ -f "/etc/ss-rust/config.json" ]; then
        main_port=$(grep -oE '"server_port"[[:space:]]*:[[:space:]]*[0-9]+' /etc/ss-rust/config.json | grep -oE '[0-9]+' | head -n 1)
    fi

    # 停止并禁用主服务
    service_stop ss-rust 2>/dev/null || true
    service_disable ss-rust 2>/dev/null || true
    rm -f "$(service_path ss-rust)"
    if [ -n "$main_port" ]; then
        close_port "$main_port"
    fi

    # 清理多端口节点服务
    local extra_service
    for extra_service in "${SERVICE_DIR}"/ss-rust-*; do
        [ -f "$extra_service" ] || continue
        local svc_name
        svc_name=$(service_name_from_path "$extra_service")
        local extra_port="${svc_name#ss-rust-}"
        case "$extra_port" in ''|*[!0-9]*) continue ;; esac
        echo -e "${YELLOW}正在停止多端口服务 (端口: ${extra_port})${RESET}"
        service_stop "$svc_name" 2>/dev/null || true
        service_disable "$svc_name" 2>/dev/null || true
        rm -f "$extra_service"
        case "$extra_port" in
            ''|*[!0-9]*) ;;
            *) close_port "$extra_port" ;;
        esac
    done

    if [ -f /etc/ss-rust/firewall-ports ]; then
        while IFS= read -r extra_port; do
            case "$extra_port" in ''|*[!0-9]*) continue ;; esac
            close_port "$extra_port"
        done < /etc/ss-rust/firewall-ports
    fi

    # 删除二进制文件和配置目录
    rm -f "/usr/local/bin/ss-rust"
    rm -rf "/etc/ss-rust"

    # OpenRC reads service definitions directly.
    service_reload

    echo -e "${GREEN}SS-2022 卸载完成！${RESET}"
}

# 卸载 ShadowTLS
uninstall_shadowtls() {
    echo -e "${CYAN}正在卸载 ShadowTLS...${RESET}"

    # 遍历所有服务定义也能清理已停止的 ShadowTLS 服务。
    local service_file service listen_addr listen_port
    for service_file in "${SERVICE_DIR}"/shadowtls-*; do
        [ -f "$service_file" ] || continue
        service=$(service_name_from_path "$service_file")
        listen_addr=$(grep -oE -- '--listen [^ ]+' "$service_file" | head -1)
        listen_port=${listen_addr##*:}
        echo -e "${YELLOW}正在移除 ${service}${RESET}"
        service_stop "$service" 2>/dev/null || true
        service_disable "$service" 2>/dev/null || true
        rm -f "$service_file"
        if [ -n "$listen_port" ]; then
            close_port "$listen_port"
        fi
    done
    
    # 删除二进制文件
    rm -f "/usr/local/bin/shadow-tls"
    
    # OpenRC reads service definitions directly.
    service_reload
    
    echo -e "${GREEN}ShadowTLS 卸载完成！${RESET}"
}

# 主菜单
show_menu() {
    clear
    echo -e "${CYAN}============================================${RESET}"
    echo -e "${CYAN}          统一管理脚本 v${current_version}${RESET}"
    echo -e "${CYAN}============================================${RESET}"
    echo -e "${GREEN}作者: jinqian${RESET}"
    echo -e "${GREEN}网站：https://jinqians.com${RESET}"
    echo -e "${CYAN}============================================${RESET}"
    
    # 显示服务状态
    check_and_show_status
    
    echo -e "${YELLOW}=== 安装管理 ===${RESET}"
    echo -e "${GREEN}1.${RESET} Snell 安装管理"
    echo -e "${GREEN}2.${RESET} SS-2022 安装管理"
    echo -e "${GREEN}3.${RESET} VLESS Reality 安装管理"
    echo -e "${GREEN}4.${RESET} ShadowTLS 安装管理"
    
    echo -e "\n${YELLOW}=== 卸载功能 ===${RESET}"
    echo -e "${GREEN}5.${RESET} 卸载 Snell"
    echo -e "${GREEN}6.${RESET} 卸载 SS-2022"
    echo -e "${GREEN}7.${RESET} 卸载 ShadowTLS"
    
    echo -e "\n${YELLOW}=== 系统功能 ===${RESET}"
    echo -e "${GREEN}8.${RESET} 更新脚本"
    echo -e "${GREEN}9.${RESET} 流量管理（推荐使用 PSM 管理）"
    echo -e "${GREEN}10.${RESET} 中国大陆屏蔽管理(ss-2022)"
    echo -e "${GREEN}0.${RESET} 退出"
    
    echo -e "${CYAN}============================================${RESET}"

    echo -e "${GREEN}退出脚本后，输入menu可进入脚本${RESET}"

    echo -e "${CYAN}============================================${RESET}"
    read -rp "请输入选项 [0-10]: " num
}

# 初始检查
check_root
require_supported_alpine
check_dependencies
install_global_command

# 主循环
while true; do
    show_menu
    case "$num" in
        1)
            manage_snell
            ;;
        2)
            manage_ss_rust
            ;;
        3)
            manage_vless
            ;;
        4)
            manage_shadowtls
            ;;
        5)
            uninstall_snell
            ;;
        6)
            uninstall_ss_rust
            ;;
        7)
            uninstall_shadowtls
            ;;
        8)
            update_script
            ;;
        9)
            echo -e "${YELLOW}PSM 流量管理依赖仓库外的 systemd 项目，Alpine 暂不支持。${RESET}"
            ;;
        10)
            if ! manage_mainland_block; then
                echo -e "${YELLOW}请检查仓库地址或网络连接后重试${RESET}"
                read -p "按任意键继续..."
            fi
            ;;
        0)
            echo -e "${GREEN}感谢使用，再见！${RESET}"
            exit 0
            ;;
        *)
            echo -e "${RED}请输入正确的选项 [0-10]${RESET}"
            ;;
    esac
    echo -e "\n${CYAN}按任意键返回主菜单...${RESET}"
    read -n 1 -s -r
done 

#!/bin/bash

# 钛盘上传工具 Linux 安装脚本
# TmpLink Uploader Linux Installation Script

set -e

# 安装目录 - 使用用户目录避免权限问题
INSTALL_DIR="$HOME/.local/bin"
GITHUB_REPO="tmplink/tmplink_uploader"
API_BASE="https://api.github.com/repos/$GITHUB_REPO"
DOWNLOAD_BASE="https://github.com/$GITHUB_REPO/releases/download"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}   钛盘上传工具 Linux 安装程序      ${NC}"
    echo -e "${BLUE}   TmpLink Uploader Linux Installer ${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo
}

print_step() {
    echo -e "${YELLOW}[步骤] $1${NC}"
}

print_success() {
    echo -e "${GREEN}[成功] $1${NC}"
}

print_error() {
    echo -e "${RED}[错误] $1${NC}"
}

print_info() {
    echo -e "${BLUE}[信息] $1${NC}"
}

check_requirements() {
    print_step "检查系统要求..."
    
    # 修复系统检测 - 适配 SLES
    if [[ "$(uname)" != "Linux" ]]; then
        print_error "此脚本仅适用于 Linux 系统"
        print_info "当前系统: $(uname)"
        exit 1
    fi
    
    # 检测具体的 Linux 发行版
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        print_info "检测到 Linux 发行版: $PRETTY_NAME"
        
        # 针对 SLES 的特殊提示
        if [[ "$ID" == "sles" ]]; then
            print_info "检测到 SUSE Linux Enterprise Server"
        fi
    fi
    
    # 创建安装目录
    mkdir -p "$INSTALL_DIR"
    print_info "安装目录: $INSTALL_DIR"
    
    # 检查是否有写入权限
    if [[ ! -w "$INSTALL_DIR" ]]; then
        print_error "没有权限写入 $INSTALL_DIR"
        exit 1
    fi
    
    # 检查必要的工具
    local missing_tools=()
    for tool in curl wget; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -eq 2 ]]; then
        print_error "需要 curl 或 wget 来下载文件"
        print_info "请使用以下命令安装:"
        print_info "  sudo zypper install curl"
        exit 1
    fi
    
    print_success "系统要求检查通过"
}

detect_architecture() {
    print_step "检测系统架构..."
    
    local arch=$(uname -m)
    case $arch in
        x86_64)
            ARCH_SUFFIX="linux-amd64"
            print_info "检测到 64位 x86 架构"
            ;;
        aarch64|arm64)
            ARCH_SUFFIX="linux-arm64"
            print_info "检测到 ARM64 架构"
            ;;
        *)
            print_error "不支持的架构: $arch"
            print_info "支持的架构: x86_64, aarch64/arm64"
            exit 1
            ;;
    esac
}

get_latest_version() {
    print_step "获取最新版本信息..."
    
    # 使用 curl 或 wget 获取最新版本
    local version_info=""
    if command -v curl &> /dev/null; then
        print_info "使用 curl 获取版本信息..."
        version_info=$(curl -s --connect-timeout 10 "$API_BASE/releases/latest" 2>/dev/null)
    elif command -v wget &> /dev/null; then
        print_info "使用 wget 获取版本信息..."
        version_info=$(wget -q -O - --timeout=10 "$API_BASE/releases/latest" 2>/dev/null)
    fi
    
    if [[ -z "$version_info" ]]; then
        print_error "获取版本信息失败，请检查网络连接"
        print_info "尝试直接使用最新版本..."
        # 如果无法获取最新版本，使用一个默认版本
        LATEST_VERSION="v1.0.0"  # 请根据实际情况调整
    else
        # 解析版本号
        LATEST_VERSION=$(echo "$version_info" | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
        
        if [[ -z "$LATEST_VERSION" ]]; then
            print_error "解析版本信息失败"
            print_info "使用默认版本..."
            LATEST_VERSION="v1.0.0"
        fi
    fi
    
    print_info "最新版本: $LATEST_VERSION"
}

download_binaries() {
    print_step "下载二进制文件..."
    
    local temp_dir=$(mktemp -d)
    local gui_binary="tmplink"
    local cli_binary="tmplink-cli"
    local gui_remote="tmplink-$ARCH_SUFFIX"
    local cli_remote="tmplink-cli-$ARCH_SUFFIX"
    
    print_info "下载地址: $DOWNLOAD_BASE/$LATEST_VERSION/"
    
    # 下载 GUI 版本
    print_info "下载 $gui_binary..."
    local download_success=false
    
    if command -v curl &> /dev/null; then
        if curl -L --progress-bar -f "$DOWNLOAD_BASE/$LATEST_VERSION/$gui_remote" -o "$temp_dir/$gui_binary" 2>/dev/null; then
            download_success=true
        fi
    elif command -v wget &> /dev/null; then
        if wget --progress=bar "$DOWNLOAD_BASE/$LATEST_VERSION/$gui_remote" -O "$temp_dir/$gui_binary" 2>/dev/null; then
            download_success=true
        fi
    fi
    
    if [[ "$download_success" != true ]]; then
        print_error "下载 $gui_binary 失败"
        print_info "尝试备用下载地址..."
        # 尝试不带版本号的下载
        if command -v curl &> /dev/null; then
            curl -L --progress-bar -f "https://github.com/$GITHUB_REPO/releases/latest/download/$gui_remote" -o "$temp_dir/$gui_binary" || {
                print_error "下载失败"
                rm -rf "$temp_dir"
                exit 1
            }
        elif command -v wget &> /dev/null; then
            wget --progress=bar "https://github.com/$GITHUB_REPO/releases/latest/download/$gui_remote" -O "$temp_dir/$gui_binary" || {
                print_error "下载失败"
                rm -rf "$temp_dir"
                exit 1
            }
        fi
    fi
    
    # 下载 CLI 版本
    print_info "下载 $cli_binary..."
    download_success=false
    
    if command -v curl &> /dev/null; then
        if curl -L --progress-bar -f "$DOWNLOAD_BASE/$LATEST_VERSION/$cli_remote" -o "$temp_dir/$cli_binary" 2>/dev/null; then
            download_success=true
        fi
    elif command -v wget &> /dev/null; then
        if wget --progress=bar "$DOWNLOAD_BASE/$LATEST_VERSION/$cli_remote" -O "$temp_dir/$cli_binary" 2>/dev/null; then
            download_success=true
        fi
    fi
    
    if [[ "$download_success" != true ]]; then
        print_error "下载 $cli_binary 失败"
        print_info "尝试备用下载地址..."
        if command -v curl &> /dev/null; then
            curl -L --progress-bar -f "https://github.com/$GITHUB_REPO/releases/latest/download/$cli_remote" -o "$temp_dir/$cli_binary" || {
                print_error "下载失败"
                rm -rf "$temp_dir"
                exit 1
            }
        elif command -v wget &> /dev/null; then
            wget --progress=bar "https://github.com/$GITHUB_REPO/releases/latest/download/$cli_remote" -O "$temp_dir/$cli_binary" || {
                print_error "下载失败"
                rm -rf "$temp_dir"
                exit 1
            }
        fi
    fi
    
    # 验证文件
    if [[ ! -f "$temp_dir/$gui_binary" ]] || [[ ! -f "$temp_dir/$cli_binary" ]]; then
        print_error "下载的文件不存在"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # 检查文件大小
    if [[ ! -s "$temp_dir/$gui_binary" ]] || [[ ! -s "$temp_dir/$cli_binary" ]]; then
        print_error "下载的文件为空"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # 添加执行权限
    chmod +x "$temp_dir/$gui_binary"
    chmod +x "$temp_dir/$cli_binary"
    
    TEMP_DIR="$temp_dir"
    print_success "二进制文件下载完成"
}

install_binaries() {
    print_step "安装程序到系统..."
    
    # 安装二进制文件
    print_info "安装 tmplink 到 $INSTALL_DIR..."
    cp "$TEMP_DIR/tmplink" "$INSTALL_DIR/"
    cp "$TEMP_DIR/tmplink-cli" "$INSTALL_DIR/"
    
    print_success "程序安装完成"
}

setup_environment() {
    print_step "配置环境..."
    
    # 检查 PATH 是否包含安装目录
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        print_info "添加 $INSTALL_DIR 到 PATH"
        
        # 检测当前 shell 并添加配置
        local shell_config=""
        if [[ -n "$BASH" ]]; then
            shell_config="$HOME/.bashrc"
        elif [[ -n "$ZSH_VERSION" ]]; then
            shell_config="$HOME/.zshrc"
        else
            shell_config="$HOME/.profile"
        fi
        
        if [[ -f "$shell_config" ]]; then
            echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$shell_config"
            print_info "已添加 PATH 配置到 $shell_config"
            print_info "请运行以下命令使配置生效:"
            echo "  source $shell_config"
        else
            print_info "请手动添加以下内容到你的 shell 配置文件:"
            echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
        fi
    fi
    
    print_success "环境配置完成"
}

verify_installation() {
    print_step "验证安装..."
    
    if [[ -x "$INSTALL_DIR/tmplink" ]] && [[ -x "$INSTALL_DIR/tmplink-cli" ]]; then
        print_success "安装验证成功"
        print_info "GUI 程序: $INSTALL_DIR/tmplink"
        print_info "CLI 程序: $INSTALL_DIR/tmplink-cli"
        
        # 尝试显示版本信息
        print_info "获取版本信息..."
        "$INSTALL_DIR/tmplink-cli" --version 2>/dev/null || echo "无法获取版本信息"
    else
        print_error "安装验证失败"
        ls -la "$INSTALL_DIR"
        exit 1
    fi
}

show_usage() {
    print_step "使用说明"
    echo
    echo "安装完成！您现在可以使用以下命令："
    echo
    echo "  tmplink      - 启动图形界面版本"
    echo "  tmplink-cli  - 使用命令行版本"
    echo
    echo "获取帮助："
    echo "  tmplink --help"
    echo "  tmplink-cli --help"
    echo
    echo "配置文件位置："
    echo "  ~/.tmplink_config.json"
    echo
    echo "注意：如果命令找不到，请运行："
    echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
    echo
}

cleanup() {
    print_step "清理临时文件..."
    if [[ -n "$TEMP_DIR" ]] && [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
        print_success "临时文件已清理"
    fi
}

main() {
    print_header
    
    check_requirements
    detect_architecture
    get_latest_version
    download_binaries
    install_binaries
    setup_environment
    verify_installation
    show_usage
    cleanup
    
    echo
    print_success "钛盘上传工具安装完成！"
    echo
}

# 捕获中断信号
trap 'print_error "安装被中断"; cleanup; exit 1' INT TERM

# 运行主函数
main "$@"
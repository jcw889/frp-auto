#!/bin/bash

# 检查root权限
if [ "$(id -u)" != "0" ]; then
    echo "请使用root用户运行此脚本！"
    exit 1
fi

# 安装依赖
apt update && apt install -y wget unzip curl

# 获取公网IP并人工确认
get_public_ip() {
    PUBLIC_IP=$(curl -s icanhazip.com)
    if [[ -z "$PUBLIC_IP" ]]; then
        echo "错误：无法获取公网IP，请检查网络连接！"
        exit 1
    fi

    echo "检测到公网IP: $PUBLIC_IP"
    read -p "请确认此IP是否正确？[y/n] " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        echo "安装中止，请手动指定IP后重试。"
        exit 1
    fi

    if [[ "$PUBLIC_IP" == *":"* ]]; then
        BIND_ADDR="::"
        echo "已启用IPv6监听"
    else
        BIND_ADDR="0.0.0.0"
        echo "已启用IPv4监听"
    fi
}

# 调用IP检测函数
get_public_ip

# 交互式配置
read -p "请输入FRP服务端端口 [默认: 7000]: " BIND_PORT
BIND_PORT=${BIND_PORT:-7000}

read -p "请输入Token密码 [默认: random123]: " TOKEN
TOKEN=${TOKEN:-random123}

# 下载FRP
FRP_VERSION="0.51.3"
FRP_URL="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_amd64.tar.gz"
echo "正在下载FRP v${FRP_VERSION}..."
wget -O frp.tar.gz "$FRP_URL" && tar -xzf frp.tar.gz
cd frp_${FRP_VERSION}_linux_amd64 || exit

# 配置服务端
cat > frps.ini <<EOF
[common]
bind_addr = ${BIND_ADDR}
bind_port = ${BIND_PORT}
token = ${TOKEN}
EOF

# 启动服务
nohup ./frps -c frps.ini > frps.log 2>&1 &

# 配置systemd服务
cat > /etc/systemd/system/frps.service <<EOF
[Unit]
Description=FRP Server
After=network.target

[Service]
Type=simple
WorkingDirectory=$(pwd)
ExecStart=$(pwd)/frps -c $(pwd)/frps.ini
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable frps
systemctl start frps

# 创建全局命令 frp
cat > /usr/local/bin/frp <<'EOF'
#!/bin/bash
case "$1" in
    -k)
        systemctl status frps
        ;;
    -xz)
        echo "正在卸载FRP..."
        systemctl stop frps
        systemctl disable frps
        rm -f /etc/systemd/system/frps.service
        systemctl daemon-reload
        rm -rf /root/frp /usr/local/bin/frp
        echo "FRP 已完全卸载！"
        ;;
    *)
        echo "用法:"
        echo "  frp -k    # 查看服务状态"
        echo "  frp -xz   # 卸载FRP服务"
        exit 1
        ;;
esac
EOF

chmod +x /usr/local/bin/frp

# 输出信息
echo "----------------------------------------"
echo "FRP服务端已启动！"
echo "公网地址: ${PUBLIC_IP}"
echo "服务端端口: ${BIND_PORT}"
echo "Token: ${TOKEN}"
echo "----------------------------------------"
echo "快捷命令:"
echo "  frp -k    # 查看服务状态"
echo "  frp -xz   # 卸载服务"
echo "----------------------------------------"

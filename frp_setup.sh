#!/bin/bash

# 检查是否为root用户
if [ "$(id -u)" != "0" ]; then
    echo "请使用root用户运行此脚本！"
    exit 1
fi

# 安装依赖
echo "正在安装依赖（wget/unzip）..."
apt update && apt install -y wget unzip

# 下载FRP
FRP_VERSION="0.51.3"
FRP_URL="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_amd64.tar.gz"
echo "正在下载FRP v${FRP_VERSION}..."
wget -O frp.tar.gz "$FRP_URL"
tar -xzf frp.tar.gz
cd frp_${FRP_VERSION}_linux_amd64 || exit

# 交互式输入公网IP和Token
read -p "请输入公网服务器IP: " SERVER_IP
read -p "请输入Token密码（用于客户端认证）: " TOKEN

# 配置FRP服务端
echo "正在配置FRP服务端..."
cat > frps.ini <<EOF
[common]
bind_port = 7000
token = ${TOKEN}
EOF

# 启动FRP服务端
echo "正在启动FRP服务端..."
nohup ./frps -c frps.ini > frps.log 2>&1 &

# 配置systemd服务（开机自启）
echo "正在配置systemd服务..."
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

# 输出配置信息
echo "FRP服务端已启动！"
echo "----------------------------------------"
echo "服务端配置:"
echo "- 监听端口: 7000"
echo "- Token: ${TOKEN}"
echo "----------------------------------------"
echo "客户端配置示例 (frpc.ini):"
cat <<EOF
[common]
server_addr = ${SERVER_IP}
server_port = 7000
token = ${TOKEN}

[ssh]
type = tcp
local_ip = 127.0.0.1
local_port = 22
remote_port = 6000
EOF
echo "----------------------------------------"
echo "日志文件: $(pwd)/frps.log"
echo "管理命令: systemctl status frps"

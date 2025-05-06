#!/bin/bash

# 检查root权限
if [ "$(id -u)" != "0" ]; then
    echo "请使用root用户运行此脚本！"
    exit 1
fi

# 安装依赖
apt update && apt install -y wget unzip curl

# 交互式设置安装目录
read -p "请输入FRP安装目录 [默认: /root/frp]: " INSTALL_DIR
INSTALL_DIR=${INSTALL_DIR:-/root/frp}
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR" || exit

# 获取公网IP（自动检测IPv4/IPv6）
PUBLIC_IP=$(curl -s icanhazip.com)
if [[ $PUBLIC_IP == *":"* ]]; then
    echo "检测到IPv6地址: $PUBLIC_IP"
    BIND_ADDR="::"
else
    echo "检测到IPv4地址: $PUBLIC_IP"
    BIND_ADDR="0.0.0.0"
fi

# 交互式输入配置
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

# 配置FRP服务端
cat > frps.ini <<EOF
[common]
bind_addr = ${BIND_ADDR}
bind_port = ${BIND_PORT}
token = ${TOKEN}
EOF

# 启动服务端
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

# 创建全局快捷命令 frp
cat > /usr/local/bin/frp <<EOF
#!/bin/bash
CONFIG_FILE="$(pwd)/frps.ini"
LOG_FILE="$(pwd)/frps.log"

case "\$1" in
    -k)
        systemctl status frps
        ;;
    -pz)
        cat "\$CONFIG_FILE"
        ;;
    -xz)
        echo "正在卸载FRP..."
        systemctl stop frps
        systemctl disable frps
        rm -f /etc/systemd/system/frps.service
        systemctl daemon-reload
        rm -rf "$INSTALL_DIR" /usr/local/bin/frp
        sed -i '/alias frp/d' /root/.bashrc
        echo "FRP 已完全卸载！"
        ;;
    *)
        echo "用法:"
        echo "  frp -k    # 查看服务状态"
        echo "  frp -pz   # 查看配置文件"
        echo "  frp -xz   # 卸载FRP服务"
        exit 1
        ;;
esac
EOF

chmod +x /usr/local/bin/frp

# 添加别名到 .bashrc（兼容性优化）
echo "alias frp-k='frp -k'" >> /root/.bashrc
echo "alias frp-pz='frp -pz'" >> /root/.bashrc
echo "alias frp-xz='frp -xz'" >> /root/.bashrc
source /root/.bashrc

# 输出配置信息
echo "----------------------------------------"
echo "FRP服务端已启动！"
echo "安装目录: $(pwd)"
echo "公网地址: ${PUBLIC_IP}"
echo "服务端端口: ${BIND_PORT}"
echo "Token: ${TOKEN}"
echo "----------------------------------------"
echo "客户端配置示例 (frpc.ini):"
cat <<EOF
[common]
server_addr = ${PUBLIC_IP}
server_port = ${BIND_PORT}
token = ${TOKEN}

[ssh]
type = tcp
local_ip = 127.0.0.1
local_port = 22
remote_port = 6000
EOF
echo "----------------------------------------"
echo "快捷命令:"
echo "frp -k    # 查看状态"
echo "frp -pz   # 查看配置"
echo "frp -xz   # 卸载服务"
echo "----------------------------------------"

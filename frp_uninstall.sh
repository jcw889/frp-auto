#!/bin/bash
systemctl stop frps 2>/dev/null
systemctl disable frps 2>/dev/null
rm -f /etc/systemd/system/frps.service
systemctl daemon-reload
rm -rf /root/frp_* frp.tar.gz frps.log /root/frps.ini
echo "FRP 已卸载完成！"

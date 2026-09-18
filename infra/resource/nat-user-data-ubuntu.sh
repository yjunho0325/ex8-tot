#!/bin/bash
# 로그를 확인하기 위해 출력 기록 (선택사항)
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>&1)

echo "=== 1. 시스템 업데이트 및 필수 패키지 설치 ==="
export DEBIAN_FRONTEND=noninteractive
apt update
apt install -y iptables-persistent cron

echo "=== 2. IP 포워딩 활성화 ==="
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

echo "=== 3. 기본 네트워크 인터페이스 자동 탐지 및 iptables NAT 설정 ==="
# 기본 게이트웨이가 연결된 네트워크 인터페이스 이름을 자동으로 찾습니다 (예: ens5 또는 eth0)
DEFAULT_IFACE=$(ip route show default | awk '/default/ {print $5}')
echo "Detected default interface: $DEFAULT_IFACE"

# NAT Masquerade 규칙 적용
iptables -t nat -A POSTROUTING -o "$DEFAULT_IFACE" -j MASQUERADE

echo "=== 4. iptables 규칙 영구 저장 및 서비스 활성화 ==="
netfilter-persistent save
systemctl enable netfilter-persistent
systemctl start netfilter-persistent

systemctl enable cron
systemctl start cron

echo "=== NAT Instance Setup Completed Successfully! ==="
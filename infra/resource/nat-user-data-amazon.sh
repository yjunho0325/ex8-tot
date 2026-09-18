#!/bin/bash
# 1. 시스템 업데이트 및 iptables 서비스 설치
dnf update -y
dnf install -y iptables-services

# 2. IP 포워딩 활성화 (커널 레벨)
# 패킷이 인스턴스를 통과할 수 있게 허용합니다.
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

# 3. iptables NAT 규칙 설정
# t3 시리즈의 기본 인터페이스 이름은 ens5입니다.
# 프라이빗 IP를 퍼블릭 IP로 변환(Masquerade)합니다.
iptables -t nat -A POSTROUTING -o ens5 -j MASQUERADE

# 4. 설정 영구 저장 및 서비스 시작
# 재부팅 시에도 iptables 규칙이 자동으로 로드되도록 합니다.
service iptables save
systemctl enable iptables
systemctl start iptables

# 5. 상태 체크를 위한 클론탭 설치
dnf install cronie -y
systemctl enable crond
systemctl start crond
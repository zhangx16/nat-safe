#!/usr/bin/env bash
set -euo pipefail
[[ ${EUID} -eq 0 ]] || { echo '请以 root 运行' >&2; exit 1; }
[[ $# -eq 0 || ( $# -eq 1 && $1 == --timer ) ]] || { echo '用法: bash install.sh [--timer]' >&2; exit 1; }
command -v python3 >/dev/null
command -v ss >/dev/null || { echo '需要 iproute2 提供的 ss' >&2; exit 1; }
python3 -c 'import sys; assert sys.version_info >= (3, 9), "需要 Python 3.9+"'
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
install -d -m 755 /opt/nat-safe
install -m 755 "$source_dir/nat_safe.py" /opt/nat-safe/nat_safe.py
install -m 644 "$source_dir/rfw_audit.py" /opt/nat-safe/rfw_audit.py
install -d -m 755 /opt/nat-safe/third_party /opt/nat-safe/docs
install -m 644 "$source_dir/third_party/RFW-LICENSE-MIT.txt" /opt/nat-safe/third_party/RFW-LICENSE-MIT.txt
install -m 644 "$source_dir/docs/rfw-rules.md" /opt/nat-safe/docs/rfw-rules.md
install -m 644 "$source_dir/rules.json" /opt/nat-safe/rules.json
install -d -m 700 /etc/nat-safe /var/log/nat-safe /var/lib/nat-safe
if [[ ! -e /etc/nat-safe/config.json ]]; then
  install -m 600 "$source_dir/config.example.json" /etc/nat-safe/config.json
fi
if [[ ${1:-} == --timer ]]; then
  command -v systemctl >/dev/null
  install -m 644 "$source_dir/systemd/nat-safe.service" /etc/systemd/system/nat-safe.service
  install -m 644 "$source_dir/systemd/nat-safe.timer" /etc/systemd/system/nat-safe.timer
  systemctl daemon-reload
  systemctl enable --now nat-safe.timer
fi
echo '已安装。只读检查: python3 /opt/nat-safe/nat_safe.py --config /etc/nat-safe/config.json'

# NAT Safe

适用于 NAT VPS 宿主机的进程、启动项与多地区共享使用检测工具。支持 **Podman、Docker、Incus**，对独角鲸 Narwhal Agent 的 TCP/UDP 端口映射做专门归属识别。

**默认只检测，不停止程序、不删客户文件、不修改防火墙。** 可显式选择容器和规则，终止命中进程，或停止整个容器。提供 JSON、Markdown、HTML 报告，原始进程参数不会写入报告。

## 快速开始

依赖：Linux、root、Python **3.9+**、`ss`（iproute2）；容器使用原有管理命令。无需 pip 即可完成基础检查。

```bash
git clone https://github.com/zhangx16/nat-safe.git
cd nat-safe
sudo python3 nat_safe.py
```

默认报告：`/var/log/nat-safe/report-*.{json,md,html}`；状态与缓存：`/var/lib/nat-safe/`。目录权限 700、文件 600，默认保留 30 天。报告包含真实 IP 和容器标识，**不要提交到公开仓库**。HTML 报告可下载到本地打开。

配置与自定义输出：

```bash
cp config.example.json config.json
sudo python3 nat_safe.py --config ./config.json \
  --output /root/nat-safe-reports --state-dir /root/nat-safe-state
```

## RFW 规则扩展（v0.2）

已核对 Rust Firewall 的 README 与实际源码，并合入：默认 SMTP 外连端口检查、可选国家黑白名单审计、短时 HTTP/SOCKS5/WireGuard/QUIC 协议观察、可选 FET 统计推断，以及现有 RFW 端口访问统计导入。详见 [RFW 规则对照与限制](docs/rfw-rules.md)。

```bash
# 显式启用被动采样；eth0 请替换为实际公网网卡名
sudo python3 nat_safe.py --capture-interface eth0 --capture-seconds 5

# 导入现有 RFW 的未分组统计，不启动或修改防火墙
sudo python3 nat_safe.py --rfw-stats /root/rfw-stats.txt
```

默认仍不抓包、不拦截。协议存在不自动等同滥用，FET 不证明某种代理；历史 Blocked 次数不会当作客户在线数。

## 检测范围

`rules.json` 包含用户指定的 14 类可编辑规则：发包工具、扫描工具、Flood/DDoS、代理面板、挖矿、机场对接后端、弱加密参数、DD 重装、MTProto、跑分压测、无头浏览器、爆破撞库、传统 VPN、SOCKS/开放代理程序。正则默认不区分大小写。

- 枚举宿主机 `/proc`，通过 cgroup/PID namespace 归属到容器，记录 PID、可执行文件、RSS 和短时 CPU。
- 检查 systemd、OpenRC、cron、rc.local 等常见启动目录。systemd 只匹配执行指令，忽略 Description；OpenRC 的 `use openvpn` 等依赖声明不会算违规进程。
- 运行与停止的容器都被列出。停止容器仅在可写层目录可访问时扫描该层，**不挂载、不启动**容器，不保证覆盖其基础镜像/外部卷。
- Microsocks / Dante 命中会附带认证配置线索。带认证 SOCKS 不等于匿名开放代理；`danted` 多个工作进程也不等于多个违规客户。不会尝试密码或连接第三方目标。
- 记录 TCP 状态、监听端口、入站公网来源；Narwhal 使用宿主机转发时，从 `/opt/narwhal-agent/agent.db` 只读关联实际容器，排除默认 SSH 22 和管理端口 8792。
- 可选 `conntrack` 检查 UDP DNAT，排除 UNREPLIED 探测；只接受目标地址属于本机的原始入站元组。

单次检查不代表历史无违规：改名工具、自编程序、仅在短时运行的程序、启动脚本间接下载的代码可能漏检。不会检查所有应用配置、客户流量内容、浏览器历史或客户账户。`httpx`、`stress` 等也可能用于正常业务；规则命中是线索，需结合服务条款和业务说明。

## 多地区 / 疑似机场共享

只统计**当前入站使用者**，不会把访问的 Google/CDN/网站 IP 当客户来源。同一来源多连接去重；默认排除 SSH 管理连接。公网 IP/国家不代表真实人数，地区资料也可能不准确，家庭共享、旅行、VPN 出口可能误报。

默认规则：同一次采样 **至少 5 个公网 IP，至少 3 个国家**；连续 3 次满足、持续至少 120 秒，提升为高风险“疑似跨地区共享”。首次命中为中风险；必须连续满足，断开/采样间隔超过 15 分钟则重新计数。国家层级可改为省州层级。持久状态放在同一 `--state-dir` 下。

**默认不向外部发送 IP**。没有 GeoIP 资料时，只报告“多个来源、地区证据不足”。二选一开启地理识别：

```bash
# 方式一：离线数据库，推荐；自行获取合法授权的 GeoLite2/GeoIP2 Country 或 City .mmdb
# 在虚拟环境安装可选 maxminddb；然后使用该环境的 Python 运行
python3 -m venv .venv
.venv/bin/pip install maxminddb
sudo .venv/bin/python nat_safe.py --geo-db /path/to/GeoLite2-City.mmdb --watch 60

# 方式二：显式同意将入站客户的公网 IP 发送给 ipwho.is 查询
sudo python3 nat_safe.py --geo-provider ipwhois --watch 60
```

在线查询走 HTTPS、缓存 24 小时，每次扫描最多 100 次查询，可用 `max_geo_lookups` 调整。第三方不可用/额度不足/数据库缺失地区时，不会把未知结果算成地区证据。IPv4/IPv6 支持；UDP 活跃记录不精确，UDP/QUIC、Cloudflare/其他隧道、多用户共用 NAT 可能隐藏实际用户。共享宿主机网络命名空间的容器会标注跳过，避免混淆归属。

跨地区线索**始终只报告，不作为自动处罚触发器**。客户业务经人工核实后，可选择已确认的程序规则处置。若所有来源都来自同一个代理/隧道出口，本工具不能还原隧道后的真实用户。无法据此证明商业机场收费或人数。

修改阈值示例：

```json
{
  "min_client_ips": 5,
  "min_geo_regions": 3,
  "min_consecutive_samples": 3,
  "min_geo_duration_seconds": 120,
  "geo_level": "region",
  "exclude_client_ports": [22, 8792, 2222],
  "allowlist": [
    {"container": "EXACT-CONTAINER-ID", "rules": ["proxy-panel"],
     "expires": "2027-01-01T00:00:00Z", "reason": "已核实自用，允许面板"}
  ]
}
```

`region` 使用国家+省/州代码，需 City 级数据库或在线查询有对应数据。数据库只有国家时，不把未知省份算作多个地区。白名单必须匹配完整 ID 和规则；可设置到期时间。

## 人工复核后的处置

先查看报告中的 `scope`（完整容器 ID）、`rule`、PID、认证线索与对应业务。再次运行时会重新采集和复核，不会直接执行旧报告里的 PID。

```bash
# 向某容器中命中的挖矿进程发 SIGTERM；不删除任何文件
sudo python3 nat_safe.py --enforce \
  --select EXACT-CONTAINER-ID --rule miner --action terminate

# 确认某容器运行被禁止的机场后端后，停止整个容器（同时中断网络）
sudo python3 nat_safe.py --enforce \
  --select EXACT-CONTAINER-ID --rule airport-node --action stop-container

# 参数 --select、--rule 都可重复，必须明确指定
```

处置边界：

- 默认 audit；`--enforce` 必须同时指定容器、规则。**HOST 进程禁止处置**。
- 必须有当前运行的进程命中；只有启动项文件、地区推断或过期 PID 时拒绝处置。
- 证据先写盘，再执行动作，动作结果与恢复命令随后更新报告。
- 终止使用 pidfd 并复核启动时间/可执行文件，避免 PID 复用误杀。需要内核与 Python 支持；不支持时拒绝，而非退回不安全的 kill PID。
- `terminate` 只发 SIGTERM；systemd/其他守护程序可能拉起它，脚本不会删除启动项。
- `stop-container` 调用运行时正常停止，超时可能由运行时强制结束。保留全部数据，报告提供 `podman/docker/incus start ...` 恢复命令；平台或其他守护程序仍可能重新启动实例。
- 不自动销毁容器，不拉黑平台客户，不改密码，不切断宿主机 SSH，不发送客户通知。

## 安装与定时巡检

```bash
sudo bash install.sh          # 安装到 /opt/nat-safe，不启动任务
sudo bash install.sh --timer  # 安装并启用每分钟 audit 定时任务
```

安装不会覆盖已有 `/etc/nat-safe/config.json`。定时任务默认不调用在线 GeoIP。可修改 `/etc/systemd/system/nat-safe.service` 的 `ExecStart` 加 `--geo-db`（若用虚拟环境，还需修改 Python 路径），再执行 `systemctl daemon-reload`。查看：

```bash
systemctl status nat-safe.timer
journalctl -u nat-safe.service
```

停止定时巡检：`systemctl disable --now nat-safe.timer`。同一状态目录有文件锁，防止手动任务与定时任务同时运行。所有采集错误、不可读路径和截断覆盖都会进入报告，不能把采集失败视为检查通过。

## 测试

```bash
python3 -m unittest discover -s tests -v
python3 -m py_compile nat_safe.py rfw_audit.py
```

覆盖误报过滤、规则、凭据脱敏、IPv6、入站/出站区分、持续多地区阈值、地区未知、白名单到期、宿主机保护、PID 过期保护和报告权限/HTML 转义。`examples/` 只有合成数据，不含客户信息。

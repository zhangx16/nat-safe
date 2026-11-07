# NAT Safe 检测报告

时间：2026-11-07T00:00:00+00:00
主机：example-host
模式：audit

名称/正则命中是待核实证据，不自动证明滥用。多地区来源属于推断。

|级别|容器|规则|证据|状态|
|---|---|---|---|---|
|medium|demo-container|代理面板|PID 12345 /usr/local/x-ui/x-ui|needs_review|
|info|demo-container|观察到明文 HTTP 入站|{"protocol": "http", "host_port": 30000, "guest_port": 8080, "observed_packets": 2, "payload_saved": false}|observation|

## 检查覆盖与限制

- 运行中进程及常见启动目录；停止容器仅检查可访问的可写层启动文件。
- 进程参数参与匹配，但不会写入报告，避免暴露账号、密码、令牌。
- 多地区检测仅使用入站来源；出站网站/CDN IP 不作为用户来源。
- 默认不联网查 IP；无地区资料时会标记证据不足。
- UDP 依赖 conntrack；单次快照无法证明历史行为，隧道可能隐藏用户。
- 未扫描全部磁盘文件、用户 shell 历史、所有应用配置或远端业务。
- HTTP/SOCKS5/WireGuard/QUIC 是协议观察，不自动等同违规；FET 只是统计推断。
- RFW 累积访问计数不当作活跃用户，受攻击的容器不因被阻断访问而受罚。

## RFW 扩展覆盖

```json
{
  "capture": {
    "enabled": true,
    "interface": "example0",
    "sampled_packets": 10,
    "payload_saved": false
  },
  "country_policy": {
    "mode": "off"
  },
  "smtp": "destination-port heuristic"
}
```

## RFW 历史端口访问计数

```json
[]
```

## 处置记录

```json
[]
```

## 采集异常

```json
[]
```

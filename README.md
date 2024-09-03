# Shadowsocks企业应用案例

## 概述
[shadowsocks](https://github.com/shadowsocks)是一款极为优秀的开源免费代理服务器软件，支持服务器、桌面、移动端几乎所有平台。
它开创性地将服务分成两部分：本地端(sslocal)和远程端(ssserver)。
本地端为用户提供各种代理服务（socks4/socks5/http/transparent等），
远程端相当于本地端的延申，与本地端之间采用独创的加密通讯协议（俗称“ss协议”）进行连接。
一个远程端可支持多个本地端连接，一个本地端可连接多个远程端从而实现负载均衡/高可用（LB/HA）。

shadowsocks最初是用python编写的，其后出现了C、C++、Go、Rust等许多实现：
- 非移动平台（Linux/Windows/macOS）最优秀的是[Rust版](https://github.com/shadowsocks/shadowsocks-rust)
- Windows还有个极为优秀的[C#版](https://github.com/shadowsocks/shadowsocks-windows)本地端
- [Andriod](https://github.com/shadowsocks/shadowsocks-android)本地端
- iOS常用本地端：shadowrocket(收费)/shadowlink/Potasto

shadowsocks为企业应用提供了完备的功能（动态管理接口、API等）。本文基于Rust版，仅以三个案例来说明shadowsocks的典型企业应用场景，并提供常用配置文件模板。

## 安装

案例中，shadowsocks-rust使用如下路径：

|      | Linux        | Windows       |
| ---- | -----------  | ------------- |
| 程序 | /opt/ss/     | c:\ss\        |
| 配置 | /etc/ss/     | c:\ss\config\ |
| 日志 | /var/log/ss/ | c:\ss\log\    |

模板中，`sss.service`和`ssl.service`分别是远程端和本地端的Linux systemd服务配置文件，要使用哪个，就把它放到`/usr/lib/systemd/system/`下面，然后设置服务：
```bash
systemctl daemon-reload
systemctl enable sss
systemctl enable ssl
```

在Windows上，可使用PowerShell设置服务。本地端和远程端设置如下：

```powershell
New-Service -Name "sslocal" `
            -DisplayName "Shadowsocks本地端服务" `
            -BinaryPathName "c:\ss\sswinservice.exe local -c c:\ss\config\ssl.json" `
            -StartupType "Automatic" `
            -DependsOn "Tcpip"

New-Service -Name "ssserver" `
            -DisplayName "Shadowsocks远程端服务" `
            -BinaryPathName "c:\ss\sswinservice.exe server -c c:\ss\config\sss.json" `
            -StartupType "Automatic" `
            -DependsOn "Tcpip"
```

可根据具体应用场景，修改模板配置文件。

## 用户

用户设备需要通过代理服务器来访问目标网络。通过设置**系统代理服务器**，可以使系统中的所有应用都通过代理服务器进行访问。
但是，通常需要精确控制哪些应用对哪些目标的访问经由哪些代理服务器，此时，如果相关应用直接支持代理服务器（例如Foxmail、QQ等），
可以在应用中直接设置；否则，需要使用单独的代理服务器接入工具，为那些不支持代理服务器的应用接入代理服务器。
常用的代理服务器接入工具有：
[SwitchyOmega](https://github.com/FelisCatus/SwitchyOmega)(GPL3)，
[proxychains](https://github.com/rofl0r/proxychains-ng)(GPL2)，
[proxychains-windows](https://github.com/shunf4/proxychains-windows)(GPL2)，
[Proxifier](http://www.proxifier.com)(收费)，
[SocksCap64](https://www.sockscap64.com/homepage/)(免费，但是禁止商用)等。

## 案例

### 1：纯本地端实现SOCKS5代理

应用场景1：某IT企业为其客户提供IT服务，需要远程接入客户内网。
客户为服务企业提供了SD-WAN解决方案，在服务企业的内网通过一台VeloCloud Edge设备接入客户内网。
但是，由于服务企业的项目组成员不是固定的、办公场所也不是固定的，所以无法通过集中办公来接入SD-WAN。
此时，可以使用一台设备同时接入内网和SD-WAN，并在内网IP地址上提供SOCKS5代理服务，供所有项目组成员使用。

应用场景2：某IT企业为其客户提供IT服务，需要远程接入客户内网。
客户为服务企业提供了远低于项目组成员数量的有限的几个VPN客户端，导致项目组成员无法同时接入客户内网。
此时，可以使用一台内网中的设备连接客户的VPN，然后在内网IP地址上提供SOCKS5代理服务，供所有项目组成员使用。

shadowsocks本地端配置文件`/etc/ss/ssl.json`（主要配置行，其他内容参见模板；下同）：
```jsonc
{
    "locals": [
        {
            "acl": "/etc/ss/ssl.acl",
            "socks5_auth_config_path": "/etc/ss/auth.json",
            "local_address": "192.168.250.60",
            "local_port": 1080
         }
    ],

    // 这里给一个不存在的远程端（用不上），因为本地端直接完成代理服务而不转发到远程端
    "servers": [
        {
            "address": "127.0.0.1",
            "port": 60000,
            "method": "none"
        }
    ]
}
```

假设要访问的客户网络为10.100.8.0/24和10.200.1.0/24，则shadowsocks本地端访问控制配置文件`/etc/ss/ssl.acl`：
```haproxy
[proxy_all]

[bypass_list]
10.100.8.0/24
10.200.1.0/24
```

这样，项目组成员就可以通过SOCKS5代理服务器192.168.250.60:1080来访问客户网络10.100.8.0/24和10.200.1.0/24。

### 2：本地端+远程端实现SOCKS5代理+LB/HA

应用场景：某科研单位的日常工作中大量使用境外网络资源(Google、ChatGPT、Wikipedia、Github等)，需要保持可访问性和稳定性。
此时，可以租用阿里云服务器美国区域、亚马逊云服务器新加坡区域、微软云服务器等，安装shadowsocks远程端，
然后在单位内网的一台设备上安装shadowsocks本地端提供SOCKS5代理服务，供单位人员使用。

假设租用了3台云服务器，它们上面都安装shadowsocks远程端，其配置文件`/etc/ss/sss.json`：
```jsonc
{
    "servers": [
        {
            "acl": "/etc/ss/sss.acl",
            "server": "0.0.0.0",
            "server_port": 8443,
            "method": "aes-256-gcm",
            "password": "Password@Port:8443"
        }
    ]
}
```

远程端只接受科研单位的公网IP连接。假设有两个公网IP：a.a.a.a，b.b.b.b，则访问控制配置文件`/etc/ss/sss.acl`：
```haproxy
[reject_all]

[white_list]
a.a.a.a
b.b.b.b
```

在科研单位内网的一台Linux上安装shadowsocks本地端。假设3台云服务器的公网IP地址为x.x.x.x，y.y.y.y，z.z.z.z，
则本地端配置文件`/etc/ss/ssl.json`：
```jsonc
{
    "locals": [
        {
            "acl": "/etc/ss/ssl.acl",
            "socks5_auth_config_path": "/etc/ss/auth.json",
            "local_address": "192.168.250.60",
            "local_port": 1081
         }
    ],

    "servers": [
        {
            "tcp_weight": 1.0,
            "address": "x.x.x.x",
            "port": 8443,
            "method": "aes-256-gcm",
            "password": "Password@Port:8443"
        },
        {
            "tcp_weight": 0.8,
            "address": "y.y.y.y",
            "port": 8443,
            "method": "aes-256-gcm",
            "password": "Password@Port:8443"
        },
        {
            "tcp_weight": 0.8,
            "address": "z.z.z.z",
            "port": 8443,
            "method": "aes-256-gcm",
            "password": "Password@Port:8443"
        }
    ]
}
```

本地端应限制访问哪些目标需要转发到远程端，因此其访问控制配置文件`/etc/ss/ssl.acl`：
```haproxy
[bypass_all]

[proxy_list]
||google.com
||chatgpt.com
||wikipedia.org
||github.com
```

这样，科研单位员工就可以通过SOCKS5代理服务器192.168.250.60:1080来访问这些境外网络资源了。

### 3：本地端+远程端+nftables实现透明代理+LB/HA

应用场景：一台Linux邮件服务器只有一个外网IP地址，这个IP地址常常会被一些邮件服务器列入黑名单，从而造成部分邮件无法投递。
此时，可以在其他网络中设置几台shadowsocks远程端，在邮件服务器上安装shadowsocks本地端提供透明代理，
用netfilters规则把对目标SMTP端口（25）的访问（SMTP发送邮件）重定向到透明代理端口，使之通过shadowsocks远程端来完成。

假设在外网有另外两台发件服务器，在它们上面都安装shadowsocks远程端，配置文件`/etc/ss/sss.json`：
```jsonc
{
    "servers": [
        {
            "acl": "/etc/ss/sss.acl",
            "server": "0.0.0.0",
            "server_port": 8443,
            "method": "aes-256-gcm",
            "password": "Password@Port:8443"
        }
    ]
}
```

访问控制配置文件`/etc/ss/sss.acl`配置成仅接受邮件服务器公网IP地址连接，不再赘述。

另外，邮件服务器自身也应该是LB/HA的一部分，因此也应安装shadowsocks远程端，配置文件`/etc/ss/sss.json`：
```jsonc
{
    "servers": [
        {
            "acl": "/etc/ss/sss.acl",
            "server": "127.0.0.1",
            "server_port": 8388,
            "method": "none"   // 远程端和本地端都在本机，无需加密
        }
    ],

    // 本机上配合透明代理，必须设置Outbound socket SO_MARK供netfilters使用：
    "outbound_fwmark": 255
}
```

在邮件服务器上使用shadowsocks本地端提供透明代理服务，把外出连接以LB/HA方式转发到3个远程端。
假设两个外部服务器的公网IP地址为x.x.x.x，y.y.y.y，则配置文件`/etc/ss/ssl.json`：
```jsonc
{
    // 本地透明代理：
    "locals": [
        {
            "local_address": "127.0.0.1",
            "local_port": 8389,
            "protocol": "redir",
            "tcp_redir": "redirect"
        }
    ],

    // 3个远程端服务器：
    "servers": [
        {   // 这个服务器在本机
            "tcp_weight": 1.0,
            "address": "127.0.0.1",
            "port": 8388,
            "method": "none"
        },
        {
            "tcp_weight": 0.8,
            "address": "x.x.x.x",
            "port": 8443,
            "method": "aes-256-gcm",
            "password": "Password@Port:8443"
        },
        {
            "tcp_weight": 0.8,
            "address": "y.y.y.y",
            "port": 8443,
            "method": "aes-256-gcm",
            "password": "Password@Port:8443"
        }
    ]
}
```

邮件服务器上必须设置netfilters规则把对目标SMTP端口的访问重定向到透明代理端口8389。
假设Linux服务器的外出访问网卡名为`eth0`，则nftables规则如下：

```haproxy
chain nat_output {
    type nat hook output priority dstnat; policy accept;
    oifname "eth0" tcp dport smtp socket mark !=255 redirect to :8389
}
```

## 许可

1. 本仓库所有内容是免费的、公开的、不限商用的，允许转载、摘录/引用，但必须遵守如下限制：
- 转载限制：必须注明原著作权人版权和原文出处，必须公开、免费发布，不允许以任何方式收费阅读（除非获得原著作权人书面授权）。
- 摘录/引用限制：必须在参考文献中列出原文出处，所形成的新作品版权归新作品著作权人所有，但其任何非纸质版本不允许以任何方式收费阅读（除非获得原著作权人书面授权）。

2. 使用本仓库的任何内容，必须遵循[《GNU通用公共许可协议》](https://www.gnu.org/licenses/)第三版的第15、16、17条之规定。

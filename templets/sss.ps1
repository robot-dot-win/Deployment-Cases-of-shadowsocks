# shadowsocks远程端Windows服务设置
#
# Copyright(C) 2025, Martin Young <martin_young@live.cn>
#------------------------------------------------------------

$serviceName = "ssserver"

New-Service -Name $serviceName `
            -DisplayName "Shadowsocks远程端服务" `
            -BinaryPathName "c:\ss\sswinservice.exe server -c c:\ss\config\sss.json" `
            -StartupType "Automatic" `
            -DependsOn "Tcpip"

# 日志级别：trace=0, debug=1, info=2, warn=3, error=4, off(pseudo level to disable all logging for the target)
$environmentVariables = "RUST_LOG=info,shadowsocks_rust::service::server=debug"
$registryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$serviceName"

Set-ItemProperty -Path $registryPath -Name "Environment" -Value $environmentVariables -Type MultiString -Force

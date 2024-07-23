#!/usr/bin/env bash

# 设置各变量
WSPATH=${WSPATH:-'glitch'}  # WS 路径前缀。(注意:伪装路径不需要 / 符号开始,为避免不必要的麻烦,请不要使用特殊符号.)
UUID=${UUID:-'de04add9-5c68-8bab-950c-08cd5320df18'}
WEB_USERNAME=${WEB_USERNAME:-'admin'}
WEB_PASSWORD=${WEB_PASSWORD:-'password'}

# 生成 xr 配置文件
generate_xr() {
  cat > xr.json << EOF
{
    "log":{
        "access":"/dev/null",
        "error":"/dev/null",
        "loglevel":"none"
    },
    "inbounds":[
        {
            "port":8080,
            "protocol":"vless",
            "settings":{
                "clients":[
                    {
                        "id":"${UUID}",
                        "flow":"xtls-rprx-vision"
                    }
                ],
                "decryption":"none",
                "fallbacks":[
                    {
                        "dest":3001
                    },
                    {
                        "path":"/${WSPATH}-vl",
                        "dest":3002
                    },
                    {
                        "path":"/${WSPATH}-vm",
                        "dest":3003
                    },
                    {
                        "path":"/${WSPATH}-tr",
                        "dest":3004
                    },
                    {
                        "path":"/${WSPATH}-ss",
                        "dest":3005
                    }
                ]
            },
            "streamSettings":{
                "network":"tcp"
            }
        },
        {
            "port":3001,
            "listen":"127.0.0.1",
            "protocol":"vless",
            "settings":{
                "clients":[
                    {
                        "id":"${UUID}"
                    }
                ],
                "decryption":"none"
            },
            "streamSettings":{
                "network":"ws",
                "security":"none"
            }
        },
        {
            "port":3002,
            "listen":"127.0.0.1",
            "protocol":"vless",
            "settings":{
                "clients":[
                    {
                        "id":"${UUID}",
                        "level":0
                    }
                ],
                "decryption":"none"
            },
            "streamSettings":{
                "network":"ws",
                "security":"none",
                "wsSettings":{
                    "path":"/${WSPATH}-vl"
                }
            },
            "sniffing":{
                "enabled":true,
                "destOverride":[
                    "http",
                    "tls",
                    "quic"
                ],
                "metadataOnly":false
            }
        },
        {
            "port":3003,
            "listen":"127.0.0.1",
            "protocol":"vmess",
            "settings":{
                "clients":[
                    {
                        "id":"${UUID}",
                        "alterId":0
                    }
                ]
            },
            "streamSettings":{
                "network":"ws",
                "wsSettings":{
                    "path":"/${WSPATH}-vm"
                }
            },
            "sniffing":{
                "enabled":true,
                "destOverride":[
                    "http",
                    "tls",
                    "quic"
                ],
                "metadataOnly":false
            }
        },
        {
            "port":3004,
            "listen":"127.0.0.1",
            "protocol":"trojan",
            "settings":{
                "clients":[
                    {
                        "password":"${UUID}"
                    }
                ]
            },
            "streamSettings":{
                "network":"ws",
                "security":"none",
                "wsSettings":{
                    "path":"/${WSPATH}-tr"
                }
            },
            "sniffing":{
                "enabled":true,
                "destOverride":[
                    "http",
                    "tls",
                    "quic"
                ],
                "metadataOnly":false
            }
        },
        {
            "port":3005,
            "listen":"127.0.0.1",
            "protocol":"shadowsocks",
            "settings":{
                "clients":[
                    {
                        "method":"chacha20-ietf-poly1305",
                        "password":"${UUID}"
                    }
                ],
                "decryption":"none"
            },
            "streamSettings":{
                "network":"ws",
                "wsSettings":{
                    "path":"/${WSPATH}-ss"
                }
            },
            "sniffing":{
                "enabled":true,
                "destOverride":[
                    "http",
                    "tls",
                    "quic"
                ],
                "metadataOnly":false
            }
        }
    ],
    "dns":{
        "servers":[
            "https+local://8.8.8.8/dns-query"
        ]
    },
    "outbounds":[
        {
            "protocol":"freedom"
        },
        {
            "tag":"WARP",
            "protocol":"wireguard",
            "settings":{
                "secretKey":"YFYOAdbw1bKTHlNNi+aEjBM3BO7unuFC5rOkMRAz9XY=",
                "address":[
                    "172.16.0.2/32",
                    "2606:4700:110:8a36:df92:102a:9602:fa18/128"
                ],
                "peers":[
                    {
                        "publicKey":"bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
                        "allowedIPs":[
                            "0.0.0.0/0",
                            "::/0"
                        ],
                        "endpoint":"162.159.193.10:2408"
                    }
                ],
                "reserved":[78, 135, 76],
                "mtu":1280
            }
        }
    ],
    "routing":{
        "domainStrategy":"AsIs",
        "rules":[
            {
                "type":"field",
                "domain":[
                    "domain:openai.com",
                    "domain:ai.com"
                ],
                "outboundTag":"WARP"
            }
        ]
    }
}
EOF
}

generate_ar() {
  cat > ar.sh << ABC
#!/usr/bin/env bash

AR_AUTH=${AR_AUTH}
AR_DOMAIN=${AR_DOMAIN}
SSH_DOMAIN=${SSH_DOMAIN}

# 下载并运行 ar
check_file() {
  [ ! -e ar ] && wget -O ar https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 && chmod +x ar
}

run() {
  if [[ -n "\${AR_AUTH}" && -n "\${AR_DOMAIN}" ]]; then
    if [[ "\$AR_AUTH" =~ TunnelSecret ]]; then
      echo "\$AR_AUTH" | sed 's@{@{"@g;s@[,:]@"\0"@g;s@}@"}@g' > tunnel.json
      cat > tunnel.yml << EOF
tunnel: \$(sed "s@.*TunnelID:\(.*\)}@\1@g" <<< "\$AR_AUTH")
credentials-file: /app/tunnel.json
protocol: http2

ingress:
  - hostname: \$AR_DOMAIN
    service: http://localhost:8080
EOF
      [ -n "\${SSH_DOMAIN}" ] && cat >> tunnel.yml << EOF
  - hostname: \$SSH_DOMAIN
    service: http://localhost:2222
EOF
    [ -n "\${FTP_DOMAIN}" ] && cat >> tunnel.yml << EOF
  - hostname: \$FTP_DOMAIN
    service: http://localhost:3333
EOF
      cat >> tunnel.yml << EOF
    originRequest:
      noTLSVerify: true
  - service: http_status:404
EOF
      nohup ./ar tunnel --edge-ip-version auto --config tunnel.yml run 2>/dev/null 2>&1 &
    elif [[ "\$AR_AUTH" =~ ^[A-Z0-9a-z=]{120,250}$ ]]; then
      nohup ./ar tunnel --edge-ip-version auto --protocol http2 run --token ${AR_AUTH} 2>/dev/null 2>&1 &
    fi
  else
    nohup ./ar tunnel --edge-ip-version auto --protocol http2 --no-autoupdate --url http://localhost:8080 2>/dev/null 2>&1 &
    sleep 5
    local LOCALHOST=\$(ss -nltp | grep '"ar"' | awk '{print \$4}')
    AR_DOMAIN=\$(wget -qO- http://\$LOCALHOST/quicktunnel | cut -d\" -f4)
  fi
}

export_list() {
  VMESS="{ \"v\": \"2\", \"ps\": \"Ar-Vm\", \"add\": \"icook.hk\", \"port\": \"443\", \"id\": \"${UUID}\", \"aid\": \"0\", \"scy\": \"none\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"\${AR_DOMAIN}\", \"path\": \"/${WSPATH}-vmess?ed=2048\", \"tls\": \"tls\", \"sni\": \"\${AR_DOMAIN}\", \"alpn\": \"\" }"
  cat > list << EOF
*******************************************
V2:
----------------------------
vless://${UUID}@icook.hk:443?encryption=none&security=tls&sni=\${AR_DOMAIN}&type=ws&host=\${AR_DOMAIN}&path=%2F${WSPATH}-vless?ed=2048#Ar-Vl
----------------------------
vmess://\$(echo \$VMESS | base64 -w0)
----------------------------
trojan://${UUID}@icook.hk:443?security=tls&sni=\${AR_DOMAIN}&type=ws&host=\${AR_DOMAIN}&path=%2F${WSPATH}-trojan?ed=2048#ar-Tr
----------------------------
ss://$(echo "chacha20-ietf-poly1305:${UUID}@icook.hk:443" | base64 -w0)@icook.hk:443#Ar-Ss
由于该软件导出的链接不全，请自行处理如下: 传输协议: WS ， 伪装域名: \${AR_DOMAIN} ，路径: /${WSPATH}-shadowsocks?ed=2048 ， 传输层安全: tls ， sni: \${AR_DOMAIN}
*******************************************
小火箭:
----------------------------
vless://${UUID}@icook.hk:443?encryption=none&security=tls&type=ws&host=\${AR_DOMAIN}&path=/${WSPATH}-vless?ed=2048&sni=\${AR_DOMAIN}#Ar-Vl
----------------------------
vmess://$(echo "none:${UUID}@icook.hk:443" | base64 -w0)?remarks=Ar-Vm&obfsParam=\${AR_DOMAIN}&path=/${WSPATH}-vmess?ed=2048&obfs=websocket&tls=1&peer=\${AR_DOMAIN}&alterId=0
----------------------------
trojan://${UUID}@icook.hk:443?peer=\${AR_DOMAIN}&plugin=obfs-local;obfs=websocket;obfs-host=\${AR_DOMAIN};obfs-uri=/${WSPATH}-trojan?ed=2048#Ar-Tr
----------------------------
ss://$(echo "chacha20-ietf-poly1305:${UUID}@icook.hk:443" | base64 -w0)?obfs=wss&obfsParam=\${AR_DOMAIN}&path=/${WSPATH}-shadowsocks?ed=2048#Ar-Ss
*******************************************
Clash:
----------------------------
- {name: Ar-Vl, type: vless, server: icook.hk, port: 443, uuid: ${UUID}, tls: true, servername: \${AR_DOMAIN}, skip-cert-verify: false, network: ws, ws-opts: {path: /${WSPATH}-vless?ed=2048, headers: { Host: \${AR_DOMAIN}}}, udp: true}
----------------------------
- {name: Ar-Vm, type: vmess, server: icook.hk, port: 443, uuid: ${UUID}, alterId: 0, cipher: none, tls: true, skip-cert-verify: true, network: ws, ws-opts: {path: /${WSPATH}-vmess?ed=2048, headers: {Host: \${AR_DOMAIN}}}, udp: true}
----------------------------
- {name: Ar-Tr, type: trojan, server: icook.hk, port: 443, password: ${UUID}, udp: true, tls: true, sni: \${AR_DOMAIN}, skip-cert-verify: false, network: ws, ws-opts: { path: /${WSPATH}-trojan?ed=2048, headers: { Host: \${AR_DOMAIN} } } }
----------------------------
- {name: Ar-Ss, type: ss, server: icook.hk, port: 443, cipher: chacha20-ietf-poly1305, password: ${UUID}, plugin: v2ray-plugin, plugin-opts: { mode: websocket, host: \${AR_DOMAIN}, path: /${WSPATH}-shadowsocks?ed=2048, tls: true, skip-cert-verify: false, mux: false } }
*******************************************
EOF
  cat list
}

check_file
run
export_list
ABC
}

generate_nz() {
  cat > nz.sh << EOF
#!/usr/bin/env bash

# nz的三个参数
NZ_SERVER=${NZ_SERVER}
NZ_PORT=${NZ_PORT}
NZ_KEY=${NZ_KEY}
TLS=${NZ_TLS:+'--tls'}

# 检测是否已运行
check_run() {
  [[ \$(pgrep -lafx nz) ]] && echo "nz客户端正在运行中" && exit
}

# 三个变量不全则不安装nz客户端
check_variable() {
  [[ -z "\${NZ_SERVER}" || -z "\${NZ_PORT}" || -z "\${NZ_KEY}" ]] && exit
}

# 运行 nz 客户端
run() {
  [ -e nz ] && nohup ./nz -s \${NZ_SERVER}:\${NZ_PORT} -p \${NZ_KEY} \${TLS} >/dev/null 2>&1 &
}

check_run
check_variable
run
EOF
}

generate_ttyd() {
  cat > ttyd.sh << EOF
#!/usr/bin/env bash

# 检测是否已运行
check_run() {
  [[ \$(pgrep -lafx ttyd) ]] && echo "ttyd 正在运行中" && exit
}

# ssh ar 域名不设置，则不安装 ttyd 服务端
check_variable() {
  [ -z "\${SSH_DOMAIN}" ] && exit
}

# 下载最新版本 ttyd
download_ttyd() {
  if [ ! -e ttyd ]; then
    URL=\$(wget -qO- "https://api.github.com/repos/tsl0922/ttyd/releases/latest" | grep -o "https.*x86_64")
    URL=\${URL:-https://github.com/tsl0922/ttyd/releases/download/1.7.3/ttyd.x86_64}
    wget -O ttyd \${URL}
    chmod +x ttyd
  fi
}

# 运行 ttyd 服务端
run() {
  [ -e ttyd ] && nohup ./ttyd -c \${WEB_USERNAME}:\${WEB_PASSWORD} -p 2222 bash >/dev/null 2>&1 &
}

check_run
check_variable
download_ttyd
run
EOF
}

# 由于 Glitch 用户空间只有 200MB，故每5秒自动删除垃圾文件
generate_autodel() {
  cat > auto_del.sh <<EOF
while true; do
  rm -rf /app/.git
  sleep 5
done
EOF
}

generate_xr
generate_ar
generate_nz
generate_ttyd
generate_autodel

[ -e nz.sh ] && bash nz.sh
[ -e ar.sh ] && bash ar.sh
[ -e ttyd.sh ] && bash ttyd.sh
[ -e auto_del.sh ] && bash auto_del.sh

#!/bin/bash

# print colored text
red() {
	echo -e "\033[31m\033[01m$1\033[0m"
}

green() {
	echo -e "\033[32m\033[01m$1\033[0m"
}

yellow() {
	echo -e "\033[33m\033[01m$1\033[0m"
}

# Check for root privileges
[[ $EUID -ne 0 ]] && red "Please run the script under the root user" && exit 1

# System related
CMD=(
	"$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)"
	"$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)"
	"$(lsb_release -sd 2>/dev/null)"
	"$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)"
	"$(grep . /etc/redhat-release 2>/dev/null)"
	"$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')"
)

# Legacy stolen
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[36m"
PLAIN="\033[0m"

# System package manager related
REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS")
PACKAGE_UPDATE=("apt-get update" "apt-get update" "yum -y update" "yum -y update")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install")
PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "yum -y autoremove")

for i in "${CMD[@]}"; do
	SYS="$i" && [[ -n $SYS ]] && break
done

for ((int = 0; int < ${#REGEX[@]}; int++)); do
	[[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]] && SYSTEM="${RELEASE[int]}" && [[ -n $SYSTEM ]] && break
done

[[ -z $SYSTEM ]] && red "The current VPS system is not supported, please use a mainstream operating system" && exit 1
[[ -z $(type -P curl) ]] && ${PACKAGE_UPDATE[int]} && ${PACKAGE_INSTALL[int]} curl

# Generate random timeout seconds to counter active probing by GFW

handshake=$(((($RANDOM*6)/32768)+4)) #4-10
connIdle=$(((($RANDOM*201)/32768)+300)) # 300-500
uplinkOnly=$(((($RANDOM*9)/32768)+2)) # 2-10
downlinkOnly=$(((($RANDOM*11)/32768)+5)) # 5-15

set_VMess_withoutTLS() {
    echo ""
    read -p "Please enter the VMess listening port (random by default): " port
    [[ -z "${port}" ]] && port=$(shuf -i200-65000 -n1)
    if [[ "${port:0:1}" == "0" ]]; then
        red "The port cannot start with 0"
        port=$(shuf -i200-65000 -n1) #Randomly generate ports
    fi
    yellow "current port: $port"
    echo ""
    uuid=$(xray uuid) # Directly call the uuid command of Xray to detect whether Xray is installed
    [[ -z "$uuid" ]] && red "Please install Xray first!" && exit 1 # In fact, it is a historical relic, and by the way, it has a function
    getUUID
    yellow "current uuid: $uuid"
    echo ""
    yellow "underlying transport protocol: "
    yellow "1. TCP(default)"
    yellow "2. websocket(ws) (recommend)"
    yellow "3. mKCP"
    yellow "4. HTTP/2"
    green "5. gRPC"
    echo ""
    read -p "please choose: " answer
    case $answer in
        1) transport="tcp" ;;
        2) transport="ws" ;;
        3) transport="mKCP" ;;
        4) transport="http" ;;
        5) transport="gRPC" ;;
        *) transport="tcp" ;;
    esac

    if [[ "$transport" == "tcp" ]]; then
        yellow "camouflage: "
        yellow "1. none(default, no masquerade)"
        yellow "2. http(stream free)"
        read -p "please choose: " answer
        if [[ "$answer" == "2" ]]; then
            read -p "Please enter the fake domain name (not necessarily your own, default: bki.ir): " host
            [[ -z "$host" ]] && host="bki.ir"
            read -p "Please enter the path (beginning with "/", random by default): " path
            while true; do
                if [[ -z "${path}" ]]; then
                    tmp=$(openssl rand -hex 6)
                    path="/$tmp"
                    break
                elif [[ "${path:0:1}" != "/" ]]; then
                    red "The masquerade path must start with /!"
                    path=""
                else
                    break
                fi
            done
            cat >/usr/local/etc/xray/config.json <<-EOF
{
    "policy": {
            "levels": {
                "1": {
                    "handshake": $handshake,
                    "connIdle": $connIdle,
                    "uplinkOnly": $uplinkOnly,
                    "downlinkOnly": $downlinkOnly
                }
            }
    },
  "inbounds": [
    {
      "port": $port,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "$uuid",
            "level": 1,
            "alterId": 0
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "tcpSettings": {
            "header": {
                "type": "http",
                "request": {
                    "path": ["$path"],
                    "headers": {
                        "Host": ["$host"]
                    }
                },
                "response": {
                    "version": "1.1",
                    "status": "200",
                    "reason": "OK"
                }
            }
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF
        echo ""
        ip=$(curl ip.sb)
        yellow "protocol: VMess"
        yellow "ip: $ip"
        yellow "port: $port"
        yellow "uuid: $uuid"
        yellow "transfer mode: TCP"
        yellow "camouflage type: http"
        yellow "fake domain name: $host"
        yellow "path: $path"
        echo ""
# from network hop
raw="{
  \"v\":\"2\",
  \"ps\":\"\",
  \"add\":\"${ip}\",
  \"port\":\"${port}\",
  \"id\":\"${uuid}\",
  \"aid\":\"0\",
  \"net\":\"tcp\",
  \"type\":\"http\",
  \"host\":\"${host}\",
  \"path\":\"${path}\",
  \"tls\":\"\"
}"
        link=$(echo -n ${raw} | base64 -w 0)
        shareLink="vmess://${link}"
        yellow "share link: "
        green "$shareLink"

        else
            cat >/usr/local/etc/xray/config.json <<-EOF
{
  "inbounds": [
    {
      "port": $port,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "$uuid",
            "alterId": 0
          }
        ]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF
            echo ""
            ip=$(curl ip.sb)
            yellow "protocol: VMess"
            yellow "ip: $ip"
            yellow "port: $port"
            yellow "uuid: $uuid"
            yellow "transfer mode: TCP"
            yellow "camouflage type: http"
            yellow "fake domain nam: $host"
            yellow "path: $path"
            echo ""
raw="{
  \"v\":\"2\",
  \"ps\":\"\",
  \"add\":\"${ip}\",
  \"port\":\"${port}\",
  \"id\":\"${uuid}\",
  \"aid\":\"0\",
  \"net\":\"tcp\",
  \"type\":\"none\",
  \"host\":\"\",
  \"path\":\"\",
  \"tls\":\"\"
}"
            link=$(echo -n ${raw} | base64 -w 0)
            shareLink="vmess://${link}"
            yellow "share link(v2RayN): "
            green "$shareLink"
            echo ""
            newLink="${uuid}@${ip}:${port}"
            yellow "Share link (Xray standard): "
            green "vmess://${newLink}"
        fi


    elif [[ "$transport" == "ws" ]]; then
        echo ""
        read -p "Please enter the path (begins with "/", random by default): " path
        while true; do
            if [[ -z "${path}" ]]; then
                tmp=$(openssl rand -hex 6)
                path="/$tmp"
                break
            elif [[ "${path:0:1}" != "/" ]]; then
                red "Masquerade path must start with /!"
                path=""
            else
                break
            fi
        done
        yellow "current path: $path"
        echo ""
        read -p "Please enter ws domain name: can be used for streaming free (default bki.ir): " host
        [[ -z "$host" ]] && host="bki.ir"
        cat >/usr/local/etc/xray/config.json <<-EOF
{
    "policy": {
            "levels": {
                "1": {
                    "handshake": $handshake,
                    "connIdle": $connIdle,
                    "uplinkOnly": $uplinkOnly,
                    "downlinkOnly": $downlinkOnly
                }
            }
    },
  "inbounds": [
    {
      "port": $port,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "$uuid",
            "level": 1,
            "alterId": 0
          }
        ]
      },
      "streamSettings": {
        "network":"ws",
        "wsSettings": {
            "path": "$path",
            "headers": {
                "Host": "$host"
            }
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF
        ip=$(curl ip.sb)
        echo ""
        yellow "protocol: VMess"
        yellow "ip: $ip"
        yellow "port: $port"
        yellow "uuid: $uuid"
        yellow "Extra ID: 0"
        yellow "Transmission method: WebSocket (ws)"
        yellow "Path: $path or ${path}?ed=2048 (the latter has a lower latency but may increase detection)"
        yellow "ws host(fake domain name): $host"
raw="{
  \"v\":\"2\",
  \"ps\":\"\",
  \"add\":\"${ip}\",
  \"port\":\"${port}\",
  \"id\":\"${uuid}\",
  \"aid\":\"0\",
  \"net\":\"ws\",
  \"host\":\"${host}\",
  \"path\":\"${path}\",
  \"tls\":\"\"
}"
        link=$(echo -n ${raw} | base64 -w 0)
        shareLink="vmess://${link}"
        echo ""
        yellow "share link: "
        green "$shareLink"
        newPath=$(echo -n $path | xxd -p | tr -d '\n' | sed 's/\(..\)/%\1/g')
        newLink="${uuid}@${ip}:${port}?type=ws&host=${host}&path=${newPath}"
        yellow "Share link (Xray standard): "
        green "vmess://${newLink}"


    elif [[ "$transport" == "mKCP" ]]; then
        echo ""
        yellow "downlink bandwidth:"
        yellow "Unit: MB/s, note that it is Byte instead of bit"
        yellow "default: 100"
        yellow "It is recommended to set a larger value"
        read -p "please set: " uplinkCapacity
        [[ -z "$uplinkCapacity" ]] && uplinkCapacity=100
        yellow "Current upstream bandwidth: $uplinkCapacity"
        echo ""
        yellow "upstream bandwidth: "
        yellow "Unit: MB/s, note that it is Byte instead of bit"
        yellow "default: 100"
        yellow "It is recommended to set your real upstream bandwidth to twice its"
        read -p "please set: " downlinkCapacity
        [[ -z "$downlinkCapacity" ]] && downlinkCapacity=100
        yellow "Current downlink bandwidth: $downlinkCapacity"
        echo ""
	yellow "Camouflage type:"
	yellow "1. no masquerading: none (default)"
	yellow "2. SRTP: Camouflage as SRTP data packets, will be recognized as video call data (such as FaceTime)"
	yellow "3. uTP: Camouflage as uTP data packets, will be recognized as BT download data"
	yellow "4. WeChat Video: Camouflage as WeChat's video calls data packets"
	yellow "5. DTLS: Camouflage as DTLS 1.2 data packets."
	yellow "6. WireGuard: Camouflage as WireGuard data packets. (It is not the actual WireGuard protocol)"
	read -p "Please choose: " answer
        case $answer in
            1) camouflageType="none" ;;
            2) camouflageType="srtp" ;;
            3) camouflageType="utp" ;;
            4) camouflageType="wechat-video" ;;
            5) camouflageType="dtls" ;;
            6) camouflageType="wireguard" ;;
            *) camouflageType="none" ;;
        esac
        yellow "current disguise: $camouflageType"
        cat >/usr/local/etc/xray/config.json <<-EOF
{
    "inbounds": [
        {
            "port": ${port},
            "protocol": "vmess",
            "settings": {
                "clients": [
                    {
                        "id": "$uuid",
                        "level": 1,
                        "alterId": 0
                    }
                ]
            },
            "streamSettings": {
                "network": "mkcp",
                "kcpSettings": {
                    "uplinkCapacity": ${uplinkCapacity},
                    "downlinkCapacity": ${downlinkCapacity},
                    "congestion": true,
                    "header": {
                        "type": "${camouflageType}"
                    }
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "settings": {}
        },
        {
            "protocol": "blackhole",
            "settings": {},
            "tag": "blocked"
        }
    ]
}
EOF
        echo ""
        ip=$(curl ip.sb)
        yellow "Protocol: VMess"
	yellow "Transfer Protocol: mKCP"
	yellow "IP: $ip"
	yellow "Port: $port"
	yellow "UUID: $uuid"
	yellow "Extra ID: 0"
	yellow "Camouflage type: $camouflageType"
	yellow "Uplink capacity: $uplinkCapacity"
	yellow "Downlink capacity: $downlinkCapacity"
	yellow "mKCP seed (obfuscation password): None"
        echo ""
raw="{
  \"v\":\"2\",
  \"ps\":\"\",
  \"add\":\"${ip}\",
  \"port\":\"${port}\",
  \"id\":\"${uuid}\",
  \"aid\":\"0\",
  \"net\":\"kcp\",
  \"type\":\"$camouflageType\",
  \"tls\":\"\"
}"
        link=$(echo -n ${raw} | base64 -w 0)
        shareLink="vmess://${link}"
        yellow "share link: "
        green "$shareLink"
        newLink="${uuid}@${ip}:${port}?type=kcp&headerType=$camouflageType"
        yellow "Share link (Xray standard): "
        green "vmess://${newLink}"


    elif [[ "$transport" == "http" ]]; then
        echo ""
        red "Warning: Due to HTTP/2 official recommendation, Xray client's HTTP/2 must force TLS to be enabled. Therefore, this feature is only used as a backend, so it only listens to the local address (127.0.0.1)"
        red "If you don’t understand, you can leave out the domain name"
        read -p "Please enter a domain name: " domain
        [[ -z "$domain" ]] && red "Please enter a domain name!" && exit 1
        yellow "current domain name: $domain"
        echo ""
        read -p "Please enter the path (begins with "/", random by default): " path
        while true; do
            if [[ -z "${path}" ]]; then
                tmp=$(openssl rand -hex 6)
                path="/$tmp"
                break
            elif [[ "${path:0:1}" != "/" ]]; then
                red "Camouflage path must start with / !"
                path=""
            else
                break
            fi
        done
        yellow "current path: $path"
        cat >/usr/local/etc/xray/config.json <<-EOF
{
  "inbounds": [
    {
      "listen": "127.0.0.1"
      "port": $port,
      "protocol": "vmess",
      "streamSettings": {
        "network": "http",
        "httpSettings": {
            "host": [
                "$domain"
            ],
            "path": "$path"
        }
      },
      "settings": {
        "clients": [
          {
            "id": "$uuid",
            "alterId": 0
          }
        ]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF
        echo ""
	yellow "Protocol: VMess"
	yellow "Port: $port"
	yellow "UUID: $uuid"
	yellow "Extra ID: 0"
	yellow "Transfer Protocol: HTTP/2 (http)"
	yellow "Domain name: $domain"
	yellow "Path: $path"
        echo ""
        yellow "Note: The client cannot connect directly! The server only listens to 127.0.0.1 "


    elif [[ "$transport" == "gRPC" ]]; then
        echo ""
        red "Warning: The client can only connect when TLS is enabled, so it only listens to 127.0.0.1"
        red "If you don't understand, please exit"
        yellow "server name: "
        yellow "Similar to the 'path' parameter in ws"
        read -p "please enter: " serverName
        while true; do
            if [[ -z "${serverName}" ]]; then
                serverName=$(openssl rand -hex 6)
                break
            else
                break
            fi
        done
        yellow "current server name: $serverName"
        cat >/usr/local/etc/xray/config.json <<-EOF
{
    "inbounds": [
        {
            "listen": "127.0.0.1",
            "port": $port,
            "protocol": "vmess",
            "settings": {
                "clients": [
                    {
                        "id": "$uuid",
                        "alterId": 0
                    }
                ]
            },
            "streamSettings": {
                "network": "grpc",
                "grpcSettings": {
                    "serviceName": "$serviceName"
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "settings": {}
        }
    ]
}
EOF
        echo ""
        yellow "protocol: VMess"
        yellow "port: $port"
        yellow "uuid: $uuid"
        yellow "Extra ID: 0"
        yellow "transfer method: gRPC"
        yellow "server name: $serverName"

        
    fi 
    systemctl stop xray
    systemctl start xray
    ufw allow $port
    ufw reload
}

set_VLESS_withoutTLS() {
    echo ""
    red "Warning: Old configuration will be overwritten!"
    echo ""
    read -p "Please enter the VLESS listening port: " port
    [[ -z "${port}" ]] && port=$(shuf -i200-65000 -n1)
    if [[ "${port:0:1}" == "0" ]]; then
        red "Port cannot start with 0"
        port=$(shuf -i200-65000 -n1)
    fi
    yellow "current port: $port"
    echo ""
    uuid=$(xray uuid)
    [[ -z "$uuid" ]] && red "Please install Xray first!" && exit 1
    getUUID
    yellow "current uuid: $uuid"
    echo ""
    yellow "underlying transport protocol: "
    yellow "Note: due to VLESS's use of plain-text transmission, the "tcp" option has been removed.;all other options, except for mKCP, will be listening only to the address 127.0.0.1"
    yellow "1. websocket(ws) (recommend)"
    yellow "2. mKCP (default)"
    yellow "3. HTTP/2"
    green "4. gRPC"
    echo ""
    read -p "please choose: " answer
    case $answer in
        1) transport="ws" ;;
        2) transport="mKCP" ;;
        3) transport="http" ;;
        4) transport="gRPC" ;;
        *) transport="mKCP" ;;
    esac
    yellow "Current underlying transport protocol: $transport"
    echo ""

    if [[ "$transport" == "ws" ]] ;then
        read -p "Please enter the path (begins with "/", random by default): " path
        while true; do
            if [[ -z "${path}" ]]; then
                tmp=$(openssl rand -hex 6)
                path="/$tmp"
                break
            elif [[ "${path:0:1}" != "/" ]]; then
                red "Camouflage path must start with /！"
                path=""
            else
                break
            fi
        done
        yellow "current path: $path"
        echo ""
        read -p "Please enter the ws domain name: (default bki.ir): " host
        [[ -z "$host" ]] && host="bki.ir"
        cat >/usr/local/etc/xray/config.json <<-EOF
{
    "inbounds": [
        {
            "listen": "127.0.0.1",
            "port": $port,
            "protocol": "VLESS",
            "settings": {
                "clients": [
                    {
                        "id": "$uuid",
                        "level": 0,
                        "email": "love@xray.com"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "ws",
                "wsSettings": {
                    "path": "$path",
                    "headers": {
                        "Host": "$host"
                    }
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "settings": {}
        }
    ]
}
EOF
        echo ""
 yellow "Protocol: VLESS" 
yellow "Port: $port" 
yellow "UUID: $uuid" 
yellow "Extra ID: 0" 
yellow "Transfer Protocol: ws (websocket)" 
yellow "Path: $path or ${path}?ed=2048 (the latter has lower latency but may increase the chance of detection)" 
yellow "ws host (camouflage domain): $host"
    

    elif [[ "$transport" == "mKCP" ]] ;then
        echo ""
        yellow "downlink bandwidth:"
        yellow "Unit: MB/s, Note that it's Bytes, not bits"
        yellow "Default: 100"
        yellow "It is recommended to set a larger value"
        read -p "please set: " uplinkCapacity
        [[ -z "$uplinkCapacity" ]] && uplinkCapacity=100
        yellow "Current upstream bandwidth: $uplinkCapacity"
        echo ""
        yellow "upstream bandwidth: "
        yellow "Unit: MB/s, Note that it's Bytes, not bits"
        yellow "default: 100"
        yellow "We suggest setting it to twice your actual uplink capacity"
        read -p "Please set: " downlinkCapacity
        [[ -z "$downlinkCapacity" ]] && downlinkCapacity=100
        yellow "Current downlink bandwidth: $downlinkCapacity"
        echo ""
        read -p "Obfuscation password (default random): " seed
        [[ -z "$seed" ]] && seed=$(openssl rand -base64 16)
        yellow "Current obfuscation password: $seed"
        echo ""
        yellow "Camouflage type: "
        yellow "1. no masquerading: none (default)"
        yellow "2. SRTP: Camouflage as SRTP data packets, will be recognized as video call data (such as FaceTime)"
        yellow "3. uTP: Camouflage as uTP data packets, will be recognized as BT download data"
        yellow "4. wechat-video: Camouflage as WeChat's video call data packets"
        yellow "5. DTLS: Camouflage as DTLS 1.2 data packets"
        yellow "6. wireguard: Camouflage as WireGuard data packets. (It is not the actual WireGuard protocol)"
        read -p "please choose: " answer
        case $answer in
            1) camouflageType="none" ;;
            2) camouflageType="srtp" ;;
            3) camouflageType="utp" ;;
            4) camouflageType="wechat-video" ;;
            5) camouflageType="dtls" ;;
            6) camouflageType="wireguard" ;;
            *) camouflageType="none" ;;
        esac
        yellow "Current camouflage: $camouflageType"
        cat >/usr/local/etc/xray/config.json <<-EOF
{
    "inbounds": [
        {
            "port": ${port},
            "protocol": "VLESS",
            "settings": {
                "clients": [
                    {
                        "id": "$uuid",
                        "level": 0,
                        "email": "love@xray.com"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "mkcp",
                "kcpSettings": {
                    "uplinkCapacity": ${uplinkCapacity},
                    "downlinkCapacity": ${downlinkCapacity},
                    "congestion": true,
                    "header": {
                        "type": "${camouflageType}"
                    },
                    "seed": "$seed"
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "settings": {}
        },
        {
            "protocol": "blackhole",
            "settings": {},
            "tag": "blocked"
        }
    ]
}
EOF
        echo ""
        ip=$(curl ip.sb)
        yellow "Protocol: VLESS"
        yellow "Transfer Protocol: mKCP"
        yellow "ip :$ip"
        yellow "Port: $port"
        yellow "uuid: $uuid"
        yellow "Extra ID: 0"
        yellow "Camouflage type: $camouflageType"
        yellow "upstream bandwidth: $uplinkCapacity"
        yellow "downlink bandwidth: $downlinkCapacity"
        yellow "mKCP seed(obfuscation password): $seed"
        echo ""
        newSeed=$(echo -n $seed | xxd -p | tr -d '\n' | sed 's/\(..\)/%\1/g')
        newLink="${uuid}@${ip}:${port}?type=kcp&headerType=${camouflageType}&seed=${newSeed}"
        yellow "Share link (Xray standard): "
        green "vless://${newLink}"


    elif [[ "$transport" == "http" ]] ;then
        read -p "Please enter a domain name: " domain
        [[ -z "$domain" ]] && red "Please enter a domain name！" && exit 1
        yellow "current domain name: $domain"
        echo ""
        read -p "Please enter the path (begins with "/", random by default): " path
        while true; do
            if [[ -z "${path}" ]]; then
                tmp=$(openssl rand -hex 6)
                path="/$tmp"
                break
            elif [[ "${path:0:1}" != "/" ]]; then
                red "The path must start with /!"
                path=""
            else
                break
            fi
        done
        yellow "current path: $path"
        cat >/usr/local/etc/xray/config.json <<-EOF
{
    "inbounds": [
        {
            "listen": "127.0.0.1",
            "port": "$port",
            "protocol": "VLESS",
            "streamSettings": {
                "network": "http",
                "httpSettings": {
                    "host": [
                        "$domain"
                    ],
                    "path": "$path"
                }
            },
            "settings": {
                "clients": [
                    {
                        "id": "$uuid",
                        "level": 0,
                        "email": "love@xray.com"
                    }
                ],
                "decryption": "none"
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "settings": {}
        }
    ]
}
EOF
        echo ""
        yellow "Protocol: VLESS"
        yellow "Port: $port"
        yellow "uuid: $uuid"
        yellow "Extra ID: 0"
        yellow "Transfer Protocol: HTTP/2(http)"
        yellow "Domain name: $domain"
        yellow "Path: $path"


    elif [[ "$transport" == "gRPC" ]] ;then
        echo ""
        red "Warning: The client can only connect when TLS is enabled, so it only listens to 127.0.0.1"
        red "If you don't understand, please exit"
        yellow "server name: "
        yellow "Functions similarly to the 'path' parameter in ws"
        read -p "Please enter: " serverName
        while true; do
            if [[ -z "${serverName}" ]]; then
                serverName=$(openssl rand -hex 6)
                break
            else
                break
            fi
        done
        yellow "current server name: $serverName"
        cat >/usr/local/etc/xray/config.json <<-EOF
{
    "inbounds": [
        {
            "listen": "127.0.0.1",
            "port": $port,
            "protocol": "VLESS",
            "settings": {
                "clients": [
                    {
                        "id": "$uuid",
                        "level": 0,
                        "email": "love@xray.com"
                    }
                ],
                "decryption": "none"
            }
            },
            "streamSettings": {
                "network": "grpc",
                "grpcSettings": {
                    "serviceName": "$serviceName"
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "settings": {}
        }
    ]
}
EOF
        echo ""
        yellow "protocol: VMess"
        yellow "Port: $port"
        yellow "uuid: $uuid"
        yellow "Extra ID: 0"
        yellow "transfer method: gRPC"
        yellow "server name: $serverName"
    fi

    systemctl stop xray
    systemctl start xray
    ufw allow $port
    ufw reload
}

#  I was lazy, after all, the original version of Shadowsocks does not have UDP over TCP
set_shadowsocks_withoutTLS() {
    echo ""
    read -p "Please enter Shadowsocks listening port (default random): " port
    [[ -z "${port}" ]] && port=$(shuf -i200-65000 -n1)
    if [[ "${port:0:1}" == "0" ]]; then
        red "Port cannot start with 0"
        port=$(shuf -i200-65000 -n1)
    fi
    yellow "Current shadowsocks listening port: $port"
    echo ""
    echo ""
    yellow "Encryption method: "
    red "Note: Encryption methods with '2022' in their names are Shadowsocks-2022 encryption methods, which are currently supported by fewer clients but are more resistant to blocking and can enable UDP over TCP"
    yellow "Sorted by recommended order"
    echo ""
    green "1. 2022-blake3-aes-128-gcm"
    green "2. 2022-blake3-aes-256-gcm"
    green "3. 2022-blake3-chacha20-poly1305"
    yellow "4. aes-128-gcm(recommended)"
    yellow "5. aes-256-gcm"
    green "6. chacha20-ietf-poly1305(default)"
    yellow "7. xchacha20-ietf-poly1305"
    red "8 none(no encryption, when selected, it will automatically only listen to 127.0.0.1 )"
    echo ""
    read -p "Please choose: " answer
    case $answer in
        1) method="2022-blake3-aes-128-gcm" && ss2022="true" ;;
        2) method="2022-blake3-aes-256-gcm" && ss2022="true" ;;
        3) method="2022-blake3-chacha20-poly1305" && ss2022="true" ;;
        4) method="aes-128-gcm" ;;
        5) method="aes-256-gcm" ;;
        6) method="chacha20-ietf-poly1305" ;;
        7) method="xchacha20-ietf-poly1305" ;;
        8) method="none" ;;
        *) method="chacha20-ietf-poly1305" ;;
    esac
    yellow "Current encryption method: $method"
    echo ""
    yellow "Note: In Xray, Shadowsocks-2022 encryption methods can all use a 32-bit password, but in standard implementation, 2022-blake3-aes-128-gcm uses a 16-bit password, and other 2022-series encryption methods supported by Xray use a 32-bit password"
    yellow "Press enter if you do not understand."
    yellow "16-bit password: "
    openssl rand -base64 16
    read -p "Please enter the shadowsocks password (default 32 bits): " password
    [[ -z "$password" ]] && password=$(openssl rand -base64 32)
    yellow "Current Password: $password"
    if [[ "$method" == "none" ]]; then
        listen="127.0.0.1"
    else
        listen="0.0.0.0"
    fi
    cat >/usr/local/etc/xray/config.json <<-EOF
{
    "policy": {
            "levels": {
                "1": {
                    "handshake": $handshake,
                    "connIdle": $connIdle,
                    "uplinkOnly": $uplinkOnly,
                    "downlinkOnly": $downlinkOnly
                }
            }
    },
    "inbounds": [
        {
            "listen": "$listen",
            "port": $port,
            "protocol": "shadowsocks",
            "settings": {
                "password": "$password",
                "method": "$method",
                "level": 1,
                "email": "love@xray.com",
                "network": "tcp,udp"
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "settings": {}
        }
    ]
}
EOF
    echo ""
    ip=$(curl ip.sb)
    yellow "协议: shadowsocks"
    yellow "ip: $ip"
    yellow "端口: $port"
    yellow "加密方式: $method"
    yellow "密码: $password"
    echo ""
    raw="${method}:${password}@${ip}:${port}"
    if [[ "$ss2022" != "true" ]]; then
        link=$(echo -n ${raw} | base64 -w 0)
    else
        link="$raw"
    fi
    green "分享链接: "
    green "ss://$link"

    systemctl stop xray
    systemctl start xray
    ufw allow $port
    ufw reload
}

set_withoutTLS() {
    echo ""
    red "WARNING: Old configuration may be deleted!"
    yellow "Please select a protocol: "
    yellow "1. VMess"
    yellow "2. shadowsocks"
    yellow "3. VLESS(Do not use VLESS to bypass the Great Firewall directly as VLESS has no encryption!)"
    echo ""
    read -p "Please choose: " protocol
    case $protocol in
        1) set_VMess_withoutTLS ;;
        2) set_shadowsocks_withoutTLS ;;
        3) set_VLESS_withoutTLS ;;
        *) red "Please enter the correct option!" ;;
    esac
}

set_withXTLS() {
    echo ""
    yellow "Please ensure: "
    yellow "1. Xray is installed"
    yellow "2. You have applied for your own TLS certificate"
    yellow "3. Nginx will be (re)installed using the system's package manager"
    red "4. The original Nginx and Xray configuration will be deleted!!!"
    echo ""
    read -p "Press any key to continue or press ctrl + c to exit" rubbish
    echo ""
    echo ""
    echo ""
    
    read -p "Please enter the VLESS listening port (default 443): " port
    [[ -z "${port}" ]] && port=443
    if [[ "${port:0:1}" == "0" ]]; then
        red "Port cannot start with 0"
        port=443
    fi
    yellow "Current port: $port"
    echo ""

    read -p "Please enter the fallback website port (default 80): " fallbackPort
    [[ -z "${fallbackPort}" ]] && fallbackPort=80
    if [[ "${fallbackPort:0:1}" == "0" ]]; then
        red "Port cannot start with 0"
        fallbackPort=80
    fi
    yellow "Current fallback port: $fallbackPort"

    echo ""
    wsPort=$(shuf -i10000-65000 -n1)
    wsPath=$(openssl rand -hex 6)
    fallbackPort2=$(shuf -i10000-65000 -n1)

    portUsed=$(lsof -i :$port)
    fallbackPortUsed=$(lsof -i :$fallbackPort)
    wsPortUsed=$(lsof -i :$fallbackPort)
    fallbackPort2Used=$(lsof -i :$fallbackPort2)
    yellow "Ports currently in use: "
    yellow "$portUsed"
    echo ""
    yellow "$fallbackPortUsed"
    echo ""
    yellow "$wsPortUsed"
    echo ""
    yellow "$fallbackPort2Used"
    echo ""
    read -p "If there is any usage, press ctrl + c to exit. If no usage or forced execution, press enter: " rubbish
    echo ""

    uuid=$(xray uuid)
    [[ -z "$uuid" ]] && red "Please install Xray first!" && exit 1
    getUUID
    yellow "Current uuid: $uuid"

    yellow "Flow control: "
    green "1. xtls-rprx-vision,none(Removed from Xray v1.7.5)"
    yellow "2. xtls-rprx-vision(default)"
    yellow "3. xtls-rprx-direct (Removed from Xray v1.7.5)"
    red "4 xtls-rprx-origin(Not recommended)  (Removed from Xray v1.7.5)"
    yellow "5. (No flow control)"
    echo ""
    green "Some tips: "
    green "Although the old flow control has been deprecated，but considering that the new flow control has not undergone time testing，Using old flow control has unexpected effect"
    echo ""
    read -p "Select an option: " answer
    case $answer in
        1) flow="xtls-rprx-vision,none" && flow2="xtls-rprx-vision" && TLS="tls" ;;
        2) flow="xtls-rprx-vision" && flow2="xtls-rprx-vision" && TLS="tls" ;;
        3) flow="xtls-rprx-direct" && flow2="xtls-rprx-direct" && TLS="xtls" ;;
        4) flow="xtls-rprx-origin" && flow2="xtls-rprx-origin" && TLS="xtls" ;;
        5) flow="" && flow2="" && TLS="tls" ;;
        *) red "xtls-rprx-vision automatically chosen!" && flow="xtls-rprx-vision" && flow2="xtls-rprx-vision" && TLS="tls" ;;
    esac
    yellow "Current flow control: $flow"

    echo ""
    read -p "Please enter your domain name: " domain
    yellow "Current domain name: $domain"
    echo ""
    read -p "Please enter the certificate path (do not start with '~'!): " cert
    if [[ ${cert:0:1} == "~" ]] || [ -z "$cert" ]; then
        red "Please enter the path to the certificate or the path to the certificate cannot start with ~!" && exit 1
    fi
    yellow "Current certificate path: $cert"
    echo ""
    read -p "Please enter the key path (do not start with '~'!): " key
    if [[ ${key:0:1} == "~" ]] || [ -z "$key" ]; then
        red "Please enter the path to the key or the path to the key cannot start with '~' ! " && exit 1
    fi
    yellow "Current key path: $key"

    echo ""
    read -p "Please enter the fallback website URL (must be an HTTPS website, default: www.bing.com): " forwardWeb
    [ -z "$forwardWeb" ] && forwardWeb="www.bing.com"
    yellow "Current fallback website: $forwardWeb"
    echo ""

# Configuration details:
# http/1.1 falls back to port 80, h2 falls back to a high port. After all, browsers don't use h2c.
# The forwarding website is beginner friendly.

    green "Installing Nginx......"
    ${PACKAGE_UPDATE[int]}
    ${PACKAGE_INSTALL[int]} nginx
    echo ""
    green "Generating Nginx configuration"
    cat >/etc/nginx/nginx.conf <<-EOF
user root;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 1024;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    gzip on;

    server {
        listen 0.0.0.0:$fallbackPort;
        listen [::]:$fallbackPort;
        listen 0.0.0.0:$fallbackPort2 http2;
        listen [::]:$fallbackPort2 http2;
        server_name $domain;

        location / {
            proxy_pass https://${forwardWeb};
            proxy_redirect off;
            proxy_ssl_server_name on;
            sub_filter_once off;
            sub_filter "${forwardWeb}" \$server_name;
            proxy_set_header Host "${forwardWeb}";
            proxy_set_header Referer \$http_referer;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header User-Agent \$http_user_agent;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto https;
            proxy_set_header Accept-Encoding "";
            proxy_set_header Accept-Language "zh-CN";
        }

        location /${wsPath} {
            proxy_redirect off;
            proxy_pass http://127.0.0.1:${wsPort};
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }

    }
}
EOF

    systemctl enable nginx
    systemctl stop nginx
    systemctl start nginx

# The default user level seems to be 0, but I made everything 1.
# Let's just stick with it, hoping that the user will know when browsing the configuration.

    echo ""
    green "Configuring Xray"
    cp $cert /usr/local/etc/xray/cert.crt
    cp $key /usr/local/etc/xray/key.key
    cat >/usr/local/etc/xray/config.json <<-EOF
{
    "policy": {
        "levels": {
            "1": {
                "handshake": $handshake,
                "connIdle": $connIdle,
                "uplinkOnly": $uplinkOnly,
                "downlinkOnly": $downlinkOnly
            }
        }
    },
    "inbounds": [
        {
            "port": $port,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$uuid",
                        "level": 1,
                        "flow": "$flow"
                    }
                ],
                "fallbacks": [
                    {
                        "alpn": "h2",
                        "dest": $fallbackPort2
                    },
                    {
                        "alpn": "http/1.1",
                        "dest": $fallbackPort
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "tls",
                "${TLS}Settings": {
                    "certificates": [
                        {
                            "certificateFile": "/usr/local/etc/xray/cert.crt",
                            "keyFile": "/usr/local/etc/xray/key.key"
                        }
                    ]
                }
            }
        },
        {
            "listen": "127.0.0.1",
            "port": $wsPort,
            "protocol": "vmess",
            "settings": {
                "clients": [
                    {
                        "id": "$uuid",
                        "level": 1,
                        "alterId": 0
                    }
                ]
            },
            "streamSettings": {
                "network": "ws",
                "wsSettings": {
                    "path": "/${wsPath}"
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "tag": "direct"
        },
        {
            "protocol": "blackhole",
            "tag": "block"
        }
    ]
}
EOF

    systemctl enable xray
    systemctl stop xray
    systemctl start xray
    ufw allow $port
    ufw reload

    ip=$(curl ip.sb)
    ipv6=$(curl ip.sb -6)
    if [ "$ip" == "$ipv6" ]; then
        linkIP="[$ip]"
    else
        linkIP="$ip"
    fi

    xtlsLink="vless://${uuid}@${linkIP}:${port}?sni=${domain}&security=${TLS}&type=tcp&flow=${flow2}"
    wsLink1="vmess://${uuid}@${linkIP}:${port}?sni=${domain}&security=${TLS}&type=ws&host=${domain}&path=${wsPath}"
raw="{
  \"v\":\"2\",
  \"ps\":\"\",
  \"add\":\"${ip}\",
  \"port\":\"${port}\",
  \"id\":\"${uuid}\",
  \"aid\":\"0\",
  \"net\":\"ws\",
  \"path\":\"${wsPath}\",
  \"host\":\"${domain}\",
  \"tls\":\"${TLS}\",
  \"sni\":\"${domain}\"
}"
    tmpLink=$(echo -n ${raw} | base64 -w 0)
    wsLink2="vmess://$tmpLink"
    tlsLink="vless://${uuid}@${linkIP}:${port}?sni=${domain}&security=tls&type=tcp"

    yellow "Node One:"
    yellow "Protocol: VLESS"
    yellow "Address: $ip or $domain"
    yellow "Port: $port"
    yellow "Underlying transport protocol: TCP"
    yellow "Transport layer security: $TLS"
    yellow "Flow control: $flow2"
    yellow "UUID: $uuid"
    yellow "Service name indication (SNI): $domain"
    echo ""
    green "Sharing link: $xtlsLink"

    echo ""
    echo ""
    yellow "Node Two:"
    yellow "Protocol: VMess"
    yellow "Address: $ip or $domain"
    yellow "Port: $port"
    yellow "Underlying transport protocol: ws"
    yellow "ws path: $wsPath"
    yellow "ws host: $domain"
    yellow "Transport layer security: TLS"
    yellow "UUID: $uuid"
    yellow "Extra ID: 0"
    yellow "Service name indication (SNI): $domain"
    echo ""
    yellow "Sharing link (DuckSoft): $wsLink1"
    echo ""
    green "Sharing link (v2rayN): $wsLink2"

    if [ "$flow2" == "xtls-rprx-vision" ]; then
        yellow "Node Three:"
        yellow "Protocol: VLESS"
        yellow "Address: $ip or $domain"
        yellow "Port: $port"
        yellow "Transport layer security: TLS"
        yellow "UUID: $uuid"
        yellow "Service name indication (SNI): $domain"
        echo ""
        green "Sharing link: $tlsLink"
    fi
}

set_REALITY_steal() {
    echo ""
    yellow " Please make sure: "
    yellow " 1. Will use the REALITY client, if not, please leave"
    yellow " 2. Installed Xray with options 1/2 of the script"
    echo ""
    read -p "Enter anything to continue, press ctrl + c to exit" rubbish
    echo ""
    yellow " Please enter the borrowed website/ip, default  dl.google.com : "
    read -p "" forwardSite
    [ -z "$forwardSite" ] && forwardSite="dl.google.com"
    yellow " Current borrowed website: $forwardSite"
    echo ""
    yellow " Please enter the sni of the borrowed website (default same as borrowed website): "
    read -p "" forwardSiteSNI
    [ -z "$forwardSiteSNI" ] && forwardSiteSNI=$forwardSite
    yellow "Current SNI of borrowed website: $forwardSiteSNI"
    echo ""
    yellow " Please enter the target website port (default 443): "
    read -p "" forwardPort
    [ -z "$forwardPort" ] && forwardPort=443
    yellow " Current target port: $port"
    echo ""
    red " Start the test: "
# At present, there is no way to read the curl result and determine whether it is successful, and the user can only judge it by himself
    curl --http2 --tlsv1.3 https://${forwardSite}:${forwardPort}
    yellow " Please make sure there is no error, then press y to continue "
    read -p " (Y/n) " rubbish
    if [ "$rubbish" != "Y" ] || [ "$rubbish" != "y" ]; then
        exit 0
    fi
    echo ""
    yellow " Please enter the Xray listening port (default 443): "
    read -p "" port
    [ -z "$port" ] && port=443
    yellow " Current Xray listening port: $port"
    if [ "$port" == "443" ] && [ "$forwardPort" == "443" ]; then
        echo ""
        green " Current 80 port usage: "
        lsof -i:80
        echo ""
        yellow " Do you want to forward port 80 ?"
        read -p " (Y/n)" answer
        if [ "$answer" == "n" ] || [ "$answer" == "N" ]; then
            "DokodemoDoorPort"=$(shuf -i10000-65000 -n1)
        else
            "DokodemoDoorPort"=80
        fi
    fi
    echo ""
    h2Port=$(shuf -i10000-65000 -n1)
    red " Check the usage of the required ports: "
    lsof -i:$port
    lsof -i:$DokodemoDoorPort
    lsof -i:$h2Port
    yellow " If there is occupancy, please use kill [pid] to release it!"
    read -p "Continue (Y/n)?" answer
    if [ "$answer" == "n" ];then
        exit 0
    fi
    echo ""
    getUUID
    echo ""
    yellow " Current uuid: $uuid"
    echo ""
    tmpKey=$(xray x25519)
    tmpPrivateKey=$(echo "$tmpKey" | grep Private | cut -d " " -f 3)
    tmpPublickKey=$(echo "$tmpKey" |  grep Public | cut -d " " -f 3)
    yellow " Please enter Reality's public/private keys, or leave blank to use auto-generated ones!"
    read -p " Private key (server): " answer
    if [ -z "$answer" ]; then
        red " The key pair has been randomly generated！"
        PrivateKey="$tmpPrivateKey"
        PublicKey="$tmpPublickKey"
    else
        PrivateKey=$answer
        read -p " Public key (client): " PublicKey
    fi
    echo ""
    yellow " Current Private key: $PrivateKey"
    yellow " Current Public key: $PubliccKey"
    echo ""
    yellow " Flow Control: "
    green " 1. xtls-rprx-vision (default)"
    yellow "2.  (no flow control)"
    echo ""
    read -p " Choose one: " answer
    case $answer in
        1) flow="xtls-rprx-vision" ;;
        2) flow="" ;;
        *) red "Auto-selected xtls-rprx-vision!" && flow="xtls-rprx-vision" ;;
    esac
    yellow " Current Flow Control: $flow"
    echo ""
    echo ""
    red " Configuring Xray!"
    cat >/usr/local/etc/xray/config.json <<-EOF
{
    "inbounds": [
        {
            "port": $port,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$uuid",
                        "flow": "$flow"
                    }
                ],
                "decryption": "none",
                "fallbacks": [
                    {
                        "dest": $h2Port
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "show": false,
                    "dest": "${forwardSite}:${forwardPort}",
                    "xver": 0,
                    "serverNames": [
                        "$forwardSiteSNI"
                    ],
                    "privateKey": "$PrivateKey",
                    "shortIds": [
                        ""
                    ]
                }
            }
        },
        {
            "listen": "127.0.0.1",
            "port": $h2Port,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$uuid"
                    }
                ],
                "decryption": "none",
            },
            "streamSettings": {
                "security": "none",
                "network": "h2",
                "httpSettings": {
                    "path": "/"
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom"
        },
        {
            "protocol": "Blackhole"
        }
    ]
}
EOF

    echo ""
    systemctl restart xray
    ufw allow $port
    if [ "$DokodemoDoorPort" == "80" ]; then
        ufw allow 80
    fi
    echo ""
    ip=$(curl ip.sb)
    ipv6=$(curl ip.sb -6)
    if [ "$ip" == "$ipv6" ]; then
        linkIP="[$ip]"
    else
        linkIP="$ip"
    fi
    yellow " Server information: "
    echo ""
    red " Node 1: "
    green " Protocol: VLESS"
    green " Server Address: $linkIP"
    green " Port: $port"
    green " uuid: $uuid"
    green " Flow Control: $flow"
    green " Transport Method: tcp"
    green " Transport Layer Security: REALITY"
    green " Browser Fingerprint: Any (iOS recommended)"
    green " serverName / Server Name Indication /sni: $forwardSiteSNI"
    green " publicKey / Public Key: $PublicKey"
    green " spiderX: Please access the target website yourself and find a reliable path，If you do not understand, fill in \"/\" "
    green " shortId: Leave blank if you do not understand"
    echo ""
    green " Sharing Link: No standard yet"
    echo ""
    echo ""
    red " Node 2:"
    green " Protocol: VLESS"
    green " Server Address: $linkIP"
    green " Port: $port"
    green " uuid: $uuid"
    green " Flow Control: none"
    green " Transport Method: HTTP/2"
    green " Path: /"
    green " Transport Layer Security: REALITY"
    green " Browser Fingerprint: Any (iOS recommended)"
    green " serverName / Server Name Indication /sni: $forwardSiteSNI"
    green " publicKey / Public Key: $PublicKey"
    green " spiderX: Please access the target website yourself and find a reliable path，If you do not understand, fill in \"/\" "
    green " shortId: Leave blank if you do not understand"
    echo ""
    green " Sharing Link: No standard yet"
}

install_build() {
    echo ""
    yellow "Please note: "
    yellow "1. Make sure latest versions of golang (Option 102 of this script can be used) and git are installed"
    yellow "2. Use the latest version at your own risk (including various bugs, protocol mismatches, etc.)"
    echo ""
    read -p "Press any key to continue, or ctrl + c to exit" rubbish
    echo ""
    red "3 seconds of calm"
    sleep 3
    git clone https://github.com/XTLS/Xray-core.git
    yellow "Compilation will begin shortly, which may take a while. Please be patient"
    cd Xray-core && go mod download
    CGO_ENABLED=0 go build -o xray -trimpath -ldflags "-s -w -buildid=" ./main
	chmod +x xray || {
		red "Xray installation failed"
        cd ..
        rm -rf Xray-core
        rm -rf /root/go
		exit 1
	}
    systemctl stop xray
    cp xray /usr/local/bin/
    cd ..
    rm -rf Xray-core/
    mkdir /usr/local/etc/xray 
    mkdir /usr/local/share/xray
    cd /usr/local/share/xray
    curl -L -k -O https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat
    mv dlc.dat geosite.dat
    curl -L -k -O https://github.com/v2fly/geoip/releases/latest/download/geoip.dat
	cat >/etc/systemd/system/xray.service <<-EOF
		[Unit]
		Description=Xray Service
		Documentation=https://github.com/XTLS/Xray-core
		After=network.target nss-lookup.target
		
		[Service]
		User=root
		#User=nobody
		#CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
		#AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
		NoNewPrivileges=true
		ExecStart=/usr/local/bin/xray run -config /usr/local/etc/xray/config.json
		Restart=on-failure
		RestartPreventExitStatus=23
		
		[Install]
		WantedBy=multi-user.target
	EOF
    systemctl daemon-reload
    systemctl enable xray.service

    echo ""
    yellow "Installation complete(sure)"
}

install_official() {
    update_system
    echo ""
    read -p "Would you like to manually specify the Xray version? If N, the latest stable version will be installed(y/N): " ownVersion
    if [[ "$ownVersion" == "y" ]]; then
        # Perhaps it is not necessary to read? After all, if the version number is not given, the official script will also report an error
        read -p "Please enter the version you wish to install (do not include the "v" prefix): " xrayVersion
        [[ -z "xrayVersion" ]] && red "Please enter a valid version number!" && exit 1
        bash -c "$(curl -L -k https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --version ${xrayVersion} -u root
    else
        bash -c "$(curl -L -k https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root
    fi
}

update_system() {
    ${PACKAGE_UPDATE[int]}
    ${PACKAGE_INSTALL[int]} curl wget tar openssl lsof
}

get_cert() {
    bash <(curl -L -k https://github.com/tdjnodj/simple-acme/releases/latest/download/simple-acme.sh)
}

install_go() {
    ${PACKAGE_INSTALL[int]} git curl
    # CPU
    bit=`uname -m`
    if [[ $bit = x86_64 ]]; then
        cpu=amd64
    elif [[ $bit = amd64 ]]; then
        cpu=amd64
    elif [[ $bit = aarch64 ]]; then
        cpu=arm64
    elif [[ $bit = armv8 ]]; then
        cpu=arm64
    elif [[ $bit = armv7 ]]; then
        cpu=arm64
    elif [[ $bit = s390x ]]; then
        cpu=s390x
    else 
        cpu=$bit
        red "CPU model ($cpu) may not be supported!"
    fi
    go_version=$(curl https://go.dev/VERSION?m=text)
    red "当前最新版本golang: $go_version"
    curl -O -k -L https://go.dev/dl/${go_version}.linux-${cpu}.tar.gz
    yellow "Extracting......"
    tar -xf go*.linux-${cpu}.tar.gz -C /usr/local/
    sleep 3
    export PATH=\$PATH:/usr/local/go/bin
    rm go*.tar.gz
    echo 'export PATH=\$PATH:/usr/local/go/bin' >> /root/.bash_profile
    source /root/.bash_profile
    yellow "Check current golang version: "
    go version
    yellow "To ensure successful installation，Please enter manually: "
    echo "echo 'export PATH=\$PATH:/usr/local/go/bin' >> /root/.bash_profile"
    red "source /root/.bash_profile"
    echo ""
    echo "If there is an error, it may be due to not deleting the old version of go"
}

unintstall_xray() {
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove --purge
}

updateGEO() {
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install-geodata
}

getUUID() {
    echo ""
    uuid_regex='^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$'
    yellow "Please enter your UUID, if the input is invalid, it will be automatically mapped to a UUID"
    read -p " " answer
    if [ -z "$answer" ]; then
        uuid=$(uuidgen)
    elif [ "$answer" == "${uuid_regex}" ]; then
        uuid="${answer}"
    else
        red "Invalid UUID !  Automatically mapped!"
        uuid=$(xray uuid -i "$answer")
    fi
}

myHelp() {
    echo ""
    yellow "bash ${PWD}/${0} [选项]"
    echo ""
    yellow "选项:"
    echo ""
    yellow "help         View this help"
    yellow "install      Install/update Xray using official script"
    yellow "build        Compile and install Xray"
    yellow "cert         Get TLS certificate"
}

menu() {
    clear
    red " Xray one-click installation/configuration script"
    echo ""
    yellow " 1. Install/update Xray using the official script"
    yellow " 2. Compile and install Xray"
    echo ""
    echo " ------------------------------------"
    echo ""
    yellow " 3. Configure Xray: Protocol without TLS"
    green " 4. Configure Xray: VLESS + xtls + web (recommended)"
    green " 5. Configure Xray: Use REALITY's borrowed certificate: VLESS + tcp + xtls / VLESS + h2 + tls coexists!"
    echo ""
    echo " ------------------------------------"
    echo " 11. Start Xray"
    echo " 12. Stop Xray"
    echo " 13. Set Xray to start automatically on boot"
    echo " 14. Disable Xray from starting automatically on boot"
    echo " 15. View Xray's running status"
    red " 16. Uninstall Xray"
    echo " 17. Update geo resource files"
    echo " ------------------------------------"
    echo ""
    yellow " 100. Update the system and install dependencies"
    yellow " 101. Apply for a TLS certificate (HTTP application/self-signed)"
    yellow " 102. Install the latest version of Golang and compile other components of Xray"
    echo ""
    echo " ------------------------------------"
    echo ""
    yellow " 0. Exit the script"
    read -p "Please select: " answer
    case $answer in
        0) exit 0 ;;
        1) install_official ;;
        2) install_build ;;
        3) set_withoutTLS ;;
        4) set_withXTLS ;;
        5) set_REALITY_steal ;;
        11) systemctl start xray ;;
        12) systemctl stop xray ;;
        13) systemctl enable xray ;;
        14) systemctl disable xray ;;
        15) systemctl status xray ;;
        16) unintstall_xray ;;
        17) updateGEO ;;
        100) update_system ;;
        101) get_cert ;;
        102) install_go ;;
        *) red "This option does not exist!" && exit 1 ;;
    esac
}

action=$1
[[ -z $1 ]] && action=menu

case "$action" in
    help) myHelp;;
    install) install_official ;;
    build) install_build ;;
    cert) get_cert ;;
    *) red "Non-existent option!" && myHelp ;;
esac

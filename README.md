# 使用
提示: 本版本开发中

```shell
wget https://raw.githubusercontent.com/tdjnodj/xray_script/main/xray.sh && bash xray.sh
```

# 旧版

https://github.com/tdjnodj/xray_script/tree/old

# 特色

- 模块化安装，方便管理。BBR、证书申请等专业活请使用专业脚本。

- 随机握手超时时间，抵御主动探测( VMess + ws / VMess + tcp + http / shadowsocks / VLESS + tcp + xtls)

# TODO

- [x] xtls + fallback(ws)

- [x] 随机`Policy`，以缓解[Xray #1511](https://github.com/XTLS/Xray-core/issues/1511)中的主动探测。

- [ ] VLESS/VMess/Trojan + gRPC + TLS

- [ ] REALITY 支持 (?)

# Thanks

[网络跳跃(hijk)](https://github.com/hijkpw)

[project X](https://xtls.github.io)

[ChatGPT](https://chat.openai.com)

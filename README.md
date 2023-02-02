# 使用
提示: 本版本开发中

```shell
wget https://raw.githubusercontent.com/tdjnodj/xray_script/main/xray.sh && bash xray.sh
```

# 旧版

https://github.com/tdjnodj/xray_script/tree/old

# 介绍

重构版，目的是增加传输协议组合的灵活性。

目前已实现 VMess/shadowsocks(2022)/VLESS 以及 ws/mKCP/HTTP/2/gRPC

未来将加上 (X)TLS ，以及伪装站点。

其他脚本把所有步骤塞到一起，会造成重装很慢。这个脚本的目的是把安装过程模块化，你想使用哪一步就使用哪一步，灵活安装。

# 特色

- 模块化安装，方便管理。BBR、证书申请等专业活请使用专业脚本。

- 随机握手超时时间，抵御主动探测( VMess + ws / VMess + tcp + http / shadowsocks)

# 功能预告

xtls + fallback(ws)

~~随机`Policy`，以缓解[Xray #1511](https://github.com/XTLS/Xray-core/issues/1511)中的主动探测。~~ 已完成

# Thanks

[网络跳跃(hijk)](https://github.com/hijkpw)

[project X](https://xtls.github.io)

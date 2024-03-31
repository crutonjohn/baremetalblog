---
title: Sheraton Wi-Fi on Linux
summary: "Captive Portals Suck"
description: "Stop using captive portals you cowards"
date: 2024-03-31
draft: false
toc: false
images:
categories:
  - tech
  - networking
tags:
  - tech
  - networking
---

To sign into roaming wifi at Sheraton hotels:

```bash
curl http://google.com > ~/login.html
```

find the login url:

```bash
cat ~/login.html

<HTML>
<!--access procedure=nx.1-->
<!--ndxid=0a820c-->
<!--protocol=https-->
<!--ndxhost=gateway.hsia.sonifi.net-->
<!--ndxport=1112-->
<!--<?xml version="1.0" encoding="UTF-8"?>
<WISPAccessGatewayParam
xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
xsi:noNamespaceSchemaLocation="http://www.acmewisp.com/WISPAccessGatewayParam.xsd">
<Proxy>
<MessageType>110</MessageType>
<ResponseCode>200</ResponseCode>
<NextURL><![CDATA[https://snapx-us1.selectnetworx.com/GuestGPNS/welcome/1004250?UI=0a820c&NI=0050e80a820c&UIP=172.16.30.2&MA=04CF4B219F85&RN=VLAN_1000&PORT=1000&RAD=yes&PP=no&PMS=yes&SIP=172.20.2.167&OS=http://www.google.com%2F]]></NextURL>
</Proxy>
</WISPAccessGatewayParam>-->
</HTML>
```

In my instance you want this URL from the output: `https://snapx-us1.selectnetworx.com/GuestGPNS/welcome/1004250?UI=0a820c&NI=0050e80a820c&UIP=172.16.30.2&MA=04CF4B219F85&RN=VLAN_1000&PORT=1000&RAD=yes&PP=no&PMS=yes&SIP=172.20.2.167&OS=http://www.google.com%2F`

Open this URL in your web browser, and you should be good to go!

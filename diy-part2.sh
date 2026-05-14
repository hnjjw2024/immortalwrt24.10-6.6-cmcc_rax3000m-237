#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

# Modify default IP
sudo apt install -y libfuse-dev
rm -rf feeds/packages/lang/golang
git clone https://github.com/sbwml/packages_lang_golang -b 24.x feeds/packages/lang/golang

# 单独禁用 lucky 插件（LuCI 界面 + 核心二进制）
sed -i 's/CONFIG_PACKAGE_luci-app-lucky=y/CONFIG_PACKAGE_luci-app-lucky=n/' .config
sed -i 's/CONFIG_PACKAGE_lucky=y/CONFIG_PACKAGE_lucky=n/' .config

# 追加打印服务配置
cat >> diy-part2.sh << 'EOF'

# ========================================
# USB Printer & CUPS Support
# ========================================
./scripts/feeds update packages

cat >> .config << 'CUSPS_EOF'

# USB Printer & CUPS Support
CONFIG_PACKAGE_kmod-usb-printer=y
CONFIG_PACKAGE_cups=y
CONFIG_PACKAGE_cups-client=y
CONFIG_PACKAGE_cups-filters=y
CONFIG_PACKAGE_libcups=y
CONFIG_PACKAGE_libcupsimage=y
CONFIG_CUPS_HAS_WEBIF=y
CUSPS_EOF

sed -i '/# CONFIG_PACKAGE_kmod-usb-printer is not set/d' .config
sed -i '/# CONFIG_PACKAGE_cups.*is not set/d' .config

make defconfig
echo "✅ CUPS 打印服务配置完成"
EOF

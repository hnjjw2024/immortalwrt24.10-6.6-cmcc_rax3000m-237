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

echo "🔧 开始执行自定义配置..."

# ========================================
# 1. 基础环境准备
# ========================================
sudo apt install -y libfuse-dev 2>/dev/null || true

# 更新 Golang（如需）
rm -rf feeds/packages/lang/golang
git clone https://github.com/sbwml/packages_lang_golang -b 24.x feeds/packages/lang/golang 2>/dev/null || true

# ========================================
# 2. 禁用 lucky 插件
# ========================================
echo "🚫 禁用 lucky 插件..."
sed -i 's/CONFIG_PACKAGE_luci-app-lucky=y/CONFIG_PACKAGE_luci-app-lucky=n/' .config
sed -i 's/CONFIG_PACKAGE_lucky=y/CONFIG_PACKAGE_lucky=n/' .config

# 在 diy-part2.sh 中禁Zabbix 和 Python-ubus用相关包
sed -i 's/CONFIG_PACKAGE_zabbix.*=y/# CONFIG_PACKAGE_zabbix is not set/g' .config
sed -i 's/CONFIG_PACKAGE_python-ubus.*=y/# CONFIG_PACKAGE_python-ubus is not set/g' .config
make defconfig
# ========================================
# 3. 添加 CUPS 打印服务支持 ⭐ 核心修复
# ========================================
echo "🖨️ 注入 CUPS 打印服务配置..."

# 3.1 确保 packages feed 已安装索引
./scripts/feeds install -a 2>/dev/null

# 3.2 直接注入配置到 .config（不要追加到脚本自身！）
cat >> .config << 'CUPS_CONFIG'

# ========== USB Printer & CUPS Support ==========
CONFIG_PACKAGE_kmod-usb-printer=y
CONFIG_PACKAGE_cups=y
CONFIG_PACKAGE_cups-client=y
CONFIG_PACKAGE_cups-filters=y
CONFIG_PACKAGE_libcups=y
CONFIG_PACKAGE_libcupsimage=y
CONFIG_CUPS_HAS_WEBIF=y
# 可选：轻量级方案（二选一）
# CONFIG_PACKAGE_p910nd=y
CUPS_CONFIG

# 3.3 清理冲突的禁用配置
sed -i '/# CONFIG_PACKAGE_kmod-usb-printer is not set/d' .config
sed -i '/# CONFIG_PACKAGE_cups.*is not set/d' .config
sed -i '/# CONFIG_PACKAGE_libcups.*is not set/d' .config

# 3.4 立即更新配置依赖（关键！）
echo "⚙️ 更新配置依赖..."
make defconfig

# 3.5 验证配置是否注入成功
if grep -q "CONFIG_PACKAGE_cups=y" .config && grep -q "CONFIG_PACKAGE_kmod-usb-printer=y" .config; then
    echo "✅ CUPS 配置注入成功！"
    echo "📦 已启用: cups, cups-client, cups-filters, kmod-usb-printer"
else
    echo "❌ CUPS 配置注入失败，请检查 .config 文件"
    exit 1
fi

# ========================================
# 4. 其他自定义配置（按需添加）
# ========================================
# 示例：修改默认主题
# sed -i 's/CONFIG_PACKAGE_luci-theme-bootstrap=y/CONFIG_PACKAGE_luci-theme-argon=y/' .config

echo "✅ 自定义配置完成，继续编译..."

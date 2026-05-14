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

echo "========================================"
echo "🔧 开始执行自定义配置脚本..."
echo "========================================"

# ========================================
# 1. 基础环境准备
# ========================================
echo "📦 安装系统依赖..."
sudo apt install -y libfuse-dev 2>/dev/null || true

# 更新 Golang（如需）
echo "🔄 更新 Golang 源..."
rm -rf feeds/packages/lang/golang
git clone https://github.com/sbwml/packages_lang_golang -b 24.x feeds/packages/lang/golang 2>/dev/null || true

# ========================================
# 2. 禁用 lucky 插件（按需）
# ========================================
echo "🚫 处理 lucky 插件配置..."
sed -i 's/CONFIG_PACKAGE_luci-app-lucky=y/CONFIG_PACKAGE_luci-app-lucky=n/' .config 2>/dev/null || true
sed -i 's/CONFIG_PACKAGE_lucky=y/CONFIG_PACKAGE_lucky=n/' .config 2>/dev/null || true

# ========================================
# 3. 添加 CUPS 打印服务支持 ⭐ 核心功能
# ========================================
echo "🖨️ 注入 CUPS 打印服务配置..."

# 3.1 确保 packages feed 索引最新
echo "📥 更新 packages feed 索引..."
./scripts/feeds update packages 2>/dev/null
./scripts/feeds install -a 2>/dev/null

# 3.2 注入 CUPS 配置到 .config
echo "📝 写入 CUPS 配置项..."
cat >> .config << 'CUPS_CONFIG'

# ========================================
# USB Printer & CUPS Support Configuration
# ========================================

# 1. USB Printer Kernel Module (必需)
CONFIG_PACKAGE_kmod-usb-printer=y

# 2. CUPS Core Packages
CONFIG_PACKAGE_cups=y
CONFIG_PACKAGE_cups-client=y
CONFIG_PACKAGE_cups-filters=y

# 3. CUPS Libraries (必需依赖)
CONFIG_PACKAGE_libcups=y
CONFIG_PACKAGE_libcupsimage=y

# 4. 可选依赖（提升打印机兼容性，尤其是 HP 喷墨打印机）
CONFIG_PACKAGE_libpng=y
CONFIG_PACKAGE_libjpeg=y
CONFIG_PACKAGE_libtiff=y

# 5. CUPS Features
CONFIG_CUPS_HAS_WEBIF=y
# CONFIG_CUPS_HAS_DBUS is not set    # 禁用 D-Bus 节省空间
# CONFIG_CUPS_HAS_GSSAPI is not set  # 禁用 GSSAPI 节省空间

# 6. 可选：PPD 驱动工具
# CONFIG_PACKAGE_cups-ppdc=y

# 7. 备选方案：p910nd 轻量级打印服务（二选一）
# 启用方法：注释上方 CUPS 配置，取消下方注释
# CONFIG_PACKAGE_p910nd=y
# CONFIG_PACKAGE_kmod-usb-printer=y

# ========================================
# End of Print Service Configuration
# ========================================
CUPS_CONFIG

# 3.3 清理冲突的禁用配置
echo "🧹 清理冲突配置项..."
sed -i '/# CONFIG_PACKAGE_kmod-usb-printer is not set/d' .config
sed -i '/# CONFIG_PACKAGE_cups.*is not set/d' .config
sed -i '/# CONFIG_PACKAGE_libcups.*is not set/d' .config
sed -i '/# CONFIG_PACKAGE_libcupsimage is not set/d' .config
sed -i '/# CONFIG_PACKAGE_libpng is not set/d' .config
sed -i '/# CONFIG_PACKAGE_libjpeg is not set/d' .config
sed -i '/# CONFIG_PACKAGE_libtiff is not set/d' .config
sed -i '/# CONFIG_PACKAGE_p910nd is not set/d' .config

# 3.4 立即更新配置依赖
echo "⚙️ 更新配置依赖关系..."
make defconfig >/dev/null 2>&1

# ========================================
# 4. 修改 CUPS 默认配置文件 ⭐ 新增：访问控制自动适配
# ========================================
echo "🔐 修改 CUPS 默认访问控制配置..."

# 查找 cups 包的安装目录中的默认 cupsd.conf
CUPSD_CONF_PATH=""

# 优先查找 packages 目录中的源文件
if [ -f "package/feeds/packages/cups/files/cupsd.conf" ]; then
    CUPSD_CONF_PATH="package/feeds/packages/cups/files/cupsd.conf"
elif [ -f "package/cups/files/cupsd.conf" ]; then
    CUPSD_CONF_PATH="package/cups/files/cupsd.conf"
elif [ -f "feeds/packages/cups/files/cupsd.conf" ]; then
    CUPSD_CONF_PATH="feeds/packages/cups/files/cupsd.conf"
fi

if [ -n "$CUPSD_CONF_PATH" ] && [ -f "$CUPSD_CONF_PATH" ]; then
    echo "✅ 找到 cupsd.conf: $CUPSD_CONF_PATH"
    
    # 修改访问控制：将硬编码网段改为 @LOCAL（自动允许所有直连局域网）
    sed -i 's/Allow From 127\.0\.0\.1/Allow From 127.0.0.1\n  Allow From @LOCAL/g' "$CUPSD_CONF_PATH"
    sed -i 's/Allow From 192\.168\.1\.0\/24/Allow From @LOCAL/g' "$CUPSD_CONF_PATH"
    
    # 确保 WebInterface 启用
    sed -i 's/WebInterface [Nn]o/WebInterface Yes/g' "$CUPSD_CONF_PATH"
    
    echo "✅ cupsd.conf 访问控制已修改为 @LOCAL"
else
    echo "⚠️  未找到 cupsd.conf 源文件，将在固件首次启动时通过脚本修复"
    
    # 创建首次启动修复脚本（备选方案）
    mkdir -p files/etc/uci-defaults
    cat > files/etc/uci-defaults/99-fix-cups-access << 'EOF'
#!/bin/sh
# 首次启动时修复 CUPS 访问控制

if [ -f /etc/cups/cupsd.conf ]; then
    # 修改访问控制为 @LOCAL
    sed -i 's/Allow From 127\.0\.0\.1/Allow From 127.0.0.1\n  Allow From @LOCAL/g' /etc/cups/cupsd.conf
    sed -i 's/Allow From 192\.168\.1\.0\/24/Allow From @LOCAL/g' /etc/cups/cupsd.conf
    
    # 确保 Web 界面启用
    sed -i 's/WebInterface [Nn]o/WebInterface Yes/g' /etc/cups/cupsd.conf
    
    # 重启 CUPS 服务
    /etc/init.d/cupsd restart
fi
exit 0
EOF
    chmod +x files/etc/uci-defaults/99-fix-cups-access
    echo "✅ 已创建首次启动修复脚本: files/etc/uci-defaults/99-fix-cups-access"
fi

# ========================================
# 5. 验证配置注入结果
# ========================================
echo "🔍 验证配置注入结果..."
if grep -q "CONFIG_PACKAGE_cups=y" .config && \
   grep -q "CONFIG_PACKAGE_kmod-usb-printer=y" .config && \
   grep -q "CONFIG_PACKAGE_libcups=y" .config; then
    echo "✅ CUPS 配置注入成功！"
    echo ""
    echo "📦 已启用组件:"
    echo "   • kmod-usb-printer  (USB 打印机内核模块)"
    echo "   • cups              (CUPS 打印服务核心)"
    echo "   • cups-client       (CUPS 客户端工具)"
    echo "   • cups-filters      (CUPS 过滤驱动)"
    echo "   • libcups           (CUPS 核心库)"
    echo "   • libcupsimage      (CUPS 图像处理库)"
    echo "   • libpng/libjpeg    (图像格式支持)"
    echo ""
    echo "🔐 访问控制: @LOCAL (自动允许所有直连局域网，含 192.168.6.0/24)"
    echo "🌐 管理界面: https://路由器IP:631"
    echo "🔑 登录账号: root / 路由器密码"
    echo ""
    echo "📋 刷写固件后配置步骤:"
    echo "   1. SSH 登录路由器: ssh root@192.168.6.1"
    echo "   2. 启动 CUPS 服务:"
    echo "      /etc/init.d/cupsd enable"
    echo "      /etc/init.d/cupsd start"
    echo "   3. 插入打印机后检查设备节点:"
    echo "      ls -l /dev/usb/lp0"
    echo "   4. 浏览器访问: https://192.168.6.1:631 添加打印机"
    echo "      (如遇证书警告，点击'高级'→'继续访问')"
    echo ""
    echo "⚠️  HP Smart Tank 510 兼容性提示:"
    echo "   • 优先使用打印机内置 Wi-Fi (支持 AirPrint)"
    echo "   • 如通过 USB 共享，在 CUPS 界面选择:"
    echo "     'HP → Smart Tank 510 series' 或 'Raw Queue'"
else
    echo "❌ CUPS 配置注入失败！"
    echo "🔍 请检查 .config 文件内容:"
    grep -E "cups|usb-printer" .config || echo "   (未找到相关配置)"
    exit 1
fi

# ========================================
# 6. 固件空间检查（RAX3000M eMMC 版）
# ========================================
echo "📊 固件空间检查..."
PARTSIZE=$(grep "CONFIG_TARGET_ROOTFS_PARTSIZE=" .config 2>/dev/null | cut -d'=' -f2 | tr -d '"')
if [ -n "$PARTSIZE" ] && [ "$PARTSIZE" -ge 160 ]; then
    echo "✅ 根文件系统: ${PARTSIZE}MB (充足，CUPS 约占用 10-13MB)"
else
    echo "⚠️  根文件系统: ${PARTSIZE:-未知}MB"
    echo "💡  CUPS 完整方案建议 ≥128MB，当前配置可能空间紧张"
fi

# ========================================
# 7. 编译前最终确认
# ========================================
echo ""
echo "========================================"
echo "✅ 自定义配置全部完成！"
echo "========================================"
echo ""
echo "🚀 下一步操作:"
echo "   1. (可选) 手动确认配置: make menuconfig"
echo "   2. 开始编译固件: make -j\$(nproc) V=s"
echo "   3. 或使用 GitHub Actions 自动编译"
echo ""
echo "📖 文档参考:"
echo "   • CUPS 官方: https://www.cups.org/documentation.html"
echo "   • OpenWrt:   https://openwrt.org/docs/guide-user/services/cups"
echo "   • 问题反馈:  查看编译日志或固件刷写后 dmesg"
echo "========================================"

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
# =================================================================
# [FIX] RAX3000M: Remove redundant AN8855 nodes from DTS
# =================================================================

echo "🔧 Patching RAX3000M DTS to remove AN8855 nodes..."

# 目标文件路径（immortalwrt-mt798x-6.6 内核）
DTS_PATH="target/linux/mediatek/dts/mt7981b-cmcc-rax3000m.dts"

if [ -f "$DTS_PATH" ]; then
    # 备份原文件
    cp "$DTS_PATH" "${DTS_PATH}.bak"
    
    # 使用 awk 精准删除 an8855-mfd 节点（处理嵌套括号）
    # 匹配从 "mfd: mfd@1 {" 开始，到对应 "};" 结束的完整节点块
    awk '
    BEGIN { in_an8855=0; brace_count=0 }
    
    # 检测 AN8855 MFD 节点起始
    /mfd:\s*mfd@1\s*\{/ && /airoha,an8855-mfd/ {
        in_an8855=1
        brace_count=1
        next
    }
    
    # 如果在删除区域内，统计括号层级
    in_an8855 {
        # 统计当前行的 { 和 }
        for(i=1; i<=length($0); i++) {
            c = substr($0, i, 1)
            if(c == "{") brace_count++
            if(c == "}") brace_count--
        }
        # 括号闭合且层级归零，结束删除
        if(brace_count <= 0) {
            in_an8855=0
        }
        next
    }
    
    # 正常输出其他行
    { print }
    ' "${DTS_PATH}.bak" > "$DTS_PATH"
    
    # 二次清理：确保没有残留的 an8855 兼容字符串
    sed -i '/airoha,an8855/d' "$DTS_PATH"
    
    # 验证结果
    if grep -q "an8855" "$DTS_PATH"; then
        echo "⚠️  Warning: Some an8855 references may remain, please check $DTS_PATH manually"
    else
        echo "✅ Success: Removed all AN8855 nodes from $DTS_PATH"
    fi
else
    echo "❌ Error: DTS file not found at $DTS_PATH"
    echo "📁 Available DTS files:"
    find target/linux/mediatek -name "*rax3000m*.dts" 2>/dev/null
fi
# 单独禁用 lucky 插件（LuCI 界面 + 核心二进制）
sed -i 's/CONFIG_PACKAGE_luci-app-lucky=y/CONFIG_PACKAGE_luci-app-lucky=n/' .config
sed -i 's/CONFIG_PACKAGE_lucky=y/CONFIG_PACKAGE_lucky=n/' .config

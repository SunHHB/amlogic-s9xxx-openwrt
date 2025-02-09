#!/bin/bash
#================================================================================================
#
# This file is licensed under the terms of the GNU General Public
# License version 2. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.
#
# This file is a part of the make OpenWrt for Amlogic s9xxx tv box
# https://github.com/ophub/amlogic-s9xxx-openwrt
#
# Description: Build OpenWrt with Image Builder
# Copyright (C) 2021~ https://github.com/unifreq/openwrt_packit
# Copyright (C) 2021~ https://github.com/ophub/amlogic-s9xxx-openwrt
# Copyright (C) 2021~ https://downloads.openwrt.org/releases
# Copyright (C) 2023~ https://downloads.immortalwrt.org/releases
#
# Download from: https://downloads.openwrt.org/releases
#                https://downloads.immortalwrt.org/releases
#
# Documentation: https://openwrt.org/docs/guide-user/additional-software/imagebuilder
# Instructions:  Download OpenWrt firmware from the official OpenWrt,
#                Use Image Builder to add packages, lib, theme, app and i18n, etc.
#
# Command: ./config/imagebuilder/imagebuilder.sh <source:branch>
#          ./config/imagebuilder/imagebuilder.sh openwrt:21.02.3
#
#======================================== Functions list ========================================
#
# error_msg               : Output error message
# download_imagebuilder   : Downloading OpenWrt ImageBuilder
# adjust_settings         : Adjust related file settings
# custom_packages         : Add custom packages
# custom_config           : Add custom config
# custom_files            : Add custom files
# rebuild_firmware        : rebuild_firmware
#
#================================ Set make environment variables ================================
#
# Set default parameters
make_path="${PWD}"
openwrt_dir="imagebuilder"
imagebuilder_path="${make_path}/${openwrt_dir}"
custom_files_path="${make_path}/config/imagebuilder/files"
custom_config_file="${make_path}/config/imagebuilder/config"

# Set default parameters
STEPS="[\033[95m STEPS \033[0m]"
INFO="[\033[94m INFO \033[0m]"
SUCCESS="[\033[92m SUCCESS \033[0m]"
WARNING="[\033[93m WARNING \033[0m]"
ERROR="[\033[91m ERROR \033[0m]"
#
#================================================================================================

# Encountered a serious error, abort the script execution
error_msg() {
    echo -e "${ERROR} ${1}"
    exit 1
}

# Downloading OpenWrt ImageBuilder
download_imagebuilder() {
    cd ${make_path}
    echo -e "${STEPS} Start downloading OpenWrt files..."

    # Determine the target system (Imagebuilder files naming has changed since 23.05.0)
    if [[ "${op_branch:0:2}" -ge "23" && "${op_branch:3:2}" -ge "05" ]]; then
        target_system="armsr/armv8"
        target_name="armsr-armv8"
        target_profile="generic"
    else
        target_system="armvirt/64"
        target_name="armvirt-64"
        target_profile="Default"
    fi

    # Downloading imagebuilder files
    download_file="https://downloads.${op_sourse}.org/releases/${op_branch}/targets/${target_system}/${op_sourse}-imagebuilder-${op_branch}-${target_name}.Linux-x86_64.tar.xz"
    curl -fsSOL ${download_file}
    [[ "${?}" -eq "0" ]] || error_msg "Download failed: [ ${download_file} ]"

    # Unzip and change the directory name
    tar -xJf *-imagebuilder-* && sync && rm -f *-imagebuilder-*.tar.xz
    mv -f *-imagebuilder-* ${openwrt_dir}

    sync && sleep 3
    echo -e "${INFO} [ ${make_path} ] directory status: $(ls -al 2>/dev/null)"
}

# Adjust related files in the ImageBuilder directory
adjust_settings() {
    cd ${imagebuilder_path}
    echo -e "${STEPS} Start adjusting .config file settings..."

    # For .config file
    if [[ -s ".config" ]]; then
        # Root filesystem archives
        sed -i "s|CONFIG_TARGET_ROOTFS_CPIOGZ=.*|# CONFIG_TARGET_ROOTFS_CPIOGZ is not set|g" .config
        # Root filesystem images
        sed -i "s|CONFIG_TARGET_ROOTFS_EXT4FS=.*|# CONFIG_TARGET_ROOTFS_EXT4FS is not set|g" .config
        sed -i "s|CONFIG_TARGET_ROOTFS_SQUASHFS=.*|# CONFIG_TARGET_ROOTFS_SQUASHFS is not set|g" .config
        sed -i "s|CONFIG_TARGET_IMAGES_GZIP=.*|# CONFIG_TARGET_IMAGES_GZIP is not set|g" .config
	sed -i "s/install \$(BUILD_PACKAGES)/install \$(BUILD_PACKAGES) --force-overwrite/" Makefile
        sed -i "s/CONFIG_TARGET_KERNEL_PARTSIZE=16/CONFIG_TARGET_KERNEL_PARTSIZE=64/" .config
	sed -i "s/CONFIG_TARGET_ROOTFS_PARTSIZE=300/CONFIG_TARGET_ROOTFS_PARTSIZE=800/" .config

    else
        echo -e "${INFO} [ ${imagebuilder_path} ] directory status: $(ls -al 2>/dev/null)"
        error_msg "There is no .config file in the [ ${download_file} ]"
    fi

    # For other files
    # ......

    sync && sleep 3
    echo -e "${INFO} [ ${imagebuilder_path} ] directory status: $(ls -al 2>/dev/null)"
}

# Add custom packages
# If there is a custom package or ipk you would prefer to use create a [ packages ] directory,
# If one does not exist and place your custom ipk within this directory.
custom_packages() {
    cd ${imagebuilder_path}
    echo -e "${STEPS} Start adding custom packages..."

    # Create a [ packages ] directory
    [[ -d "packages" ]] || mkdir packages
    cd packages

    # Download luci-app-amlogic
    amlogic_api="https://api.github.com/repos/ophub/luci-app-amlogic/releases"
    #
    amlogic_file="luci-app-amlogic"
    amlogic_file_down="$(curl -s ${amlogic_api} | grep "browser_download_url" | grep -oE "https.*${amlogic_name}.*.ipk" | head -n 1)"
    curl -fsSOJL ${amlogic_file_down}
    [[ "${?}" -eq "0" ]] || error_msg "[ ${amlogic_file} ] download failed!"
    echo -e "${INFO} The [ ${amlogic_file} ] is downloaded successfully."
    #
    amlogic_i18n="luci-i18n-amlogic"
    amlogic_i18n_down="$(curl -s ${amlogic_api} | grep "browser_download_url" | grep -oE "https.*${amlogic_i18n}.*.ipk" | head -n 1)"
    curl -fsSOJL ${amlogic_i18n_down}
    [[ "${?}" -eq "0" ]] || error_msg "[ ${amlogic_i18n} ] download failed!"
    echo -e "${INFO} The [ ${amlogic_i18n} ] is downloaded successfully."

    # Download other luci-app-xxx
    other_packages="armv8_packages"
    other_packages_down="https://github.com/SunHHB/op_armsr/releases/latest/download/packages.tar.gz"
    curl -fsSOJL ${other_packages_down}
    [[ "${?}" -eq "0" ]] || error_msg "[ ${other_packages} ] download failed!"
    echo -e "${INFO} The [ ${other_packages} ] is downloaded successfully."

    luci_openclash="luci-app-openclash"
    luci_openclash_down="https://github.com/vernesong/OpenClash/releases/download/v0.46.064/luci-app-openclash_0.46.064_all.ipk"
    curl -fsSOJL ${luci_openclash_down}
    [[ "${?}" -eq "0" ]] || error_msg "[ ${luci_openclash} ] download failed!"
    echo -e "${INFO} The [ ${luci_openclash} ] is downloaded successfully."
    
    luci_cloudflared="luci-app-cloudflared"
    luci_cloudflared_down="https://github.com/moetayuko/openwrt-cloudflared/releases/download/2025.1.1-r1/cloudflared-2025.1.1-r1-aarch64_generic.apk"
    curl -fsSOJL ${luci_cloudflared_down}
    [[ "${?}" -eq "0" ]] || error_msg "[ ${luci_cloudflared} ] download failed!"
    echo -e "${INFO} The [ ${luci_cloudflared} ] is downloaded successfully."
    
    ls *.tar.gz | xargs -n1 tar xzvf
    rm *tar.gz

    sync && sleep 3
    echo -e "${INFO} [ packages ] directory status: $(ls -al 2>/dev/null)"
}

# Add custom packages, lib, theme, app and i18n, etc.
custom_config() {
    cd ${imagebuilder_path}
    echo "Start Clash Core Download !"
    mkdir -p files/etc/openclash && cd files/etc/openclash
    CLASH_META_URL="https://github.com/SunHHB/ShellCrash/raw/refs/heads/dev/bin/meta/clash-linux-armv8"
    GEO_MMDB="https://github.com/alecthw/mmdb_china_ip_list/raw/release/lite/Country.mmdb"
    GEO_SITE="https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geosite.dat"
    GEO_IP="https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geoip.dat"
    GEO_META="https://github.com/MetaCubeX/meta-rules-dat/raw/release/geoip.metadb"
   
    curl -sfL -o Country.mmdb $GEO_MMDB
    curl -sfL -o GeoSite.dat $GEO_SITE
    curl -sfL -o GeoIP.dat $GEO_IP
    curl -sfL -o GeoIP.metadb $GEO_META
    mkdir ./core/ && cd ./core/
  # curl -sfL -o meta.tar.gz $CORE_MATE && tar -zxf meta.tar.gz && mv -f CrashCore clash_meta
  #wget -qO- $CORE_MATE | tar xOvz > clash_meta
   wget -qO- $CLASH_META_URL > clash_meta
   chmod +x ./clash* && rm -rf ./*.gz
   echo "openclash date has been updated!"
 
}

# Add custom files
# The FILES variable allows custom configuration files to be included in images built with Image Builder.
# The [ files ] directory should be placed in the Image Builder root directory where you issue the make command.
custom_files() {
    cd ${imagebuilder_path}
    echo -e "${STEPS} Start adding custom files..."

    if [[ -d "${custom_files_path}" ]]; then
        # Copy custom files
        [[ -d "files" ]] || mkdir -p files
        cp -rf ${custom_files_path}/* files

        sync && sleep 3
        echo -e "${INFO} [ files ] directory status: $(ls files -al 2>/dev/null)"
    else
        echo -e "${INFO} No customized files were added."
    fi
}

# Rebuild OpenWrt firmware
rebuild_firmware() {
    cd ${imagebuilder_path}
    echo -e "${STEPS} Start building OpenWrt with Image Builder..."

    # Selecting default packages, lib, theme, app and i18n, etc.
     make info
     # 主配置名称
     
     PACKAGES=""
      # 主题
     PACKAGES="$PACKAGES luci-theme-argon luci-i18n-argon-config-zh-cn"
     # 常用kmod组件
     PACKAGES="$PACKAGES git bash"
     PACKAGES="$PACKAGES kmod-usb2 kmod-usb3 kmod-usb-ohci kmod-usb-uhci usbutils"
     PACKAGES="$PACKAGES kmod-usb-printer"
     # MT76x2u 网卡驱动或无线组件
     PACKAGES="$PACKAGES kmod-mt76x2u hostapd wpa-supplicant"
     # 常用软件服务
     PACKAGES="$PACKAGES luci-i18n-usb-printer-zh-cn"
     PACKAGES="$PACKAGES luci-i18n-ttyd-zh-cn"
     PACKAGES="$PACKAGES luci-i18n-vlmcsd-zh-cn"
     PACKAGES="$PACKAGES luci-i18n-wol-zh-cn"
     PACKAGES="$PACKAGES luci-i18n-ddns-go-zh-cn"
     PACKAGES="$PACKAGES luci-i18n-autoreboot-zh-cn"
     # PACKAGES="$PACKAGES luci-i18n-ramfree-zh-cn"
     PACKAGES="$PACKAGES luci-i18n-cloudflared-zh-cn"
     PACKAGES="$PACKAGES luci-i18n-socat-zh-cn"

     # tailscale
     PACKAGES="$PACKAGES tailscale"
     PACKAGES="$PACKAGES luci-app-tailscale"
     PACKAGES="$PACKAGES luci-i18n-tailscale-zh-cn"

     #PACKAGES="$PACKAGES luci-i18n-ddns-zh-cn"
     # upnp
     PACKAGES="$PACKAGES luci-i18n-upnp-zh-cn"
     # OpenClash 代理
     PACKAGES="$PACKAGES luci-app-openclash"
    # Docker 组件
    # PACKAGES="$PACKAGES luci-lib-docker luci-i18n-dockerman-zh-cn"
    # homeproxy 组件
    # PACKAGES="$PACKAGES luci-i18n-homeproxy-zh-cn"
    # alsit 组件	
    PACKAGES="$PACKAGES alist luci-i18n-alist-zh-cn"
    # mosdns 组件	
    PACKAGES="$PACKAGES luci-i18n-mosdns-zh-cn"
    # XUNLEI组件
    # PACKAGES="$PACKAGES libc6-compat xunlei luci-app-xunlei luci-i18n-xunlei-zh-cn"
    # 宽带监控 Nlbwmon
    PACKAGES="$PACKAGES luci-i18n-nlbwmon-zh-cn"
    # Diskman 磁盘管理
    PACKAGES="$PACKAGES luci-i18n-diskman-zh-cn"
    # zsh 终端
    PACKAGES="$PACKAGES zsh"
    PACKAGES="luci-app-amlogic luci-i18n-amlogic-zh-cn"
    # Vim 完整版，带语法高亮
    PACKAGES="$PACKAGES vim-fuller"
    # 界面翻译补全
    PACKAGES="$PACKAGES luci-i18n-opkg-zh-cn luci-i18n-base-zh-cn luci-i18n-firewall-zh-cn"
    # 移除不需要的包

    # 一些自定义文件
    FILES="files"

    # Rebuild firmware
    make image PROFILE="${target_profile}" PACKAGES="$PACKAGES" FILES="files"

    sync && sleep 3
    echo -e "${INFO} [ ${openwrt_dir}/bin/targets/*/* ] directory status: $(ls bin/targets/*/* -al 2>/dev/null)"
    echo -e "${SUCCESS} The rebuild is successful, the current path: [ ${PWD} ]"
}

# Show welcome message
echo -e "${STEPS} Welcome to Rebuild OpenWrt Using the Image Builder."
[[ -x "${0}" ]] || error_msg "Please give the script permission to run: [ chmod +x ${0} ]"
[[ -z "${1}" ]] && error_msg "Please specify the OpenWrt Branch, such as [ ${0} openwrt:22.03.3 ]"
[[ "${1}" =~ ^[a-z]{3,}:[0-9]+ ]] || error_msg "Incoming parameter format <source:branch>: openwrt:22.03.3"
op_sourse="${1%:*}"
op_branch="${1#*:}"
echo -e "${INFO} Rebuild path: [ ${PWD} ]"
echo -e "${INFO} Rebuild Source: [ ${op_sourse} ], Branch: [ ${op_branch} ]"
echo -e "${INFO} Server space usage before starting to compile: \n$(df -hT ${make_path}) \n"
#
# Perform related operations
download_imagebuilder
adjust_settings
custom_packages
custom_config
custom_files
rebuild_firmware
#
# Show server end information
echo -e "Server space usage after compilation: \n$(df -hT ${make_path}) \n"
# All process completed
wait

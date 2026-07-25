# Copyright (c) 2026 Majaahh
# SPDX-License-Identifier: GPL-3.0-or-later

# Firmware
for v in "SM-A3360" "SM-A336B" "SM-A336E" "SM-A336M" "SM-A336N"; do
    if [ -d "$WORK_DIR/vendor/firmware/$v" ]; then
        EVAL "rm -rf \"$WORK_DIR/vendor/firmware/$v\""
    fi
    EVAL "mkdir -p \"$WORK_DIR/vendor/firmware/$v\""
    SET_METADATA "vendor" "firmware/$v" 0 2000 755 "u:object_r:vendor_fw_file:s0"

    for f in "AP_AUDIO_SLSI.bin" "APDV_AUDIO_SLSI.bin" \
            "calliope_sram.bin" "mfc_fw.bin" "NPU.bin" \
            "os.checked.bin" "vts.bin"; do
        if [ -f "$WORK_DIR/vendor/firmware/$f" ]; then
            LOG "- Moving /vendor/firmware/$f to /vendor/firmware/$v/$f"
            EVAL "cp \"$WORK_DIR/vendor/firmware/$f\" \"$WORK_DIR/vendor/firmware/$v/$f\""
            SET_METADATA "vendor" "firmware/$v/$f" 0 0 644 "u:object_r:vendor_fw_file:s0"
        fi
    done
done

# Cleanup dummy firmware from root
for f in "AP_AUDIO_SLSI.bin" "APDV_AUDIO_SLSI.bin" \
        "calliope_sram.bin" "mfc_fw.bin" "NPU.bin" \
        "os.checked.bin" "vts.bin"; do
    if [ -f "$WORK_DIR/vendor/firmware/$f" ]; then
        EVAL "rm -f \"$WORK_DIR/vendor/firmware/$f\""
        EVAL "touch \"$WORK_DIR/vendor/firmware/$f\""
    fi
done

# TEEgris - Firmware
TEEGRIS_ZIPS=(
    # a33xks (kor_singlex)
    "A336NKSSBFYH1/A336NKSSBFYH1_tee.zip"
    # a33xub (latam_open)
    "A336MUBSEFYH2/A336MUBSEFYH2_tee.zip"
    # a33xnsxx (eur_open)
    "A336BXXSEFYH2/A336BXXSEFYH2_tee.zip"
    # a33xzh (chn_hk)
    "A3360ZHSEFYH2/A3360ZHSEFYH2_tee.zip"
    # a33xnsdxx (asia_open)
    "A336EDXSEFYH2/A336EDXSEFYH2_tee.zip"
)

if [ -d "$TMP_DIR" ]; then
    EVAL "rm -rf \"$TMP_DIR\""
fi
EVAL "mkdir -p \"$TMP_DIR\""

if [ -d "$WORK_DIR/vendor/firmware/tee" ]; then
    EVAL "rm -rf \"$WORK_DIR/vendor/firmware/tee\""
fi
EVAL "mkdir -p \"$WORK_DIR/vendor/firmware/tee\""
SET_METADATA "vendor" "firmware/tee" 0 2000 755 "u:object_r:tee_file:s0"

for f in "${TEEGRIS_ZIPS[@]}"; do
    FILE_NAME="$(basename "$f")"

    LOG "- Downloading $FILE_NAME"
    DOWNLOAD_FILE "https://github.com/fynrae/proprietary_vendor_samsung_a33x/releases/download/$f" "$TMP_DIR/$FILE_NAME"

    MODEL="SM-$(cut -c1-5 <<< "$FILE_NAME")"
    TEE_DIR="$WORK_DIR/vendor/firmware/tee/$MODEL"

    if [ -d "$TEE_DIR" ]; then
        EVAL "rm -rf \"$TEE_DIR\""
    fi
    EVAL "mkdir -p \"$TEE_DIR\""
    SET_METADATA "vendor" "firmware/tee/$(basename "$TEE_DIR")" 0 2000 755 "u:object_r:tee_file:s0"

    LOG "- Extracting ${TMP_DIR//$SRC_DIR\//}/$FILE_NAME to /${TEE_DIR//$WORK_DIR\//}"
    EVAL "unzip \"$TMP_DIR/$FILE_NAME\" -d \"$TEE_DIR\" > /dev/null"

    if [ -d "$TEE_DIR/tee" ]; then
        EVAL "mv \"$TEE_DIR/tee/\"* \"$TEE_DIR/\""
        EVAL "rm -rf \"$TEE_DIR/tee\""
    fi

    LOG "- Adding SEPolicy for TAs in /${TEE_DIR//$WORK_DIR\//}"
    while IFS= read -r t; do
        GROUP=0
        MODE="644"
        if [ -d "$TEE_DIR/$t" ]; then
            GROUP="2000"
            MODE="755"
        fi

        SET_METADATA "vendor" "firmware/tee/$(basename "$TEE_DIR")/$t" 0 "$GROUP" "$MODE" "u:object_r:tee_file:s0" > /dev/null

        unset GROUP MODE
    done < <(find "$TEE_DIR" | sed "s|$TEE_DIR||g" | sed "s/^\\///g" | sed "/^\$/d")

    EVAL "rm -f \"$TMP_DIR/$FILE_NAME\""

    unset FILE_NAME MODEL TEE_DIR
done

# Properties
ADD_TO_WORK_DIR "$MODPATH" "vendor_dlkm" "." 0 0 755 "u:object_r:vendor_file:s0"

for i in "odm" "vendor" "vendor_dlkm"; do
    PROP="$i/etc/build.prop"
    if [[ "$i" == "vendor" ]]; then
        PROP="$i/build.prop"
    fi

    {
        echo "# Added by target/a33x/patches/variants/customize.sh"
        echo "import /$i/etc/sku/\${ro.boot.em.model}.prop"
    } >> "$WORK_DIR/$PROP"

    unset PROP
done

LOG "- Adding SELinux entries"
{
    echo "(allow init_31_0 tee_file (dir (mounton)))"
    echo "(allow priv_app_31_0 tee_file (dir (getattr)))"
    echo "(allow init_31_0 vendor_fw_file (file (mounton)))"
    echo "(allow priv_app_31_0 vendor_fw_file (file (getattr)))"
} >> "$WORK_DIR/vendor/etc/selinux/vendor_sepolicy.cil" || return 1

# Nuke model checks
# Before: [mov r7,r0]
# After: [movs r7,#0x1]
HEX_PATCH "$WORK_DIR/vendor/lib/soundfx/libswdap.so" "3046884707463068" "3046884701273068"

# Before: [
#  ldr x8,[x8, #0x10]
#  blr x8
# ]
# After: [
#  mov w0,#0x1
#  nop
# ]
HEX_PATCH "$WORK_DIR/vendor/lib64/soundfx/libswdap.so" "e00315aa080940f900013fd6" "e00315aa200080521f2003d5"

unset TEEGRIS_ZIPS

REPOSITORY="https://github.com/fynrae/proprietary_vendor_samsung_a33x/releases/download/"
TARS=(
    # a33xnsdxx (asia_open)
    "A336EDXSEFYH2/BL_A336EDXSEFYH2_A336EDXSEFYH2_MQB99309930_REV00_user_low_ship_MULTI_CERT.tar.md5"
    "A336EDXSEFYH2/CP_A336EDXSEFYH2_CP31162942_MQB99309930_REV00_user_low_ship_MULTI_CERT.tar.md5"

    # a33xnsxx (eur_open)
    "A336BXXSEFYH2/BL_A336BXXSEFYH2_A336BXXSEFYH2_MQB99309924_REV00_user_low_ship_MULTI_CERT.tar.md5"
    "A336BXXSEFYH2/CP_A336BXXSEFYH2_CP31162939_MQB99309924_REV00_user_low_ship_MULTI_CERT.tar.md5"

    # a33xub (latam_open)
    "A336MUBSEFYH2/BL_A336MUBSEFYH2_A336MUBSEFYH2_MQB99549195_REV00_user_low_ship_MULTI_CERT.tar.md5"
    "A336MUBSEFYH2/CP_A336MUBSEFYH2_CP31238025_MQB99549195_REV00_user_low_ship_MULTI_CERT.tar.md5"

    # a33xks (kor_singlex)
    "A336NKSSBFYH1/BL_A336NKSSBFYH1_A336NKSSBFYH1_MQB99403667_REV00_user_low_ship_MULTI_CERT.tar.md5"
    "A336NKSSBFYH1/CP_A336NKOSBFYH1_CP31202905_MQB99403667_REV00_user_low_ship_MULTI_CERT.tar.md5"

    # a33xzh (chn_hk)
    "A3360ZHSEFYH2/BL_A3360ZHSEFYH2_A3360ZHSEFYH2_MQB99798029_REV00_user_low_ship_MULTI_CERT.tar.md5"
    "A3360ZHSEFYH2/CP_A3360ZHSEFYH2_CP31301209_MQB99798029_REV00_user_low_ship_MULTI_CERT.tar.md5"
)

for i in "${TARS[@]}"; do
    LOG "- Downloading $(basename "$i")"
    DOWNLOAD_FILE "$REPOSITORY/$i" "$TMP_DIR/$(basename "$i")" || return 1

done

while IFS= read -r f; do
    FILE_NAME="$(basename "$f")"
    LOG "- Verifying $FILE_NAME"

    FILE_NAME="${FILE_NAME%.md5}"

    # Samsung stores the output of `md5sum` at the very end of the file
    LENGTH="32" # Length of MD5 hash
    LENGTH="$((LENGTH + 2))" # 2 whitespace chars
    LENGTH="$((LENGTH + ${#FILE_NAME}))" # File name without .md5 extension
    LENGTH="$((LENGTH + 1))" # 1 newline char

    STORED_HASH="$(tail -c "$LENGTH" "$f" | cut -d " " -f 1 -s)"
    if [ ! "$STORED_HASH" ] || [[ "${#STORED_HASH}" != "32" ]]; then
        LOG "\033[0;31m! Expected hash could not be parsed\033[0m"
        return 1
    fi

    CALCULATED_HASH="$(head -c-$LENGTH "$f" | md5sum | cut -d " " -f 1 -s)"

    if [[ "$STORED_HASH" != "$CALCULATED_HASH" ]]; then
        LOG "\033[0;31m! File is damaged\033[0m"
        return 1
    fi

    FILE_NAME="$(basename "$f")"
    LOG "- Extracting $FILE_NAME"

    if [[ "$FILE_NAME" == "BL"* ]]; then
        BL_FIRMWARE_VER="$(cut -d "_" -f 2 <<< "$FILE_NAME")"
    elif [[ "$FILE_NAME" != "BL"* ]] && [ ! "$BL_FIRMWARE_VER" ]; then
        LOGE "BL_FIRMWARE_VER is not set"
        return 1
    fi

    FIRMWARE_DIR="$TMP_DIR/firmware/$BL_FIRMWARE_VER"

    if [ ! -d "$FIRMWARE_DIR" ]; then
        EVAL "mkdir -p \"$FIRMWARE_DIR\"" || return 1
    fi

    EVAL "cd \"$FIRMWARE_DIR\"; tar -xf \"$f\"" || return 1
    EVAL "rm -f \"$f\"" || return 1

    if [ -f "$FIRMWARE_DIR/modem_debug.bin.lz4" ]; then
        LOG "- Deleting ${FIRMWARE_DIR//$TMP_DIR\//}/modem_debug.bin.lz4"
        EVAL "rm -f \"$FIRMWARE_DIR/modem_debug.bin.lz4\"" || return 1
    fi

    unset FILE_NAME LENGTH STORED_HASH CALCULATED_HASH FIRMWARE_DIR
done < <(find "$TMP_DIR" -type f -name "*.md5")

while IFS= read -r f; do
    LOG "- Decompressing ${f#"$TMP_DIR"/}"
    EVAL "lz4 -d --rm \"$f\" \"${f%.lz4}\"" || return 1
done < <(find "$TMP_DIR" -type f -name "*.lz4")

while IFS= read -r f; do
    LOG "- Patching ${f#"$TMP_DIR"/}"
    # https://android.googlesource.com/platform/system/core/+/refs/tags/android-15.0.0_r1/fastboot/fastboot.cpp#1129
    EVAL "printf \"\x03\" | dd of=\"$f\" bs=1 seek=123 count=1 conv=notrunc" || return 1
done < <(find "$TMP_DIR" -type f -name "vbmeta.img")

unset REPOSITORY TARS BL_FIRMWARE_VER

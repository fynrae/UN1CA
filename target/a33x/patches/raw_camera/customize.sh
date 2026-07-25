# Enable RAW Support

# 32 bit
# Before: [
#  movs r0, #4
#  mov.w r3, #-1
#  stmia r2!, {r1, r5, r7}
# ]
# After: [
#  movs r0, #4
#  orr r7, r7, #0x10
#  stmia r2!, {r1, r5, r7}
# ]
HEX_PATCH "$WORK_DIR/vendor/lib/libexynoscamera3.so" \
    "04204ff0ff33a2c2" \
    "042047f01007a2c2"

# 64 bit
# Before: [
#  movz w0, #0x4
#  mov w7, w21
#  str x23, [sp]
# ]
# After: [
#  movz w0, #0x4
#  orr w23, w23, #0x10
#  str x23, [sp]
# ]
HEX_PATCH "$WORK_DIR/vendor/lib64/libexynoscamera3.so" \
    "80008052e703152af70300f9" \
    "80008052f7021c32f70300f9"

LOG_STEP_IN "- Creating required permissions"
LOG "- Generating /vendor/etc/permissions/android.hardware.camera.raw.xml"
# https://android.googlesource.com/platform/frameworks/native/+/refs/tags/android-16.0.0_r1/data/etc/android.hardware.camera.raw.xml
{
    echo "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
    echo "<!--"
    echo "    Copyright (c) 2014 The Android Open Source Project"
    echo "    SPDX-License-Identifier: Apache-2.0"
    echo "-->"
    echo "<permissions>"
    echo "    <feature name=\"android.hardware.camera.capability.raw\" />"
    echo "</permissions>"
} >> "$WORK_DIR/vendor/etc/permissions/android.hardware.camera.raw.xml"

SET_METADATA "vendor" "etc/permissions/android.hardware.camera.raw.xml" 0 0 644 "u:object_r:vendor_configs_file:s0"
LOG_STEP_OUT

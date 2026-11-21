"""Generate Android resources (vector icons, widget layouts) for UfiPeek."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from icons import ICONS, to_android

RES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "android", "app", "src", "main", "res")
A = 'xmlns:android="http://schemas.android.com/apk/res/android"'


def w(path, text):
    full = os.path.join(RES, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w", encoding="utf-8") as f:
        f.write(text)


# ---------- icons ----------
for name, parts in ICONS.items():
    w(f"drawable/{name}.xml", to_android(parts))

# ---------- shapes ----------
w("drawable/widget_bg.xml", f'''<?xml version="1.0" encoding="utf-8"?>
<shape {A} android:shape="rectangle">
    <solid android:color="@color/widget_bg"/>
    <corners android:radius="20dp"/>
</shape>
''')
w("drawable/chip_bg.xml", f'''<?xml version="1.0" encoding="utf-8"?>
<shape {A} android:shape="rectangle">
    <solid android:color="@color/chip_bg"/>
    <corners android:radius="8dp"/>
</shape>
''')

# ---------- launcher icon (adaptive) ----------
fg = []
for d, mode in ICONS["ic_router"]:
    if mode == "eo":
        fg.append(f'        <path android:fillColor="#FFFFFFFF" android:fillType="evenOdd" android:pathData="{d}"/>')
    elif mode == "fill":
        fg.append(f'        <path android:fillColor="#FFFFFFFF" android:pathData="{d}"/>')
    else:
        fg.append(f'        <path android:strokeColor="#FFFFFFFF" android:strokeWidth="{mode.split(":")[1]}" '
                  f'android:strokeLineCap="round" android:pathData="{d}"/>')
w("drawable/ic_launcher_foreground.xml", f'''<?xml version="1.0" encoding="utf-8"?>
<vector {A}
    android:width="108dp" android:height="108dp"
    android:viewportWidth="108" android:viewportHeight="108">
    <group android:translateX="30" android:translateY="28" android:scaleX="2" android:scaleY="2">
{chr(10).join(fg)}
    </group>
</vector>
''')
w("drawable/ic_launcher_background.xml", f'''<?xml version="1.0" encoding="utf-8"?>
<shape {A} android:shape="rectangle">
    <gradient android:startColor="#FF2F7BFF" android:endColor="#FF0040B8" android:angle="315"/>
</shape>
''')
w("mipmap-anydpi-v26/ic_launcher.xml", f'''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon {A}>
    <background android:drawable="@drawable/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
''')

# ---------- layout helpers ----------
SAMPLE = {
    "model": "U30 Air", "ufi_ver": "UFI v4.1.0", "signal_bar": "5", "battery": "90%",
    "daily_value": "9.88", "daily_unit": "GB", "monthly_value": "40.7", "monthly_unit": "GB",
    "net": "中国移动 5G", "band": "N41", "cpu": "4%", "temp": "48.4℃",
    "ssid": "ZTE_E8CDF6", "wifi_band": "5G", "mem": "58%", "devices": "2", "sms": "0",
    "signal_detail": "RSRP -90dBm · RSRQ -6 · SNR 12", "update_time": "08-05 12:59",
    "monthly": "40.7GB", "error_text": "",
}


def txt(id_, style, sample, extra=""):
    t = SAMPLE.get(id_, "--") if sample else ("" if id_ == "error_text" else "--")
    if id_ == "ufi_ver" and not sample:
        t = "UFI v--"
    if id_ == "battery" and not sample:
        t = "--%"
    return (f'<TextView android:id="@+id/{id_}" style="@style/{style}" '
            f'android:layout_width="wrap_content" android:layout_height="wrap_content" '
            f'android:text="{t}" {extra}/>')


def img(src, size, tint=None, id_=None, extra=""):
    i = f'android:id="@+id/{id_}" ' if id_ else ""
    t = f'android:tint="@color/{tint}" ' if tint else ""
    return (f'<ImageView {i}android:layout_width="{size}dp" android:layout_height="{size}dp" '
            f'android:src="@drawable/{src}" {t}{extra}/>')


def chip(id_, icon, tint, sample, text_extra="", icon_id=None, last=False):
    me = "" if last else 'android:layout_marginEnd="4dp" '
    return f'''        <LinearLayout android:layout_width="wrap_content" android:layout_height="wrap_content"
            android:orientation="horizontal" android:gravity="center_vertical"
            android:background="@drawable/chip_bg" {me}
            android:paddingStart="5dp" android:paddingEnd="6dp" android:paddingTop="2dp" android:paddingBottom="2dp">
            {img(icon, 11, tint, icon_id)}
            {txt(id_, "W.Chip", sample, 'android:layout_marginStart="3dp" ' + text_extra)}
        </LinearLayout>'''


def top_bar(sample):
    return f'''    <LinearLayout android:id="@+id/top_bar" android:layout_width="match_parent" android:layout_height="wrap_content"
        android:orientation="horizontal" android:gravity="center_vertical">
        {img("ic_router", 14, "router")}
        {txt("model", "W.Title", sample, 'android:layout_marginStart="4dp" android:maxLines="1"')}
        <TextView android:id="@+id/ufi_ver" style="@style/W.Small" android:layout_width="0dp" android:layout_weight="1"
            android:layout_height="wrap_content" android:layout_marginStart="6dp" android:maxLines="1" android:ellipsize="end"
            android:text="{SAMPLE['ufi_ver'] if sample else 'UFI v--'}"/>
        {img("ic_signal", 12, "text")}
        {txt("signal_bar", "W.Title", sample, 'android:layout_marginStart="3dp"')}
        <TextView style="@style/W.Small" android:layout_width="wrap_content" android:layout_height="wrap_content"
            android:layout_marginStart="5dp" android:layout_marginEnd="5dp" android:text="|" android:textColor="@color/divider"/>
        <ImageView android:id="@+id/bat_icon" android:layout_width="18dp" android:layout_height="18dp" android:src="@drawable/ic_bat_100"
            android:tint="#FF16A34A"/>
        {txt("battery", "W.Title", sample, 'android:layout_marginStart="2dp"')}
    </LinearLayout>'''


def traffic_block(prefix, label, sample):
    return f'''        <LinearLayout android:layout_width="0dp" android:layout_weight="1" android:layout_height="wrap_content"
            android:orientation="vertical" android:gravity="center_horizontal">
            <TextView style="@style/W.Label" android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="{label}"/>
            <LinearLayout android:layout_width="wrap_content" android:layout_height="wrap_content" android:orientation="horizontal"
                android:baselineAligned="true">
                {txt(prefix + "_value", "W.Big", sample)}
                {txt(prefix + "_unit", "W.Unit", sample, 'android:layout_marginStart="2dp"')}
            </LinearLayout>
        </LinearLayout>'''


def traffic(sample):
    return f'''    <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content"
        android:orientation="horizontal" android:gravity="center_vertical" android:layout_marginTop="2dp" android:baselineAligned="false">
{traffic_block("daily", "今日流量", sample)}
        <FrameLayout android:layout_width="1dp" android:layout_height="30dp" android:background="@color/divider"/>
{traffic_block("monthly", "本月流量", sample)}
    </LinearLayout>'''


def row(children):
    return f'''    <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content"
        android:orientation="horizontal" android:gravity="center" android:layout_marginTop="4dp">
{chr(10).join(children)}
    </LinearLayout>'''


def row1(sample):
    return row([
        chip("net", "ic_globe", "c_net", sample, 'android:maxWidth="96dp" android:maxLines="1" android:ellipsize="end"'),
        chip("band", "ic_antenna", "accent", sample),
        chip("cpu", "ic_cpu", "c_cpu", sample),
        chip("temp", "ic_temp", "c_temp", sample, last=True),
    ])


def row2(sample):
    return row([
        chip("ssid", "ic_wifi", "c_wifi", sample, 'android:maxWidth="84dp" android:maxLines="1" android:ellipsize="end"'),
        chip("wifi_band", "ic_waves", "c_wifi", sample),
        chip("mem", "ic_memory", "c_mem", sample),
        chip("devices", "ic_devices", "c_dev", sample),
        chip("sms", "ic_mail", None, sample, icon_id="sms_icon", last=True),
    ])


def bottom(sample):
    return f'''    <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content"
        android:orientation="horizontal" android:gravity="center" android:layout_marginTop="4dp">
        <LinearLayout android:id="@+id/signal_group" android:layout_width="wrap_content" android:layout_height="wrap_content"
            android:orientation="horizontal" android:gravity="center_vertical">
            {img("ic_antenna", 11, "signal")}
            {txt("signal_detail", "W.Foot", sample, 'android:layout_marginStart="3dp" android:maxLines="1"')}
        </LinearLayout>
        <TextView android:id="@+id/error_text" style="@style/W.Foot" android:layout_width="wrap_content" android:layout_height="wrap_content"
            android:textColor="#FFDC2626" android:maxLines="1" android:ellipsize="end" android:maxWidth="200dp" android:visibility="gone"/>
        {img("ic_clock", 11, "clock", extra='android:layout_marginStart="8dp"')}
        {txt("update_time", "W.Foot", sample, 'android:layout_marginStart="3dp"')}
    </LinearLayout>'''


def root(inner, pad_v="7dp", pad_h="10dp"):
    return f'''<?xml version="1.0" encoding="utf-8"?>
<!-- 由 tools/gen_android.py 生成 -->
<LinearLayout {A}
    android:id="@+id/root"
    android:layout_width="match_parent" android:layout_height="match_parent"
    android:orientation="vertical" android:gravity="center_vertical"
    android:background="@drawable/widget_bg"
    android:paddingStart="{pad_h}" android:paddingEnd="{pad_h}" android:paddingTop="{pad_v}" android:paddingBottom="{pad_v}">
{inner}
</LinearLayout>
'''


def medium(sample):
    return root("\n".join([top_bar(sample), traffic(sample), row1(sample), row2(sample), bottom(sample)]))


def medium_compact(sample):
    return root("\n".join([top_bar(sample), traffic(sample), row1(sample), bottom(sample)]), pad_v="5dp")


def small(sample):
    return root(f'''    <LinearLayout android:id="@+id/top_bar" android:layout_width="match_parent" android:layout_height="wrap_content"
        android:orientation="horizontal" android:gravity="center_vertical">
        {img("ic_router", 13, "router")}
        <TextView android:id="@+id/model" style="@style/W.Title" android:layout_width="0dp" android:layout_weight="1"
            android:layout_height="wrap_content" android:layout_marginStart="4dp" android:maxLines="1" android:ellipsize="end"
            android:text="{SAMPLE['model'] if sample else '--'}"/>
        <ImageView android:id="@+id/bat_icon" android:layout_width="16dp" android:layout_height="16dp" android:src="@drawable/ic_bat_100"
            android:tint="#FF16A34A"/>
        {txt("battery", "W.Small", sample, 'android:layout_marginStart="2dp" android:textStyle="bold"')}
    </LinearLayout>
    <FrameLayout android:layout_width="match_parent" android:layout_height="0dp" android:layout_weight="1"/>
    <TextView style="@style/W.Label" android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="今日流量"/>
    <LinearLayout android:layout_width="wrap_content" android:layout_height="wrap_content" android:orientation="horizontal"
        android:baselineAligned="true">
        {txt("daily_value", "W.BigSmall", sample)}
        {txt("daily_unit", "W.Unit", sample, 'android:layout_marginStart="2dp"')}
    </LinearLayout>
    <LinearLayout android:layout_width="wrap_content" android:layout_height="wrap_content" android:orientation="horizontal"
        android:gravity="center_vertical">
        <TextView style="@style/W.Label" android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="本月"/>
        {txt("monthly", "W.Title", sample, 'android:layout_marginStart="4dp"')}
    </LinearLayout>
    <FrameLayout android:layout_width="match_parent" android:layout_height="0dp" android:layout_weight="1"/>
    <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content"
        android:orientation="horizontal" android:gravity="center_vertical">
        {img("ic_signal", 10, "text")}
        <TextView android:id="@+id/net" style="@style/W.Foot" android:layout_width="0dp" android:layout_weight="1"
            android:layout_height="wrap_content" android:layout_marginStart="3dp" android:maxLines="1" android:ellipsize="end"
            android:text="{SAMPLE['net'] if sample else '--'}"/>
        <TextView android:id="@+id/error_text" style="@style/W.Foot" android:layout_width="0dp" android:layout_weight="1"
            android:layout_height="wrap_content" android:layout_marginStart="3dp" android:maxLines="1" android:ellipsize="end"
            android:textColor="#FFDC2626" android:visibility="gone"/>
        {txt("update_time", "W.Foot", sample, 'android:layout_marginStart="4dp"')}
    </LinearLayout>''', pad_v="10dp", pad_h="12dp")


w("layout/widget_medium.xml", medium(False))
w("layout/widget_medium_compact.xml", medium_compact(False))
w("layout/widget_medium_preview.xml", medium(True))
w("layout/widget_small.xml", small(False))
w("layout/widget_small_preview.xml", small(True))
print("ok")

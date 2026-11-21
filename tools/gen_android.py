"""Generate Android resources (vector icons, widget layouts) for UfiPeek."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from icons import ICONS, to_android

RES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "android", "app", "src", "main", "res")
A = 'xmlns:android="http://schemas.android.com/apk/res/android"'


def w(path, text):
    full = os.path.join(RES, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


# ---------- icons ----------
for name, parts in ICONS.items():
    w(f"drawable/{name}.xml", to_android(parts))

# ---------- shapes ----------
w("drawable/widget_bg.xml", f'''<?xml version="1.0" encoding="utf-8"?>
<shape {A} android:shape="rectangle">
    <solid android:color="@color/widget_bg"/>
    <corners android:radius="22dp"/>
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
    "ssid": "ZTE_E8CDF6", "wifi_band": "5 GHz", "mem": "58%", "devices": "2", "sms": "0",
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


def metric(id_, icon, sample, flexible=False, icon_id=None):
    width = 'android:layout_width="0dp" android:layout_weight="1"' if flexible else 'android:layout_width="wrap_content"'
    return f'''        <LinearLayout android:id="@+id/{id_}_metric" {width} android:layout_height="wrap_content"
            android:orientation="horizontal" android:gravity="center_vertical"
            android:paddingEnd="8dp" android:paddingTop="1dp" android:paddingBottom="1dp">
            {img(icon, 11, "secondary", icon_id)}
            {txt(id_, "W.Metric", sample, 'android:layout_marginStart="3dp" android:maxLines="1" android:ellipsize="end"')}
        </LinearLayout>'''


def top_bar(sample, compact=False):
    battery_size = 15 if compact else 17
    return f'''    <LinearLayout android:id="@+id/top_bar" android:layout_width="match_parent" android:layout_height="wrap_content"
        android:orientation="horizontal" android:gravity="center_vertical">
        {img("ic_router", 14, "accent")}
        {txt("model", "W.Title", sample, 'android:layout_marginStart="5dp" android:maxWidth="104dp" android:maxLines="1" android:ellipsize="end"')}
        <TextView android:id="@+id/ufi_ver" style="@style/W.Small" android:layout_width="0dp" android:layout_weight="1"
            android:layout_height="wrap_content" android:layout_marginStart="6dp" android:layout_marginEnd="4dp" android:maxLines="1" android:ellipsize="end"
            android:text="{SAMPLE['ufi_ver'] if sample else 'UFI v--'}"/>
        {img("ic_signal", 12, "secondary", "signal_icon")}
        {txt("signal_bar", "W.Small", sample, 'android:layout_marginStart="3dp"')}
        <ImageView android:id="@+id/bat_icon" android:layout_width="{battery_size}dp" android:layout_height="{battery_size}dp" android:src="@drawable/ic_bat_100"
            android:layout_marginStart="5dp" android:tint="@color/success"/>
        {txt("battery", "W.Title", sample, 'android:layout_marginStart="3dp"')}
    </LinearLayout>'''


def traffic_value(prefix, sample, style):
    return f'''            <LinearLayout android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:orientation="horizontal" android:baselineAligned="true">
                <TextView android:id="@+id/{prefix}_value" style="@style/{style}" android:layout_width="wrap_content"
                    android:layout_height="wrap_content" android:layout_weight="1" android:maxLines="1" android:ellipsize="end"
                    android:autoSizeTextType="uniform" android:autoSizeMinTextSize="12sp"
                    android:autoSizeStepGranularity="1sp" android:text="{SAMPLE[prefix + '_value'] if sample else '--'}"/>
                {txt(prefix + "_unit", "W.Unit", sample, 'android:layout_marginStart="3dp"')}
            </LinearLayout>'''


def traffic_block(prefix, label, sample, compact=False):
    value_style = "W.BigCompact" if compact else "W.Big"
    inset = "0dp" if prefix == "daily" else "10dp"
    return f'''        <LinearLayout android:layout_width="0dp" android:layout_weight="1" android:layout_height="wrap_content"
            android:orientation="vertical" android:paddingStart="{inset}" android:paddingEnd="4dp">
            <TextView style="@style/W.Label" android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="{label}"/>
{traffic_value(prefix, sample, value_style)}
        </LinearLayout>'''


def traffic(sample, compact=False):
    return f'''    <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content"
        android:orientation="horizontal" android:gravity="center_vertical"
        android:layout_marginTop="{3 if compact else 8}dp" android:baselineAligned="false">
{traffic_block("daily", "今日流量", sample, compact)}
        <FrameLayout android:layout_width="1dp" android:layout_height="{24 if compact else 32}dp" android:background="@color/divider"/>
{traffic_block("monthly", "本月流量", sample, compact)}
    </LinearLayout>'''


def row(id_, children, gap):
    return f'''    <LinearLayout android:id="@+id/{id_}" android:layout_width="match_parent" android:layout_height="wrap_content"
        android:orientation="horizontal" android:gravity="center_vertical" android:layout_marginTop="{gap}dp">
{chr(10).join(children)}
    </LinearLayout>'''


def row1(sample, compact=False):
    return row("mobile_metrics", [
        metric("net", "ic_globe", sample, flexible=True),
        metric("band", "ic_antenna", sample),
        metric("cpu", "ic_cpu", sample),
        metric("temp", "ic_temp", sample),
    ], 3 if compact else 8)


def row2(sample):
    return row("wifi_metrics", [
        metric("ssid", "ic_wifi", sample, flexible=True),
        metric("wifi_band", "ic_waves", sample),
        metric("mem", "ic_memory", sample),
        metric("devices", "ic_devices", sample),
        metric("sms", "ic_mail", sample, icon_id="sms_icon"),
    ], 4)


def bottom(sample, compact=False):
    return f'''    <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content"
        android:orientation="horizontal" android:gravity="center_vertical" android:layout_marginTop="{2 if compact else 6}dp">
        <LinearLayout android:id="@+id/signal_group" android:layout_width="0dp" android:layout_weight="1" android:layout_height="wrap_content"
            android:orientation="horizontal" android:gravity="center_vertical">
            {img("ic_antenna", 11, "secondary")}
            {txt("signal_detail", "W.Foot", sample, 'android:layout_marginStart="3dp" android:maxLines="1" android:ellipsize="end"')}
        </LinearLayout>
        <TextView android:id="@+id/error_text" style="@style/W.Foot" android:layout_width="0dp" android:layout_weight="1"
            android:layout_height="wrap_content" android:textColor="@color/error" android:maxLines="1" android:ellipsize="end" android:visibility="gone"/>
        {img("ic_clock", 11, "secondary", extra='android:layout_marginStart="5dp"')}
        {txt("update_time", "W.Foot", sample, 'android:layout_marginStart="3dp"')}
    </LinearLayout>'''


def root(inner, pad_v="5dp", pad_h="13dp"):
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
    blocks = [top_bar(sample, True), traffic(sample, True), row1(sample, True), bottom(sample, True)]
    return root("\n".join(blocks), pad_v="2dp")


def small(sample):
    return root(f'''    <LinearLayout android:id="@+id/top_bar" android:layout_width="match_parent" android:layout_height="wrap_content"
        android:orientation="horizontal" android:gravity="center_vertical">
        {img("ic_router", 13, "accent")}
        <TextView android:id="@+id/model" style="@style/W.Title" android:layout_width="0dp" android:layout_weight="1"
            android:layout_height="wrap_content" android:layout_marginStart="4dp" android:maxLines="1" android:ellipsize="end"
            android:text="{SAMPLE['model'] if sample else '--'}"/>
        <ImageView android:id="@+id/bat_icon" android:layout_width="16dp" android:layout_height="16dp" android:src="@drawable/ic_bat_100"
            android:tint="@color/success"/>
        {txt("battery", "W.Small", sample, 'android:layout_marginStart="2dp" android:textStyle="bold"')}
    </LinearLayout>
    <FrameLayout android:layout_width="match_parent" android:layout_height="0dp" android:layout_weight="1"/>
    <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="vertical">
        <TextView style="@style/W.Label" android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="今日流量"/>
{traffic_value("daily", sample, "W.BigSmall")}
    </LinearLayout>
    <LinearLayout android:layout_width="wrap_content" android:layout_height="wrap_content" android:orientation="horizontal"
        android:gravity="center_vertical" android:layout_marginTop="2dp">
        <TextView style="@style/W.Label" android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="本月"/>
        {txt("monthly", "W.Title", sample, 'android:layout_marginStart="4dp" android:maxLines="1" android:ellipsize="end"')}
    </LinearLayout>
    <FrameLayout android:layout_width="match_parent" android:layout_height="0dp" android:layout_weight="1"/>
    <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content"
        android:orientation="horizontal" android:gravity="center_vertical">
        {img("ic_signal", 10, "secondary", "signal_icon")}
        <TextView android:id="@+id/net" style="@style/W.Foot" android:layout_width="0dp" android:layout_weight="1"
            android:layout_height="wrap_content" android:layout_marginStart="3dp" android:maxLines="1" android:ellipsize="end"
            android:text="{SAMPLE['net'] if sample else '--'}"/>
        <TextView android:id="@+id/error_text" style="@style/W.Foot" android:layout_width="0dp" android:layout_weight="1"
            android:layout_height="wrap_content" android:layout_marginStart="3dp" android:maxLines="1" android:ellipsize="end"
            android:textColor="@color/error" android:visibility="gone"/>
        {txt("update_time", "W.Foot", sample, 'android:layout_marginStart="4dp"')}
    </LinearLayout>''', pad_v="6dp", pad_h="8dp")


w("layout/widget_medium.xml", medium(False))
w("layout/widget_medium_compact.xml", medium_compact(False))
w("layout/widget_medium_preview.xml", medium(True))
w("layout/widget_small.xml", small(False))
w("layout/widget_small_preview.xml", small(True))
print("ok")

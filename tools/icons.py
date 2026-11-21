# Icon definitions shared by the Android vector drawables and the preview sheet.
# Each icon: list of (pathData, mode) where mode is "fill", "eo" (even-odd fill) or "stroke:<width>".

def bat(level):
    outline = ("M3,6.5h14.5a1.5,1.5 0 0 1 1.5,1.5v8a1.5,1.5 0 0 1 -1.5,1.5H3a1.5,1.5 0 0 1 -1.5,-1.5V8"
               "a1.5,1.5 0 0 1 1.5,-1.5z M3,8v8h14.5V8z", "eo")
    nub = ("M20,10h1a1,1 0 0 1 1,1v2a1,1 0 0 1 -1,1h-1z", "fill")
    parts = [outline, nub]
    if level > 0:
        w = round(12.5 * level, 2)
        parts.append((f"M4,9.5h{w}v5H4z", "fill"))
    return parts

ICONS = {
    "ic_router": [
        ("M4,13h16a2,2 0 0 1 2,2v4a2,2 0 0 1 -2,2H4a2,2 0 0 1 -2,-2v-4a2,2 0 0 1 2,-2z "
         "M5.8,17a1.2,1.2 0 1 0 2.4,0a1.2,1.2 0 1 0 -2.4,0z "
         "M9.8,17a1.2,1.2 0 1 0 2.4,0a1.2,1.2 0 1 0 -2.4,0z", "eo"),
        ("M17,13V8", "stroke:2"),
        ("M14.6,6.2a3.4,3.4 0 0 1 4.8,0", "stroke:1.8"),
        ("M12.4,3.9a6.5,6.5 0 0 1 9.2,0", "stroke:1.8"),
    ],
    "ic_signal": [("M3,16h3v5H3z M8.5,12h3v9h-3z M14,8h3v13h-3z M19.5,3h3v18h-3z", "fill")],
    "ic_bat_0": bat(0),
    "ic_bat_25": bat(0.25),
    "ic_bat_50": bat(0.5),
    "ic_bat_75": bat(0.75),
    "ic_bat_100": bat(1),
    "ic_bat_charge": bat(0) + [("M11.5,8 L7,12.8 H10 L9,16 L13.5,11.2 H10.5 Z", "fill")],
    "ic_globe": [
        ("M3,12a9,9 0 1 0 18,0a9,9 0 1 0 -18,0", "stroke:1.7"),
        ("M12,3c-3.2,3.5 -3.2,14.5 0,18c3.2,-3.5 3.2,-14.5 0,-18", "stroke:1.5"),
        ("M3,12h18 M4.6,7.5h14.8 M4.6,16.5h14.8", "stroke:1.5"),
    ],
    "ic_antenna": [
        ("M10,10a2,2 0 1 0 4,0a2,2 0 1 0 -4,0z", "fill"),
        ("M12,12v9", "stroke:2"),
        ("M8.8,6.8a4.5,4.5 0 0 0 0,6.4 M15.2,6.8a4.5,4.5 0 0 1 0,6.4", "stroke:1.8"),
        ("M6,4a8.5,8.5 0 0 0 0,12 M18,4a8.5,8.5 0 0 1 0,12", "stroke:1.8"),
    ],
    "ic_cpu": [
        ("M7,5h10a2,2 0 0 1 2,2v10a2,2 0 0 1 -2,2H7a2,2 0 0 1 -2,-2V7a2,2 0 0 1 2,-2z M8.5,8.5v7h7v-7z", "eo"),
        ("M10,10h4v4h-4z", "fill"),
        ("M9.5,2v3 M14.5,2v3 M9.5,19v3 M14.5,19v3 M2,9.5h3 M2,14.5h3 M19,9.5h3 M19,14.5h3", "stroke:1.6"),
    ],
    "ic_temp": [
        ("M10.5,15V5.5a1.5,1.5 0 0 1 3,0V15", "stroke:1.8"),
        ("M8.5,17.5a3.5,3.5 0 1 0 7,0a3.5,3.5 0 1 0 -7,0z", "fill"),
        ("M12,9v8", "stroke:2"),
    ],
    "ic_wifi": [
        ("M10.5,19a1.5,1.5 0 1 0 3,0a1.5,1.5 0 1 0 -3,0z", "fill"),
        ("M8.6,15.4a4.8,4.8 0 0 1 6.8,0", "stroke:2"),
        ("M5.4,12.2a9.3,9.3 0 0 1 13.2,0", "stroke:2"),
        ("M2.2,9a13.8,13.8 0 0 1 19.6,0", "stroke:2"),
    ],
    "ic_waves": [
        ("M10,12a2,2 0 1 0 4,0a2,2 0 1 0 -4,0z", "fill"),
        ("M8.5,8.5a5,5 0 0 0 0,7 M15.5,8.5a5,5 0 0 1 0,7", "stroke:1.8"),
        ("M5.6,5.6a9,9 0 0 0 0,12.8 M18.4,5.6a9,9 0 0 1 0,12.8", "stroke:1.8"),
    ],
    "ic_memory": [
        ("M3,6.5h18a1,1 0 0 1 1,1v8a1,1 0 0 1 -1,1H3a1,1 0 0 1 -1,-1v-8a1,1 0 0 1 1,-1z "
         "M4.5,9v5h3.5V9z M10.25,9v5h3.5V9z M16,9v5h3.5V9z", "eo"),
        ("M5,17v3 M9,17v3 M13,17v3 M17,17v3", "stroke:1.6"),
    ],
    "ic_devices": [
        ("M3,5h12a1,1 0 0 1 1,1v8H2V6a1,1 0 0 1 1,-1z M3.8,6.8v5.4h10.4V6.8z", "eo"),
        ("M1,15h15.5v1.2a1.3,1.3 0 0 1 -1.3,1.3H2.3a1.3,1.3 0 0 1 -1.3,-1.3z", "fill"),
        ("M18.5,8h3.5a1,1 0 0 1 1,1v10a1,1 0 0 1 -1,1h-3.5a1,1 0 0 1 -1,-1V9a1,1 0 0 1 1,-1z M19.1,9.8v8.4h2.3V9.8z", "eo"),
    ],
    "ic_mail": [
        ("M3,5.5h18a1,1 0 0 1 1,1v11a1,1 0 0 1 -1,1H3a1,1 0 0 1 -1,-1v-11a1,1 0 0 1 1,-1z M3.8,7.3v9.4h16.4V7.3z", "eo"),
        ("M4,8l8,5.6l8,-5.6", "stroke:1.8"),
    ],
    "ic_clock": [
        ("M19.5,12a7.5,7.5 0 1 1 -2.2,-5.3", "stroke:1.9"),
        ("M21,3.5v6h-6z", "fill"),
        ("M12,8v4.3l2.8,1.8", "stroke:1.9"),
    ],
    "ic_gear": [
        ("M10.3,2h3.4l0.5,2.6a8,8 0 0 1 2,1.2l2.5,-0.9l1.7,2.9l-2,1.7a8,8 0 0 1 0,2.4l2,1.7l-1.7,2.9"
         "l-2.5,-0.9a8,8 0 0 1 -2,1.2L13.7,22h-3.4l-0.5,-2.6a8,8 0 0 1 -2,-1.2l-2.5,0.9l-1.7,-2.9l2,-1.7"
         "a8,8 0 0 1 0,-2.4l-2,-1.7l1.7,-2.9l2.5,0.9a8,8 0 0 1 2,-1.2z "
         "M9,12a3,3 0 1 0 6,0a3,3 0 1 0 -6,0z", "eo"),
    ],
}


def to_svg(parts, color="#000"):
    out = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24">']
    for d, mode in parts:
        if mode == "fill":
            out.append(f'<path d="{d}" fill="{color}"/>')
        elif mode == "eo":
            out.append(f'<path d="{d}" fill="{color}" fill-rule="evenodd"/>')
        else:
            w = mode.split(":")[1]
            out.append(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{w}" '
                       f'stroke-linecap="round" stroke-linejoin="round"/>')
    out.append("</svg>")
    return "".join(out)


def to_android(parts):
    out = ['<?xml version="1.0" encoding="utf-8"?>',
           '<vector xmlns:android="http://schemas.android.com/apk/res/android"',
           '    android:width="24dp" android:height="24dp"',
           '    android:viewportWidth="24" android:viewportHeight="24">']
    for d, mode in parts:
        if mode == "fill":
            out.append(f'    <path android:fillColor="#FF000000" android:pathData="{d}"/>')
        elif mode == "eo":
            out.append(f'    <path android:fillColor="#FF000000" android:fillType="evenOdd" android:pathData="{d}"/>')
        else:
            w = mode.split(":")[1]
            out.append(f'    <path android:strokeColor="#FF000000" android:strokeWidth="{w}" '
                       f'android:strokeLineCap="round" android:strokeLineJoin="round" '
                       f'android:pathData="{d}"/>')
    out.append('</vector>')
    return "\n".join(out) + "\n"


if __name__ == "__main__":
    import io, sys
    import cairosvg
    from PIL import Image
    names = list(ICONS)
    cell = 96
    cols = 6
    rows = (len(names) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell, rows * cell), "white")
    for i, n in enumerate(names):
        png = cairosvg.svg2png(bytestring=to_svg(ICONS[n]).encode(), output_width=80, output_height=80)
        im = Image.open(io.BytesIO(png))
        sheet.paste(im, ((i % cols) * cell + 8, (i // cols) * cell + 8), im)
    sheet.save(sys.argv[1])
    print(names)

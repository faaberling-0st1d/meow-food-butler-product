from pathlib import Path
from PIL import Image, ImageDraw

OUTPUT_DIR_ANDROID = Path(__file__).resolve().parent.parent / "android" / "app" / "src" / "main" / "res"
OUTPUT_DIR_IOS = Path(__file__).resolve().parent.parent / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"

ANDROID_SIZES = {
    "mipmap-mdpi/ic_launcher.png": 48,
    "mipmap-hdpi/ic_launcher.png": 72,
    "mipmap-xhdpi/ic_launcher.png": 96,
    "mipmap-xxhdpi/ic_launcher.png": 144,
    "mipmap-xxxhdpi/ic_launcher.png": 192,
}

IOS_SIZES = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}


def draw_gradient(draw, size):
    for y in range(size):
        t = y / (size - 1)
        r = int(248 + (255 - 248) * t)
        g = int(173 + (110 - 173) * t)
        b = int(206 + (186 - 206) * t)
        draw.line([(0, y), (size, y)], fill=(r, g, b))


def draw_cat_face(draw, size):
    center = size // 2
    face_radius = int(size * 0.37)
    ear_size = int(size * 0.22)
    bowl_height = int(size * 0.22)
    bowl_width = int(size * 0.66)
    bowl_top = int(size * 0.70)
    bowl_bottom = int(size * 0.84)

    # Background circle for face
    draw.ellipse(
        [
            (center - face_radius, center - face_radius * 0.95),
            (center + face_radius, center + face_radius * 1.05),
        ],
        fill=(255, 255, 255, 255),
    )

    # Ears
    left_ear = [
        (center - face_radius * 0.75, center - face_radius * 0.85),
        (center - face_radius * 0.45, center - face_radius * 1.65),
        (center - face_radius * 0.15, center - face_radius * 0.85),
    ]
    right_ear = [
        (center + face_radius * 0.75, center - face_radius * 0.85),
        (center + face_radius * 0.45, center - face_radius * 1.65),
        (center + face_radius * 0.15, center - face_radius * 0.85),
    ]
    draw.polygon(left_ear, fill=(255, 255, 255, 255))
    draw.polygon(right_ear, fill=(255, 255, 255, 255))

    # Eyes
    eye_radius = max(1, int(size * 0.05))
    eye_offset_x = int(size * 0.12)
    eye_offset_y = int(size * 0.05)
    left_eye = (center - eye_offset_x, int(center - eye_offset_y))
    right_eye = (center + eye_offset_x, int(center - eye_offset_y))
    draw.ellipse(
        [
            (left_eye[0] - eye_radius, left_eye[1] - eye_radius),
            (left_eye[0] + eye_radius, left_eye[1] + eye_radius),
        ],
        fill=(56, 46, 55, 255),
    )
    draw.ellipse(
        [
            (right_eye[0] - eye_radius, right_eye[1] - eye_radius),
            (right_eye[0] + eye_radius, right_eye[1] + eye_radius),
        ],
        fill=(56, 46, 55, 255),
    )

    # Nose
    nose = [
        (center, center + int(size * 0.06)),
        (center - int(size * 0.03), center + int(size * 0.08)),
        (center + int(size * 0.03), center + int(size * 0.08)),
    ]
    draw.polygon(nose, fill=(255, 153, 180, 255))

    # Mouth
    mouth_offset = int(size * 0.06)
    draw.line(
        [
            (center, center + mouth_offset),
            (center - int(size * 0.04), center + int(size * 0.10)),
        ],
        fill=(141, 33, 61, 255),
        width=max(1, int(size * 0.015)),
    )
    draw.line(
        [
            (center, center + mouth_offset),
            (center + int(size * 0.04), center + int(size * 0.10)),
        ],
        fill=(141, 33, 61, 255),
        width=max(1, int(size * 0.015)),
    )

    # Bowl
    bowl_left = int(center - bowl_width / 2)
    bowl_right = int(center + bowl_width / 2)
    draw.rectangle(
        [(bowl_left, bowl_top), (bowl_right, bowl_bottom)],
        fill=(114, 118, 151, 255),
    )
    draw.ellipse(
        [(bowl_left, bowl_bottom - int(size * 0.02)), (bowl_right, bowl_bottom + int(size * 0.04))],
        fill=(114, 118, 151, 255),
    )
    draw.rectangle(
        [(bowl_left + int(size * 0.06), bowl_top - int(size * 0.06)), (bowl_right - int(size * 0.06), bowl_top)],
        fill=(255, 255, 255, 255),
    )

    # Optional whiskers
    whisker_y = center + int(size * 0.03)
    whisker_length = int(size * 0.14)
    whisker_gap = int(size * 0.02)
    for direction in (-1, 1):
        for i in (-1, 1):
            draw.line(
                [
                    (center + direction * int(size * 0.05), whisker_y + i * whisker_gap),
                    (center + direction * (int(size * 0.05) + whisker_length), whisker_y + i * whisker_gap - int(size * 0.01)),
                ],
                fill=(141, 33, 61, 255),
                width=max(1, int(size * 0.01)),
            )


def create_icon(size):
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw_gradient(draw, size)
    draw_cat_face(draw, size)
    return image


def save_icons():
    for filename, icon_size in ANDROID_SIZES.items():
        path = OUTPUT_DIR_ANDROID / filename
        path.parent.mkdir(parents=True, exist_ok=True)
        create_icon(icon_size).save(path, optimize=True)
        print(f"Wrote Android icon: {path}")

    for filename, icon_size in IOS_SIZES.items():
        path = OUTPUT_DIR_IOS / filename
        path.parent.mkdir(parents=True, exist_ok=True)
        create_icon(icon_size).save(path, optimize=True)
        print(f"Wrote iOS icon: {path}")


if __name__ == "__main__":
    save_icons()

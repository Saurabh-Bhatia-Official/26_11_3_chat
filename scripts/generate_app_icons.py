import os
from PIL import Image

def generate_icons(source_path, base_dir):
    img = Image.open(source_path).convert("RGBA")
    
    # 1. Windows ICO (multi-resolution)
    win_ico_path = os.path.join(base_dir, "frontend", "windows", "runner", "resources", "app_icon.ico")
    os.makedirs(os.path.dirname(win_ico_path), exist_ok=True)
    ico_sizes = [(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (16, 16)]
    img.save(win_ico_path, format="ICO", sizes=ico_sizes)
    print(f"Generated Windows icon: {win_ico_path}")

    # 2. Android mipmaps
    android_res = os.path.join(base_dir, "frontend", "android", "app", "src", "main", "res")
    android_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in android_sizes.items():
        folder_path = os.path.join(android_res, folder)
        os.makedirs(folder_path, exist_ok=True)
        resized = img.resize((size, size), Image.Resampling.LANCZOS)
        out_file = os.path.join(folder_path, "ic_launcher.png")
        resized.save(out_file, format="PNG")
        print(f"Generated Android icon: {out_file} ({size}x{size})")

    # 3. Web Icons
    web_dir = os.path.join(base_dir, "frontend", "web")
    web_icons_dir = os.path.join(web_dir, "icons")
    os.makedirs(web_icons_dir, exist_ok=True)
    
    # Favicon
    favicon = img.resize((64, 64), Image.Resampling.LANCZOS)
    favicon.save(os.path.join(web_dir, "favicon.png"), format="PNG")
    print(f"Generated Web Favicon: {os.path.join(web_dir, 'favicon.png')}")

    # Web PWA Icons
    for size, name in [
        (192, "Icon-192.png"),
        (512, "Icon-512.png"),
        (192, "Icon-maskable-192.png"),
        (512, "Icon-maskable-512.png")
    ]:
        resized = img.resize((size, size), Image.Resampling.LANCZOS)
        out_file = os.path.join(web_icons_dir, name)
        resized.save(out_file, format="PNG")
        print(f"Generated Web PWA icon: {out_file} ({size}x{size})")

    # 4. iOS Icons
    ios_icon_dir = os.path.join(base_dir, "frontend", "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    if os.path.exists(ios_icon_dir):
        ios_files = {
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
        for name, size in ios_files.items():
            resized = img.resize((size, size), Image.Resampling.LANCZOS)
            out_file = os.path.join(ios_icon_dir, name)
            resized.save(out_file, format="PNG")
            print(f"Generated iOS icon: {name} ({size}x{size})")

    # 5. macOS Icons
    macos_icon_dir = os.path.join(base_dir, "frontend", "macos", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    if os.path.exists(macos_icon_dir):
        macos_files = {
            "app_icon_16.png": 16,
            "app_icon_32.png": 32,
            "app_icon_64.png": 64,
            "app_icon_128.png": 128,
            "app_icon_256.png": 256,
            "app_icon_512.png": 512,
            "app_icon_1024.png": 1024,
        }
        for name, size in macos_files.items():
            resized = img.resize((size, size), Image.Resampling.LANCZOS)
            out_file = os.path.join(macos_icon_dir, name)
            resized.save(out_file, format="PNG")
            print(f"Generated macOS icon: {name} ({size}x{size})")

if __name__ == "__main__":
    base_proj = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    master_icon = os.path.join(base_proj, "assets", "branding", "whisper_logo.png")
    generate_icons(master_icon, base_proj)

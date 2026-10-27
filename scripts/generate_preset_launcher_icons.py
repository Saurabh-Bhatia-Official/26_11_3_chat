import os
from PIL import Image, ImageDraw

def create_rounded_icon(size, bg_color1, bg_color2, symbol_drawer):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Draw rounded rectangle background
    corner_radius = int(size * 0.22)
    # Simple gradient effect or solid
    draw.rounded_rectangle(
        [(0, 0), (size - 1, size - 1)],
        radius=corner_radius,
        fill=bg_color1,
        outline=bg_color2,
        width=max(1, int(size * 0.04))
    )
    
    # Draw symbol
    symbol_drawer(draw, size)
    return img

def draw_whisper(draw, size, master_img):
    if master_img:
        inset = int(size * 0.08)
        resized_master = master_img.resize((size - 2 * inset, size - 2 * inset), Image.Resampling.LANCZOS)
        # We can composite
        pass

def draw_bolt(draw, size):
    # Cyber pulse: Bolt
    w, h = size, size
    points = [
        (w * 0.54, h * 0.18),
        (w * 0.28, h * 0.52),
        (w * 0.46, h * 0.52),
        (w * 0.42, h * 0.82),
        (w * 0.72, h * 0.46),
        (w * 0.52, h * 0.46),
    ]
    draw.polygon(points, fill=(255, 255, 255, 245))

def draw_shield(draw, size):
    # Cyber shield: Shield
    w, h = size, size
    points = [
        (w * 0.5, h * 0.20),
        (w * 0.75, h * 0.32),
        (w * 0.75, h * 0.55),
        (w * 0.5, h * 0.80),
        (w * 0.25, h * 0.55),
        (w * 0.25, h * 0.32),
    ]
    draw.polygon(points, fill=(255, 255, 255, 245))

def draw_moon(draw, size):
    # Cosmic night: Crescent moon
    w, h = size, size
    bbox = [w * 0.26, h * 0.22, w * 0.74, h * 0.78]
    draw.pieslice(bbox, 60, 300, fill=(255, 255, 255, 245))
    cut_bbox = [w * 0.36, h * 0.18, w * 0.78, h * 0.72]
    draw.pieslice(cut_bbox, 60, 300, fill=(139, 92, 246, 255))

def draw_flare(draw, size):
    # Solar flare: Flame
    w, h = size, size
    points = [
        (w * 0.5, h * 0.18),
        (w * 0.65, h * 0.38),
        (w * 0.72, h * 0.58),
        (w * 0.5, h * 0.80),
        (w * 0.28, h * 0.58),
        (w * 0.35, h * 0.38),
    ]
    draw.polygon(points, fill=(255, 255, 255, 245))

def main():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    android_res = os.path.join(base_dir, "frontend", "android", "app", "src", "main", "res")
    master_icon_path = os.path.join(base_dir, "assets", "branding", "whisper_logo.png")
    master_img = Image.open(master_icon_path).convert("RGBA") if os.path.exists(master_icon_path) else None
    
    android_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    
    presets = [
        ("ic_launcher", (30, 136, 229, 255), (0, 180, 216, 255), None), # Uses master_img
        ("ic_launcher_cyber_pulse", (6, 182, 212, 255), (2, 132, 199, 255), draw_bolt),
        ("ic_launcher_cyber_shield", (16, 185, 129, 255), (5, 150, 105, 255), draw_shield),
        ("ic_launcher_cosmic_night", (139, 92, 246, 255), (109, 40, 217, 255), draw_moon),
        ("ic_launcher_solar_flare", (245, 158, 11, 255), (239, 68, 68, 255), draw_flare),
    ]
    
    for folder, size in android_sizes.items():
        folder_path = os.path.join(android_res, folder)
        os.makedirs(folder_path, exist_ok=True)
        
        for name, col1, col2, drawer in presets:
            out_file = os.path.join(folder_path, f"{name}.png")
            if name == "ic_launcher" and master_img:
                resized = master_img.resize((size, size), Image.Resampling.LANCZOS)
                resized.save(out_file, format="PNG")
            else:
                icon_img = create_rounded_icon(size, col1, col2, drawer)
                icon_img.save(out_file, format="PNG")
            print(f"Generated {out_file} ({size}x{size})")

if __name__ == "__main__":
    main()


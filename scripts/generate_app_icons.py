import os
import fitz  # PyMuPDF
from PIL import Image

def generate_icons():
    svg_path = r'd:\Freelance\KeyFlow\AppLogo.svg'
    base_out_dir = r'd:\Freelance\KeyFlow\app'

    print("Rasterizing SVG with PyMuPDF...")
    doc = fitz.open(svg_path)
    page = doc[0]
    pix = page.get_pixmap(dpi=600)  # High-res master render
    
    master_png_path = os.path.join(base_out_dir, 'assets', 'images', 'app_logo.png')
    os.makedirs(os.path.dirname(master_png_path), exist_ok=True)
    pix.save(master_png_path)
    print(f"Master PNG created at: {master_png_path}")

    master_img = Image.open(master_png_path)

    # 1. Android Mipmap Icons
    android_res = os.path.join(base_out_dir, 'android', 'app', 'src', 'main', 'res')
    android_sizes = {
        'mipmap-mdpi': 48,
        'mipmap-hdpi': 72,
        'mipmap-xhdpi': 96,
        'mipmap-xxhdpi': 144,
        'mipmap-xxxhdpi': 192,
    }

    for folder, size in android_sizes.items():
        folder_path = os.path.join(android_res, folder)
        os.makedirs(folder_path, exist_ok=True)
        resized = master_img.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(os.path.join(folder_path, 'ic_launcher.png'))
        print(f"Generated Android icon {size}x{size} in {folder}")

    # 2. Windows Icon (.ico)
    windows_icon_path = os.path.join(base_out_dir, 'windows', 'runner', 'resources', 'app_icon.ico')
    os.makedirs(os.path.dirname(windows_icon_path), exist_ok=True)
    master_img.save(windows_icon_path, format='ICO', sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    print(f"Generated Windows app_icon.ico at: {windows_icon_path}")

    # 3. macOS AppIcon Set
    macos_icon_dir = os.path.join(base_out_dir, 'macos', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
    os.makedirs(macos_icon_dir, exist_ok=True)
    macos_sizes = [16, 32, 64, 128, 256, 512, 1024]
    for sz in macos_sizes:
        resized = master_img.resize((sz, sz), Image.Resampling.LANCZOS)
        resized.save(os.path.join(macos_icon_dir, f'app_icon_{sz}.png'))
    print("Generated macOS icon set.")

    # 4. iOS AppIcon Set
    ios_icon_dir = os.path.join(base_out_dir, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
    os.makedirs(ios_icon_dir, exist_ok=True)
    ios_sizes = [20, 29, 40, 60, 76, 83.5, 1024]
    for sz in ios_sizes:
        int_sz = int(sz * 2) # @2x
        resized = master_img.resize((int_sz, int_sz), Image.Resampling.LANCZOS)
        resized.save(os.path.join(ios_icon_dir, f'Icon-App-{sz}x{sz}@2x.png'))
    print("Generated iOS icon set.")

if __name__ == '__main__':
    generate_icons()

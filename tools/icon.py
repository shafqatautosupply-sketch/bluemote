from PIL import Image, ImageDraw, ImageFilter
import math

def create_ios6_bluetooth_icon(size=114, output_path="Icon@2x.png"):
    # Render at 2x target resolution and downsample for crisp anti-aliasing
    scale = 2
    s = size * scale
    center = s // 2
    
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    
    # 1. Background Rounded Square (iOS 6 corner radius ~17.5%)
    radius = int(s * 0.175)
    bg = Image.new("RGBA", (s, s), (0, 0, 0, 255))
    bg_draw = ImageDraw.Draw(bg)
    
    for y in range(s):
        t = y / s
        r = int(55 * (1 - t) + 25 * t)
        g = int(62 * (1 - t) + 30 * t)
        b = int(72 * (1 - t) + 36 * t)
        bg_draw.line([(0, y), (s, y)], fill=(r, g, b, 255))
        
    # Subtle radial metallic sheen
    glow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    max_r = int(s * 0.65)
    for rad in range(max_r, 0, -4):
        alpha = int(60 * (1 - rad / max_r))
        glow_draw.ellipse([center - rad, center - rad, center + rad, center + rad], fill=(140, 155, 175, alpha))
    bg = Image.alpha_composite(bg, glow)
    
    # Rounded square mask & outer metallic bezel
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, s-1, s-1], radius=radius, fill=255)
    
    bezel = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    bezel_draw = ImageDraw.Draw(bezel)
    bezel_width = max(2, int(s * 0.035))
    bezel_draw.rounded_rectangle([0, 0, s-1, s-1], radius=radius, outline=(180, 190, 200, 220), width=bezel_width)
    bezel_draw.rounded_rectangle([bezel_width//2, bezel_width//2, s-1-bezel_width//2, s-1-bezel_width//2], 
                                 radius=max(1, radius - bezel_width//2), outline=(40, 45, 52, 255), width=max(1, int(s*0.01)))
    
    bg = Image.alpha_composite(bg, bezel)
    img.paste(bg, (0, 0), mask)
    
    # 2. Outer Silver D-Pad Ring
    outer_dpad_r = int(s * 0.34)
    inner_dpad_r = int(s * 0.16)
    
    # D-Pad Drop Shadow
    shadow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse([center - outer_dpad_r, center - outer_dpad_r + int(s*0.015), 
                                    center + outer_dpad_r, center + outer_dpad_r + int(s*0.015)], fill=(0, 0, 0, 180))
    shadow = shadow.filter(ImageFilter.GaussianBlur(max(1, int(s * 0.02))))
    img = Image.alpha_composite(img, shadow)
    
    # Silver Gradient Disc
    dpad = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    dpad_draw = ImageDraw.Draw(dpad)
    for y in range(center - outer_dpad_r, center + outer_dpad_r):
        t = (y - (center - outer_dpad_r)) / (2 * outer_dpad_r)
        val = int(225 * (1 - t) + 145 * t)
        dpad_draw.line([(center - outer_dpad_r, y), (center + outer_dpad_r, y)], fill=(val, val+4, val+10, 255))
        
    dpad_mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(dpad_mask).ellipse([center - outer_dpad_r, center - outer_dpad_r, 
                                       center + outer_dpad_r, center + outer_dpad_r], fill=255)
    
    dpad_ring = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(dpad_ring).ellipse([center - outer_dpad_r, center - outer_dpad_r, center + outer_dpad_r, center + outer_dpad_r], 
                                      outline=(245, 250, 255, 230), width=max(1, int(s*0.008)))
    dpad = Image.alpha_composite(dpad, dpad_ring)
    img.paste(dpad, (0, 0), dpad_mask)
    
    # 3. Directional Arrows & Diagonal Ticks
    draw = ImageDraw.Draw(img)
    arrow_dist = int(s * 0.255)
    arrow_size = int(s * 0.032)
    arrow_color = (70, 78, 88, 255)
    
    # Up, Down, Left, Right triangles
    draw.polygon([(center, center - arrow_dist - arrow_size//2), (center - arrow_size//2, center - arrow_dist + arrow_size//2), (center + arrow_size//2, center - arrow_dist + arrow_size//2)], fill=arrow_color)
    draw.polygon([(center, center + arrow_dist + arrow_size//2), (center - arrow_size//2, center + arrow_dist - arrow_size//2), (center + arrow_size//2, center + arrow_dist - arrow_size//2)], fill=arrow_color)
    draw.polygon([(center - arrow_dist - arrow_size//2, center), (center - arrow_dist + arrow_size//2, center - arrow_size//2), (center - arrow_dist + arrow_size//2, center + arrow_size//2)], fill=arrow_color)
    draw.polygon([(center + arrow_dist + arrow_size//2, center), (center + arrow_dist - arrow_size//2, center - arrow_size//2), (center + arrow_dist - arrow_size//2, center + arrow_size//2)], fill=arrow_color)
    
    for angle_deg in [45, 135, 225, 315]:
        rad = math.radians(angle_deg)
        r1, r2 = int(s * 0.235), int(s * 0.275)
        draw.line([(center + int(r1 * math.cos(rad)), center + int(r1 * math.sin(rad))),
                   (center + int(r2 * math.cos(rad)), center + int(r2 * math.sin(rad)))], 
                  fill=(90, 98, 108, 220), width=max(1, int(s*0.008)))
        
    # 4. Center Recessed Button + Glowing Cyan Bluetooth Symbol
    recess_r = int(inner_dpad_r * 1.12)
    draw.ellipse([center - recess_r, center - recess_r, center + recess_r, center + recess_r], 
                 fill=(45, 52, 60, 255), outline=(110, 120, 130, 255), width=max(1, int(s*0.006)))
    
    btn = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    btn_draw = ImageDraw.Draw(btn)
    for y in range(center - inner_dpad_r, center + inner_dpad_r):
        t = (y - (center - inner_dpad_r)) / (2 * inner_dpad_r)
        val = int(175 * (1 - t) + 115 * t)
        btn_draw.line([(center - inner_dpad_r, y), (center + inner_dpad_r, y)], fill=(val, val+8, val+18, 255))
    btn_mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(btn_mask).ellipse([center - inner_dpad_r, center - inner_dpad_r, center + inner_dpad_r, center + inner_dpad_r], fill=255)
    img.paste(btn, (0, 0), btn_mask)
    
    # Bluetooth Rune Geometry
    bh = int(inner_dpad_r * 0.62)
    bw = int(bh * 0.52)
    pts = [
        (center - bw, center - bh//2),
        (center + bw, center + bh//2),
        (center, center + bh),
        (center, center - bh),
        (center + bw, center - bh//2),
        (center - bw, center + bh//2)
    ]
    
    # Outer cyan glow
    bt_glow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(bt_glow).line(pts, fill=(0, 210, 255, 255), width=max(2, int(s * 0.024)), joint="curve")
    bt_glow = bt_glow.filter(ImageFilter.GaussianBlur(max(1, int(s * 0.015))))
    img = Image.alpha_composite(img, bt_glow)
    
    # Crisp inner cyan core
    ImageDraw.Draw(img).line(pts, fill=(130, 240, 255, 255), width=max(1, int(s * 0.014)), joint="curve")
    
    # 5. Classic iOS 6 Top Curved Gloss Overlay
    gloss = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(gloss).ellipse([-int(s*0.25), -int(s*0.65), int(s*1.25), int(s*0.48)], fill=(255, 255, 255, 55))
    gloss_clipped = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    gloss_clipped.paste(gloss, (0, 0), mask)
    img = Image.alpha_composite(img, gloss_clipped)
    
    # Export final anti-aliased PNG
    final_img = img.resize((size, size), Image.Resampling.LANCZOS)
    final_img.save(output_path, "PNG")

# Generate all standard iOS 6 iPhone 4S icon sizes:
create_ios6_bluetooth_icon(114, "Icon@2x.png")       # iPhone 4S Retina Home Screen
create_ios6_bluetooth_icon(57, "Icon.png")           # Non-Retina Home Screen
create_ios6_bluetooth_icon(58, "Icon-Small@2x.png")  # Settings / Spotlight Retina
create_ios6_bluetooth_icon(512, "iTunesArtwork.png") # Cydia / App Store Artwork

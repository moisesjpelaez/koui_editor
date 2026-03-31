import os
import json
import arm.utils
import arm.log as log


def _discover_canvas_images():
    """Scan Bundled/koui_canvas/*.json for imageName references and find
    matching image files under Assets/. Returns a list of relative asset paths."""
    project_path = arm.utils.get_fp()
    canvas_dir = os.path.join(project_path, 'Bundled', 'koui_canvas')
    assets_dir = os.path.join(project_path, 'Assets')

    if not os.path.isdir(canvas_dir) or not os.path.isdir(assets_dir):
        return []

    image_names = set()
    for filename in os.listdir(canvas_dir):
        if not filename.endswith('.json'):
            continue
        filepath = os.path.join(canvas_dir, filename)
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                canvas_data = json.load(f)
            for scene in canvas_data.get('scenes', []):
                for element in scene.get('elements', []):
                    props = element.get('properties')
                    if props and props.get('imageName'):
                        image_names.add(props['imageName'])
        except (json.JSONDecodeError, OSError):
            pass

    if not image_names:
        return []

    # Build index of image files under Assets/ (name without ext -> relative path)
    image_index = {}
    for root, _dirs, files in os.walk(assets_dir):
        for f in files:
            name_no_ext, ext = os.path.splitext(f)
            if ext.lower() in ('.png', '.jpg', '.jpeg', '.gif', '.bmp', '.hdr'):
                rel = os.path.relpath(os.path.join(root, f), project_path).replace('\\', '/')
                # First match wins (avoids duplicates)
                if name_no_ext not in image_index:
                    image_index[name_no_ext] = rel

    found_assets = []
    for name in sorted(image_names):
        if name in image_index:
            found_assets.append(image_index[name])
        else:
            log.warn(f"Koui: canvas references image '{name}' but no matching file found under Assets/")

    return found_assets


def write_main():
    assets = [
        ('Assets/koui_canvas/ui_override.ksn', {'destination': '{name}'})
    ]

    for image_path in _discover_canvas_images():
        assets.append((image_path, {'destination': '{name}'}))

    return {
        'imports': 'import koui.Koui;',
        'main_pre': 'iron.App.notifyOnInit(function() { kha.Assets.loadBlobFromPath("ui_override.ksn", function(_) { Koui.init(function() { iron.App.notifyOnRender2D(function(g) { g.end(); @:privateAccess Koui.g.imageScaleQuality = armory.ui.Canvas.imageScaleQuality; Koui.render(g); g.begin(false); }); }); }); });',
        'assets': assets
    }

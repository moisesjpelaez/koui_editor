import os
import subprocess
import glob
import json
import bpy
from bpy.props import StringProperty
import arm.utils
import arm.props_traits as pt
import arm.log as log

# This library's folder: the built editor is in its tools/ folder, the default theme in its Assets/
_KOUI_EDITOR_DIR = os.path.dirname(os.path.realpath(__file__))


def koui_canvas_file(canvas_name):
    """The canvas' file in Bundled/koui_canvas; a canvas with a file there is a Koui canvas."""
    return os.path.join(arm.utils.get_fp(), 'Bundled', 'koui_canvas', canvas_name + '.json')


# Patching
#
# Each patch keeps the function it replaced on the wrapper (_koui_original).
# Patching again first unwraps the previous patch, and unpatching restores the
# function the current patch replaced. This keeps working when Armory reloads
# this module (it shares the 'blender' name with other libraries), which
# resets the module's variables.

def _patch(owner, name, make_wrapper):
    current = getattr(owner, name)
    original = getattr(current, '_koui_original', current)
    wrapper = make_wrapper(original)
    wrapper._koui_original = original
    setattr(owner, name, wrapper)


def _unpatch(owner, name):
    original = getattr(getattr(owner, name, None), '_koui_original', None)
    if original is not None:
        setattr(owner, name, original)


def _make_edit_canvas_execute(original):
    """The Edit Canvas button: Koui canvases open in the Koui Editor, other canvases as before."""
    def execute(self, context):
        obj = bpy.context.object if self.is_object else bpy.context.scene
        item = obj.arm_traitlist[obj.arm_traitlist_index]
        canvas_name = item.canvas_name_prop if item.canvas_name_prop else item.name
        if not canvas_name or not os.path.exists(koui_canvas_file(canvas_name)):
            return original(self, context)

        log.info(f"Koui Editor: Using canvas name = '{canvas_name}'")
        bpy.ops.koui.launch_editor(canvas_name=canvas_name)
        return {'FINISHED'}
    return execute


def _make_new_canvas_execute(original):
    """The New Canvas dialog: writes an empty Koui canvas and opens it in the Koui Editor."""
    def execute(self, context):
        obj = bpy.context.object if self.is_object else bpy.context.scene

        self.canvas_name = self.canvas_name.replace(' ', '')

        # Create empty canvas JSON file so it shows up in the list
        canvas_file = koui_canvas_file(self.canvas_name)
        os.makedirs(os.path.dirname(canvas_file), exist_ok=True)
        if not os.path.exists(canvas_file):
            # Create a minimal empty canvas with one scene
            render_settings = bpy.context.scene.render
            empty_canvas = {
                "name": self.canvas_name,
                "version": "2.0",
                "canvas": {
                    "width": render_settings.resolution_x,
                    "height": render_settings.resolution_y,
                    "settings": {
                        "expandOnResize": True,
                        "scaleOnResize": True,
                        "autoScale": True,
                        "scaleHorizontal": False,
                        "scaleVertical": False
                    }
                },
                "radioGroups": [],
                "scenes": [
                    {
                        "key": "Scene_1",
                        "active": True,
                        "elements": []
                    }
                ]
            }
            with open(canvas_file, 'w') as f:
                json.dump(empty_canvas, f, indent=2)
            log.info(f"Koui Editor: Created canvas file '{canvas_file}'")

        # Refresh scripts so the new canvas shows up in the list
        bpy.ops.arm.refresh_scripts()

        # Set the canvas name on the trait
        item = obj.arm_traitlist[obj.arm_traitlist_index]
        item.canvas_name_prop = self.canvas_name

        log.info(f"Koui Editor: Created canvas trait '{self.canvas_name}'")

        # Auto-launch Koui Editor for new canvas
        bpy.ops.koui.launch_editor(canvas_name=self.canvas_name)

        return {'FINISHED'}
    return execute


def _make_export_traits(original):
    """
    Exports Koui canvas traits as KouiCanvas. Armory's export runs unchanged and
    its result is fixed afterwards, so the traits' data is never touched.
    """
    from arm import exporter

    def export_traits(self, bobject, o):
        koui_canvases = []
        for item in getattr(bobject, 'arm_traitlist', []):
            if not item.enabled_prop and not item.fake_user:
                continue
            if item.type_prop == 'UI Canvas' and item.canvas_name_prop and os.path.exists(koui_canvas_file(item.canvas_name_prop)):
                koui_canvases.append(item.canvas_name_prop)

        if not koui_canvases:
            return original(self, bobject, o)

        # Armory looks for every canvas in Bundled/canvas and warns that Koui canvases
        # aren't there; only those warnings are left out, and only during this call
        warn = exporter.log.warn
        expected = [f'Referenced canvas "{name}" not found' for name in koui_canvases]

        def filtered_warn(text, *args, **kwargs):
            if any(message in str(text) for message in expected):
                return
            return warn(text, *args, **kwargs)

        exporter.log.warn = filtered_warn
        try:
            original(self, bobject, o)
        finally:
            exporter.log.warn = warn

        # An Armory2D canvas with the same name in Bundled/canvas gave a CanvasScript: the Koui canvas replaces it
        parameters = ["'" + name + "'" for name in koui_canvases]
        traits = [t for t in o.get('traits', [])
                  if not (t.get('class_name') == 'armory.trait.internal.CanvasScript' and t.get('parameters', [None])[0] in parameters)]
        koui_traits = [{
            'type': 'Script',
            'class_name': 'armory.trait.internal.KouiCanvas',
            'parameters': [parameter]
        } for parameter in parameters]
        o['traits'] = koui_traits + traits
        exporter.ArmoryExporter.export_ui = True
        for name in koui_canvases:
            log.info(f"Koui Editor: Using KouiCanvas for '{name}'")

    return export_traits


def _make_fetch_script_names(original):
    """The canvas list also lists the canvases in Bundled/koui_canvas."""
    def fetch_script_names():
        original()

        wrd = bpy.data.worlds['Arm']
        koui_canvas_path = os.path.join(arm.utils.get_fp(), 'Bundled', 'koui_canvas')
        if os.path.isdir(koui_canvas_path):
            listed = [c.name for c in wrd.arm_canvas_list]
            for file in glob.glob(os.path.join(koui_canvas_path, '*.json')):
                name = os.path.basename(file).rsplit('.', 1)[0]
                if name not in listed:
                    wrd.arm_canvas_list.add().name = name
    return fetch_script_names


class KOUI_OT_launch_editor(bpy.types.Operator):
    bl_idname = 'koui.launch_editor'
    bl_label = 'Launch Koui Editor'
    bl_description = 'Open the Koui Editor'
    bl_options = {'REGISTER'}

    canvas_name: StringProperty(name="Canvas", default="")

    def execute(self, context):
        sdk_path = arm.utils.get_sdk_path()
        ext = 'd3d11' if arm.utils.get_os() == 'win' else 'opengl'
        sdk_koui_path = os.path.join(_KOUI_EDITOR_DIR, 'tools', ext) if sdk_path else ""

        if sdk_koui_path and os.path.exists(sdk_koui_path):
            koui_editor_path = sdk_koui_path
            print(f"Koui Editor: Using SDK build at {koui_editor_path}")
            setup_assets_dir()
        else:
            self.report({'ERROR'},
                f'Koui Editor not found.\n'
                f'SDK path: {sdk_koui_path}\n'
                f'Please build the editor first (open koui_editor.blend and click Play).')
            return {'CANCELLED'}

        krom_location, krom_path = arm.utils.krom_paths()
        if not os.path.exists(krom_path):
            self.report({'ERROR'}, f'Krom not found at: {krom_path}')
            return {'CANCELLED'}
        os.chdir(krom_location)

        # Ensure canvas_name is not empty
        canvas_name = self.canvas_name if self.canvas_name else "UntitledCanvas"

        # Get project root (respects arm_project_root, falls back to blend file directory).
        # os.path.normpath resolves any ".." segments (e.g. from a relative arm_project_root
        # like "//../../") so Krom receives a clean absolute path.
        project_dir = os.path.normpath(arm.utils.get_fp()) if bpy.data.filepath else os.getcwd()

        uiscale = str(arm.utils.get_ui_scale())
        cmd = [krom_path, koui_editor_path, koui_editor_path, canvas_name, uiscale]

        # Pass render resolution
        render_settings = context.scene.render
        cmd.append(str(render_settings.resolution_x))
        cmd.append(str(render_settings.resolution_y))

        # Pass project directory
        cmd.append(project_dir)
        cmd.append(ext)

        if arm.utils.get_os() == 'win':
            cmd.append('--consolepid')
            cmd.append(str(os.getpid()))

        log.info(f"Launching Koui Editor: {' '.join(cmd)}")
        subprocess.Popen(cmd)

        return {'FINISHED'}


classes = (
    KOUI_OT_launch_editor,
)


def _patch_targets():
    """(owner, attribute, wrapper factory) of each patch; owners Armory doesn't have are left out."""
    from arm import exporter
    targets = [
        (getattr(pt, 'ArmEditCanvasButton', None), 'execute', _make_edit_canvas_execute),
        (getattr(pt, 'ArmNewCanvasDialog', None), 'execute', _make_new_canvas_execute),
        (getattr(exporter, 'ArmoryExporter', None), 'export_traits', _make_export_traits),
        (arm.utils, 'fetch_script_names', _make_fetch_script_names),
    ]
    return [target for target in targets if target[0] is not None]


def register():
    for cls in classes:
        bpy.utils.register_class(cls)

    for owner, name, make_wrapper in _patch_targets():
        try:
            _patch(owner, name, make_wrapper)
            log.info(f"Koui Editor: Patched {getattr(owner, '__name__', owner)}.{name}")
        except Exception as e:
            log.warn(f"Koui Editor: Could not patch {name}: {e}")

    # Armory filled the canvas list before loading libraries: add the Koui canvases
    try:
        if bpy.data.filepath and 'Arm' in bpy.data.worlds:
            arm.utils.fetch_script_names()
    except Exception as e:
        log.warn(f"Koui Editor: Could not refresh the canvas list: {e}")

    # Ensure Assets/koui_canvas exist and default files are copied on import
    try:
        if bpy.data.filepath:
            setup_assets_dir()
    except Exception as e:
        log.warn(f"Koui Editor: Could not initialise Assets directory on register: {e}")

    log.info("Koui Editor: Registered")


def unregister():
    for owner, name, _ in _patch_targets():
        _unpatch(owner, name)

    for cls in reversed(classes):
        try:
            bpy.utils.unregister_class(cls)
        except RuntimeError:
            # Class may already be unregistered during script reload
            pass


def setup_assets_dir():
    project_path = arm.utils.get_fp()

    assets_dir = os.path.join(project_path, 'Assets')
    if not os.path.exists(assets_dir):
        os.makedirs(assets_dir)
        print(f"Koui Editor: Created Assets directory")

    theme_dir = os.path.join(project_path, assets_dir, 'koui_canvas')
    if not os.path.exists(theme_dir):
        os.makedirs(theme_dir)
        print(f"Koui Editor: Created Assets/koui_canvas directory")

    # Ensure ui_override.ksn exists in project Assets directory
    ui_override_project = os.path.join(theme_dir, 'ui_override.ksn')
    if not os.path.exists(ui_override_project):
        # Copy default from library
        ui_override_default = os.path.join(_KOUI_EDITOR_DIR, 'Assets', 'koui_canvas', 'ui_override.ksn')
        if os.path.exists(ui_override_default):
            import shutil
            shutil.copy2(ui_override_default, ui_override_project)
            print(f"Koui Editor: Copied default ui_override.ksn to project Assets")
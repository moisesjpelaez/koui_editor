"""
Koui Editor - Armory Library Integration

This file is automatically loaded by Armory when koui_editor is in the Libraries folder.
It registers the Koui Editor UI panel and operators.

Setup:
1. Symlink or copy koui_editor folder to your project's Libraries/ folder
2. Open Blender with Armory - the Koui panel will appear automatically
"""

import os
import subprocess
import bpy
from bpy.props import BoolProperty, StringProperty

# Check if Armory is available
try:
    import arm.utils
    ARMORY_AVAILABLE = True
except ImportError:
    ARMORY_AVAILABLE = False


def get_os():
    """Get the current operating system identifier."""
    import platform
    s = platform.system()
    if s == 'Windows':
        return 'win'
    elif s == 'Darwin':
        return 'mac'
    else:
        return 'linux'


def get_sdk_path():
    """Get the Armory SDK path."""
    if ARMORY_AVAILABLE:
        return arm.utils.get_sdk_path()
    return ""


def get_krom_paths():
    """Get Krom executable location and path."""
    if ARMORY_AVAILABLE:
        return arm.utils.krom_paths()

    sdk_path = get_sdk_path()
    os_name = get_os()

    if os_name == 'win':
        krom_location = sdk_path + '/Krom'
        krom_path = krom_location + '/Krom.exe'
    elif os_name == 'mac':
        krom_location = sdk_path + '/Krom/Krom.app/Contents/MacOS'
        krom_path = krom_location + '/Krom'
    else:
        krom_location = sdk_path + '/Krom'
        krom_path = krom_location + '/Krom'

    return krom_location, krom_path


def get_ui_scale():
    """Get the UI scale factor."""
    if ARMORY_AVAILABLE:
        return arm.utils.get_ui_scale()
    return bpy.context.preferences.system.ui_scale


class KOUI_OT_launch_editor(bpy.types.Operator):
    """Launch the Koui Editor"""
    bl_idname = 'koui.launch_editor'
    bl_label = 'Launch Koui Editor'
    bl_description = 'Open the Koui Editor'
    bl_options = {'REGISTER'}

    def execute(self, context):
        # Get the path to this blender.py file (koui_editor library root)
        this_dir = os.path.dirname(os.path.realpath(__file__))

        # Fall back to SDK path
        sdk_path = get_sdk_path()
        ext = 'd3d11' if get_os() == 'win' else 'opengl'
        sdk_koui_path = os.path.join(this_dir, 'tools', ext) if sdk_path else ""

        if sdk_koui_path and os.path.exists(sdk_koui_path):
            koui_editor_path = sdk_koui_path
            print(f"Koui Editor: Using SDK build at {koui_editor_path}")
        else:
            self.report({'ERROR'},
                f'Koui Editor not found.\n'
                f'SDK path: {sdk_koui_path}\n'
                f'Please build the editor first (open koui_editor.blend and click Play).')
            return {'CANCELLED'}

        # Get Krom paths
        krom_location, krom_path = get_krom_paths()

        if not os.path.exists(krom_path):
            self.report({'ERROR'}, f'Krom not found at: {krom_path}')
            return {'CANCELLED'}

        os.chdir(krom_location)

        # Prepare command-line arguments
        uiscale = str(get_ui_scale())

        # Build command
        cmd = [krom_path, koui_editor_path, koui_editor_path, "", uiscale]

        if get_os() == 'win':
            cmd.append('--consolepid')
            cmd.append(str(os.getpid()))

        print(f"Launching Koui Editor: {' '.join(cmd)}")
        subprocess.Popen(cmd)

        return {'FINISHED'}


class KOUI_PT_panel(bpy.types.Panel):
    """Koui Editor Panel in the 3D View sidebar"""
    bl_label = "Koui Editor"
    bl_idname = "KOUI_PT_panel"
    bl_space_type = 'VIEW_3D'
    bl_region_type = 'UI'
    bl_category = 'Koui'

    def draw(self, context):
        layout = self.layout

        layout.operator("koui.launch_editor", icon='WINDOW')


# Registration
classes = (
    KOUI_OT_launch_editor,
    KOUI_PT_panel
)


def register():
    for cls in classes:
        bpy.utils.register_class(cls)
    print("Koui Editor: Registered")


def unregister():
    for cls in reversed(classes):
        bpy.utils.unregister_class(cls)
    print("Koui Editor: Unregistered")

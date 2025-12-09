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
        sdk_path = get_sdk_path()

        if not sdk_path:
            self.report({'ERROR'}, 'Armory SDK path not found.')
            return {'CANCELLED'}

        # Determine graphics backend
        ext = 'd3d11' if get_os() == 'win' else 'opengl'

        # Path to pre-built koui_editor
        koui_editor_path = os.path.join(sdk_path, 'lib', 'armory_tools', 'koui_editor', ext)

        # Check if koui_editor exists
        if not os.path.exists(koui_editor_path):
            self.report({'ERROR'}, f'Koui Editor not found at: {koui_editor_path}\nPlease build the standalone editor first.')
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


class KOUI_OT_launch_with_scene(bpy.types.Operator):
    """Launch the Koui Editor with the current scene exported"""
    bl_idname = 'koui.launch_with_scene'
    bl_label = 'Launch with Scene'
    bl_description = 'Export current scene and open in Koui Editor'
    bl_options = {'REGISTER'}

    @classmethod
    def poll(cls, context):
        return ARMORY_AVAILABLE

    def execute(self, context):
        if not ARMORY_AVAILABLE:
            self.report({'ERROR'}, 'Armory not available.')
            return {'CANCELLED'}

        from arm.exporter import ArmoryExporter

        sdk_path = get_sdk_path()
        ext = 'd3d11' if get_os() == 'win' else 'opengl'
        koui_editor_path = os.path.join(sdk_path, 'lib', 'armory_tools', 'koui_editor', ext)

        if not os.path.exists(koui_editor_path):
            self.report({'ERROR'}, f'Koui Editor not found at: {koui_editor_path}')
            return {'CANCELLED'}

        # Export the current scene
        scene = context.scene
        scene_name = arm.utils.safestr(scene.name)

        # Get build directory
        build_dir = arm.utils.get_fp_build()
        export_dir = os.path.join(build_dir, 'koui_preview', 'Assets')

        if not os.path.exists(export_dir):
            os.makedirs(export_dir)

        # Export scene to .arm file
        scene_path = os.path.join(export_dir, scene_name + '.arm')

        try:
            depsgraph = context.evaluated_depsgraph_get()
            ArmoryExporter.export_scene(context, scene_path, scene=scene, depsgraph=depsgraph)
        except Exception as e:
            self.report({'ERROR'}, f'Failed to export scene: {str(e)}')
            return {'CANCELLED'}

        # Get Krom paths
        krom_location, krom_path = get_krom_paths()
        os.chdir(krom_location)

        # Prepare command
        scene_path_normalized = scene_path.replace('\\', '/')
        uiscale = str(get_ui_scale())

        cmd = [krom_path, koui_editor_path, koui_editor_path, scene_path_normalized, uiscale]

        if get_os() == 'win':
            cmd.append('--consolepid')
            cmd.append(str(os.getpid()))

        print(f"Launching Koui Editor with scene: {' '.join(cmd)}")
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

        if ARMORY_AVAILABLE:
            layout.operator("koui.launch_with_scene", icon='SCENE_DATA')
        else:
            box = layout.box()
            box.label(text="Armory not loaded", icon='INFO')


# Registration
classes = (
    KOUI_OT_launch_editor,
    KOUI_OT_launch_with_scene,
    KOUI_PT_panel,
)


def register():
    for cls in classes:
        bpy.utils.register_class(cls)
    print("Koui Editor: Registered")


def unregister():
    for cls in reversed(classes):
        bpy.utils.unregister_class(cls)
    print("Koui Editor: Unregistered")

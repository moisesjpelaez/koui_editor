import os
import subprocess
import bpy
import arm.utils

def get_os():
    import platform
    s = platform.system()
    if s == 'Windows':
        return 'win'
    elif s == 'Darwin':
        return 'mac'
    else:
        return 'linux'


class KOUI_OT_launch_editor(bpy.types.Operator):
    bl_idname = 'koui.launch_editor'
    bl_label = 'Launch Koui Editor'
    bl_description = 'Open the Koui Editor'
    bl_options = {'REGISTER'}

    def execute(self, context):
        this_dir = os.path.dirname(os.path.realpath(__file__))

        sdk_path = arm.utils.get_sdk_path()
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

        krom_location, krom_path = arm.utils.krom_paths()
        if not os.path.exists(krom_path):
            self.report({'ERROR'}, f'Krom not found at: {krom_path}')
            return {'CANCELLED'}
        os.chdir(krom_location)

        uiscale = str(arm.utils.get_ui_scale())
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

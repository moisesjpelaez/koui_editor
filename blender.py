import os
import subprocess
import bpy
from bpy.props import StringProperty
import arm.utils
import arm.props_traits as pt
import arm.log as log

# Stored originals for Armory patching
_original_arm_edit_canvas_execute = None
_original_arm_edit_canvas_label = None

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

    canvas_name: StringProperty(name="Canvas", default="")

    def execute(self, context):
        this_dir = os.path.dirname(os.path.realpath(__file__))

        sdk_path = arm.utils.get_sdk_path()
        ext = 'd3d11' if get_os() == 'win' else 'opengl'
        sdk_koui_path = os.path.join(this_dir, 'tools', ext) if sdk_path else ""

        if sdk_koui_path and os.path.exists(sdk_koui_path):
            koui_editor_path = sdk_koui_path
            print(f"Koui Editor: Using SDK build at {koui_editor_path}")

            project_path = arm.utils.get_fp()
            assets_dir = os.path.join(project_path, 'Assets')
            if not os.path.exists(assets_dir):
                os.makedirs(assets_dir)
                print(f"Koui Editor: Created Assets directory")

            # Ensure ui_override.ksn exists in project Assets directory
            ui_override_project = os.path.join(assets_dir, 'ui_override.ksn')
            if not os.path.exists(ui_override_project):
                # Copy default from library
                ui_override_default = os.path.join(this_dir, 'Assets', 'ui_override.ksn')
                if os.path.exists(ui_override_default):
                    import shutil
                    shutil.copy2(ui_override_default, ui_override_project)
                    print(f"Koui Editor: Copied default ui_override.ksn to project Assets")

            # Ensure ui_override.ksn exists in build directory
            ui_override_build = os.path.join(koui_editor_path, 'ui_override.ksn')
            if not os.path.exists(ui_override_build):
                if os.path.exists(ui_override_project):
                    import shutil
                    shutil.copy2(ui_override_project, ui_override_build)
                    print(f"Koui Editor: Copied ui_override.ksn to build directory")
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

        # Build canvas path if a canvas name is provided
        canvas_arg = ""
        if self.canvas_name:
            project_path = arm.utils.get_fp()
            canvas_arg = os.path.join(project_path, 'Bundled', 'canvas', self.canvas_name + '.json')
            canvas_arg = canvas_arg.replace('\\', '/')

        uiscale = str(arm.utils.get_ui_scale())
        cmd = [krom_path, koui_editor_path, koui_editor_path, canvas_arg, uiscale]

        # Pass render resolution
        render_settings = context.scene.render
        cmd.append(str(render_settings.resolution_x))
        cmd.append(str(render_settings.resolution_y))

        if get_os() == 'win':
            cmd.append('--consolepid')
            cmd.append(str(os.getpid()))

        log.info(f"Launching Koui Editor: {' '.join(cmd)}")
        subprocess.Popen(cmd)

        return {'FINISHED'}


classes = (
    KOUI_OT_launch_editor,
)


def register():
    for cls in classes:
        bpy.utils.register_class(cls)

    try:
        ArmEditCanvasButton = pt.ArmEditCanvasButton
    except Exception:
        ArmEditCanvasButton = None

    if ArmEditCanvasButton is not None:
        global _original_arm_edit_canvas_execute, _original_arm_edit_canvas_label
        _original_arm_edit_canvas_execute = ArmEditCanvasButton.execute
        try:
            _original_arm_edit_canvas_label = ArmEditCanvasButton.bl_label
        except Exception:
            _original_arm_edit_canvas_label = None

        # Change label
        ArmEditCanvasButton.bl_label = 'Edit with Koui'

        # Define replacement execute
        def _koui_edit_canvas_execute(self, context):
            canvas_name = ''
            try:
                if self.is_object:
                    obj = bpy.context.object
                else:
                    obj = bpy.context.scene
                item = obj.arm_traitlist[obj.arm_traitlist_index]
                canvas_name = item.canvas_name_prop

                # Launch Koui editor via our operator
                bpy.ops.koui.launch_editor(canvas_name=canvas_name)
            except Exception:
                log.error("Koui Editor: could not launch from patched button")
            return {'FINISHED'}

        ArmEditCanvasButton.execute = _koui_edit_canvas_execute
        log.info("Koui Editor: Patched ArmEditCanvasButton to open Koui")
    log.info("Koui Editor: Registered")


def unregister():
    try:
        ArmEditCanvasButton = pt.ArmEditCanvasButton
    except Exception:
        ArmEditCanvasButton = None

    if ArmEditCanvasButton is not None and _original_arm_edit_canvas_execute is not None:
        ArmEditCanvasButton.execute = _original_arm_edit_canvas_execute
        if _original_arm_edit_canvas_label is not None:
            ArmEditCanvasButton.bl_label = _original_arm_edit_canvas_label
        log.info("Koui Editor: Restored ArmEditCanvasButton")

    for cls in reversed(classes):
        bpy.utils.unregister_class(cls)

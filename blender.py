import os
import subprocess
import bpy
from bpy.props import StringProperty
import arm.utils

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
        if getattr(self, 'canvas_name', None):
            project_path = arm.utils.get_fp()
            canvas_arg = os.path.join(project_path, 'Bundled', 'canvas', self.canvas_name + '.json')
            canvas_arg = canvas_arg.replace('\\', '/')

        uiscale = str(arm.utils.get_ui_scale())
        cmd = [krom_path, koui_editor_path, koui_editor_path, canvas_arg, uiscale]

        if get_os() == 'win':
            cmd.append('--consolepid')
            cmd.append(str(os.getpid()))

        print(f"Launching Koui Editor: {' '.join(cmd)}")
        subprocess.Popen(cmd)

        return {'FINISHED'}


classes = (
    KOUI_OT_launch_editor,
)


def register():
    for cls in classes:
        bpy.utils.register_class(cls)

    # Patch Armory's Edit Canvas button to open Koui instead
    try:
        import arm.props_traits as pt
        if hasattr(pt, 'ArmEditCanvasButton'):
            global _original_arm_edit_canvas_execute, _original_arm_edit_canvas_label
            _original_arm_edit_canvas_execute = pt.ArmEditCanvasButton.execute
            _original_arm_edit_canvas_label = getattr(pt.ArmEditCanvasButton, 'bl_label', None)

            # Change label
            pt.ArmEditCanvasButton.bl_label = 'Edit with Koui'

            # Define replacement execute
            def _koui_edit_canvas_execute(self, context):
                try:
                    if self.is_object:
                        obj = bpy.context.object
                    else:
                        obj = bpy.context.scene
                    item = obj.arm_traitlist[obj.arm_traitlist_index]
                    canvas_name = item.canvas_name_prop
                except Exception:
                    canvas_name = ''

                # Launch Koui editor via our operator
                try:
                    bpy.ops.koui.launch_editor(canvas_name=canvas_name)
                except Exception as e:
                    print(f"Koui Editor: failed to launch from patched button: {e}")
                return {'FINISHED'}

            pt.ArmEditCanvasButton.execute = _koui_edit_canvas_execute
            print("Koui Editor: Patched ArmEditCanvasButton to open Koui")
    except Exception:
        print("Koui Editor: ArmEditCanvasButton patch skipped (Armory not available)")

    print("Koui Editor: Registered")


def unregister():
    # Restore ArmEditCanvasButton if patched
    try:
        import arm.props_traits as pt
        if hasattr(pt, 'ArmEditCanvasButton') and _original_arm_edit_canvas_execute is not None:
            try:
                pt.ArmEditCanvasButton.execute = _original_arm_edit_canvas_execute
                if _original_arm_edit_canvas_label is not None:
                    pt.ArmEditCanvasButton.bl_label = _original_arm_edit_canvas_label
                print("Koui Editor: Restored ArmEditCanvasButton")
            except Exception:
                pass
    except Exception:
        pass

    for cls in reversed(classes):
        try:
            bpy.utils.unregister_class(cls)
        except Exception:
            pass
    print("Koui Editor: Unregistered")

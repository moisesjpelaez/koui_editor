import os
import subprocess
import glob
import bpy
from bpy.props import StringProperty
import arm.utils
import arm.props_traits as pt
import arm.log as log

# Stored originals for Armory patching
_original_arm_edit_canvas_execute = None
_original_arm_edit_canvas_label = None
_original_arm_new_canvas_execute = None
_original_export_trait_code = None
_original_fetch_script_names = None

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

            theme_dir = os.path.join(project_path, assets_dir, 'koui_canvas')
            if not os.path.exists(theme_dir):
                os.makedirs(theme_dir)
                print(f"Koui Editor: Created Assets/koui_canvas directory")

            # Ensure ui_override.ksn exists in project Assets directory
            ui_override_project = os.path.join(theme_dir, 'ui_override.ksn')
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

        # Ensure canvas_name is not empty
        canvas_name = self.canvas_name if self.canvas_name else "UntitledCanvas"

        # Get project directory (where the .blend file is)
        project_dir = os.path.dirname(bpy.data.filepath) if bpy.data.filepath else os.getcwd()

        uiscale = str(arm.utils.get_ui_scale())
        cmd = [krom_path, koui_editor_path, koui_editor_path, canvas_name, uiscale]

        # Pass render resolution
        render_settings = context.scene.render
        cmd.append(str(render_settings.resolution_x))
        cmd.append(str(render_settings.resolution_y))

        # Pass project directory
        cmd.append(project_dir)
        cmd.append(ext)

        if get_os() == 'win':
            cmd.append('--consolepid')
            cmd.append(str(os.getpid()))

        log.info(f"Launching Koui Editor: {' '.join(cmd)}")
        subprocess.Popen(cmd)

        return {'FINISHED'}


classes = (
    KOUI_OT_launch_editor,
)


# Handler to refresh canvas list when a file is loaded
@bpy.app.handlers.persistent
def on_load_post(dummy):
    """Called after a blend file is loaded - refresh scripts to include koui_canvas"""
    try:
        if 'Arm' in bpy.data.worlds and bpy.data.filepath:
            bpy.ops.arm.refresh_scripts()
    except Exception:
        pass  # Silently ignore errors during load


def register():
    for cls in classes:
        bpy.utils.register_class(cls)

    # Register load handler
    if on_load_post not in bpy.app.handlers.load_post:
        bpy.app.handlers.load_post.append(on_load_post)

    try:
        ArmEditCanvasButton = pt.ArmEditCanvasButton
    except Exception:
        ArmEditCanvasButton = None

    try:
        ArmNewCanvasDialog = pt.ArmNewCanvasDialog
    except Exception:
        ArmNewCanvasDialog = None

    # Patch Edit Canvas button
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
            canvas_name = 'UntitledCanvas'
            try:
                if self.is_object:
                    obj = bpy.context.object
                else:
                    obj = bpy.context.scene
                item = obj.arm_traitlist[obj.arm_traitlist_index]

                # Use canvas_name_prop if set, otherwise use the trait's name
                if item.canvas_name_prop:
                    canvas_name = item.canvas_name_prop
                elif item.name:
                    canvas_name = item.name

                log.info(f"Koui Editor: Using canvas name = '{canvas_name}'")

                # Launch Koui editor via our operator
                bpy.ops.koui.launch_editor(canvas_name=canvas_name)
            except Exception as e:
                log.error(f"Koui Editor: could not launch from patched button: {e}")
                import traceback
                log.error(traceback.format_exc())
            return {'FINISHED'}

        ArmEditCanvasButton.execute = _koui_edit_canvas_execute
        log.info("Koui Editor: Patched ArmEditCanvasButton to open Koui")

    # Patch New Canvas dialog
    if ArmNewCanvasDialog is not None:
        global _original_arm_new_canvas_execute
        _original_arm_new_canvas_execute = ArmNewCanvasDialog.execute

        def _koui_new_canvas_execute(self, context):
            if self.is_object:
                obj = bpy.context.object
            else:
                obj = bpy.context.scene

            self.canvas_name = self.canvas_name.replace(' ', '')

            # Create empty canvas JSON file so it shows up in the list
            canvas_path = arm.utils.get_fp() + '/Bundled/koui_canvas'
            if not os.path.exists(canvas_path):
                os.makedirs(canvas_path)

            canvas_file = os.path.join(canvas_path, self.canvas_name + '.json')
            if not os.path.exists(canvas_file):
                # Create a minimal empty canvas with one scene
                import json
                render_settings = bpy.context.scene.render
                empty_canvas = {
                    "name": self.canvas_name,
                    "version": "1.1",
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
                    "scenes": [
                        {
                            "key": "Scene_1",
                            "elements": [],
                            "active": True
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

        ArmNewCanvasDialog.execute = _koui_new_canvas_execute
        log.info("Koui Editor: Patched ArmNewCanvasDialog to use KouiCanvas")

    # Patch exporter to use KouiCanvas class for koui_canvas folder
    try:
        from arm import exporter
        global _original_export_trait_code

        if hasattr(exporter, 'ArmoryExporter'):
            _original_export_trait_code = exporter.ArmoryExporter.export_traits

            def patched_export_traits(self, bobject, o):
                if not hasattr(bobject, 'arm_traitlist'):
                    return

                # Track which traits we handle (by index) so we can skip them in original
                handled_indices = set()

                for idx, traitlistItem in enumerate(bobject.arm_traitlist):
                    if not traitlistItem.enabled_prop and not traitlistItem.fake_user:
                        continue

                    # Handle UI Canvas - check koui_canvas folder first
                    if traitlistItem.type_prop == 'UI Canvas':
                        canvas_name = traitlistItem.canvas_name_prop
                        koui_cpath = os.path.join(arm.utils.get_fp(), 'Bundled', 'koui_canvas', canvas_name + '.json')

                        if os.path.exists(koui_cpath):
                            # Use KouiCanvas for koui_canvas folder
                            out_trait = {
                                'type': 'Script',
                                'class_name': 'armory.trait.internal.KouiCanvas',
                                'parameters': ["'" + canvas_name + "'"]
                            }
                            if 'traits' not in o:
                                o['traits'] = []
                            o['traits'].append(out_trait)
                            exporter.ArmoryExporter.export_ui = True
                            handled_indices.add(idx)
                            log.info(f"Koui Editor: Using KouiCanvas for '{canvas_name}'")

                # Temporarily disable handled traits before calling original
                original_enabled = {}
                for idx in handled_indices:
                    original_enabled[idx] = bobject.arm_traitlist[idx].enabled_prop
                    bobject.arm_traitlist[idx].enabled_prop = False

                # Call original for all other traits
                _original_export_trait_code(self, bobject, o)

                # Restore enabled state
                for idx, enabled in original_enabled.items():
                    bobject.arm_traitlist[idx].enabled_prop = enabled

            exporter.ArmoryExporter.export_traits = patched_export_traits
            log.info("Koui Editor: Patched export_traits to support KouiCanvas")
    except Exception as e:
        log.warn(f"Koui Editor: Could not patch exporter: {e}")

    # Patch fetch_script_names to also scan koui_canvas folder
    try:
        global _original_fetch_script_names
        _original_fetch_script_names = arm.utils.fetch_script_names

        def patched_fetch_script_names():
            # Call original first
            _original_fetch_script_names()

            # Also add canvases from koui_canvas folder
            wrd = bpy.data.worlds['Arm']
            koui_canvas_path = arm.utils.get_fp() + '/Bundled/koui_canvas'
            if os.path.isdir(koui_canvas_path):
                for file in glob.glob(os.path.join(koui_canvas_path, '*.json')):
                    name = os.path.basename(file).rsplit('.', 1)[0]
                    # Check if not already in the list
                    if name not in [c.name for c in wrd.arm_canvas_list]:
                        wrd.arm_canvas_list.add().name = name

        arm.utils.fetch_script_names = patched_fetch_script_names
        log.info("Koui Editor: Patched fetch_script_names to scan koui_canvas folder")

        # Refresh the canvas list immediately to pick up koui_canvas files
        try:
            if bpy.data.filepath:  # Only if a project is loaded
                patched_fetch_script_names()
                log.info("Koui Editor: Refreshed canvas list")
        except Exception:
            pass  # May fail if 'Arm' world doesn't exist yet
    except Exception as e:
        log.warn(f"Koui Editor: Could not patch fetch_script_names: {e}")

    log.info("Koui Editor: Registered")


def unregister():
    try:
        ArmEditCanvasButton = pt.ArmEditCanvasButton
    except Exception:
        ArmEditCanvasButton = None

    try:
        ArmNewCanvasDialog = pt.ArmNewCanvasDialog
    except Exception:
        ArmNewCanvasDialog = None

    # Restore Edit Canvas button
    if ArmEditCanvasButton is not None and _original_arm_edit_canvas_execute is not None:
        ArmEditCanvasButton.execute = _original_arm_edit_canvas_execute
        if _original_arm_edit_canvas_label is not None:
            ArmEditCanvasButton.bl_label = _original_arm_edit_canvas_label
        log.info("Koui Editor: Restored ArmEditCanvasButton")

    # Restore New Canvas dialog
    if ArmNewCanvasDialog is not None and _original_arm_new_canvas_execute is not None:
        ArmNewCanvasDialog.execute = _original_arm_new_canvas_execute
        log.info("Koui Editor: Restored ArmNewCanvasDialog")

    # Restore exporter
    try:
        from arm import exporter
        if hasattr(exporter, 'ArmoryExporter') and _original_export_trait_code is not None:
            exporter.ArmoryExporter.export_traits = _original_export_trait_code
            log.info("Koui Editor: Restored export_traits")
    except Exception:
        pass

    # Restore fetch_script_names
    if _original_fetch_script_names is not None:
        arm.utils.fetch_script_names = _original_fetch_script_names
        log.info("Koui Editor: Restored fetch_script_names")

    # Remove load handler
    if on_load_post in bpy.app.handlers.load_post:
        bpy.app.handlers.load_post.remove(on_load_post)

    for cls in reversed(classes):
        try:
            bpy.utils.unregister_class(cls)
        except RuntimeError:
            # Class may already be unregistered during script reload
            pass

import bpy


def write_main():
    if bpy.data.worlds['Arm'].arm_ui == 'Disabled':
        scale_quality = ''
    else:
        scale_quality = '@:privateAccess Koui.g.imageScaleQuality = armory.ui.Canvas.imageScaleQuality; '

    return {
        'imports': 'import koui.Koui;',
        'main_pre': 'iron.App.notifyOnInit(function() { Koui.init(function() { iron.App.notifyOnRender2D(function(g) { g.end(); ' + scale_quality + 'Koui.render(g); g.begin(false); }); }); });',
        'assets': [
            ('Assets/koui_canvas/ui_override.ksn', {'destination': 'data/{name}'})
        ]
    }

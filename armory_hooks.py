def write_main():
    return {
        'imports': 'import koui.Koui;',
        'main_post': 'kha.Assets.loadBlobFromPath("ui_override.ksn", function(_) { Koui.init(function() { iron.App.notifyOnRender2D(function(g) { g.end(); @:privateAccess Koui.g.imageScaleQuality = armory.ui.Canvas.imageScaleQuality; Koui.render(g); g.begin(false); }); }); });',
        'assets': [
            ('Assets/koui_canvas/ui_override.ksn', {'destination': '{name}'})
        ]
    }

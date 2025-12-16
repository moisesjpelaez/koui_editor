def write_main():
    return {
        'imports': 'import koui.Koui;',
        'main_post': 'iron.data.Data.getBlob("ui_override.ksn", function(_) { Koui.init(function() { iron.App.notifyOnRender2D(function(g) { g.end(); Koui.render(g); g.begin(false); }); }); });',
        'assets': [
            'Assets/ui_override.ksn'
        ]
    }

package arm;

import haxe.Json;
import koui.elements.Element;

class CanvasLoader {
    public static function load(jsonString: String): Element {
        var data: Dynamic = Json.parse(jsonString);
        return parseElement(data);
    }

    static function parseElement(data: Dynamic): Element {
        var type = data.type;
        var el: Element = null;
        switch (type) {
            case "AnchorPane":
                el = new koui.elements.layouts.AnchorPane();
                if (Reflect.hasField(data, "children")) {
                    var children:Array<Dynamic> = data.children;
                    for (child in children) {
                        el.addChild(parseElement(child));
                    }
                }
            case "Label":
                var label = new koui.elements.Label();
                if (Reflect.hasField(data, "text")) label.text = data.text;
                el = label;
            case "Button":
                var button = new koui.elements.Button();
                if (Reflect.hasField(data, "text")) button.text = data.text;
                el = button;
            default:
                el = new Element(); // fallback for unknown types
        }
        // Set common properties (x, y, width, height, etc.)
        if (Reflect.hasField(data, "x")) el.x = data.x;
        if (Reflect.hasField(data, "y")) el.y = data.y;
        if (Reflect.hasField(data, "width")) el.width = data.width;
        if (Reflect.hasField(data, "height")) el.height = data.height;
        return el;
    }
}

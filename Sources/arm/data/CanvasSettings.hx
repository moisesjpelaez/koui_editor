package arm.data;

class CanvasSettings {
    public static var expandOnResize: Bool = true;
    public static var scaleOnResize: Bool = true;
    public static var autoScale: Bool = true;
    public static var scaleHorizontal: Bool = false;
    public static var scaleVertical: Bool = false;

    // Editor-only settings
    public static var undoStackSize: Int = 50; // Range: 25-256
}
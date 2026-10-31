package arm.panels;

import arm.data.SceneData;
import arm.editors.ElementRegistry;
import arm.events.ElementEvents;
import arm.base.UIBase;
import arm.CanvasViewport.TScreenRect;
import iron.App;
import zui.Id;
import zui.Zui.Handle;

@:access(zui.Zui)
class ElementsPanel {
	/** One per category: a handle made in the loop would be shared by every category. */
	var categoryHandles: Map<String, Handle> = new Map();
	/** Height of what the panel drew; below it the canvas shows through. */
	var contentHeight: Int = 0;

	public function new() {

	}

	/** The part of the panel drawn over the canvas, in screen pixels. */
	public function getRect(uiBase: UIBase): TScreenRect {
		var window: TScreenRect = getWindowRect(uiBase);
		window.h = Std.int(Math.min(window.h, contentHeight));
		return window;
	}

	static function getWindowRect(uiBase: UIBase): TScreenRect {
		var uiScale: Float = uiBase.ui.SCALE();
		return {
			x: Std.int(10 * uiScale),
			y: Std.int(10 * uiScale),
			w: Std.int(100 * uiScale),
			h: App.h() - uiBase.getBottomH() - Std.int(20 * uiScale)
		};
	}

	public function draw(uiBase: UIBase): Void {
		uiBase.ui.t.FILL_WINDOW_BG = false;
		var rect: TScreenRect = getWindowRect(uiBase);

		if (uiBase.ui.window(Id.handle(), rect.x, rect.y, rect.w, rect.h, false)) {
			for (category in ElementRegistry.categories()) {
				if (!categoryHandles.exists(category)) categoryHandles.set(category, new Handle({selected: true}));
				if (uiBase.ui.panel(categoryHandles.get(category), category)) {
					uiBase.ui.indent();
					for (editor in ElementRegistry.byCategory(category)) {
						if (uiBase.ui.button(editor.displayName)) {
							var element = editor.createDefault(SceneData.data.radioGroups);
							ElementEvents.elementAdded.emit({ key: editor.typeName, element: element });
						}
					}
					uiBase.ui.unindent();
				}
			}
			contentHeight = Std.int(uiBase.ui._y);
		}

		uiBase.ui.t.FILL_WINDOW_BG = true;
	}
}

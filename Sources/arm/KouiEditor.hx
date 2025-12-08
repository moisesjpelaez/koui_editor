package arm;

import kha.graphics2.Graphics;
import koui.Koui;
import koui.elements.Label;

class KouiEditor extends iron.Trait {
	var label: Label;

	public function new() {
		super();

		notifyOnInit(function() {
			Koui.init(function () {
				label = new Label("Hello Koui Editor!");
				label.setPosition(10, 10);
				Koui.add(label);
			});

			notifyOnRender2D(render2D);
			notifyOnRemove(onRemove);
		});
	}

	function render2D(g2: Graphics) {
		g2.end();
		Koui.render(g2);
		g2.begin(false);
	}

	function onRemove() {
		Koui.remove(label);
	}
}

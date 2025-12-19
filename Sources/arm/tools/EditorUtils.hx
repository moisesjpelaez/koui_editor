package arm.tools;

import arm.data.CanvasSettings;
import arm.data.SceneData;
import arm.data.SceneData.TElementEntry;
import arm.data.SceneData.TSceneEntry;
import arm.events.ElementEvents;
import arm.events.SceneEvents;
import arm.tools.CanvasUtils.TElementData;
import arm.tools.ElementUtils;
import arm.tools.HierarchyUtils;
import arm.types.Enums.DropZone;

import koui.elements.Element;
import koui.elements.layouts.AnchorPane;
import koui.elements.layouts.Layout;

enum UndoActionType {
	PropertyChanged;
	ElementAdded;
	ElementRemoved;
	ElementMoved;
	ElementRenamed;
	SceneAdded;
	SceneRemoved;
	SceneRenamed;
	SceneSwitched;
}

typedef TUndoAction = {
	var type: UndoActionType;
	var data: Dynamic;
}

@:access(koui.elements.Element)
class EditorUtils {
	static var undoStack: Array<TUndoAction> = [];
	static var redoStack: Array<TUndoAction> = [];
	static var sceneData: SceneData = SceneData.data;

	// Flag to prevent recording actions during undo/redo operations
	static var isUndoingOrRedoing: Bool = false;

	/**
	 * Initialize the undo/redo system by connecting to all relevant events.
	 */
	public static function init(): Void {
		// Element events
		ElementEvents.propertyChanged.connect(onPropertyChanged);
		ElementEvents.elementAdded.connect(onElementAdded);
		ElementEvents.elementRemoved.connect(onElementRemoved);
		ElementEvents.elementDropped.connect(onElementDropped);
		ElementEvents.elementNameChanged.connect(onElementRenamed);

		// Scene events
		SceneEvents.sceneAdded.connect(onSceneAdded);
		SceneEvents.sceneRemoved.connect(onSceneRemoved);
		SceneEvents.sceneNameChanged.connect(onSceneRenamed);
		SceneEvents.sceneChanged.connect(onSceneChanged);

		// Clear stacks on canvas load/clear
		SceneEvents.canvasLoaded.connect(clearStacks);
	}

	/**
	 * Pushes an action onto the undo stack.
	 */
	static function pushAction(action: TUndoAction): Void {
		if (isUndoingOrRedoing) return;

		undoStack.push(action);
		redoStack = []; // Clear redo stack on new action

		// Enforce stack size limit
		while (undoStack.length > CanvasSettings.undoStackSize) {
			undoStack.shift();
		}
	}

	/**
	 * Performs an undo operation.
	 */
	public static function undo(): Void {
		if (undoStack.length == 0) return;

		isUndoingOrRedoing = true;
		var action: TUndoAction = undoStack.pop();
		applyAction(action, true);
		redoStack.push(action);
		isUndoingOrRedoing = false;
	}

	/**
	 * Performs a redo operation.
	 */
	public static function redo(): Void {
		if (redoStack.length == 0) return;

		isUndoingOrRedoing = true;
		var action: TUndoAction = redoStack.pop();
		applyAction(action, false);
		undoStack.push(action);
		isUndoingOrRedoing = false;
	}

	/**
	 * Clears both undo and redo stacks.
	 */
	public static function clearStacks(): Void {
		undoStack = [];
		redoStack = [];
	}

	/**
	 * Returns true if there are actions to undo.
	 */
	public static function canUndo(): Bool {
		return undoStack.length > 0;
	}

	/**
	 * Returns true if there are actions to redo.
	 */
	public static function canRedo(): Bool {
		return redoStack.length > 0;
	}

	/**
	 * Applies an action (for undo or redo).
	 * @param action The action to apply
	 * @param isUndo True if undoing, false if redoing
	 */
	static function applyAction(action: TUndoAction, isUndo: Bool): Void {
		switch (action.type) {
			case PropertyChanged:
				applyPropertyChange(action.data, isUndo);
			case ElementAdded:
				if (isUndo) removeElement(action.data);
				else restoreElement(action.data);
			case ElementRemoved:
				if (isUndo) restoreElement(action.data);
				else removeElement(action.data);
			case ElementMoved:
				applyElementMove(action.data, isUndo);
			case ElementRenamed:
				applyElementRename(action.data, isUndo);
			case SceneAdded:
				if (isUndo) removeScene(action.data.sceneKey);
				else restoreScene(action.data);
			case SceneRemoved:
				if (isUndo) restoreScene(action.data);
				else removeScene(action.data.sceneKey);
			case SceneRenamed:
				applySceneRename(action.data, isUndo);
			case SceneSwitched:
				applySwitchScene(action.data, isUndo);
		}
	}

	// ========== Property Change ==========

	static function onPropertyChanged(element: Element, property: Dynamic, oldValue: Dynamic, newValue: Dynamic): Void {
		if (isUndoingOrRedoing) return;

		pushAction({
			type: PropertyChanged,
			data: {
				element: element,
				property: property,
				oldValue: oldValue,
				newValue: newValue
			}
		});
	}

	static function applyPropertyChange(data: Dynamic, isUndo: Bool): Void {
		var element: Element = data.element;
		var property: Dynamic = data.property;
		var value: Dynamic = isUndo ? data.oldValue : data.newValue;

		if (element == null) return;

		// Check if it's an array of properties (batch change)
		if (Std.isOfType(property, Array)) {
			var props: Array<String> = cast property;
			var vals: Array<Dynamic> = cast value;
			for (i in 0...props.length) {
				setElementProperty(element, props[i], vals[i]);
			}
		} else {
			setElementProperty(element, cast property, value);
		}

		element.invalidateElem();
		ElementEvents.elementSelected.emit(element);
	}

	static function setElementProperty(element: Element, property: String, value: Dynamic): Void {
		switch (property) {
			case "posX": element.posX = value;
			case "posY": element.posY = value;
			case "width": element.width = value;
			case "height": element.height = value;
			case "visible": element.visible = value;
			case "disabled": element.disabled = value;
			case "anchor": element.anchor = value;
			case "tID", "TID": element.setTID(value);
			case "text":
				if (Std.isOfType(element, koui.elements.Label)) {
					cast(element, koui.elements.Label).text = value;
				} else if (Std.isOfType(element, koui.elements.Button)) {
					cast(element, koui.elements.Button).text = value;
				}
			case "isPressed":
				if (Std.isOfType(element, koui.elements.Button)) {
					cast(element, koui.elements.Button).isPressed = value;
				}
			case "isToggle":
				if (Std.isOfType(element, koui.elements.Button)) {
					cast(element, koui.elements.Button).isToggle = value;
				}
		}
	}

	// ========== Element Add/Remove ==========

	static function onElementAdded(entry: TElementEntry): Void {
		if (isUndoingOrRedoing) return;

		// Capture element data for restoration
		var element: Element = entry.element;
		var parent: Element = element.parent;
		var index: Int = getChildIndex(parent, element);

		pushAction({
			type: ElementAdded,
			data: {
				element: element,
				key: entry.key,
				parent: parent,
				index: index,
				serialized: serializeElementForUndo(element)
			}
		});
	}

	static function onElementRemoved(element: Element): Void {
		if (isUndoingOrRedoing) return;

		// Capture data BEFORE the element is actually removed
		var parent: Element = element.parent;
		var index: Int = getChildIndex(parent, element);
		var key: String = sceneData.getElementKey(element);

		pushAction({
			type: ElementRemoved,
			data: {
				element: element,
				key: key,
				parent: parent,
				index: index,
				serialized: serializeElementForUndo(element)
			}
		});
	}

	static function removeElement(data: Dynamic): Void {
		var element: Element = data.element;
		if (element == null) return;

		// Remove from parent
		HierarchyUtils.detachFromCurrentParent(element);

		// Remove from scene data
		sceneData.onElementRemoved(element);
		ElementEvents.elementSelected.emit(null);
	}

	static function restoreElement(data: Dynamic): Void {
		var element: Element = data.element;
		var parent: Element = data.parent;
		var index: Int = data.index;
		var key: String = data.key;

		if (element == null || parent == null) return;

		// Add back to parent using HierarchyUtils which handles all layout types
		HierarchyUtils.moveAsChild(element, parent);

		// For AnchorPane, try to restore the original index
		if (Std.isOfType(parent, AnchorPane)) {
			moveChildToIndex(parent, element, index);
		}

		// Add back to scene data
		sceneData.onElementAdded({key: key, element: element});
		ElementEvents.elementSelected.emit(element);
	}

	// ========== Element Move (Drag & Drop) ==========

	static function onElementDropped(element: Element, target: Element, zone: Dynamic): Void {
		if (isUndoingOrRedoing) return;

		// Note: This event is emitted BEFORE the move happens, so we capture old state here
		var oldParent: Element = element.parent;
		var oldIndex: Int = getChildIndex(oldParent, element);

		// We need to capture new parent/index after the move completes
		// For now, we'll store target and zone to determine new position
		pushAction({
			type: ElementMoved,
			data: {
				element: element,
				oldParent: oldParent,
				oldIndex: oldIndex,
				target: target,
				zone: zone
			}
		});
	}

	static function applyElementMove(data: Dynamic, isUndo: Bool): Void {
		var element: Element = data.element;
		if (element == null) return;

		if (isUndo) {
			// Move back to old parent at old index
			var oldParent: Element = data.oldParent;
			var oldIndex: Int = data.oldIndex;

			// Use moveAsChild which handles all layout types correctly
			HierarchyUtils.moveAsChild(element, oldParent);

			// For AnchorPane, try to restore the original index
			if (Std.isOfType(oldParent, AnchorPane)) {
				moveChildToIndex(oldParent, element, oldIndex);
			}
		} else {
			// Redo: perform the drop again using HierarchyUtils
			var target: Element = data.target;
			var zone: DropZone = data.zone;

			// Re-apply the move using the same logic as KouiEditor.onElementDropped
			switch (zone) {
				case AsChild:
					HierarchyUtils.moveAsChild(element, target);
				case BeforeSibling:
					HierarchyUtils.moveRelativeToTarget(element, target, true);
				case AfterSibling:
					HierarchyUtils.moveRelativeToTarget(element, target, false);
				case None:
					// Do nothing
			}
		}

		element.invalidateElem();
		ElementEvents.elementSelected.emit(element);
	}

	// ========== Element Rename ==========

	static function onElementRenamed(element: Element, oldName: String, newName: String): Void {
		if (isUndoingOrRedoing) return;

		pushAction({
			type: ElementRenamed,
			data: {
				element: element,
				oldName: oldName,
				newName: newName
			}
		});
	}

	static function applyElementRename(data: Dynamic, isUndo: Bool): Void {
		var element: Element = data.element;
		var name: String = isUndo ? data.oldName : data.newName;

		if (element == null) return;

		sceneData.updateElementKey(element, name);
		ElementEvents.elementSelected.emit(element);
	}

	// ========== Scene Operations ==========

	static var lastSceneKey: String = null;

	static function onSceneAdded(sceneKey: String): Void {
		if (isUndoingOrRedoing) return;

		// Find the scene that was just added
		var scene: TSceneEntry = null;
		for (s in sceneData.scenes) {
			if (s.key == sceneKey) {
				scene = s;
				break;
			}
		}

		pushAction({
			type: SceneAdded,
			data: {
				sceneKey: sceneKey,
				previousSceneKey: lastSceneKey
			}
		});

		lastSceneKey = sceneKey;
	}

	static function onSceneRemoved(sceneKey: String): Void {
		if (isUndoingOrRedoing) return;

		// Capture scene data before removal for restoration
		var scene: TSceneEntry = null;
		for (s in sceneData.scenes) {
			if (s.key == sceneKey) {
				scene = s;
				break;
			}
		}

		if (scene == null) return;

		pushAction({
			type: SceneRemoved,
			data: {
				sceneKey: sceneKey,
				serializedScene: serializeSceneForUndo(scene)
			}
		});
	}

	static function onSceneRenamed(oldKey: String, newKey: String): Void {
		if (isUndoingOrRedoing) return;

		pushAction({
			type: SceneRenamed,
			data: {
				oldKey: oldKey,
				newKey: newKey
			}
		});
	}

	static function onSceneChanged(sceneKey: String): Void {
		if (isUndoingOrRedoing) return;

		var oldSceneKey: String = lastSceneKey;
		if (oldSceneKey == sceneKey) return; // No actual change

		pushAction({
			type: SceneSwitched,
			data: {
				oldSceneKey: oldSceneKey,
				newSceneKey: sceneKey
			}
		});

		lastSceneKey = sceneKey;
	}

	static function removeScene(sceneKey: String): Void {
		// Find and remove the scene
		for (i in 0...sceneData.scenes.length) {
			if (sceneData.scenes[i].key == sceneKey) {
				sceneData.scenes.splice(i, 1);
				break;
			}
		}

		// Switch to another scene if needed
		if (sceneData.scenes.length > 0) {
			sceneData.currentScene = sceneData.scenes[0];
			lastSceneKey = sceneData.currentScene.key;
		}
	}

	static function restoreScene(data: Dynamic): Void {
		var sceneKey: String = data.sceneKey;

		// Check if we have serialized scene data
		if (data.serializedScene != null) {
			// Restore from serialized data
			var serialized: Dynamic = data.serializedScene;
			var root: AnchorPane = new AnchorPane(0, 0, serialized.width, serialized.height);

			var scene: TSceneEntry = {
				key: sceneKey,
				root: root,
				elements: [],
				active: false
			};

			sceneData.scenes.push(scene);
			sceneData.currentScene = scene;

			// Restore elements
			if (serialized.elements != null) {
				var elements: Array<Dynamic> = serialized.elements;
				for (elemData in elements) {
					var element: Element = ElementUtils.createElement(
						elemData.type,
						elemData.posX,
						elemData.posY,
						elemData.width,
						elemData.height,
						elemData.anchor,
						elemData.visible,
						elemData.disabled,
						elemData.tID,
						elemData.properties
					);
					if (element != null) {
						root.add(element, element.anchor);
						scene.elements.push({key: elemData.key, element: element});
					}
				}
			}
		} else {
			// Just create an empty scene
			var root: AnchorPane = new AnchorPane(0, 0, 800, 600);
			var scene: TSceneEntry = {
				key: sceneKey,
				root: root,
				elements: [],
				active: false
			};
			sceneData.scenes.push(scene);
			sceneData.currentScene = scene;
		}

		lastSceneKey = sceneKey;
	}

	static function applySceneRename(data: Dynamic, isUndo: Bool): Void {
		var oldKey: String = isUndo ? data.newKey : data.oldKey;
		var newKey: String = isUndo ? data.oldKey : data.newKey;

		for (scene in sceneData.scenes) {
			if (scene.key == oldKey) {
				scene.key = newKey;
				break;
			}
		}

		if (lastSceneKey == oldKey) {
			lastSceneKey = newKey;
		}
	}

	static function applySwitchScene(data: Dynamic, isUndo: Bool): Void {
		var targetKey: String = isUndo ? data.oldSceneKey : data.newSceneKey;

		for (scene in sceneData.scenes) {
			if (scene.key == targetKey) {
				sceneData.currentScene = scene;
				lastSceneKey = targetKey;
				break;
			}
		}

		ElementEvents.elementSelected.emit(null);
	}

	// ========== Helper Functions ==========

	static function getChildIndex(parent: Element, child: Element): Int {
		var children: Array<Element> = HierarchyUtils.getChildren(parent);
		if (children == null) return 0;

		for (i in 0...children.length) {
			if (children[i] == child) return i;
		}
		return 0;
	}

	static function moveChildToIndex(parent: Element, child: Element, targetIndex: Int): Void {
		var children: Array<Element> = HierarchyUtils.getChildren(parent);
		if (children == null) return;

		// Find current index
		var currentIndex: Int = -1;
		for (i in 0...children.length) {
			if (children[i] == child) {
				currentIndex = i;
				break;
			}
		}

		if (currentIndex == -1 || currentIndex == targetIndex) return;

		// Remove and reinsert at target index
		children.splice(currentIndex, 1);
		if (targetIndex >= children.length) {
			children.push(child);
		} else {
			children.insert(targetIndex, child);
		}
	}

	static function serializeElementForUndo(element: Element): Dynamic {
		var type: String = ElementUtils.getElementType(element);
		return {
			type: type,
			key: sceneData.getElementKey(element),
			posX: element.posX,
			posY: element.posY,
			width: element.width,
			height: element.height,
			anchor: element.anchor,
			visible: element.visible,
			disabled: element.disabled,
			tID: element.getTID(),
			properties: ElementUtils.serializeProperties(element, type)
		};
	}

	static function serializeSceneForUndo(scene: TSceneEntry): Dynamic {
		var elements: Array<Dynamic> = [];
		for (entry in scene.elements) {
			elements.push(serializeElementForUndo(entry.element));
		}

		return {
			key: scene.key,
			width: scene.root.width,
			height: scene.root.height,
			elements: elements
		};
	}

	static function applySerializedProperties(element: Element, data: Dynamic): Void {
		element.posX = data.posX;
		element.posY = data.posY;
		element.width = data.width;
		element.height = data.height;
		element.anchor = data.anchor;
		element.visible = data.visible;
		element.disabled = data.disabled;

		if (data.tID != null && data.tID != "") {
			element.setTID(data.tID);
		}

		// Apply type-specific properties
		if (data.properties != null) {
			if (Std.isOfType(element, koui.elements.Label) && data.properties.text != null) {
				cast(element, koui.elements.Label).text = data.properties.text;
			} else if (Std.isOfType(element, koui.elements.Button)) {
				var btn: koui.elements.Button = cast element;
				if (data.properties.text != null) btn.text = data.properties.text;
				if (data.properties.isToggle != null) btn.isToggle = data.properties.isToggle;
				if (data.properties.isPressed != null) btn.isPressed = data.properties.isPressed;
			}
		}
	}
}

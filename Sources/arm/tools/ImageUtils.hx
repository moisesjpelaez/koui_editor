package arm.tools;

import kha.graphics4.BlendingFactor;
import kha.graphics4.PipelineState;
import kha.graphics4.VertexStructure;
import kha.graphics4.VertexData;
import kha.Image;
import kha.Shaders;
import zui.Zui;
import zui.Zui.State;

/**
 * Utility class for rendering images with proper alpha blending.
 *
 * The default Kha pipeline uses BlendOne which causes transparent areas
 * to show incorrectly. This class provides a pipeline with SourceAlpha
 * blending for proper transparency handling.
 */
class ImageUtils {
	static var alphaPipeline: PipelineState = null;

	/**
	 * Initialize the alpha-blended pipeline. Called automatically on first use.
	 */
	public static function init(): Void {
		if (alphaPipeline != null) return;

		var structure: VertexStructure = new VertexStructure();
		structure.add("vertexPosition", VertexData.Float32_3X);
		structure.add("vertexUV", VertexData.Float32_2X);
		structure.add("vertexColor", VertexData.UInt8_4X_Normalized);

		alphaPipeline = new PipelineState();
		alphaPipeline.fragmentShader = Shaders.painter_image_frag;
		alphaPipeline.vertexShader = Shaders.painter_image_vert;
		alphaPipeline.inputLayout = [structure];
		// Use SourceAlpha blending for proper alpha transparency
		alphaPipeline.blendSource = BlendingFactor.SourceAlpha;
		alphaPipeline.blendDestination = BlendingFactor.InverseSourceAlpha;
		alphaPipeline.alphaBlendSource = BlendingFactor.SourceAlpha;
		alphaPipeline.alphaBlendDestination = BlendingFactor.InverseSourceAlpha;
		alphaPipeline.compile();
	}

	/**
	 * Get the alpha-blended pipeline for manual use.
	 */
	public static function getPipeline(): PipelineState {
		init();
		return alphaPipeline;
	}

	/**
	 * Draw an image with proper alpha blending using Zui.
	 * Automatically sets and restores the pipeline.
	 */
	public static function image(ui: Zui, image: Image, tint: Int = 0xffffffff, h: Null<Float> = null,
			sx: Int = 0, sy: Int = 0, sw: Int = 0, sh: Int = 0): State {
		init();
		ui.g.pipeline = alphaPipeline;
		var result = ui.image(image, tint, h, sx, sy, sw, sh);
		ui.g.pipeline = null;
		return result;
	}

	/**
	 * Helper to get a tile rectangle from a 50x50 icon atlas.
	 */
	public static inline function tile50(x: Int, y: Int): {x: Int, y: Int, w: Int, h: Int} {
		return { x: x * 50, y: y * 50, w: 50, h: 50 };
	}

	/**
	 * Helper to get a tile rectangle from a 100x100 icon atlas (2x scale).
	 */
	public static inline function tile100(x: Int, y: Int): {x: Int, y: Int, w: Int, h: Int} {
		return { x: x * 100, y: y * 100, w: 100, h: 100 };
	}
}

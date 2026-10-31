package arm.tools;

import kha.graphics4.BlendingFactor;
import kha.graphics4.PipelineState;
import kha.graphics4.VertexStructure;
import kha.graphics4.VertexData;
import kha.Shaders;

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
	static function init(): Void {
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
	 * Helper to get a tile rectangle from an atlas.
	 */
	public static inline function tile(x: Int, y: Int, ?size: Int = 50): TTileRect {
		return { x: x * size, y: y * size, w: size, h: size };
	}
}

typedef TTileRect = {
	var x: Int;
	var y: Int;
	var w: Int;
	var h: Int;
};

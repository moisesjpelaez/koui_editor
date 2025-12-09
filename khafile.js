// Standalone Koui Editor - for launching from Blender
let project = new Project('koui_editor');

// Use standalone main entry point
project.addSources('Sources');
project.addLibrary("C:/game-development/armory3d/armory/armory");
project.addLibrary("C:/game-development/armory3d/armory/iron");
await project.addProject("Subprojects/Koui");

// Main entry point
project.addParameter('Main');
project.addParameter("--macro keep('Main')");
project.addParameter('arm.KouiEditor');
project.addParameter("--macro keep('arm.KouiEditor')");
project.addParameter('armory.trait.internal.UniformsManager');
project.addParameter("--macro keep('armory.trait.internal.UniformsManager')");

// Shaders and assets from Armory
project.addLibrary("C:/game-development/armory3d/armory/lib/zui");
project.addAssets("C:/game-development/armory3d/armory/armory/Assets/font_default.ttf", { notinlist: false });
project.addAssets("C:/game-development/armory3d/armory/armory/Assets/brdf.png", { notinlist: true });

// Render path defines
project.addDefine('arm_hosek');
project.addDefine('arm_csm');
project.addDefine('arm_brdf');
project.addDefine('rp_hdr');
project.addDefine('rp_renderer=Forward');
project.addDefine('rp_shadowmap');
project.addDefine('rp_shadowmap_cascade=2048');
project.addDefine('rp_shadowmap_cube=512');
project.addDefine('rp_background=World');
project.addDefine('rp_render_to_texture');
project.addDefine('rp_compositornodes');
project.addDefine('rp_antialiasing=SMAA');
project.addDefine('rp_supersampling=1');
project.addDefine('rp_ssgi=Off');
project.addDefine('rp_bloom');
project.addDefine('rp_translucency');

// General defines
project.addDefine('js-es=6');
project.addDefine('arm_assert_level=Warning');
project.addDefine('arm_ui');
project.addDefine('arm_skin');
project.addDefine('arm_particles');
project.addDefine('arm_resizable');
project.addDefine('armory');

// Standalone mode flag
project.addDefine('koui_standalone');

// Assets
project.addAssets("Assets/ui_override.ksn");

resolve(project);

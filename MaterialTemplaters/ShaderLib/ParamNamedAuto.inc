#ifndef _ParamNamedAuto_INC_
#define _ParamNamedAuto_INC_

/// max foward light number
#ifndef MAX_LIGHT_NUM
#define MAX_LIGHT_NUM 3
#endif

/// max hardware skin bone number
#ifndef MAX_SKIN_BONE_NUM
#define MAX_SKIN_BONE_NUM 74
#endif
// 四元数骨骼最大数量
#ifndef MAX_QUAT_SKIN_BONE_NUM
#define MAX_QUAT_SKIN_BONE_NUM 105
#endif

uniform float4x4 world_matrix;											// ACT_WORLD_MATRIX
uniform float4x4 inverse_world_matrix;							// ACT_INVERSE_WORLD_MATRIX
uniform float4x4 inverse_world_matrix_3x4;					// ACT_INVERSE_WORLD_MATRIX_3x4
uniform float4x4 transpose_world_matrix;						// ACT_TRANSPOSE_WORLD_MATRIX
uniform float4x4 inverse_transpose_world_matrix;		// ACT_INVERSE_TRANSPOSE_WORLD_MATRIX
uniform float4x4 world_matrix_array[MAX_SKIN_BONE_NUM];								// ACT_WORLD_MATRIX_ARRAY	
uniform float3x4 world_matrix_array_3x4[MAX_SKIN_BONE_NUM]; // ACT_WORLD_MATRIX_ARRAY_3x4;
uniform float2x4 dual_quaternion_array_2x4[MAX_QUAT_SKIN_BONE_NUM]; // ACT_DUAL_QUATERNION_ARRAY_2x4;

uniform float4x4 view_matrix;												// ACT_VIEW_MATRIX
uniform float4x4 inverse_view_matrix;								// ACT_INVERSE_VIEW_MATRIX
uniform float4x4 inverse_view_matrix_3x4;						// ACT_INVERSE_VIEW_MATRIX_3x4
uniform float4x4 transpose_view_matrix;							// ACT_TRANSPOSE_VIEW_MATRIX
uniform float4x4 inverse_transpose_view_matrix;			// ACT_INVERSE_TRANSPOSE_VIEW_MATRIX

uniform float4x4 projection_matrix;									// ACT_PROJECTION_MATRIX
uniform float4x4 inverse_projection_matrix;					// ACT_INVERSE_PROJECTION_MATRIX
uniform float4x4 transpose_projection_matrix;				// ACT_TRANSPOSE_PROJECTION_MATRIX
uniform float4x4 inverse_transpose_projection_matrix;		// ACT_INVERSE_TRANSPOSE_PROJECTION_MATRIX

uniform float4x4 viewproj_matrix;							// ACT_VIEWPROJ_MATRIX
uniform float4x4 inverse_viewproj_matrix;			// ACT_INVERSE_VIEWPROJE_MATRIX
uniform float4x4 transpose_viewproj_matrix;		// ACT_TRANSPOSE_VIEWPROJ_MATRIX
uniform float4x4 inverse_transpose_viewproj_matrix;// ACT_INVERSE_TRANSPOSE_VIEWPROJ_MATRIX

uniform float4x4 worldview_matrix;									// ACT_WORLDVIEW_MATRIX
uniform float4x4 inverse_worldview_matrix;					// ACT_INVERSE_WORLDVIEW_MATRIX
uniform float4x4 inverse_worldview_matrix_3x4;			// ACT_INVERSE_WORLDVIEW_MATRIX_3x4
uniform float4x4 transpose_worldview_matrix;				// ACT_TRANSPOSE_WORLDVIEW_MATRIX
uniform float4x4 inverse_transpose_worldview_matrix;		// ACT_INVERSE_TRANSPOSE_WORLDVIEW_MATRIX


uniform float4x4 worldviewproj_matrix;						// ACT_WORLDVIEWPROJ_MATRIX
uniform float4x4 inverse_worldviewrojection_matrix;			// ACT_INVERSE_WORLDVIEWROJECTION_MATRIX
uniform float4x4 transpose_worldviewrojection_matrix;		// ACT_TRANSPOSE_WORLDVIEWROJECTION_MATRIX
uniform float4x4 inverse_transpose_worldviewrojection_matrix;	// ACT_INVERSE_TRANSPOSE_WORLDVIEWROJECTION_MATRIX

uniform float4x4 cliptoworld_matrix; //ACT_CLIPTOWORLD_MATRIX

uniform float3 camera_position;										// ACT_CAMERA_POSITION
uniform float3 camera_position_object_space;	// ACT_CAMERA_POSITION_OBJECT_SPACE

uniform float4 viewport_size;  // ACT_VIEWPORT_SIZE
uniform float3 view_direction; // ACT_VIEW_DIRECTION

// surface color
uniform float4 surface_ambient_colour; // ACT_SURFACE_AMBIENT_COLOUR
uniform float4 surface_diffuse_colour; // ACT_SURFACE_DIFFUSE_COLOUR
uniform float4 surface_specular_colour;	// ACT_SURFACE_SPECULAR_COLOUR
uniform float surface_shininess; // ACT_SURFACE_SHININESS
uniform float4 surface_emissive_colour; // ACT_SURFACE_EMISSIVE_COLOUR


uniform float4 derived_scene_colour; // ACT_DERIVED_SCENE_COLOUR
uniform float4 derived_ambient_light_colour; // ACT_DERIVED_AMBIENT_LIGHT_COLOUR
uniform float4 derived_pbr_scene_colour; // ACT_DERIVED_PBR_SCENE_COLOUR

// actor
uniform float4 actor_ambient_params; // ACT_LIGHT_AMBIENT_PARAMS
uniform float4 actor_lightone_params; // ACT_LIGHT_ONE_PARAMS
uniform float4 actor_lighttwo_params; // ACT_LIGHT_TWO_PARAMS

// light
uniform float light_count;
uniform float4 ambient_light_colour; // ACT_AMBIENT_LIGHT_COLOUR
uniform float4 light_position_array[MAX_LIGHT_NUM]; // ACT_LIGHT_POSITION_ARRAY
uniform float4 light_position_view_space_array[MAX_LIGHT_NUM]; // ACT_LIGHT_POSITION_VIEW_SPACE_ARRAY
uniform float4 light_attenuation_array[MAX_LIGHT_NUM]; // ACT_LIGHT_ATTENUATION_ARRAY

uniform float4 light_specular_colour_array[MAX_LIGHT_NUM]; // ACT_LIGHT_SPECULAR_COLOUR_ARRAY
uniform float4 light_diffuse_colour_array[MAX_LIGHT_NUM]; // ACT_LIGHT_DIFFUSE_COLOUR_ARRAY
uniform float4 derived_light_diffuse_colour_array[MAX_LIGHT_NUM]; // ACT_DERIVED_LIGHT_DIFFUSE_COLOUR_ARRAY

uniform float4 light_position0; // ACT_LIGHT_POSITION
uniform float4 light_specular_colour0; // ACT_LIGHT_SPECULAR_COLOUR

uniform float4 light_direction0; // ACT_LIGHT_DIRECTION
uniform float4 light_diffuse_colour0; // ACT_LIGHT_DIFFUSE_COLOUR

// shadow
uniform float4x4 shadow_view_matrix; // ACT_SHADOW_VIEW_MATRIX
uniform float4x4 shadow_proj_matrix; // ACT_SHADOW_PROJ_MATRIX
uniform float4x4 shadow_viewproj_matrix; // ACT_SHADOW_VIEWPROJ_MATRIX
uniform float4 shadow_param; // ACT_SHADOW_PARAMS
uniform float4 shadow_csm_param; // ACT_SHADOW_CSM_PARAMS
uniform row_major float4x4 shadow_csm_proj_scale; // ACT_SHADOW_CSM_PROJ_SCALE
uniform row_major float4x4 shadow_csm_proj_offset; // ACT_SHADOW_CSM_PROJ_OFFSET

uniform float4 fog_colour; // ACT_FOG_COLOUR
uniform float4 fog_params; // ACT_FOG_PARAMS;
uniform float4 fog_type;

uniform float4 inverse_texture_size;

uniform float time;
uniform float time_0_x;
uniform float time_0_1;

uniform float near_clip_distance; // ACT_NEAR_CLIP_DISTANCE
uniform float far_clip_distance; // ACT_FAR_CLIP_DISTANCE

uniform float2x4 texture_matrix_2x4_0; // ACT_TEXTURE_MATRIX
uniform float2x4 texture_matrix_2x4_1; // ACT_TEXTURE_MATRIX

// x: hdr
// y: is linear color space
//uniform float4 isystem_userdata = float4(0, 0, 0, 0);
uniform float4 isystem_userdata;

// x: model or actor
// y: bone weight 
// z: alpha test value 
//uniform float4 imodel_userdata = float4(0, 0, 0, 0);
uniform float4 imodel_userdata;

// x: wind dir X
// y: wind dir Z
// z: wind strength
uniform float4 wind_control_params = float4(1, 0, 16, 0);

#ifndef PER_ALPHA
#define PER_ALPHA 0
#endif

#endif
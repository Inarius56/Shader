#ifndef _Water_VS_H_
#define _Water_VS_H_

// Define In VS
#define __VS__

#include "WaterDef.inc"

VS_OUT main( VS_IN IN )
{
	VS_OUT OUT = (VS_OUT)0;
	
	OUT.oPos = mul(worldviewproj_matrix, IN.position);
	OUT.oPosInView = mul(worldview_matrix, IN.position);
	float4x4 scalemat = float4x4(0.5,   0,   0, 0.5, 
	                              0,-0.5,   0, 0.5,
								   							0,   0, 0.5, 0.5,
								   							0,   0,   0,   1);
	OUT.oUVScreen = mul(scalemat, OUT.oPos);
	OUT.oEyeDir = camera_position_object_space - IN.position.xyz;
	OUT.oCamFrontDir = mul(world_matrix, view_direction);
	
	OUT.oUV = IN.uv0.xyxy;

	OUT.oSpecColor = float4(0.0,0.0,0.0,0.0);
	OUT.oColor = float4(1.0,1.0,1.0,1.0);

#if CALC_LIT == 1
	OUT.oSpecColor = float4(0.0,0.0,0.0,0.0);
	OUT.oColor = surface_emissive_colour;
	OUT.oColor += derived_ambient_light_colour;
	//calc lit 
	float3 N = normalize(mul(IN.normal, world_matrix).xyz);
	float3 V = normalize(OUT.oEyeDir);
	for(int l = 0; l < 2 ; ++l)
	{
		float3 L = normalize(light_position_array[l].xyz);
		float NdotL = dot(N,L);
		OUT.oColor += max(NdotL,0) * light_diffuse_colour_array[l]* surface_diffuse_colour;

		float3 H = normalize(V + L);
		float HdotN = dot(H,N);
		OUT.oSpecColor += pow(max(HdotN,0), surface_shininess) * light_specular_colour_array[l] * surface_specular_colour;
	}
#endif
	
	return OUT;
}

#endif



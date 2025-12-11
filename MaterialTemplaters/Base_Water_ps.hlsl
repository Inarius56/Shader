#ifndef _Base_Water_PS_H_
#define _Base_Water_PS_H_

// Define In PS
#define __PS__

uniform sampler2D baseTexture : register(s0);
uniform sampler2D depthMap : register(s1);
uniform float2 heightParams;

#include "WaterDef.inc"

PS_OUT main( VS_OUT IN )
{
	PS_OUT OUT = (PS_OUT)0;
	// cal screen uv
	float2 originUV = IN.oUVScreen.xy / IN.oUVScreen.w;
#ifdef D3D11
	float2 texelCenter = originUV.xy + viewport_size.zw * 1e-5f;
#else
	float2 texelCenter = ((originUV.xy * viewport_size.xy) + float2(0.5, 0.5)) * viewport_size.zw;
#endif

	float sceneDepth = tex2D(depthMap, texelCenter.xy).x;
#if USE_DSINTZ == 1
	sceneDepth = DeviceDepthToEyeLinear(sceneDepth, near_clip_distance, far_clip_distance );
#endif
	float volumeDepth = min( -IN.oPosInView.z - sceneDepth - heightParams.y, 0 );
	float waterVolumeFog = 1.0 - exp(volumeDepth*0.1*heightParams.x);
	
	// Final colour
	float4 texColor = tex2D(baseTexture, IN.oUV);
	OUT.color = IN.oColor * texColor + IN.oSpecColor;
	
	OUT.color.w = waterVolumeFog;

	// fog
	Calc_Fog_Color(-IN.oPosInView.z, OUT.color.xyz);
	return OUT;
}

#endif
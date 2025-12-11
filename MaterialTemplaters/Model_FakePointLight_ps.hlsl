#ifndef _Model_FakePointLight_PS_H_
#define _Model_FakePointLight_PS_H_

// Define In PS
#define __PS__

uniform sampler2D depthMap : register(s0);

uniform float4 lightParams;											
uniform float globalIntensity;

#include "FakePointLightDef.inc"


PS_OUT main( VS_OUT IN )
{
	PS_OUT OUT = (PS_OUT)0;
	// cal screen uv
	float2 originUV = IN.oUVScreen.xy / IN.oUVScreen.w;
	float2 texelCenter = (originUV.xy * viewport_size.xy) + float2(0.5, 0.5);

	float sceneDepth = tex2D(depthMap, texelCenter.xy * viewport_size.zw).x;
#if USE_DSINTZ
  sceneDepth = DeviceDepthToEyeLinear(sceneDepth, near_clip_distance, far_clip_distance );
#endif
	float sceneDepth01 = sceneDepth/far_clip_distance;
	
	float3 r = IN.oRay * far_clip_distance / abs(IN.oRay.z);
	float4 vPos = float4(r * sceneDepth01, 1.0);
	float3 oPos = mul(inverse_worldview_matrix_3x4, vPos);
	oPos *= 0.01;
	
	clip(float3(0.5, 0.5, 0.5) - abs(oPos.xyz));

	float2 uv0 = oPos.xy + 0.5;
	float2 uv1 = oPos.xz + 0.5;
	float2 uv2 = oPos.yz + 0.5;
	
	float col = 1.0;
	col *= saturate(lightParams.w - distance(float2(0.5, 0.5), uv0) * 3);
	col *= saturate(lightParams.w - distance(float2(0.5, 0.5), uv1) * 3);
	col *= saturate(lightParams.w - distance(float2(0.5, 0.5), uv2) * 3);
	
	OUT.color.xyz = lightParams.xyz * col * globalIntensity;
	OUT.color.w = 1;

	//Calc_Fog_Color( sceneDepth, OUT.color.rgb );

	return OUT;
}

#endif





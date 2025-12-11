#ifndef USE_DSINTZ
    #define USE_DSINTZ          0
#endif

//--------------------------------------------------------------------------------------
/// LinearizeDepthPS
//--------------------------------------------------------------------------------------
float DeviceDepthToEyeLinear(float fDepth, float nearZ, float farZ)
{
	float x = (nearZ - farZ) / (farZ * nearZ);
	float y = 1.0 / nearZ;
	return 1.0 / (x * fDepth + y);
}

struct VS_OUTPUT {
   float4 Pos: POSITION;
   float4 oTexCoord: TEXCOORD0;
   float3 oRay : TEXCOORD1;
};

sampler2D sceneTex				 : register(s0);
sampler2D depthMap       : register(s1);


/** FogDensity in x, FogHeight in y, FogHeightFalloff in z, FogPowFactor in w. */
float4 HFogParams;
/** FogDensity in x, FogHeightFalloff in y, FogStartDistance in z. */
float4 DFogParams;
float4 FogColorParams;
float4 DirectionalInscatteringColor;

uniform float4 cTargetSize;
uniform float4 light_direction0;
uniform float3 vfViewPos;
uniform float near_clip_distance;
uniform float far_clip_distance;





//===================================================================================
float4 main(VS_OUTPUT IN) : COLOR0
{
	float2 originUV = IN.oTexCoord.xy / IN.oTexCoord.w;
#ifdef D3D11
	float2 texelCenter = originUV + cTargetSize.zw * 1e-5f;
#else
	float2 texelCenter = ((originUV.xy * cTargetSize.xy) + float2(0.5, 0.5)) * cTargetSize.zw;
#endif

	float sceneDepth = tex2D(depthMap, texelCenter.xy).x;
#if USE_DSINTZ == 1
  sceneDepth = DeviceDepthToEyeLinear(sceneDepth, near_clip_distance, far_clip_distance );
#endif
	//float sceneDepth01 = sceneDepth/far_clip_distance;

	float4 sceneColor = tex2D(sceneTex, texelCenter);
	//if (sceneDepth01 < 0.95)
	{
	
	// 世界空间下到摄像机到物体向量（只记录方向）
	float3 CameraToReceiver = sceneDepth * IN.oRay.xyz;
	float3 worldPos = CameraToReceiver + vfViewPos;
	
	float posHeight = worldPos.y;
	float rayLength = sqrt(dot(CameraToReceiver, CameraToReceiver));
	
	// height dir
	float hHeight = max(0.0, (posHeight - HFogParams.y));
	float hFogFactor = HFogParams.x * exp(-HFogParams.z/1000 * hHeight);
	hFogFactor = pow(hFogFactor, HFogParams.w);
	
	// depth dir
	float rayRealLength = max(0.0, rayLength - DFogParams.z);
	float dFogFactor = 1-( DFogParams.x * exp(-DFogParams.y/1000 * rayRealLength) );


	// Inscattering factor
	float3 CameraToReceiverNorm = normalize(-CameraToReceiver);
	float inscatterFactor = saturate(dot(CameraToReceiverNorm, light_direction0.xyz));
	inscatterFactor = pow(inscatterFactor,DirectionalInscatteringColor.w);
	//float3 inscatterColor = DirectionalInscatteringColor.rgb * inscatterFactor;

	float3 fogFinalColor = lerp(FogColorParams.rgb, DirectionalInscatteringColor.rgb, inscatterFactor);
	fogFinalColor = saturate(fogFinalColor);
	
  
  //sceneColor.rgb = lerp(sceneColor.rgb, saturate(FogColorParams.rgb + inscatterColor), hFogFactor *dFogFactor);
  sceneColor.rgb = lerp(sceneColor.rgb, fogFinalColor, hFogFactor *dFogFactor);
  }
  
  
  return sceneColor;
}


#ifndef USE_DSINTZ
    #define USE_DSINTZ          0
#endif

#ifndef USE_MIRROR
    #define USE_MIRROR          0
#endif

////////////////////////////////////////////////////////////////////////
// LinearizeDepthPS
////////////////////////////////////////////////////////////////////////
float DeviceDepthToEyeLinear(float fDepth, float nearZ, float farZ)
{
	float x = (nearZ - farZ) / (farZ * nearZ);
	float y = 1.0 / nearZ;
	return 1.0 / (x * fDepth + y);
}

float Fogging(float depthInView, float4 fogType, float4 fogParam)
{
		float fogFactor = 0.0;
		fogFactor += fogType[0];
		fogFactor += fogType[1] * exp(- depthInView * fogParam.x);
		fogFactor += fogType[2] * exp(- (depthInView * fogParam.x) * (depthInView * fogParam.x));
		fogFactor += fogType[3] * saturate((fogParam.z - depthInView) * fogParam.w);
		
		return fogFactor;
}

////////////////////////////////////////////////////////////////////////
// render fog under water
////////////////////////////////////////////////////////////////////////
void WaterFog_VS(
		float4 position	: POSITION,

		uniform float4x4 worldMatrix,
		uniform float4x4 worldViewProjMatrix,
		uniform float4 eyePosition,
		uniform float4 camFrontDir,

		out float4 oPos : POSITION,
		out float4 oUV : TEXCOORD0,
		out float4 oEyeDir : TEXCOORD1,
		out float4 oCamFrontDir : TEXCOORD2)
{
	oPos = mul(worldViewProjMatrix, position);
	float4x4 scalemat = float4x4(0.5,   0,   0, 0.5, 
	                              0,-0.5,   0, 0.5,
								   							0,   0, 0.5, 0.5,
								   							0,   0,   0,   1);
	oUV = mul(scalemat, oPos);
	oEyeDir = eyePosition - position;
	oCamFrontDir = mul(worldMatrix, camFrontDir);
}

void WaterFog_PS(float4 pos : POSITION,
		float4 UV : TEXCOORD0,
		float4 eyeDir : TEXCOORD1,
		float4 camFrontDir : TEXCOORD2,
		uniform sampler2D depthMap : register(s0),
		
		uniform float4 FogColorDensity,
		#if USE_DSINTZ
    	uniform float near_clip_distance,
			uniform float far_clip_distance,
    #endif    
    uniform float4 viewport_size,          
		out float4 oColor	: COLOR)
{
	// cal screen uv
	float2 originUV = UV.xy / UV.w;
	//camFrontDir = normalize(camFrontDir);
	
	float2 texelCenter = (originUV.xy * viewport_size.xy) + float2(0.5, 0.5);

	//float sceneDepth = tex2D(depthMap, originUV.xy).x;
	float sceneDepth = tex2D(depthMap, texelCenter.xy * viewport_size.zw).x;
#if USE_DSINTZ
  sceneDepth = DeviceDepthToEyeLinear(sceneDepth, near_clip_distance, far_clip_distance );
#endif
	float volumeDepth = min( dot( eyeDir, -camFrontDir ) - sceneDepth, 0 );
  //float waterVolumeFog = exp2( -FogColorDensity.w * volumeDepth / dot( normalize( eyeDir ), -camFrontDir ) );
	//float waterVolumeFog = saturate(volumeDepth * DepthLimintInv);
	
	float waterVolumeFog = 1.0 - exp(volumeDepth* FogColorDensity.w*0.00001);
	//oColor.xyz = (1.0 - (depth - 1.0) * (depth - 1.0)) * FogColorDensity.xyz * FogColorDensity.w;
	oColor.xyz = FogColorDensity.xyz;
	oColor.w = waterVolumeFog;
}



////////////////////////////////////////////////////////////////////////
// render surface of water
////////////////////////////////////////////////////////////////////////
void WaterReflectionReraction_VS(
		float4 position			: POSITION,
		float4 normal		: NORMAL,
		float2 tex			: TEXCOORD0,
		float tex_depth			: TEXCOORD1,

		out float4 oPos	: POSITION,
    		out float4 oUV		: TEXCOORD0,
		out float3 oEyeDir : TEXCOORD1,
		out float4 oWave0 : TEXCOORD2,
		out float4 oWave1 : TEXCOORD3,
		out float4 oPosInView : TEXCOORD4,
		
		uniform float4x4 worldViewProjMatrix,
		uniform float4x4 worldview_matrix,
		uniform float3 eyePosition,
		uniform float timeVal,
		uniform float wavesSpeed)
{
	oPos = mul(worldViewProjMatrix, position);
	oPosInView = mul(worldview_matrix, position);
	
	// cal wave UV
	float2 vTranslation= float2(0, timeVal * wavesSpeed);
  
	float4 vTex = float4( tex.xy, 0, 1 );
	oWave0.xy = vTex.xy*2*1.0 + vTranslation*2.0;
  	oWave0.wz = vTex.xy*1.0 + vTranslation*3.0;
  	oWave1.xy = vTex.xy*2*2.0 + vTranslation*2.0;
  	oWave1.wz = vTex.xy*2*4.0 + vTranslation*3.0;
	
	oEyeDir = eyePosition - position.xyz;
	
	float4x4 scalemat = float4x4(0.5, 0, 0, 0.5, 0,-0.5, 0, 0.5, 0, 0, 0.5, 0.5, 0, 0, 0, 1);
	oUV = mul(scalemat, oPos);
	oUV.z = tex_depth;
}


void WaterReflectionReraction_PS(float4 pos : POSITION,
   		float4 UV	: TEXCOORD0,
		float3 eyeDir	: TEXCOORD1,
		float4 wave0	: TEXCOORD2,
		float4 wave1	: TEXCOORD3,
		float4 posInView: TEXCOORD4,

		out float4 oColour	: COLOR,
		
		uniform sampler2D noiseMap : register(s0),
#if USE_MIRROR
		uniform sampler2D reflectMap : register(s1),
#else
		uniform samplerCUBE reflectMap : register(s1),
#endif
		uniform sampler2D refractMap : register(s2),
		//uniform sampler1D depthMap : register(s3),
		
		uniform float3 SunLightDir,
		uniform float4 SunColor,
		
		uniform float BigWavesScale,
		uniform float SmallWavesScale,
		uniform float2 BumpScale,
#if USE_MIRROR == 0
		uniform float ReflectionAmount,
#endif
		uniform float TransparencyRatio,
		uniform float SunShinePow,
		uniform float SunMultiplier,
		uniform float FresnelBias,
		uniform float2 UVScale,

		uniform float4 fog_type,
		uniform float4 fog_params,
		uniform float4 fog_colour
		)
{
	eyeDir = normalize(eyeDir);
	// cal screen uv
	float2 originUV = UV.xy / UV.w;

	// depth uv for 1d texture
	float UVDepth = saturate(UV.z*10);
	
	// cal normal
	float3 bumpColorA = half3(0,1,0);
  	float3 bumpColorB = half3(0,1,0);
  	float3 bumpColorC = half3(0,1,0);
  	float3 bumpColorD = half3(0,1,0);
  	float3 bumpLowFreq = half3(0,1,0);
  	float3 bumpHighFreq = half3(0,1,0);
    
  	// merge big waves
  	bumpColorA.xz = tex2D(noiseMap, wave0.xy*UVScale).xy;           
  	bumpColorB.xz = tex2D(noiseMap, wave0.wz*UVScale).xy;           
  	bumpLowFreq.xz = (bumpColorA.xz + bumpColorB.xz)*BigWavesScale - BigWavesScale;

  	// merge small waves
  	bumpColorC.xz = tex2D(noiseMap, wave1.xy*UVScale).xy;
  	bumpColorD.xz = tex2D(noiseMap, wave1.wz*UVScale).xy;
  	bumpHighFreq.xz = (bumpColorC.xz + bumpColorD.xz)*SmallWavesScale - SmallWavesScale;

  	// merge all waves
  	float3 bumpNormal = float3(0,1,0);
  	bumpNormal.xz = bumpLowFreq.xz + bumpHighFreq.xz;

  	bumpNormal.xyz = normalize( bumpNormal.xyz );
	bumpNormal.xz *= BumpScale;
	bumpNormal.xyz = normalize( bumpNormal.xyz );
		
	// get Reflection color
	float3 reflectDir = (2*dot(eyeDir, bumpNormal)*bumpNormal - eyeDir);

#if USE_MIRROR
	float4 reflectionColour = tex2D(reflectMap, originUV + bumpNormal.xz*0.1);
#else
	float4 reflectionColour = texCUBE(reflectMap, reflectDir);
#endif
	// get refraction color
	float4 oriColour = tex2D(refractMap, originUV);
	float4 refractionColour = tex2D(refractMap, originUV + bumpNormal.xz*0.1);
	
	if(oriColour.w > 0.0001 || refractionColour.w > 0.0001)
			refractionColour = oriColour;
		
	// cal fresnel
	float vdn = abs(dot(eyeDir, bumpNormal));
	float fresnel = saturate(FresnelBias + (1-FresnelBias)*pow(1 - vdn, 5));
	
	// Final colour
#if USE_MIRROR
	oColour = lerp(refractionColour, reflectionColour, fresnel * clamp(TransparencyRatio,0.8,1));
#else
	oColour = lerp(refractionColour, reflectionColour * ReflectionAmount, fresnel * TransparencyRatio);
#endif
	// use sun shine
	float RdoTL = saturate(dot(reflectDir, -SunLightDir));
  	float sunSpecular = pow( RdoTL , SunShinePow );                        
  	float3 vSunGlow = sunSpecular * SunColor.xyz * SunMultiplier;
  
  	// add sun shine term
  	oColour.xyz += vSunGlow;
  	oColour.xyz = lerp(oriColour.xyz, oColour.xyz, UVDepth);

	// fog
	float fogFactor = Fogging(-posInView.z, fog_type, fog_params);
	oColour.xyz = lerp(fog_colour.xyz, oColour.xyz, fogFactor);

	oColour.w = 1;
}


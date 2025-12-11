#ifndef _Model_Water_PS_H_
#define _Model_Water_PS_H_

// Define In PS
#define __PS__

uniform sampler2D depthMap : register(s0);
uniform sampler2D noiseMap : register(s1);
uniform samplerCUBE reflectMap : register(s2);
uniform sampler2D refractMap : register(s3);

uniform float2 texRotateScale;
uniform float texDepthFactor;
uniform float wavesSpeed;

uniform float4 FogColorDensity;
uniform float BigWavesScale;
uniform float SmallWavesScale;
uniform float2 BumpScale;
uniform float ReflectionAmount;
uniform float TransparencyRatio;
uniform float SunShinePow;
uniform float SunMultiplier;
uniform float FresnelBias;
uniform float2 UVScale;


#include "WaterDef.inc"


 

PS_OUT main( VS_OUT IN )
{
	PS_OUT OUT = (PS_OUT)0;
	// cal screen uv
	float2 originUV = IN.oUVScreen.xy / IN.oUVScreen.w;

	float sceneDepth = tex2D(depthMap, originUV).x;
#if USE_DSINTZ
  sceneDepth = DeviceDepthToEyeLinear(sceneDepth, near_clip_distance, far_clip_distance );
#endif
	float volumeDepth = min( dot( IN.oEyeDir, -IN.oCamFrontDir.xyz ) - sceneDepth, 0 );
	float waterVolumeFog = 1.0 - exp(volumeDepth* FogColorDensity.w*0.00001);
	#if PBR_TIME == 1
		float2 vTranslation= wind_control_params.ww * wavesSpeed;
	#else
		float2 vTranslation= time.xx * wavesSpeed;
	#endif
	float cosValue = cos(texRotateScale.x);
  float sinValue = sin(texRotateScale.x);
        
  float4 vTex = float4( 0, 0, 0, 1 );
  vTex.x = texRotateScale.y * (IN.oUV.x*cosValue - IN.oUV.y*sinValue);
  vTex.y = texRotateScale.y * (IN.oUV.x*sinValue + IN.oUV.y*cosValue);
	
  float4 wave0 = float4(0, 0, 0, 0);
  float4 wave1 = float4(0, 0, 0, 0);
  wave0.xy = vTex.xy*2*1.0 + vTranslation*2.0;
  wave0.wz = vTex.xy*1.0 + vTranslation*3.0;
  wave1.xy = vTex.xy*2*2.0 + vTranslation*2.0;
  wave1.wz = vTex.xy*2*4.0 + vTranslation*3.0;
	
	float3 eyeDir = normalize(IN.oEyeDir);

	
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
	float2 bumpUV = originUV + bumpNormal.xz*0.1;
		
	// get Reflection color
	float3 reflectDir = (2*dot(eyeDir, bumpNormal)*bumpNormal - eyeDir);
	float4 reflectionColour = texCUBE(reflectMap, reflectDir);
	
	// get refraction color
	float bumpSceneDepth = tex2D(depthMap, bumpUV).x;
#if USE_DSINTZ
	bumpSceneDepth = DeviceDepthToEyeLinear(bumpSceneDepth, near_clip_distance, far_clip_distance );
#endif
	float bumpVolumeDepth = min( dot( IN.oEyeDir, -IN.oCamFrontDir.xyz ) - bumpSceneDepth, 0 );
	float4 oriColour = tex2D(refractMap, originUV);
	float4 refractionColour = bumpVolumeDepth < 0 ? tex2D(refractMap, bumpUV) : oriColour;
	float waterVolumeFog2 = bumpVolumeDepth < 0 ? (1.0 - exp(bumpVolumeDepth* FogColorDensity.w*0.00001)) : waterVolumeFog;
	refractionColour.xyz = lerp(refractionColour.xyz, FogColorDensity.xyz, waterVolumeFog2);
	oriColour.xyz = lerp(oriColour.xyz, FogColorDensity.xyz, waterVolumeFog);
		
	// cal fresnel
	float vdn = abs(dot(eyeDir, bumpNormal));
	float fresnel = saturate(FresnelBias + (1-FresnelBias)*pow(1 - vdn, 5));
	
	// Final colour
	OUT.color = lerp(refractionColour, reflectionColour * ReflectionAmount, fresnel * TransparencyRatio);
	
	// use sun shine
	float RdoTL = saturate(dot(reflectDir, -light_direction0.xyz));
  float sunSpecular = pow( RdoTL , SunShinePow );                        
  float3 vSunGlow = sunSpecular * light_diffuse_colour0.xyz * SunMultiplier;
  
  // add sun shine term
  OUT.color.xyz += vSunGlow;
  
  OUT.color.xyz = lerp(oriColour.xyz, OUT.color.xyz, saturate(waterVolumeFog * texDepthFactor) );
	OUT.color.w = 1;

	// fog
	Calc_Fog_Color(-IN.oPosInView.z, OUT.color.xyz);
	return OUT;
}

#endif





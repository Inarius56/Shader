#ifndef _Model_Pbr_Chara_PS_H_
#define _Model_Pbr_Chara_PS_H_

// Define In VS
#define __PS__

#define PI 3.14159265359
/////#define ColorSpaceDielectricSpec float4(0.220916301, 0.220916301, 0.220916301, 1.0 - 0.220916301)  ////gamma
#define ColorSpaceDielectricSpec float4(0.04, 0.04, 0.04, 1.0 - 0.04) 
#include "ModelDef.inc"

/// fragment params for pbr
struct FragParams_pbr_bd
{
		FragInput 	FI;
		SystemParams SP;

		float4 cAlbedoTex;
		float4 cMetallicTex;
		float4 cEnvTex;

		float3 cLight;
		float4 cFinal;
};

sampler2D MetallicSampler : register(s1);
sampler2D NormalSampler : register(s2);
sampler2D EnvSampler			: register(s3);

#if IS_DETAIL == 0
sampler2D AlbedoSampler : register(s0);
#else
sampler2D MaskSampler : register(s0);
sampler2D D0Sampler : register(s6);
sampler2D DN0Sampler : register(s7);
sampler2D D1Sampler : register(s8);
sampler2D DN1Sampler : register(s9);

uniform float4 D0UV_params;
uniform float4 D1UV_params;
uniform float4 DN_params;
#endif

//--------------------------------------------------------
float3 GammaToLinearSpace0 (float3 sRGB)
{
	return pow(sRGB,2.2f);
}

float3 GammaToLinearSpaceEasy (float3 sRGB)
{
    return sRGB * (sRGB * (sRGB * 0.305306011f + 0.682171111f) + 0.012522878f);
}

float GammaToLinearSpaceEasySingle (float sRGB)
{
    return sRGB * (sRGB * (sRGB * 0.305306011f + 0.682171111f) + 0.012522878f);
}

float3 LinearToGammaSpace0 (float3 linRGB)
{
	return pow(linRGB,0.45f);
}

float3 LinearToGammaSpaceEasy (float3 linRGB)
{
    linRGB = max(linRGB, float3(0.f, 0.f, 0.f));
   return max(1.055f * pow(linRGB, 0.416666667f) - 0.055f, 0.f);
}

FragInput fmt_input( VS_OUT IN )
{
	FragInput FI = (FragInput)0;


	FI.baseTC = IN.oUV0;
	FI.fPw = IN.oPw;
	FI.fNw = float4(normalize(IN.oNw),0);
	FI.fNo = normalize(IN.oNo);
	FI.oNw = normalize(IN.oNw);
	FI.fView = float4( normalize(IN.oV.xyz), IN.oV.w );
#if USE_TANGENT == 1
	FI.fTw = normalize(IN.oTw.xyz);
	FI.fBw = normalize(IN.oBw.xyz);
#endif
#if SHADOWMAP_TYPE != SHADOWMAP_NONE
  FI.fShadow = IN.oShadow;
#endif
	FI.color = IN.oColour;
	return FI;
}

PS_OUT fmt_output( FragParams_pbr_bd params )
{
	PS_OUT OUT = (PS_OUT)0;
	OUT.color = float4( params.cFinal.rgb, params.cAlbedoTex.a * params.FI.color.a * surface_diffuse_colour.a );

	return OUT;
}

#if IS_DETAIL == 1
float3 Calc_NormalInTangentSpace(float2 normalTexUV, float2 d0UV, float2 d1UV, float4 mask)
#else
float3 Calc_NormalInTangentSpace(float2 normalTexUV)
#endif
{
	// normal
	float3 normal = UnpackScaleNormal(tex2D(NormalSampler, normalTexUV.xy), 1);
	
#if IS_DETAIL == 1
	float3 detailN0 = UnpackScaleNormal(tex2D(DN0Sampler, d0UV.xy), DN_params.r);
	//detailN0.g = 1 - detailN0.g;
	float3 detailN1 = UnpackScaleNormal(tex2D(DN1Sampler, d1UV.xy), DN_params.g);
	//detailN1.g = 1 - detailN1.g;
	
	float3 detailN = (detailN0 - float3(0,0,1)) * mask.x + float3(0,0,1);
	detailN = (detailN1 - detailN) * mask.g + detailN;
	//float4 detailN = lerp(detailN0, detailN1, mask.y);
	
	normal.xy = detailN.xy + normal.xy;
	normal.z = detailN.z * normal.z;
#endif
	normal.xyz = normalize(normal.xyz);
	return normal.xyz;
}

void Calc_Pbr_Tex(inout FragParams_pbr_bd params)
{
	params.cAlbedoTex = float4(0.0,0.0,0.0,1.0);
	params.cMetallicTex = float4(0.0,0.0,0.0,1.0);
	params.cEnvTex = float4(0.0,0.0,0.0,1.0);

	// sample albedoTex
#if IS_DETAIL == 1
	float4 maskTex = tex2D(MaskSampler, params.FI.baseTC.xy);
	
	float2 d0UV = params.FI.baseTC.xy * D0UV_params.xy + D0UV_params.zw;
	float2 d1UV = params.FI.baseTC.xy * D1UV_params.xy + D1UV_params.zw;
	
	float4 d0Tex = tex2D(D0Sampler, d0UV);
	float4 d1Tex = tex2D(D1Sampler, d1UV);

	params.cAlbedoTex = d0Tex;
	params.cAlbedoTex.rgb = lerp(params.cAlbedoTex.rgb, d1Tex.rgb, maskTex.g);
	params.cAlbedoTex.rgb = GammaToLinearSpaceEasy(params.cAlbedoTex.rgb);
#else
	params.cAlbedoTex = tex2D(AlbedoSampler, params.FI.baseTC.xy);
	params.cAlbedoTex.rgb = GammaToLinearSpaceEasy(params.cAlbedoTex.rgb);
#endif

	/// alpha rejection
	Tex_Kill( params.cAlbedoTex.a );
	
	// sample roughness
	params.cMetallicTex = tex2D(MetallicSampler, params.FI.baseTC.xy);
	params.cMetallicTex.r = GammaToLinearSpaceEasySingle(params.cMetallicTex.r);
	
	// sample normalTex
	float3 normalInTangentSpace = 
#if IS_DETAIL == 1
							Calc_NormalInTangentSpace(params.FI.baseTC.xy, d0UV, d1UV, maskTex);
#else
							Calc_NormalInTangentSpace(params.FI.baseTC.xy);
#endif
	params.FI.fNw.xyz = Calc_Normal_ps( params.FI.fTw.xyz, params.FI.fBw.xyz, params.FI.fNw.xyz, normalInTangentSpace );
}

//--------------------------------------------------------
float Pow5 (float x)
{
  return x*x*x*x*x;;
}
//--------------------------------------------------------
float3 FresnelTerm (float3 F0, float cosA)
{
  float t = Pow5 (1 - cosA);   // ala Schlick interpoliation
  return F0 + (1-F0) * t;
}
//--------------------------------------------------------
float3 FresnelLerp (float3 F0, float3 F90, float cosA)
{
  float t = Pow5 (1 - cosA);   // ala Schlick interpoliation
	return lerp (F0, F90, t);
}
//--------------------------------------------------------
float SmithJointGGXVisibilityTerm (float NdotL, float NdotV, float roughness)
{

	float a = roughness;
	float lambdaV = NdotL * (NdotV * (1 - a) + a);
	float lambdaL = NdotV * (NdotL * (1 - a) + a);
	return 0.5f / (lambdaV + lambdaL + 1e-5f);
}
//--------------------------------------------------------
float GGXTerm (float NdotH, float roughness)
{
	float a2 = roughness * roughness;
	float d = (NdotH * a2 - NdotH) * NdotH + 1.0f;
	return (1/PI) * a2 / (d * d + 1e-7f);
}
//--------------------------------------------------------
float NDFBlinnPhongNormalizedTerm (float NdotH, float smoothness)
{

	float perceptualRoughness = (1 - smoothness);
	float m = perceptualRoughness * perceptualRoughness;

	float sq = max(1e-4f, m*m);
	float n = (2.0 / sq) - 2.0;
	n = max(n, 1e-4f);

	float normTerm = (n + 2.0) * (0.5/PI);
	float specTerm = pow (NdotH, n);
	return specTerm * normTerm;
}
//--------------------------------------------------------
float SmoothnessToPerceptualRoughness(float smoothness)
{
	return (1 - smoothness);
}
//--------------------------------------------------------
float PerceptualRoughnessToRoughness(float perceptualRoughness)
{
	return perceptualRoughness * perceptualRoughness;
}
//--------------------------------------------------------
///////disney
float DisneyDiffuse(float NdotV, float NdotL, float LdotH, float perceptualRoughness)
{
	float fd90 = 0.5 + 2 * LdotH * LdotH * perceptualRoughness;
	float lightScatter   = (1 + (fd90 - 1) * Pow5(1 - NdotL));
	float viewScatter    = (1 + (fd90 - 1) * Pow5(1 - NdotV));

	return lightScatter * viewScatter;
}
//--------------------------------------------------------
float OneMinusReflectivityFromMetallic(float metallic)
{
	float oneMinusDielectricSpec = ColorSpaceDielectricSpec.a;
	return oneMinusDielectricSpec - metallic * oneMinusDielectricSpec;
}
//--------------------------------------------------------
float3 DiffuseAndSpecularFromMetallic(float3 albedo, float metallic)
{
	float3 specColor = lerp (ColorSpaceDielectricSpec.rgb, albedo, metallic);
	float oneMinusReflectivity = OneMinusReflectivityFromMetallic(metallic);
	return albedo * oneMinusReflectivity;
}

//--------------------------------------------------------
void Calc_Pbr(inout FragParams_pbr_bd params)
{
		// calculate shadow factor
		float shadowFactor;
		float3 shadowColor;
		Calc_Shadow_Ps(params.FI, shadowFactor, shadowColor);
		
		// PBR
		float3 albedo = params.cAlbedoTex.rgb;
		
    float Metallic = params.cMetallicTex.r;  ///pow(params.cMetallicTex.r,2.2);
		float smooth = params.cMetallicTex.g;  ///pow(params.cMetallicTex.g,2.2);

		float smoothness =  saturate((smooth));
		smoothness *= 1;   ///总控系数

		float4 lightPosition[MAX_LIGHT_NUM+1];
    float4 lightAttenuation[MAX_LIGHT_NUM+1];
    float3 diffuseColour[MAX_LIGHT_NUM+1];

		diffuseColour[0] = GammaToLinearSpaceEasy((light_diffuse_colour_array[0].rgb * light_diffuse_colour_array[0].a * (1.0 - imodel_userdata.x) + actor_lightone_params.rgb * actor_lightone_params.a * imodel_userdata.x));
		diffuseColour[1] = GammaToLinearSpaceEasy((light_diffuse_colour_array[1].rgb * light_diffuse_colour_array[1].a * (1.0 - imodel_userdata.x) + actor_lighttwo_params.rgb * actor_lighttwo_params.a * imodel_userdata.x));
		diffuseColour[2] = GammaToLinearSpaceEasy(light_diffuse_colour_array[2].rgb * light_diffuse_colour_array[2].a);
		diffuseColour[3] = GammaToLinearSpaceEasy(float3(204/255.0,179/255.0,154/255.0));

			lightPosition[0] = light_position_array[0];
	    lightPosition[1] = light_position_array[1];
	    lightPosition[2] = light_position_array[2];
	    lightPosition[3] = float4(params.FI.fView.xyz,0);

		  lightAttenuation[0] = light_attenuation_array[0];
	    lightAttenuation[1] = light_attenuation_array[1];
	    lightAttenuation[2] = light_attenuation_array[2];
	    lightAttenuation[3] = light_attenuation_array[0];

      float3 indirectDiffuse = float3(0,0,0);
      float3 indirectSpecular = float3(0,0,0);
      
      float3 actorDerivedScene = actor_ambient_params.rgb - surface_emissive_colour.rgb + min(0.5, surface_emissive_colour.rgb);
      #if IS_PBR_MODEL == 1
 	    	indirectDiffuse = (derived_pbr_scene_colour.rgb * (1.0 - imodel_userdata.x) + actorDerivedScene.rgb * imodel_userdata.x);
 	    #else
 	    	indirectDiffuse = (derived_scene_colour.rgb * (1.0 - imodel_userdata.x) + actorDerivedScene.rgb * imodel_userdata.x);
 	    #endif
 	    
 	    float4 finalcolor = float4(0.0,0.0,0.0,1.0);

 	    float perceptualRoughness = SmoothnessToPerceptualRoughness (smoothness);
			float roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
		  roughness = max(roughness, 0.002);
		  float3 specColor = lerp (ColorSpaceDielectricSpec.rgb, albedo, Metallic);

		  float oneMinusReflectivity = OneMinusReflectivityFromMetallic(Metallic);
		  albedo.rgb = albedo.rgb * oneMinusReflectivity;
		  

      float nv = abs(dot(params.FI.fNw.xyz, params.FI.fView.xyz));
			float3 diffuse[MAX_LIGHT_NUM+1]; 
			diffuse[3] = float3(0,0,0);
			float3 specular[MAX_LIGHT_NUM+1];
			specular[3] = float3(0,0,0);

			int l = 0;
			float3 testvar[4];

			for (; l < MAX_LIGHT_NUM +1; ++l)
	    {
				float3 lightDir = lightPosition[l].xyz - (params.FI.fPw.xyz * lightPosition[l].w);
			 	//lightDir = float3(0.557,0.427,0.0);
				float3 lightDirection = normalize(lightDir);
				float lightDirLength = length(lightDir);
				//float att = lerp(0, 1, 1 / dot(float3(1, lightDirLength, lightDirLength*lightDirLength), lightAttenuation[l].yzw));
				float att = pow(saturate(-lightDirLength / lightAttenuation[l].x + 1.0), lightAttenuation[l].y);
   		float3 attenColor = (diffuseColour[l]) * saturate(att)*2.5;

	      float3 halfDir = normalize (lightDirection + params.FI.fView.xyz);

				float nl = saturate(dot(params.FI.fNw.xyz, lightDirection));
      	float nh = saturate(dot(params.FI.fNw.xyz, halfDir));
      	nh = nh>0.5? 2*(nh-0.5)*(nh-0.5) + 0.5 :nh;
     		float lv = saturate(dot(lightDirection, params.FI.fView.xyz));
     		float lh = saturate(dot(lightDirection, halfDir));
				float diffuseTerm = DisneyDiffuse(nv, nl, lh, perceptualRoughness) * nl;
				roughness = max(roughness, 0.002);

				float V = SmithJointGGXVisibilityTerm (nl, nv, roughness);
				float D = GGXTerm (nh, roughness);
				float specularTerm = V*D * PI;

			//	specularTerm = sqrt(max(1e-4h, specularTerm));
				specularTerm = max(0, specularTerm * nl);
				specularTerm *= any(specColor) ? 1.0 : 0.0;

				diffuse[l] =  attenColor *  diffuseTerm;
				specular[l] = specularTerm * attenColor * FresnelTerm (specColor, lh);
				///lightDir;//params.FI.fView.xyz;//
				testvar[l] = indirectDiffuse;///diffuseColour[0];//attenColor;///FresnelTerm (specColor, lh);
	    }

			float surfaceReduction;
      ///surfaceReduction = 1.0-0.28*roughness*perceptualRoughness;
			
			surfaceReduction = 1.0 / (roughness*roughness + 1.0);
			float grazingTerm = saturate(smoothness + (1-oneMinusReflectivity));
		
		diffuse[0] *= params.FI.color.rgb * surface_diffuse_colour.rgb;
		indirectDiffuse += (diffuse[1] + diffuse[2]+ diffuse[3]*0.000001) * params.FI.color.rgb * surface_diffuse_colour.rgb;
		
		// calculate envmap color by roughness
    perceptualRoughness = perceptualRoughness*(1.7 - 0.7*perceptualRoughness);
    float mip = perceptualRoughness * 6;
		float2 _Env_UV = 1 - (normalize(mul(view_matrix, float4(params.FI.fNw.xyz, 0.0))).xy*0.5 + 0.5);
		params.cEnvTex = tex2Dlod(EnvSampler, float4(_Env_UV.xy,0,mip));
		params.cEnvTex.rgb = GammaToLinearSpaceEasy(params.cEnvTex.rgb);
		indirectSpecular += params.cEnvTex.rgb;		
		
		finalcolor.rgb = albedo * (diffuse[0] * shadowFactor + indirectDiffuse)
                    + specular[0] * shadowFactor
                    + (specular[1]*0.001+ specular[2]*0.6 + specular[3]*0.6)
                    + surfaceReduction * indirectSpecular * FresnelLerp (specColor, grazingTerm, nv)
                    ;										
		params.cLight.rgb = LinearToGammaSpaceEasy(finalcolor.rgb);

		params.cFinal.rgb = params.cLight.rgb;

		//params.cFinal.rgb = params.cFinal.rgb*0.00001 + params.cMetallicTex.rgb;
}

PS_OUT main( VS_OUT IN )
{
	FragParams_pbr_bd params = (FragParams_pbr_bd)0;
	params.FI = fmt_input( IN );

	/// 设置渲染参数
	Set_SystemParams( params.SP );

	/// diffuse rt
	Calc_Pbr_Tex( params );

	// calc pbr light model
	Calc_Pbr( params );

	/// fog
	Calc_Fog_Color( params.FI.fPw.w, params.cFinal.rgb );

	return fmt_output( params );
}

#endif





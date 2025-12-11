#ifndef _Model_Pbr_Terrain_PS_H_
#define _Model_Pbr_Terrain_PS_H_

// Define In VS
#define __PS__

#define PI 3.14159265359
/////#define ColorSpaceDielectricSpec float4(0.220916301, 0.220916301, 0.220916301, 1.0 - 0.220916301)  ////gamma
#define ColorSpaceDielectricSpec float4(0.04, 0.04, 0.04, 1.0 - 0.04) 
#include "ModelDef.inc"

/// fragment params for pbr
struct FragParams_pbr_terrain
{
		FragInput 	FI;
		SystemParams SP;

		float4 cAlbedoTex;
		float4 cMetallicTex;
		float4 cEnvTex;

		float3 cLight;
		float4 cFinal;
};


sampler2D L0Sampler : register(s0);
sampler2D LN0Sampler : register(s1);
sampler2D L1Sampler : register(s2);
sampler2D LN1Sampler : register(s3);
sampler2D L2Sampler : register(s6);
sampler2D LN2Sampler : register(s7);
sampler2D MaskSampler : register(s8);
sampler2D EnvSampler : register(s9);

uniform float4 L0UV_params;
uniform float4 L1UV_params;
uniform float4 L2UV_params;
uniform float4 LN_params;

FragInput fmt_input( VS_OUT IN )
{
	FragInput FI = (FragInput)0;

	FI.baseTC = IN.oUV0;
	FI.fPw = IN.oPw;
	FI.fNw = float4(normalize(IN.oNw),0);
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

PS_OUT fmt_output( FragParams_pbr_terrain params )
{
	PS_OUT OUT = (PS_OUT)0;
	OUT.color = float4( params.cFinal.rgb, params.cAlbedoTex.a * params.FI.color.a * surface_diffuse_colour.a );

	return OUT;
}


float3 Calc_NormalInTangentSpace(float2 layer0UV, float2 layer1UV, float2 layer2UV, float4 mask)
{
	// normal
	float3 normal = UnpackScaleNormal(tex2D(LN0Sampler, layer0UV.xy), LN_params.r);

	float3 layerN1 = UnpackScaleNormal(tex2D(LN1Sampler, layer1UV.xy), LN_params.g);
	float3 layerN2 = UnpackScaleNormal(tex2D(LN2Sampler, layer2UV.xy), LN_params.b);
	
	//float3 layN = (layerN1 - float3(0,0,1)) * mask.r + float3(0,0,1);
	//layN = (layerN2 - layN) * mask.g + layN;
	
	//normal.xy = layN.xy + normal.xy;
	//normal.z = layN.z * normal.z;
	
	normal = lerp(normal, layerN1, mask.r);
	normal = lerp(normal, layerN2, mask.g);

	normal.xyz = normalize(normal.xyz);
	return normal.xyz;
}

void Calc_Pbr_Tex(inout FragParams_pbr_terrain params)
{
	params.cAlbedoTex = float4(0.0,0.0,0.0,1.0);
	params.cMetallicTex = float4(0.0,0.0,0.0,1.0);
	params.cEnvTex = float4(0.0,0.0,0.0,1.0);

	// sample albedoTex
	float2 maskUV = params.FI.baseTC.xy;
	float2 layer0UV = params.FI.baseTC.xy * L0UV_params.xy + L0UV_params.zw;
	float2 layer1UV = params.FI.baseTC.xy * L1UV_params.xy + L1UV_params.zw;
	float2 layer2UV = params.FI.baseTC.xy * L2UV_params.xy + L2UV_params.zw;
	
	float4 maskTex = tex2D(MaskSampler, maskUV);
	float4 layer0Tex = tex2D(L0Sampler, layer0UV);
	float4 layer1Tex = tex2D(L1Sampler, layer1UV);
	float4 layer2Tex = tex2D(L2Sampler, layer2UV);

	float4 layerColor = lerp(layer0Tex, layer1Tex, maskTex.r);
	layerColor = lerp(layerColor, layer2Tex, maskTex.g);
	params.cAlbedoTex.rgb = GammaToLinearSpace(layerColor.rgb);
	
	// sample roughness
	params.cMetallicTex.g = layerColor.a;
	
	// sample normalTex
	float3 normalInTangentSpace = Calc_NormalInTangentSpace(layer0UV, layer1UV, layer2UV, maskTex);
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
void Calc_Pbr(inout FragParams_pbr_terrain params)
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

		diffuseColour[0] = GammaToLinearSpace((light_diffuse_colour_array[0].rgb * light_diffuse_colour_array[0].a * (1.0 - imodel_userdata.x) + actor_lightone_params.rgb * actor_lightone_params.a * imodel_userdata.x));
		diffuseColour[1] = GammaToLinearSpace((light_diffuse_colour_array[1].rgb * light_diffuse_colour_array[1].a * (1.0 - imodel_userdata.x) + actor_lighttwo_params.rgb * actor_lighttwo_params.a * imodel_userdata.x));
		diffuseColour[2] = GammaToLinearSpace(light_diffuse_colour_array[2].rgb * light_diffuse_colour_array[2].a);
		diffuseColour[3] = GammaToLinearSpace(float3(1/255.0,1/255.0,1/255.0));

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
      
      #if IS_PBR_MODEL == 1
 	    	indirectDiffuse = (derived_pbr_scene_colour.rgb * (1.0 - imodel_userdata.x) + actor_ambient_params.rgb * imodel_userdata.x);
 	    #else
 	    	indirectDiffuse = (derived_scene_colour.rgb * (1.0 - imodel_userdata.x) + actor_ambient_params.rgb * imodel_userdata.x);
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
		indirectDiffuse += (diffuse[1] + diffuse[2]+ diffuse[3]) * params.FI.color.rgb * surface_diffuse_colour.rgb;
		
		// calculate envmap color by roughness
    perceptualRoughness = perceptualRoughness*(1.7 - 0.7*perceptualRoughness);
    float mip = perceptualRoughness * 6;
		float2 _Env_UV = 1 - (normalize(mul(view_matrix, float4(params.FI.fNw.xyz, 0.0))).xy*0.5 + 0.5);
		params.cEnvTex = tex2Dlod(EnvSampler, float4(_Env_UV.xy,0,mip));
		params.cEnvTex.rgb = GammaToLinearSpace(params.cEnvTex.rgb);
		indirectSpecular += params.cEnvTex.rgb;		
		
		finalcolor.rgb = albedo * (diffuse[0] * shadowFactor + indirectDiffuse)
                    + specular[0] * shadowFactor
                    + (specular[1]*0.001+ specular[2]*0.6 + specular[3]*0.3)
                    + surfaceReduction * indirectSpecular * FresnelLerp (specColor, grazingTerm, nv)
                    ;										
		params.cLight.rgb = LinearToGammaSpace(finalcolor.rgb);

		params.cFinal.rgb = params.cLight.rgb;

		//params.cFinal.rgb = params.cFinal.rgb*0.00001 + params.FI.fTw.xyz;
}

PS_OUT main( VS_OUT IN )
{
	FragParams_pbr_terrain params = (FragParams_pbr_terrain)0;
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





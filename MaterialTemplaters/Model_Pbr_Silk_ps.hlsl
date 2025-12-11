#ifndef _Model_Pbr_Silk_PS_H_
#define _Model_Pbr_Silk_PS_H_

// Define In VS
#define __PS__

#define PI 3.14159265359
#define ColorSpaceDielectricSpec float4(0.220916301, 0.220916301, 0.220916301, 1.0 - 0.220916301)

#include "ModelDef.inc"

/// fragment params for pbr
struct FragParams_pbr
{
		FragInput 	FI;
		SystemParams SP;
		
		float4 cAlbedoTex;
		float4 cMetallicTex;
		float4 cNormalTex;
		float3 cLight;
		float4 cFinal;
		
};

sampler2D AlbedoSampler : register(s0);
sampler2D MetallicSampler : register(s1);
sampler2D NormalSampler : register(s2);
	
 
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

PS_OUT fmt_output( FragParams_pbr params )
{
	PS_OUT OUT = (PS_OUT)0; 
	OUT.color = float4( params.cFinal.rgb, params.cAlbedoTex.a * params.FI.color.a * surface_diffuse_colour.a );
	return OUT;
}

void Calc_Pbr_Tex(inout FragParams_pbr params)
{
	params.cAlbedoTex = float4(0.0,0.0,0.0,1.0);
	params.cMetallicTex = float4(0.0,0.0,0.0,1.0);
	params.cNormalTex = float4(0.0,0.0,0.0,1.0);
	
	params.cAlbedoTex = tex2D(AlbedoSampler, params.FI.baseTC.xy);
	params.cMetallicTex = tex2D(MetallicSampler, params.FI.baseTC.xy);
	params.cNormalTex = tex2D(NormalSampler, params.FI.baseTC.xy);
			
	params.cNormalTex.g = 1 - params.cNormalTex.g;
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
float3 DiffuseAndSpecularFromMetallic (float3 albedo, float metallic,out float3 specColor,out float oneMinusReflectivity)
{
	specColor = lerp (ColorSpaceDielectricSpec.rgb, albedo, metallic);
	oneMinusReflectivity = OneMinusReflectivityFromMetallic(metallic);
	return albedo * oneMinusReflectivity;
}
float sqr(float x)
{
	return x*x;
}
float TrowbridgeReitzAnisotropicNDF(float roughness, float anisotropic, float NdotH, float HdotX, float HdotY)
{
	float aspect = sqrt(1.0h-anisotropic * 0.9h);
	float X = max(.001, sqr(roughness) / aspect) * 5;
	float Y = max(.001, sqr(roughness) * aspect) * 5;
	return 1.0 / (3.1415926535 * X*Y * sqr(sqr(HdotX / X) + sqr(HdotY / Y) + NdotH * NdotH));
}
void AnisotropyToValueTB(half value, half anisotropy, out half valueT, out half valueB)
{
	valueT = value * (1 + anisotropy);
	valueB = value * (1 - anisotropy);
}

void ConvertAnisotropyToRoughness(half perceptualRoughness, half anisotropy, out half roughnessT, out half roughnessB)
{
	half roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
	AnisotropyToValueTB(roughness, anisotropy, roughnessT, roughnessB);
}
half AshikhminGSF(half NdotL, half NdotV)
{
	return 1.0 / (4.0 * (NdotL + NdotV - NdotL * NdotV));
}
float3 Unity_SafeNormalize(float3 inVec)
{
	float dp3 = max(0.0001f,dot(inVec,inVec));
	return inVec * rsqrt(dp3);
}
//--------------------------------------------------------
void Calc_Pbr_Silk(inout FragParams_pbr params)
{
		float Metallic = params.cMetallicTex.r; 
		float smoothness =  1 - saturate((params.cMetallicTex.g));  	
		float skin = params.cMetallicTex.b;
		float4 lightPosition[MAX_LIGHT_NUM+1];
    	float4 lightAttenuation[MAX_LIGHT_NUM+1];    
		float3 diffuseColour[MAX_LIGHT_NUM+1]; 
      
    	diffuseColour[0] = (light_diffuse_colour_array[0].rgb * light_diffuse_colour_array[0].a * (1.0 - imodel_userdata.x) + actor_lightone_params.rgb * actor_lightone_params.a * imodel_userdata.x) * surface_diffuse_colour.rgb;
		diffuseColour[1] = (light_diffuse_colour_array[1].rgb * light_diffuse_colour_array[1].a * (1.0 - imodel_userdata.x) + actor_lighttwo_params.rgb * actor_lighttwo_params.a * imodel_userdata.x) * surface_diffuse_colour.rgb;
		diffuseColour[2] = light_diffuse_colour_array[2].rgb * light_diffuse_colour_array[2].a;
		diffuseColour[3] = float4(200/255.0,200/255.0,200/255.0,1.0);
			
		lightPosition[0] = light_position_array[0];
	    lightPosition[1] = light_position_array[1]; 
	    lightPosition[2] = light_position_array[2];
	    lightPosition[3] = float4(params.FI.fView.xyz,0);
	    
		lightAttenuation[0] = light_attenuation_array[0];
	    lightAttenuation[1] = light_attenuation_array[1];   
	    lightAttenuation[2] = light_attenuation_array[2];
	    lightAttenuation[3] = light_attenuation_array[0];
      
		float3 indirectDiffuse = float3(0,0,0);
    	indirectDiffuse += 0.5 * derived_scene_colour.rgb * (1.0 - imodel_userdata.x) + actor_ambient_params.rgb * imodel_userdata.x; // Ambient Light     
 	    float4 finalcolor = float4(0.0,0.0,0.0,1.0);
 	    
		float3 specColor;
		float3 albedo = DiffuseAndSpecularFromMetallic (albedoTexVar.rgb, Metallic , /*out*/ specColor,/*out*/ oneMinusReflectivity );	
 	    float perceptualRoughness = SmoothnessToPerceptualRoughness (smoothness);
		float roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
		roughness = max(roughness, 0.002);
		float3 specColor = lerp (ColorSpaceDielectricSpec.rgb, params.cAlbedoTex.rgb + indirectDiffuse, Metallic);
		float3 specColorWithIndirect = lerp (ColorSpaceDielectricSpec.rgb, params.cAlbedoTex.rgb + indirectDiffuse, Metallic);
		float oneMinusReflectivity = OneMinusReflectivityFromMetallic(Metallic);
      
		float nv = abs(dot(params.FI.fNw.xyz, params.FI.fView.xyz));
		float3 diffuse[MAX_LIGHT_NUM+1];
		float3 specular[MAX_LIGHT_NUM+1];
		float3 kk[MAX_LIGHT_NUM+1];
		//丝绸额外降低摄像机Y高度	
		params.FI.fView.y = params.FI.fView.y - 0.3f;
		int l = 0;
		for (; l < MAX_LIGHT_NUM + 1; ++l)
	    {
			float3 lightDir = lightPosition[l].xyz - (params.FI.fPw.xyz * lightPosition[l].w);
			float3 lightDirection = normalize(lightPosition[l].xyz - (params.FI.fPw.xyz * lightPosition[l].w));
			float lightDirLength = length(lightDir);
			//float att = lerp(0, 1, 1 / dot(float3(1, lightDirLength, lightDirLength*lightDirLength), lightAttenuation[l].yzw));
			float att = pow(saturate(-lightDirLength / lightAttenuation[l].x + 1.0), lightAttenuation[l].y);
			float3 attenColor = (max(max(max(diffuseColour[l].r,diffuseColour[l].g),diffuseColour[l].b),0.2).xxx) * saturate(att);
			lightDirection.r = -lightDirection.r;
			
		
			float3 halfDir = Unity_SafeNormalize (lightDirection + params.FI.fView.xyz);
			half ht = dot(halfDir, params.FI.fTw);
			half hb = dot(halfDir, params.FI.fBw);
			float nl = saturate(dot(params.FI.fNw.xyz, lightDirection));
			float nh = saturate(dot(params.FI.fNw.xyz, halfDir));
			float lv = saturate(dot(lightDirection, params.FI.fView.xyz));
			float lh = saturate(dot(lightDirection, halfDir));
			float diffuseTerm = DisneyDiffuse(nv, nl, lh, perceptualRoughness) * nl;
		
			//NDF
			float D = TrowbridgeReitzAnisotropicNDF(roughness, anisotropic, nh, ht, hb);
			D = min(D, 5.0);
			//Second NDF
			float SD = GGXTerm (nh, roughness);
			D = lerp(SD, D, metallicTexVar.a);
			//D = lerp(SD, D, 0);				
			//Geomerty Shadow Mask Function				
			float G = AshikhminGSF(nl, nv);
			//float G = SmithJointGGXVisibilityTerm (nl, nv, roughness);
			//Fresnel Function
			half3 F = FresnelTerm(specColor, lh);
			
			half3 specularTerm = G * D * F * PI;
			specularTerm = max(0, specularTerm);;				
			
			diffuse[l] =  attenColor *  diffuseTerm;
			specular[l] = specularTerm * attenColor * nl;
			kk[l] = acos(lv) / PI;
				
	    }	
	
			float surfaceReduction;
			surfaceReduction = 1.0 / (roughness*roughness + 1.0);
			float grazingTerm = saturate(smoothness + (1-oneMinusReflectivity));
			
			float3 k = kk[1] * 0.5 + 0.55;
			finalcolor.rgb =   albedo.rgb* ( diffuse[0] + diffuse[1] + diffuse[2] + indirectDiffuse ) * surface_diffuse_colour 
												 + specular[0]+ specular[1] 
												+ specColorWithIndirect*0.3 * surfaceReduction * FresnelLerp (specColor, grazingTerm, nv) ;						
		 
		 
		 	//finalcolor.rgb =   params.cAlbedoTex.rgb * ((diffuse[0] * 0.2 + diffuse[1] * 0.2 + diffuse[2] * 0.3 + diffuse[3] *k + indirectDiffuse * 0.2)) * (1-Metallic +0.04) * surface_diffuse_colour.rgb
			//									+ specular[0] * 0.4 + specular[1] * 0.4 + specular[2] * 0.3 + specular[3] *k
			//									+ surfaceReduction * FresnelLerp (specColorWithIndirect, grazingTerm, nv)* 0.3;
												
		float grey = 0.2125 * finalcolor.r + 0.7154 * finalcolor.g + 0.0721 * finalcolor.b;
		float3 greys = float3(grey, grey ,grey);
		finalcolor.rgb = lerp(greys, finalcolor.rgb, 1.1);
		
		// 皮肤部分使用原始光照模型
    float3 oldColor = float3(0.0,0.0,0.0);
    float3 LightDiffuse = float3(0.0,0.0,0.0);
    for (l = 0; l < MAX_LIGHT_NUM; ++l)
    {
    		float3 lightDir = lightPosition[l].xyz - (params.FI.fPw.xyz * lightPosition[l].w);
				float3 lightDirection = normalize(lightPosition[l].xyz - (params.FI.fPw.xyz * lightPosition[l].w));
				float lightDirLength = length(lightDir);
				float att = lerp(0, 1, 1 / dot(float3(1, lightDirLength, lightDirLength*lightDirLength), lightAttenuation[l].yzw));
    		float3 attenColor = diffuseColour[l].rgb;

    		float fNdotL = dot(params.FI.fNw.xyz, lightDirection);

       LightDiffuse += att * max(fNdotL, 0) * diffuseColour[l].rgb;
     }
    //oldColor.rgb = params.cAlbedoTex.rgb * saturate(LightDiffuse + indirectDiffuse.rgb);
	oldColor.rgb = params.cAlbedoTex.rgb * GetColorByLightGreaterOne(LightDiffuse + indirectDiffuse.rgb, params.SP);
		params.cLight = 1.03 * (oldColor.rgb * skin + finalcolor.rgb * (1 - skin));
		params.cFinal.rgb = params.cLight; 
}

PS_OUT main( VS_OUT IN ) 
{ 
	FragParams_pbr params = (FragParams_pbr)0;
	params.FI = fmt_input( IN );
	
	/// 设置渲染参数
	Set_SystemParams( params.SP );
	
	/// diffuse rt
	Calc_Pbr_Tex( params );
	
	/// alpha rejection
	Tex_Kill( params.cAlbedoTex.a );
	
	// calc normal
	Calc_Normal_ps( params.FI, params.cNormalTex );
	
	// calc pbr light model
	Calc_Pbr_Silk( params );
	
	/// fog
	Calc_Fog_Color( params.FI.fPw.w, params.cFinal.rgb );
	
	return fmt_output( params );
}

#endif


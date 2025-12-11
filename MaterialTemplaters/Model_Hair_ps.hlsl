#ifndef _Model_Hair_PS_H_
#define _Model_Hair_PS_H_

// Define In VS
#define __PS__

#ifndef HAIR_Sp
	#define HAIR_Sp 0
#endif

sampler2D DiffuseSampler 	: register(s0);
sampler2D NormalSampler 	: register(s1);
uniform float3 haircolor;
#include "ModelDef.inc"


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
PS_OUT fmt_output( FragParams params )
{
	PS_OUT OUT = (PS_OUT)0; 
#if FROZEN_ENANLE
	params.cFinal.rgb *= multiBlendColor.xyz * multiBlendColor.w;
#endif

	OUT.color = float4( params.cFinal.rgb, params.cDiffuseRT.a * params.FI.color.a * surface_diffuse_colour.a );		
	return OUT;
}

void Calc_Normal_Tex(inout FragParams params)
{
	
	float4 cNormalTex = float4(0.0,0.0,0.0,1.0);	
	//cNormalTex = tex2D(NormalSampler, params.FI.baseTC.xy);	
	//cNormalTex.g = 1 - cNormalTex.g;
	//Calc_Normal_ps(params.FI,cNormalTex);
	
	
	cNormalTex = tex2D(NormalSampler, params.FI.baseTC.xy);
	float3 normalInTangentSpace = UnpackScaleNormal(cNormalTex, 1);
	params.FI.fNw.xyz = Calc_Normal_ps( params.FI.fTw.xyz, params.FI.fBw.xyz, params.FI.fNw.xyz, normalInTangentSpace );
	params.FI.fNw.w = cNormalTex.a;
}
void Calc_Hair_Light_In_Ps( inout FragParams params )
{
#if LIGHT_CALC_TYPE == LIGHT_CALC_NONE
		params.cFinal.rgb *= params.FI.color.rgb;
		
#elif LIGHT_CALC_TYPE == LIGHT_CALC_VS
		#if BLEND_OP_0 == 3
      params.cFinal.rgb += params.FI.color.rgb;
    #else
			params.cFinal.rgb *= params.FI.color.rgb;
		#endif
		params.cFinal.rgb += Calc_Specular(params);
		//params.cFinal.rgb = params.cFinal.rgb  * 0.00001 +Calc_Specular(params);
#elif LIGHT_CALC_TYPE == LIGHT_CALC_PS
		float shadowFactor;
		float3 shadowColor;
		Calc_Shadow_Ps(params.FI, shadowFactor, shadowColor);

	  float3 Nn = params.FI.fNw.xyz;
		float3 Vn = params.FI.fView.xyz;

    /*#if HAIR_Sp == 0
		float4 sceneColor = derived_scene_colour * (1.0 - imodel_userdata.x) + actor_ambient_params * imodel_userdata.x;
    #endif*/

    float4 lightDiffuseColor[MAX_LIGHT_NUM];
		lightDiffuseColor[0] = light_diffuse_colour_array[0] * (1.0 - imodel_userdata.x) + actor_lightone_params * imodel_userdata.x;
		
    
    
    float3 directLightDiffuse = float3(0.0,0.0,0.0);
    float3 directLightSpecular = float3(0.0,0.0,0.0);
    
    
    // direct light
    float3 lightDir = light_position_array[0].xyz;
    float3 Ln = normalize(lightDir);
    float fNdotL = dot(Nn, Ln);

	#if HAIR_Sp == 0
		directLightDiffuse = max(fNdotL,0.8) ;
		directLightSpecular = Calc_Specular(params) * shadowFactor * (0.4 * (surface_emissive_colour.rgb - 1) * (surface_emissive_colour.rgb - 1) + 1); 
		// indirect light
		directLightDiffuse *= params.FI.color.rgb * surface_diffuse_colour.rgb * lerp(1,0.8,params.cDiffuseRT.r );    
    #else
		float lightness = surface_emissive_colour.r * 0.299 + surface_emissive_colour.g * 0.587 + surface_emissive_colour.b * 0.114;
		float3 emissivecolor = surface_emissive_colour  * lerp(1,0.8,( ( max(lightness,0.8) - 0.8 ) * (10/3)  ) );
		lightness = emissivecolor.r * 0.299 + emissivecolor.g * 0.587 + emissivecolor.b * 0.114;
		float diffuseK = 0.5*(lightness - 1) * (lightness - 1) + 0.5;
    
		directLightDiffuse = max(0.95,max(fNdotL,0.8))* diffuseK + 0.95 * (1-diffuseK);
		directLightSpecular = Calc_Specular(params) * shadowFactor * emissivecolor;    

		directLightDiffuse *= params.FI.color.rgb * surface_diffuse_colour.rgb * lerp(1.08,1,params.cDiffuseRT.r );    
	#endif

    params.cLight = saturate(directLightDiffuse ) * shadowFactor ;
    float bbb = params.cLight * params.cLight;

	#if HAIR_Sp == 0
		float3 aaa = max(surface_emissive_colour.rgb,0.2 * float3(bbb,bbb,bbb));
	#else
		bbb = max(lightness, 0.4 * bbb);
	#endif

    #if BLEND_OP_0 == 3
				params.cFinal.rgb = params.cFinal.rgb + params.cLight+ directLightSpecular;
    
    #else
		#if HAIR_Sp == 0
				params.cFinal.rgb = params.cLight  * aaa+  directLightSpecular + surface_emissive_colour.rgb * 0.2;
				params.cFinal.rgb = params.cFinal.rgb;/// *0.00001 + params.cLight;
		#else
				params.cFinal.rgb = params.cLight  * bbb +  directLightSpecular;
		#endif
    #endif

#endif

}


PS_OUT main( VS_OUT IN ) 
{ 
	FragParams params = (FragParams)0;
	params.FI = fmt_input( IN );
	
	/// …Ë÷√‰÷»æ≤Œ ˝
	Set_SystemParams( params.SP );
	
	/// diffuse rt
	Calc_Diffuse_Tex( DiffuseSampler, params );	
		
	//normal map
	Calc_Normal_Tex(params);
	
	/// alpha rejection
	Tex_Kill( params.cDiffuseRT.a );	
	
	/// lighting
	Calc_Hair_Light_In_Ps( params );
	
	/// fog
	Calc_Fog_Color( params.FI.fPw.w, params.cFinal.rgb );
	
	return fmt_output( params );
}

#endif





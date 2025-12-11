#ifndef _Model_LSScene_PS_H_
#define _Model_LSScene_PS_H_

// Define In VS
#define __PS__

#ifndef USE_EMISSIVE
	#define USE_EMISSIVE 0
#endif

sampler2D DiffuseSampler 	: register(s0);
sampler2D NormalSampler 	: register(s1);
sampler2D ReflectSampler 	: register(s2);
#if USE_EMISSIVE == 1
sampler2D EmissiveSampler   : register(s3);
#endif
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
	//OUT.color.rgb = OUT.color.rgb * 0.000001 + params.cLight.rgb;
	//OUT.color.a = 1;
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

PS_OUT main( VS_OUT IN ) 
{ 
	FragParams params = (FragParams)0;
	params.FI = fmt_input( IN );
	
	/// 设置渲染参数
	Set_SystemParams( params.SP );
	
	/// diffuse rt
	Calc_Diffuse_Tex( DiffuseSampler, params );
	
	//normal map
	//Calc_Normal_Tex(params);
	
	/// alpha rejection
	Tex_Kill( params.cDiffuseRT.a );	
	
	/// lighting
	Calc_Light_In_Ps( params );
	
	/// fog
	Calc_Fog_Color( params.FI.fPw.w, params.cFinal.rgb );
	
	return fmt_output( params );
}
PS_OUT mainN( VS_OUT IN ) 
{ 
	FragParams params = (FragParams)0;
	params.FI = fmt_input( IN );
	
	/// 设置渲染参数
	Set_SystemParams( params.SP );
	
	/// diffuse rt
	Calc_Diffuse_Tex( DiffuseSampler, params );

	#if LIGHT_CALC_TYPE == LIGHT_CALC_PS
		Calc_Normal_Tex(params);
	#endif
	/// alpha rejection
	Tex_Kill( params.cDiffuseRT.a );	
	
	/// lighting
	Calc_Light_In_Ps( params );

	/// emissive
	#if USE_EMISSIVE == 1
		float4 cEmissiveTex = tex2D(EmissiveSampler, params.FI.baseTC.xy);
		params.cFinal.rgb += params.cDiffuseRT.rgb * cEmissiveTex.r * step(imodel_userdata.w, 0.4);
	#endif
	
	/// fog
	Calc_Fog_Color( params.FI.fPw.w, params.cFinal.rgb );
	
	return fmt_output( params );
}


#endif





#ifndef _Model_LSChar_PS_H_
#define _Model_LSChar_PS_H_

// Define In VS
#define __PS__

sampler2D DiffuseSampler 	: register(s0);
sampler2D NormalSampler 	: register(s1);
sampler2D EnvSampler			: register(s2);

#include "ModelDef.inc"



FragInput fmt_input( VS_OUT IN )
{
	FragInput FI = (FragInput)0;
	FI.baseTC = IN.oUV0;
	FI.fPw = IN.oPw;
	FI.fNw = float4(normalize(IN.oNw),0);
	FI.fNo = normalize(IN.oNo);
	FI.oNw = normalize(IN.oNw);
	FI.fView = float4( normalize( IN.oV.xyz ), IN.oV.w );
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


PS_OUT main( VS_OUT IN ) 
{ 
	FragParams params = (FragParams)0;
	params.FI = fmt_input( IN );


	/// …Ë÷√‰÷»æ≤Œ ˝
	Set_SystemParams( params.SP );
	
	/// diffuse rt
	Calc_Diffuse_Tex( DiffuseSampler, params );
	
	/// alpha rejection
	Tex_Kill( params.cDiffuseRT.a );
	#if LIGHT_CALC_TYPE == LIGHT_CALC_PS
		/// env
		Calc_EnvMap( params );	
	#endif
	
	#if HIGHLIGHT_LSCHAR_ENABLE == 2 && LIGHT_CALC_TYPE == LIGHT_CALC_PS
		Calc_Normal_Tex( params);
	#endif

	
	/// lighting
	
//	float2 ReflUV = 1 - (normalize(mul(view_matrix, float4(params.FI.fNw.xyz, 0.0))).xy*0.5 + 0.5);        					
//	float4 envTexVar = tex2D(EnvSampler, ReflUV);
	
	Calc_Light_In_Ps( params );
	//, normalMapTexVar.a , envTexVar.rgb 
	
	/// fog
	Calc_Fog_Color( params.FI.fPw.w, params.cFinal.rgb );
	

	return fmt_output( params );
}


#endif





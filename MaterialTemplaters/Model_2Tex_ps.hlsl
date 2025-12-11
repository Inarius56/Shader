#ifndef _Model_2Tex_PS_H_
#define _Model_2Tex_PS_H_

// Define In VS
#define __PS__

sampler2D DiffuseSampler 	: register(s0);
sampler2D Diffuse2Sampler 	: register(s1);

#include "ModelDef.inc"


FragInput fmt_input( VS_OUT IN )
{
	FragInput FI = (FragInput)0;
	FI.baseTC = IN.oUV0;
	FI.fPw = IN.oPw;	
	FI.fNo = normalize(IN.oNo);
	FI.fNw = float4(normalize(IN.oNw),0);
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
	OUT.color = float4( params.cFinal.rgb, params.cDiffuseRT.a * params.FI.color.a * surface_diffuse_colour.a );

	return OUT;
}


PS_OUT main( VS_OUT IN ) 
{ 
	FragParams params = (FragParams)0;
	params.FI = fmt_input( IN );
	
	/// …Ë÷√‰÷»æ≤Œ ˝
	Set_SystemParams( params.SP );
	
	/// diffuse rt
	Calc_Diffuse_2Tex( DiffuseSampler, Diffuse2Sampler, params );
	
	/// alpha rejection
	Tex_Kill( params.cDiffuseRT.a );
	
	/// lighting
	Calc_Light_In_Ps( params );
	
	/// fog
	Calc_Fog_Color( params.FI.fPw.w, params.cFinal.rgb );
	
	return fmt_output( params );
}

#endif





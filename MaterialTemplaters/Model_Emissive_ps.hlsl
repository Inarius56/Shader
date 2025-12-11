#ifndef _Model_Emissive_PS_H_
#define _Model_Emissive_PS_H_

// Define In VS
#define __PS__

sampler2D DiffuseSampler : register(s0);
sampler2D EmissiveSampler : register(s1);

#include "ModelDef.inc"


struct FragParams_emissive
{
		FragParams ori;
		float4 cDiffuseTex;
		float4 cEmissiveTex;
};

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

PS_OUT fmt_output( FragParams_emissive params )
{
	PS_OUT OUT = (PS_OUT)0; 
	OUT.color = float4( params.ori.cFinal.rgb, params.ori.cDiffuseRT.a * params.ori.FI.color.a * surface_diffuse_colour.a );

	return OUT;
}

void Calc_Emissive_Tex(inout FragParams_emissive params)
{
	Calc_Diffuse_Tex( DiffuseSampler, params.ori );
	params.cEmissiveTex = tex2D(EmissiveSampler, params.ori.FI.baseTC.xy);
}

void Calc_Emissive(inout FragParams_emissive params)
{
	params.ori.cFinal.rgb += params.ori.cDiffuseRT.rgb * params.cEmissiveTex.r * step(imodel_userdata.w, 0.4);
}

PS_OUT main( VS_OUT IN ) 
{ 
	FragParams_emissive params = (FragParams_emissive)0;
	params.ori.FI = fmt_input( IN );
	
	/// …Ë÷√‰÷»æ≤Œ ˝
	Set_SystemParams( params.ori.SP );
	
	/// diffuse rt
	Calc_Emissive_Tex(params);
	
	/// alpha rejection
	Tex_Kill( params.ori.cDiffuseRT.a );
	
	/// env
	Calc_EnvMap( params.ori );
	
	/// lighting
	Calc_Light_In_Ps( params.ori );
	
	/// emissive
	Calc_Emissive(params);
	
	/// fog
	Calc_Fog_Color( params.ori.FI.fPw.w, params.ori.cFinal.rgb );
	
	return fmt_output( params );
}


#endif
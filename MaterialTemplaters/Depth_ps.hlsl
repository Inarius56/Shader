#ifndef _Depth_PS_H_
#define _Depth_PS_H_

// Define In VS
#define __PS__

sampler2D DiffuseSampler 	: register(s0);

#include "DepthDef.inc"


FragInput fmt_input( VS_OUT IN )
{
	FragInput FI = (FragInput)0;
#if USE_TEXCOORD == 1
	FI.baseTC = IN.oDepth;
#else
	FI.baseTC.z = IN.oDepth;
#endif
	return FI;
}

PS_OUT fmt_output( inout FragParams params )
{
	PS_OUT OUT = (PS_OUT)0; 
	OUT.color = float4(0,0,1,1);
	OUT.color.r = params.FI.baseTC.z;

	return OUT;
}

void Calc_Diffuse_Tex_Depth(sampler2D diffuseTex, inout FragParams params)
{
	params.cDiffuseRT = tex2D(diffuseTex, params.FI.baseTC.xy);				
}

PS_OUT main( VS_OUT IN ) 
{ 
	FragParams params = (FragParams)0;
	params.FI = fmt_input( IN );

	#if USE_TEXCOORD == 1 && ALPHATEST_ENABLE == 1
	/// diffuse rt
	Calc_Diffuse_Tex_Depth( DiffuseSampler, params );
	
	/// alpha rejection
	Tex_Kill( params.cDiffuseRT.a );
	#endif

	return fmt_output( params );
}


#endif





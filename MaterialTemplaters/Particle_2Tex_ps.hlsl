#ifndef _Particle_2Tex_PS_H_
#define _Particle_2Tex_PS_H_

// Define In VS
#define __PS__

sampler2D DiffuseSampler 	: register(s0);
sampler2D Diffuse2Sampler 	: register(s1);
#if DISSOLVE_EFFECT > 0
	sampler2D dissolveMap : register(s2);
#endif

#include "ParticleDef.inc"


FragInput fmt_input( VS_OUT IN )
{
	FragInput FI = (FragInput)0;
	FI.baseTC = IN.oUV0;
	FI.color = IN.oColour;
	FI.baseTC.xy = Calc_MeshUV(FI.baseTC.xy,sequenceFrameUVFactor);
	return FI;
}

PS_OUT fmt_output( FragParams params )
{
	PS_OUT OUT = (PS_OUT)0; 
	OUT.color = float4( params.cFinal.rgb, params.cDiffuseRT.a * params.FI.color.a * surface_diffuse_colour.a );
	#if DISSOLVE_EFFECT > 0
		OUT.color = Calc_Dissolve_Color_1(OUT.color, params.FI.baseTC.xy);
	#endif
	OUT.color = saturate(OUT.color);
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
	Calc_Light_Particle_In_Ps( params );
	
	return fmt_output( params );
}

#endif





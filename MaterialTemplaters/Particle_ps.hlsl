#ifndef _Particle_PS_H_
#define _Particle_PS_H_

// Define In VS
#define __PS__

#ifndef ENABLE_CLAMP
	#define ENABLE_CLAMP 0
#endif

sampler2D DiffuseSampler 	: register(s0);
#if DISSOLVE_EFFECT > 0
	sampler2D dissolveMap : register(s1);
#endif

#include "ParticleDef.inc"

FragInput fmt_input( VS_OUT IN )
{
	FragInput FI = (FragInput)0;
	FI.baseTC = IN.oUV0;
	if(useRibbon > 0.5)
	FI.baseTC.xy = Calc_RibbonUV(FI.baseTC.xy, useRibbon, useUDirection, widthRatio, blocks);
	else
	FI.baseTC.xy = Calc_MeshUV(FI.baseTC.xy,sequenceFrameUVFactor);
		
	FI.color = IN.oColour;
	return FI;
}

PS_OUT fmt_output( FragParams params )
{
	PS_OUT OUT = (PS_OUT)0;
	OUT.color = float4( params.cFinal.rgb
#if PER_ALPHA == 1
		* params.FI.color.a * surface_diffuse_colour.a
#endif
		,params.cDiffuseRT.a * params.FI.color.a * surface_diffuse_colour.a );
	#if DISSOLVE_EFFECT > 0
			OUT.color = Calc_Dissolve_Color_1(OUT.color, params.FI.baseTC.xy);
	#endif
		OUT.color = clamp(OUT.color, 0, 1);
		  
	return OUT;
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
	
	/// lighting
	Calc_Light_Particle_In_Ps( params );
	
	return fmt_output( params );
}

#endif





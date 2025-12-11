#ifndef _Particle_VS_H_
#define _Particle_VS_H_

// Define In VS
#define __VS__

#include "ParticleDef.inc"

VertInput fmt_input( VS_IN IN )
{
	VertInput VI 	= (VertInput)0;
	VI.position 	= float4( IN.position.xyz, 1 );
	VI.tc0				= IN.uv0.xyxy;
#if USE_VERTEXCOLOR == 1
	VI.vColor= IN.vColor;
#endif
	return VI;
}


VS_OUT fmt_output( VertParams params )
{
	VS_OUT OUT = (VS_OUT)0;
	OUT.oPos = params.ps;
	OUT.oUV0 = params.baseTC;
	OUT.oColour	= params.color;
	return OUT;
}

VS_OUT main( VS_IN IN )
{
	VertParams params	= (VertParams)0;
	params.VI = fmt_input( IN );
	
	/// …Ë÷√‰÷»æ≤Œ ˝
	Set_SystemParams( params.SP );
	
	/// calc position
	Calc_Position( params );
	
	/// calc uv
	Calc_Uv( params );
	
	/// calc lighting
	Calc_Light_Particle_In_Vs( params );
	
	return fmt_output( params );
}

#endif



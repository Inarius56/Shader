#ifndef _Depth_VS_H_
#define _Depth_VS_H_

// Define In VS
#define __VS__

#include "DepthDef.inc"

VertInput fmt_input( VS_IN IN )
{
	VertInput VI 	= (VertInput)0;
	VI.position 	= float4( IN.position.xyz, 1 );
#if VS_ANIMATION == 1
	VI.normal			= float4( IN.normal.rgb, 0 );
#endif
#if USE_TEXCOORD == 1
	VI.tc0				= IN.uv0.xyxy;
#endif
#if USE_SKIN == 1
	VI.blendIdx		= IN.blendIndex;
	VI.weight			= IN.blendWeight;
#endif
	return VI;
}


VS_OUT fmt_output( VertParams params )
{
	VS_OUT OUT = (VS_OUT)0;
	OUT.oPos = params.ps;
#if USE_TEXCOORD == 1
	OUT.oDepth = float4(params.baseTC.xy, -params.pv.z, 0);
#else
	OUT.oDepth = -params.pv.z;
#endif
	return OUT;
}

VS_OUT main( VS_IN IN )
{
	VertParams params	= (VertParams)0;
	params.VI = fmt_input( IN );
	/// calc position
	Calc_Position( params );
	
	/// calc uv
	Calc_Uv( params );
	
	return fmt_output( params );
}


#endif



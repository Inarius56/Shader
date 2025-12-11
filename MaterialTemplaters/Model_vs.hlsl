#ifndef _Model_VS_H_
#define _Model_VS_H_

// Define In VS
#define __VS__

#include "ModelDef.inc"

VertInput fmt_input( VS_IN IN )
{
	VertInput VI 	= (VertInput)0;
	VI.position 	= float4( IN.position.xyz, 1 );
	VI.normal			= float4( IN.normal.rgb, 0 );
	VI.tc0				= IN.uv0.xyxy;
#if USE_SKIN == 1
	VI.blendIdx		= IN.blendIndex;
	VI.weight			= IN.blendWeight;
#endif
#if USE_TANGENT == 1
	VI.tangent		= IN.tangent;
#endif
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
	OUT.oNw	= params.nw.xyz;
	OUT.oNo	= params.no.xyz;
	OUT.oV = float4( params.view.xyz, params.ps.z / params.ps.w );
	OUT.oPw	= float4( params.pw.xyz, -params.pv.z );
	OUT.oPo = params.po;
#if USE_TANGENT == 1
	OUT.oTw = params.tw.xyz;
	OUT.oBw	= params.bw.xyz;
#endif
#if SHADOWMAP_TYPE != SHADOWMAP_NONE
  OUT.oShadow = params.shadow;
#endif
#if XINGNING_EFFECT == 1
	OUT.oClipPos = params.ps;
	OUT.oViewNormal = params.nv;
#endif
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
	
	/// calc view
	Calc_View( params );
	
	/// calc lighting
	Calc_Light_In_Vs( params );
	
	/// calc shadow
	Calc_Shadow_Vs( params );
	
	return fmt_output( params );
}

#endif



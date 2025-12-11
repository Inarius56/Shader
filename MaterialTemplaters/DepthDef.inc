#ifndef _DepthDef_INC_
#define _DepthDef_INC_

#include "ShaderLib/ShadingParams.inc"
#ifdef __VS__
#include "ShaderLib/CalcPos.inc"
#include "ShaderLib/CalcUV.inc"
#endif
#ifdef __PS__
//#include "ShaderLib/Diffuse.inc"
#include "ShaderLib/TexKill.inc"
#endif

struct VS_IN
{
	float4 	position 	: POSITION;
#if VS_ANIMATION == 1
	float4  normal		: NORMAL;
#endif
#if USE_TEXCOORD == 1
	float2 	uv0				: TEXCOORD0;
#endif
#if USE_SKIN == 1
	BLD_IDX	blendIndex	: BLENDINDICES;
	float4	blendWeight		: BLENDWEIGHT;
#endif

};

struct VS_OUT
{
	float4 	oPos : POSITION;
#if USE_TEXCOORD == 1
	float4  oDepth : TEXCOORD0;
#else
	float  oDepth : TEXCOORD0;
#endif
};

struct PS_OUT
{
	float4	color : COLOR0;
};


#endif



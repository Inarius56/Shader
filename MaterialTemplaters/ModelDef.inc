#ifndef _ModelDef_INC_
#define _ModelDef_INC_

#include "ShaderLib/ShadingParams.inc"
#include "ShaderLib/Utility.inc"
#include "ShaderLib/CalcLight.inc"
#ifdef __VS__
#include "ShaderLib/CalcPos.inc"
#include "ShaderLib/CalcUV.inc"
#include "ShaderLib/CalcView.inc"
#endif
#ifdef __PS__
#include "ShaderLib/CalcPos.inc"
#include "ShaderLib/Diffuse.inc"
#include "ShaderLib/Fog.inc"
#include "ShaderLib/TexKill.inc"
#include "ShaderLib/EnvMap.inc"
#endif

struct VS_IN
{
	float4 	position 	: POSITION;
	float2 	uv0				: TEXCOORD0;
	float4  normal		: NORMAL;
#if USE_SKIN == 1
	BLD_IDX	blendIndex	: BLENDINDICES;
	float4	blendWeight		: BLENDWEIGHT;
#endif
#if USE_TANGENT == 1
	float4	tangent		: TANGENT;
#endif
#if USE_VERTEXCOLOR
	float4  vColor			: COLOR0;
#endif

};

#include "Model_VS_OUT.inc"

struct PS_OUT
{
	float4	color		: COLOR0;
};


#endif



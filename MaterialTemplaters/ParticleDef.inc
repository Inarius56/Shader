#ifndef _ParticleDef_INC_
#define _ParticleDef_INC_

#include "ShaderLib/ShadingParams.inc"
#include "ShaderLib/Utility.inc"
#include "ShaderLib/CalcLight.inc"
#include "ShaderLib/CalcUV.inc"
#ifdef __VS__
#include "ShaderLib/CalcPos.inc"
#include "ShaderLib/CalcView.inc"
#endif
#ifdef __PS__
#include "ShaderLib/Diffuse.inc"
#include "ShaderLib/TexKill.inc"
#endif

struct VS_IN
{
	float4 	position 	: POSITION;
	float2 	uv0				: TEXCOORD0;
#if USE_VERTEXCOLOR
	float4  vColor			: COLOR0;
#endif

};

#if USE_MODEL_VS_OUT
#include "Model_VS_OUT.inc"
#else
struct VS_OUT
{
	float4 oPos	: POSITION;
	float4 oUV0	: TEXCOORD0;
  float4 oColour : COLOR0;
};
#endif

struct PS_OUT
{
	float4	color		: COLOR0;
};


#endif



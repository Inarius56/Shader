#ifndef _FakePointLightDef_INC_
#define _FakePointLightDef_INC_

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
};

struct VS_OUT
{
	float4 	oPos			: POSITION;
	float4  oUVScreen	: TEXCOORD0;
	float3 	oRay			: TEXCOORD1;
};

struct PS_OUT
{
	float4	color		: COLOR0;
};


#endif



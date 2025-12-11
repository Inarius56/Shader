#ifndef _WaterDef_INC_
#define _WaterDef_INC_

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

#ifndef PBR_TIME
	#define PBR_TIME 0
#endif

#endif

#ifndef CALC_LIT
	#define CALC_LIT 0
#endif

struct VS_IN
{
	float4 	position 	: POSITION;
	float2 	uv0		: TEXCOORD0;
	float4  normal		: NORMAL;
};

struct VS_OUT
{
	float4 	oPos		: POSITION;
	float4  oUV		: TEXCOORD0;
	float4 oColor   : COLOR0;
	float4 oSpecColor : COLOR1;
	float4  oUVScreen	: TEXCOORD1;
	float3 	oEyeDir		: TEXCOORD2;
	float4  oCamFrontDir	: TEXCOORD3;
	float4  oPosInView	: TEXCOORD4;
};

struct PS_OUT
{
	float4	color		: COLOR0;
};


#endif



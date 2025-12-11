#ifndef _Model_VS_OUT_INC_
#define _Model_VS_OUT_INC_

struct VS_OUT
{
	float4 	oPos			: POSITION;
	float4  oUV0				: TEXCOORD0;
	float3 	oNw		: TEXCOORD1;
	float3 	oNo : TEXCOORD2;
	float4  oV	: TEXCOORD3;
	float4  oPw	: TEXCOORD4;
	float4  oPo	: TEXCOORD5;
#if USE_TANGENT == 1
	float3	oTw		: TEXCOORD6;
	float3 	oBw  : TEXCOORD7;
#endif       
#if SHADOWMAP_TYPE != SHADOWMAP_NONE
  float4 oShadow : TEXCOORD8;
#endif
#if XINGNING_EFFECT == 1
	float4 oClipPos : TEXCOORD9;
	float3 oViewNormal : TEXCOORD10;
#endif
  float4 oColour : COLOR0;
};

#endif

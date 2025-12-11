#ifndef _Diffuse_INC_
#define _Diffuse_INC_


float2 makeUV(float color)
{
	float2 LUTPos = float2(0,0);
	LUTPos.y = floor(color * 255 / 16) / 16;
	LUTPos.x = color * 255 % 16 / 16;
	return LUTPos;
}

float3 LUTColor(sampler2D lutTex, float3 textureColor)
{
		float3 color = float3(0,0,0);
		color.r = tex2Dlod(lutTex, float4(makeUV(textureColor.r), 0, 0)).r;
		color.g = tex2Dlod(lutTex, float4(makeUV(textureColor.g), 0, 0)).g;
		color.b = tex2Dlod(lutTex, float4(makeUV(textureColor.b), 0, 0)).b;
		return color;
}

void LUTCorrect(inout FragParams params)
{
	#if LUT_ENABLE == 1
		if (imodel_userdata.x == 0)
		{
			params.cDiffuseRT.xyz = LUTColor(LUTSampler, params.cDiffuseRT.xyz);
		}
	#endif
}

void Calc_Diffuse_Tex1(sampler2D diffuseTex, inout FragParams params)
{
	params.cDiffuseRT = float4(0,0,0,1);
#if USE_TEXLOD0
	float4 baseTexColour = tex2Dlod(diffuseTex, float4(params.FI.baseTC.xy,0,0));
#else
	float4 baseTexColour = tex2D(diffuseTex, params.FI.baseTC.xy);				
#endif
#if BLEND_OP_0 == 1
	params.cDiffuseRT.xyz = baseTexColour.xyz * 2.0;
#elif BLEND_OP_0 == 2
	params.cDiffuseRT.xyz = baseTexColour.xyz * 4.0;
#else
	params.cDiffuseRT.xyz = baseTexColour.xyz;
#endif
#if PER_ALPHA == 1
	params.cDiffuseRT *= baseTexColour.w;
#else
	params.cDiffuseRT.w = baseTexColour.w;
#endif
}

void Calc_Diffuse_Tex2(sampler2D diffuseTex2, inout FragParams params)
{
	//#if DIFFUSE_2_ENABLE
		float4 diffuse2TexColour = tex2D(diffuseTex2, params.FI.baseTC.zw);
  #if BLEND_OP_1 == 1
    params.cDiffuseRT.xyz *= diffuse2TexColour.xyz * 2.0;
  #elif BLEND_OP_1 == 2
    params.cDiffuseRT.xyz *= diffuse2TexColour.xyz * 4.0;
  #elif BLEND_OP_1 == 3
    params.cDiffuseRT.xyz += diffuse2TexColour.xyz;
  #else
    params.cDiffuseRT.xyz *= diffuse2TexColour.xyz;
  #endif
    params.cDiffuseRT.w *= diffuse2TexColour.w;
	//#endif
}

void Calc_Diffuse_2Tex( sampler2D diffuseTex, sampler2D diffuseTex2, inout FragParams params )
{
	Calc_Diffuse_Tex1(diffuseTex, params);	
	#if FROZEN_ENANLE
		params.cDiffuseRT.xyz *= tex0BlendColor.rgb;
	#endif
	Calc_Diffuse_Tex2(diffuseTex2, params);
	// lut
	LUTCorrect(params);
	params.cFinal = params.cDiffuseRT;

}

void Calc_Diffuse_Tex(sampler2D diffuseTex, inout FragParams params)
{
	Calc_Diffuse_Tex1(diffuseTex, params);
	#if FROZEN_ENANLE
		params.cDiffuseRT.xyz *= tex0BlendColor.rgb;
	#endif
	// lut
	LUTCorrect(params);
	params.cFinal = params.cDiffuseRT;
}


#endif
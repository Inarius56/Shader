#ifndef _Utility_INC_
#define _Utility_INC_

void Set_SystemParams( inout SystemParams params )
{
	params.bHDREnable = 0;//isystem_userdata.x;
	params.bLinearSpaceEnable = isystem_userdata.y;
	params.bLightGreaterOneEnable = abs(sign(isystem_userdata.z));
}

float3 GetColorByLightGreaterOne(float3 src, in SystemParams params)
{
	return lerp(saturate(src), src, params.bLightGreaterOneEnable);
}

// Legacy for compatibility with existing shaders
bool IsLinearSpace()
{
	if (isystem_userdata.y == 1)
        return true;
    else
        return false;
}

float GammaToLinearSpaceExact (float value)
{
    if (value <= 0.04045f)
        return value / 12.92f;
    else if (value < 1.0f)
        return pow((value + 0.055f)/1.055f, 2.4f);
    else
        return pow(value, 2.2f);
}

float3 GammaToLinearSpace (float3 sRGB)
{
    // Approximate version from http://chilliant.blogspot.com.au/2012/08/srgb-approximations-for-hlsl.html?m=1
    return sRGB * (sRGB * (sRGB * 0.305306011f + 0.682171111f) + 0.012522878f);

    // Precise version, useful for debugging.
    //return half3(GammaToLinearSpaceExact(sRGB.r), GammaToLinearSpaceExact(sRGB.g), GammaToLinearSpaceExact(sRGB.b));
}

float LinearToGammaSpaceExact (float value)
{
    if (value <= 0.0f)
        return 0.0f;
    else if (value <= 0.0031308f)
        return 12.92f * value;
    else if (value < 1.0f)
        return 1.055f * pow(value, 0.4166667f) - 0.055f;
    else
        return pow(value, 0.45454545f);
}

float3 LinearToGammaSpace (float3 linRGB)
{
    linRGB = max(linRGB, half3(0.f, 0.f, 0.f));
    // An almost-perfect approximation from http://chilliant.blogspot.com.au/2012/08/srgb-approximations-for-hlsl.html?m=1
    return max(1.055f * pow(linRGB, 0.416666667f) - 0.055f, 0.f);

    // Exact version, useful for debugging.
    //return half3(LinearToGammaSpaceExact(linRGB.r), LinearToGammaSpaceExact(linRGB.g), LinearToGammaSpaceExact(linRGB.b));
}

#define color_toLinear(c) isystem_userdata.y * GammaToLinearSpace(c.rgb) + (1 - isystem_userdata.y) * c.rgb
#define color_toGamma(c) isystem_userdata.y * LinearToGammaSpace(c.rgb) + (1 - isystem_userdata.y) * c.rgb

float4 tex2D_toLinear(sampler2D tex, float2 uv)
{
	float4 texColor = float4(0,0,0,1);
	texColor = tex2D(tex, uv);
	return float4(color_toLinear(texColor), texColor.a);
}

float4 tex2Dlod_toLinear(sampler2D tex, float4 uv)
{
	float4 texColor = float4(0,0,0,1);
	texColor = tex2Dlod(tex, uv);
	return float4(color_toLinear(texColor), texColor.a);
}


////////////////////////////////////////////////////////////////////////
// LinearizeDepthPS
////////////////////////////////////////////////////////////////////////
float DeviceDepthToEyeLinear(float fDepth, float nearZ, float farZ)
{
	float x = (nearZ - farZ) / (farZ * nearZ);
	float y = 1.0 / nearZ;
	return 1.0 / (x * fDepth + y);
}

#endif
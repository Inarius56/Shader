float4
fadeColor_fp(
        in float2 texCoord: TEXCOORD0,
        uniform float colour_amount,
        uniform float gray_amount,
        uniform sampler2D image : register(s0)
        ) : COLOR
{
	static const float3 coefficients = float3(0.1, 0.25, 0.11);
    static const float3 yellowcolor = float3(0.8, 0.8, 0);

    float4 colour = tex2D(image, texCoord);
    colour.rgb = ( dot(colour.rgb, coefficients) + colour.rgb * yellowcolor ) * gray_amount + colour.rgb * colour_amount;
    return colour;
}

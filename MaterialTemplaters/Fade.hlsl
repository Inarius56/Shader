float4
fade_fp(float4 pos : POSITION,
        in float2 texCoord: TEXCOORD0,
        uniform float colour_amount,
        uniform float gray_amount,
        uniform sampler2D image : register(s0)
        ) : COLOR
{
    static const float3 coefficients = float3(0.3, 0.59, 0.11);

    float4 colour = tex2D(image, texCoord);
    colour.rgb = dot(colour.rgb, coefficients) * gray_amount + colour.rgb * colour_amount;
    return colour;
}

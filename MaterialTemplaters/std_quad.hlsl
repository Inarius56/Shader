void
std_quad_vs(
        in float4 pos : POSITION,
        in float2 texCoord : TEXCOORD0,

        out float4 oPos : POSITION,
        out float2 oTexCoord : TEXCOORD0,

        uniform float4x4 worldViewProj
        )
{
    oPos = mul(worldViewProj, pos);

    oTexCoord = texCoord;
}


void
std_quad_vs_3_0(
        in float4 pos : POSITION,
        in float2 texCoord : TEXCOORD0,

        out float4 oPos : POSITION,
        out float2 oTexCoord : TEXCOORD0,

        uniform float4x4 worldViewProj
        )
{
    oPos = mul(worldViewProj, pos);

    oTexCoord = texCoord;
}

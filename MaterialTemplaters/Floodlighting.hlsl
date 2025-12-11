void quarter_down_sample_vp(
        in float4 pos : POSITION,
        in float2 texCoord : TEXCOORD0,

        out float4 oPos : POSITION,
        out float2 oTexCoord0 : TEXCOORD0,
        out float2 oTexCoord1 : TEXCOORD1,
        out float2 oTexCoord2 : TEXCOORD2,
        out float2 oTexCoord3 : TEXCOORD3,

        uniform float4 viewportSize,
        uniform float4x4 worldViewProj
        )
{
    oPos = mul(worldViewProj, pos);

    oTexCoord0 = texCoord + 2.0 * viewportSize.zw * float2(0, 0);
    oTexCoord1 = texCoord + 2.0 * viewportSize.zw * float2(1, 0);
    oTexCoord2 = texCoord + 2.0 * viewportSize.zw * float2(0, 1);
    oTexCoord3 = texCoord + 2.0 * viewportSize.zw * float2(1, 1);
}

float4 quarter_down_sample_fp(float4 pos : POSITION,
        in float2 uv0 : TEXCOORD0,
        in float2 uv1 : TEXCOORD1,
        in float2 uv2 : TEXCOORD2,
        in float2 uv3 : TEXCOORD3,
        uniform sampler2D image : register(s0)
        ) : COLOR
{
    float4 sum = tex2D(image, uv0) +
                 tex2D(image, uv1) +
                 tex2D(image, uv2) +
                 tex2D(image, uv3);

    return sum / 4;
}

void blur_vp(
        in float4 pos : POSITION,
        in float2 texCoord : TEXCOORD0,

        out float4 oPos : POSITION,
        out float2 oTexCoord0 : TEXCOORD0,
        out float2 oTexCoord1 : TEXCOORD1,
        out float2 oTexCoord2 : TEXCOORD2,
        out float2 oTexCoord3 : TEXCOORD3,

        // blur direction: (1, 0) for horizontal, (0, 1) for vertical
        uniform float2 direction,
        uniform float4 viewportSize,
        uniform float4x4 worldViewProj
        )
{
    oPos = mul(worldViewProj, pos);

    oTexCoord0 = texCoord + 2.0 * viewportSize.zw * -direction;
    oTexCoord1 = texCoord + 2.0 * viewportSize.zw * -direction / 2;
    oTexCoord2 = texCoord + 2.0 * viewportSize.zw * +direction / 2;
    oTexCoord3 = texCoord + 2.0 * viewportSize.zw * +direction;
}

float4 blur_fp(float4 pos : POSITION,
        in float2 uv0 : TEXCOORD0,
        in float2 uv1 : TEXCOORD1,
        in float2 uv2 : TEXCOORD2,
        in float2 uv3 : TEXCOORD3,
        uniform sampler2D image : register(s0)
        ) : COLOR
{
    return ((tex2D(image, uv0) + tex2D(image, uv3)) + 3 * (tex2D(image, uv1) + tex2D(image, uv2))) / 8;
}

void blend_vp(
        in float4 pos : POSITION,
        in float2 texCoord : TEXCOORD0,

        out float4 oPos : POSITION,
        out float2 oBaseTexCoord : TEXCOORD0,
        out float2 oBlurTexCoord : TEXCOORD1,

        uniform float4x4 worldViewProj
        )
{
    oPos = mul(worldViewProj, pos);

    oBaseTexCoord = texCoord;
    oBlurTexCoord = texCoord;
}

float4 blend_fp(float4 pos : POSITION,
        in float2 baseTexCoord : TEXCOORD0,
        in float2 blurTexCoord : TEXCOORD1,
        uniform sampler2D baseImage : register(s0),
        uniform sampler2D blurImage : register(s1),
        uniform float brightness,
        uniform float blur_amount,
        uniform float shine_amount
        ) : COLOR
{
    float4 baseColor = tex2D(baseImage, baseTexCoord);
    float4 blurColor = tex2D(blurImage, blurTexCoord);
    float4 outputColor = float4(1.0, 1.0, 1.0, 1.0);
    outputColor.x = (1.0 - (1.0 - baseColor.x)*(1.0 - blurColor.x * blur_amount));
    outputColor.y = (1.0 - (1.0 - baseColor.y)*(1.0 - blurColor.y * blur_amount));
    outputColor.z = (1.0 - (1.0 - baseColor.z)*(1.0 - blurColor.z * blur_amount));
    outputColor.x = outputColor.x <= 0 ? 0 : pow(outputColor.x, 1.0 / brightness);
    outputColor.y = outputColor.y <= 0 ? 0 : pow(outputColor.y, 1.0 / brightness);
    outputColor.z = outputColor.z <= 0 ? 0 : pow(outputColor.z, 1.0 / brightness);

    return outputColor + blurColor * blurColor * shine_amount;
}

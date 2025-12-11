void shadowbaking_vs(
		in float3 position : POSITION,
		in float2 uv0 : TEXCOORD0,

        out float4 oPosition : POSITION,
		out float4 oPosInView : TEXCOORD3,

		uniform float4x4 world_matrix,
        uniform float4x4 viewproj_matrix
           )
{
    float4 worldPos = mul(world_matrix, float4(position, 1.0));
    oPosition = mul( viewproj_matrix, worldPos);
	oPosInView = oPosition;
}

void shadowbaking_ps(float4 Position : POSITION,
	in float4 posInView : TEXCOORD3,
    out float4 oColour : COLOR)
{
	oColour = float4(0,0,0,1.0);
	oColour = posInView * 0.5 + 0.5;
}





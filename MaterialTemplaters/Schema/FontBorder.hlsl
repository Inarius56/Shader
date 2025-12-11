void
FontBorder_ps(float4 pos : POSITION,
    in float2 uv0 : TEXCOORD0,
    uniform sampler2D layer0 : register(s0),
    in float4 diffuse : COLOR0,
    uniform float4 borderColor,
    out float4 oColour : COLOR)
{			
		oColour = tex2D(layer0, uv0);

		if (oColour.w > 0.1)
		{	
				oColour = diffuse;
		}
		else if(oColour.x > 0.1)
		{
				oColour.xyz = borderColor.xyz;
				oColour.w = diffuse.w;
		}
}
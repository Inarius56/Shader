
float4 psColorMask(float4 pos : POSITION, float2 iTex : TEXCOORD,
					uniform float4 maskColor,					
					uniform float fAlpha,					
					uniform sampler2D sampScene : register(s0) ) : COLOR
{		
	float4 t = tex2D( sampScene, iTex );	
	float4 Color = float4(0,0,0,1);
	Color.rgb = t.rgb * (1-fAlpha) + maskColor.rgb * fAlpha;		
	Color.a = 1;
	return Color;
}
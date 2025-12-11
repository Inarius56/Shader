#include "PostProcessUtility.inc"

void copy_frame(float4 pos : POSITION, 	
float2 uv : TEXCOORD0,
 uniform sampler2D Tex0	:	register(s0), 
 out float4 colour : COLOR )
{
	colour =  tex2D( Tex0, uv.xy );
}

void ConvertToLinearSpace(float4 pos : POSITION, 	
float2 uv : TEXCOORD0,
 uniform sampler2D Tex0	:	register(s0), 
 out float4 colour : COLOR )
{
	colour =  tex2D( Tex0, uv.xy );
	colour.rgb = GammaToLinearSpace(colour.rgb);
}

void FinalConvertToGammaSpace( 	
float2 uv : TEXCOORD0,
 uniform sampler2D Tex0	:	register(s0), 
 out float4 colour : COLOR )
{
	colour =  tex2D( Tex0, uv.xy );
	colour.rgb = LinearToGammaSpace(colour.rgb);
}


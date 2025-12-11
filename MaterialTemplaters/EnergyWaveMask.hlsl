#define _UNROLL 
static float3 c_avg_rgb = float3(0.333, 0.334, 0.333);
float4 psEnergyWaveMask(float4 pos : POSITION, float2 iTex : TEXCOORD,
						uniform float fTime,
						uniform float4 vvp,
						uniform sampler2D sampMask : register(s0),
						uniform sampler2D sampScene : register(s1),
						uniform sampler2D sampNoise : register(s2) ) : COLOR
{
	float fMask = dot( tex2D(sampMask, iTex), c_avg_rgb );
	fMask = 1 - pow(0.01,fMask);

	float2 tNoise = iTex * 512 * vvp.zw;
	float noisy = tex2D( sampNoise, tNoise + float2( 0, fTime * 0.1 ) );
	noisy = (noisy * 2 - 1) * noisy;
	iTex += noisy * vvp.zw * fMask * lerp(64,32,fMask);
	
	float4 t = tex2D( sampScene, iTex );
	return t;
}
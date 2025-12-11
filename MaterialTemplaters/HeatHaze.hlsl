#define _UNROLL 

static float3 c_avg_rgb = float3(0.333, 0.334, 0.333);

float4 psHeatWave(float4 pos : POSITION, float2 iTex : TEXCOORD,
					uniform float fTime,
					uniform float4 vvp,
					uniform float fSpeed,
					uniform sampler2D sampScene : register(s0),
					uniform sampler2D sampNoise : register(s1) ) : COLOR
{
	//float s = 1 - min( 1, length(iTex - 0.5) / 0.2 );

	float2 tNoise = iTex * 512 * vvp.zw;
	float noisy = tex2D( sampNoise, tNoise + float2( 0, fTime * fSpeed ) );
	noisy = (noisy * 2 - 1) * lerp( 0.02, 0.07, noisy );
	iTex += noisy * 32 * vvp.zw;
	
	float4 t = tex2D( sampScene, iTex );
	return t;
}

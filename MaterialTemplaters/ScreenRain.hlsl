#define _UNROLL 


static float3 c_avg_rgb = float3(0.333, 0.334, 0.333);

float4 psScreenRainMix(float4 pos : POSITION, float2 iTex : TEXCOORD,
						uniform float fElapsedTime,
						uniform float fTrailWeakness,
						uniform sampler2D sampPrev : register(s0),
						uniform sampler2D sampCur : register(s1) ) : COLOR
{
	float4 tC = tex2D( sampCur, iTex );
	float4 tP = tex2D( sampPrev, iTex );
	//return lerp( tP, tC, fTrailWeakness * fElapsedTime );
	return tC + tP * (1 - fTrailWeakness * fElapsedTime);
}

float4 psScreenRain(float4 pos : POSITION, float2 iTex : TEXCOORD,
					uniform float3 vTrailColor,
					uniform float vTrailDensity,
					uniform float fTime,
					uniform float4 vvp,
					uniform sampler2D sampScene : register(s0),
					uniform sampler2D sampMask : register(s1),
					uniform sampler2D sampNoise : register(s2),
					uniform sampler2D sampMaskUB : register(s3) ) : COLOR
{
	float4 tMaskUB = tex2D( sampMaskUB, iTex );
	float fMaskUB = dot( tMaskUB, c_avg_rgb );
	float sin_mask = sin(fMaskUB * 1.5707963);
	float spe = pow(sin_mask,4);

	float fMask = dot( tex2D( sampMask, iTex ), c_avg_rgb );

	float2 tNoise = iTex * 512 * vvp.zw;
	float noisy = tex2D( sampNoise, tNoise + float2( 0, fTime * 0.05 ) );
	noisy = (noisy * 2 - 1) * noisy;
	iTex += noisy * vvp.zw * fMask * lerp(4,24,fMask);

	float4 tS = tex2D( sampScene, iTex );
	tS.rgb = lerp( tS, vTrailColor, fMask * vTrailDensity );
	tS.rgb = lerp( tS, tMaskUB, 1 - tMaskUB.a );
	tS.rgb += spe;
	return tS;
}

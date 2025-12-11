#define _UNROLL 


float4 psDrunk(		in float4 pos : POSITION,
					in float2 iTex : TEXCOORD0,
					uniform float fTime,
					uniform float fStrength,
					uniform float4 vvp,
					uniform sampler2D sampScene : register(s0),
					uniform sampler2D sampNoise : register(s1) ) : COLOR
{

	float2 tNoise = iTex * 512 * vvp.zw;
	float noisy = tex2D( sampNoise, 0.5 * (tNoise + float2( 0, fTime * 0.05 )) );
	noisy = (noisy * 2 - 1) * lerp( 0.02, 0.07, noisy );
	iTex += noisy * 32 * vvp.zw;
	
	
	float strengthK = fStrength;////1.05;   /// 1 ~ x   Хэ
	float normalStrength = strengthK -1;
	normalStrength = min(0,min(normalStrength , 0.6));
	normalStrength = normalStrength / 0.6;   //// 0 ~ 1  Хэ

	float d2 = (iTex.x - 0.5)*(iTex.x - 0.5) + (iTex.y - 0.5)*(iTex.y - 0.5);
	float d2div = lerp(1,1.2,normalStrength) * d2 / 0.5;   ///  0 ~ 1  Хэ
	
	float uvk = lerp(1,0.94,normalStrength) * lerp(1,0.98,d2div);   ///0.95*0.98 ~ 1   Дж
	
	
	float4 fragColor =0;
	float2 eye1Jitter = 0.01 * float2(-cos(fTime / (2 / (strengthK-0.7))), sin(fTime / (2 / (strengthK-0.7)))* cos(fTime / (2 / (strengthK-0.7))));
	float2 eye2Jitter = 0.005 * float2(cos(fTime / (1 / (strengthK-0.5)))*cos(fTime / (1 / (strengthK-0.5))), sin(fTime / (1 / (strengthK-0.5))));
	

	
	float2 eye1Offset = float2(0.0,-0.003*strengthK) + (strengthK-0.5) * eye1Jitter;
	float2 eye2Offset = float2(0.003,-0.005*strengthK) + (strengthK-0.5) * eye2Jitter;

	
	float4 t1 = tex2D( sampScene, iTex * uvk + d2div * eye1Offset );
	float4 t2 = tex2D( sampScene, iTex * uvk + d2div * eye2Offset );
	

	return t1 * 0.5 + t2 * 0.5;

}

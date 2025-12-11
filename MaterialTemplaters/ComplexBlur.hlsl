#define _UNROLL 

float4 psComplexBlur(		float2 iTex : TEXCOORD,
					uniform float4 vvp,
					uniform float fDistance,
					uniform float fUnblured,
					uniform float fStrength,
					uniform sampler2D sampScene : register(s0) ) : COLOR
{
	float2 vdir = iTex - 0.5;
	float flen = length( vdir );
	vdir *= 1 / flen * max( 0, flen - fUnblured ) * 8 * vvp.zw;

	float4 sum = 0;
	_UNROLL for ( int i = 0; i < 8; ++i )
	{
		float4 t = tex2D( sampScene, iTex - vdir * (i+fDistance) );
		sum += t;
	}
	//sum = sum * fStrength + tex2D( sampScene, iTex );
	sum *= fStrength;
	float p = dot( sum, float3(0.333, 0.334, 0.333) );
	sum += (1 - p) * tex2D( sampScene, iTex );

	sum.rgb = saturate(sum.rgb);
	return sum;
}

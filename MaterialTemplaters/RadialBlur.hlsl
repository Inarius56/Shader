#define _UNROLL 

float4 psRadialBlur(		float2 iTex : TEXCOORD,
					uniform float4 vvp,
					uniform float fStrength,
					uniform float fUnblured,
					uniform sampler2D sampScene : register(s0) ) : COLOR
{
	float2 vdir = iTex - 0.5;
	float flen = length( vdir );
	vdir *= 1 / flen * max( 0, flen - fUnblured ) * 8 * vvp.zw;

	float4 sum = 0;
	_UNROLL for ( int i = 0; i < 16; ++i )
	{
		float4 t = tex2D( sampScene, iTex + fStrength * vdir * i );
		sum += t;
	}
	sum /= 16;
	return sum;
}

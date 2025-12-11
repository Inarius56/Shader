#define _UNROLL 

static const float c_GBlurWeights[13] = 
{
    0.002216,
    0.008764,
    0.026995,
    0.064759,
    0.120985,
    0.176033,
    0.199471,
    0.176033,
    0.120985,
    0.064759,
    0.026995,
    0.008764,
    0.002216,
};

float4 psGaussianBlur(float4 pos : POSITION, float2 iTex : TEXCOORD,
					uniform float4 vvp,
					uniform float2 offset,
					uniform float fStrength,
					uniform sampler2D sampScene : register(s0) ) : COLOR
{
	offset *= 2 * vvp.zw;

	float4 sum = 0;
	_UNROLL for ( int i = -6; i <= 6; ++i )
	{
		float4 t = tex2D( sampScene, iTex + fStrength * offset * i );
		sum += t * c_GBlurWeights[i + 6];
	}
	return sum;
}
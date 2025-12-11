#define _UNROLL 
#define TAU 6.28318530718
#define MAX_ITER 5

static float3 c_avg_rgb = float3(0.333, 0.334, 0.333);

float4 psLightMove(float4 pos : POSITION, float2 iTex : TEXCOORD,
					uniform float fTime,
					uniform float fSpeed,
					uniform sampler2D sampScene : register(s0),
					uniform sampler2D sampNoise : register(s1) ) : COLOR
{
	float time = fTime * fSpeed * 0.2 + 23.0;
    float2 uv = iTex;
	
    float2 p = fmod(uv * TAU, TAU) - 250.0;
    float2 i = p;
    float c = 1.0;
    float inten = 0.005;

    for (int n = 0; n < MAX_ITER; n++) {
        float t = time * (1.0 - (3.5 / float(n + 1)));
        i = p + float2(cos(t - i.x) + sin(t + i.y), sin(t - i.y) + cos(t + i.x));
        c += 1.0 / length(float2(p.x / (sin(i.x + t) / inten), p.y / (cos(i.y + t) / inten)));
    }

    c /= float(MAX_ITER);
    c = 1.17-pow(abs(c), 1.4);
	float pownum = pow(abs(c), 8.0);
    float3 colour = float3(pownum, pownum, pownum);
    //colour = clamp(colour + float3(0.0, 0.0, 0.0), 0.0, 1.0);

    float4 fragColor = float4(colour, 1.0)*0.5 + tex2D(sampScene,uv);
	return fragColor;
}
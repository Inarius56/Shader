struct a2v
{
	float4 position : POSITION;
	float2 texcoord : TEXCOORD0;
};

struct v2f
{
	float4 position : POSITION;
	float2 texcoord : TEXCOORD0;
};

static const int NUM_OCCLUSION_TEST_SAMPLES = 32;
static float2 occlusionTestSampleOffsets[NUM_OCCLUSION_TEST_SAMPLES] = {
	float2(0.658752441406,-0.0977704077959),
	float2(0.505380451679,-0.862896621227),
	float2(-0.678673446178,0.120453640819),
	float2(-0.429447203875,-0.501827657223),
	float2(-0.239791020751,0.577527523041),
	float2(-0.666824519634,-0.745214760303),
	float2(0.147858589888,-0.304675519466),
	float2(0.0334240831435,0.263438135386),
	float2(-0.164710089564,-0.17076793313),
	float2(0.289210408926,0.0226817727089),
	float2(0.109557107091,-0.993980526924),
	float2(-0.999996423721,-0.00266989553347),
	float2(0.804284930229,0.594243884087),
	float2(0.240315377712,-0.653567194939),
	float2(-0.313934922218,0.94944447279),
	float2(0.386928111315,0.480902403593),
	float2(0.979771316051,-0.200120285153),
	float2(0.505873680115,-0.407543361187),
	float2(0.617167234421,0.247610524297),
	float2(-0.672138273716,0.740425646305),
	float2(-0.305256098509,-0.952270269394),
	float2(0.493631094694,0.869671344757),
	float2(0.0982239097357,0.995164275169),
	float2(0.976404249668,0.21595069766),
	float2(-0.308868765831,0.150203511119),
	float2(-0.586166858673,-0.19671548903),
	float2(-0.912466347218,-0.409151613712),
	float2(0.0959918648005,0.666364192963),
	float2(0.813257217407,-0.581904232502),
	float2(-0.914829492569,0.403840065002),
	float2(-0.542099535465,0.432246923447),
	float2(-0.106764614582,-0.618209302425)
};

float4x4 vertexTransform;
float4 color = float4(0.0,0.0,0.0,0.0);
float3 lightObjPosRadius;
sampler2D depthMap: register(s0);
sampler2D tex: register(s1);

float calcVisibility()
{
	float numVisibleSamples = 0;

	for (int i = 0; i != NUM_OCCLUSION_TEST_SAMPLES; ++i)
	{
		float2 uv = lightObjPosRadius.xy + occlusionTestSampleOffsets[i] * lightObjPosRadius.z;
		uv = uv * float2(0.5, -0.5) + float2(0.5, 0.5);

		if (uv.x >= 0 && uv.x <= 1 &&
			uv.y >= 0 && uv.y <= 1 &&
			tex2D(depthMap, uv).x > 0.999)
		{
			++numVisibleSamples;	
		}
	}

	return (float)numVisibleSamples / NUM_OCCLUSION_TEST_SAMPLES;
}

v2f lensFlare_vp(a2v input)
{
	v2f output;
	output.position = mul(vertexTransform, input.position);
	output.texcoord = input.texcoord;
	return output;
}

float4 lensFlare_fp(v2f input) : COLOR0
{
	float4 c = tex2D(tex, input.texcoord) * color;
	c.a *= calcVisibility();
	return c;
}

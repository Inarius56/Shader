uniform float4x4 sceneCamProjMat;
uniform float4 viewport_size;
uniform float4 fov_samplingRadius_occlusionRange;

sampler2D depthMap : register(s0);

static const int kernelSize = 64;
static float3 kernel[kernelSize] =
{
	float3(0.1058996, -0.225847, 0.07388928),
	float3(0.2490156, -0.7089797, 0.08289462),
	float3(0.4514665, 0.4807889, 0.161732),
	float3(0.1385268, 0.1955787, 0.9457654),
	float3(0.1317618, 0.521488, -0.8388212),
	float3(0.4691584, 0.5071891, -0.3686014),
	float3(0.3664, 0.4222094, -0.1165669),
	float3(0.8745453, 0.2709869, -0.2733346),
	float3(0.02024577, -0.7797946, 0.3126302),
	float3(0.4621755, -0.01393253, -0.5343856),
	float3(-0.7214282, 0.210229, 0.3876619),
	float3(-0.003349229, 0.856683, -0.02647791),
	float3(0.5804359, -0.6747428, -0.08820023),
	float3(0.03146793, -0.3796379, 0.8733468),
	float3(0.2268098, -0.2971199, -0.1877737),
	float3(0.2801335, 0.07264145, -0.8190038),
	float3(0.09682728, -0.410822, -0.7520159),
	float3(-0.1633892, 0.2876242, -0.8504074),
	float3(-0.6799845, 0.1351887, 0.1447983),
	float3(0.4925364, 0.02097932, 0.8471743),
	float3(0.3851371, 0.1567314, 0.1843074),
	float3(-0.4182226, 0.6539604, 0.05806429),
	float3(-0.07437578, -0.4044704, -0.2276383),
	float3(-0.4645377, -0.1662424, -0.2457019),
	float3(-0.8443137, 0.125603, 0.4117476),
	float3(-0.7044039, 0.4457723, 0.3866891),
	float3(0.2589621, 0.867705, -0.112641),
	float3(-0.3194188, -0.5647023, 0.6235557),
	float3(0.2369573, -0.0014206, -0.4804466),
	float3(-0.4378985, 0.6831034, -0.4591225),
	float3(-0.332114, -0.311841, 0.4719219),
	float3(0.3417599, -0.03577846, 0.9109596),
	float3(-0.39227, 0.6516256, 0.145015),
	float3(0.4418923, 0.1287006, 0.713366),
	float3(-0.1631543, -0.1440308, 0.6366481),
	float3(-0.5349482, -0.640564, 0.2491606),
	float3(-0.3321258, -0.3747577, -0.3674941),
	float3(-0.2731919, -0.1433859, 0.6769626),
	float3(-0.2792184, 0.1335169, 0.06689546),
	float3(-0.9164986, -0.02476616, -0.0431233),
	float3(-0.7171922, 0.2447023, -0.6288724),
	float3(0.0007952989, -0.02063318, 0.8551918),
	float3(-0.3064038, 0.581476, 0.6483251),
	float3(-0.3464301, -0.7511604, -0.030356),
	float3(-0.4811307, -0.5094486, 0.1943509),
	float3(-0.712402, 0.3126173, 0.3776516),
	float3(-0.02512877, 0.1855982, -0.1764062),
	float3(0.6283092, 0.3235035, -0.2069241),
	float3(0.3835402, -0.6958995, -0.006776443),
	float3(0.1231542, -0.1789159, 0.225706),
	float3(0.53245, -0.1004773, -0.4848658),
	float3(0.003475558, 0.3432736, -0.02992521),
	float3(0.4240621, -0.2093243, -0.3341477),
	float3(0.1802572, -0.1878866, 0.5058719),
	float3(0.2542596, -0.697333, 0.188255),
	float3(0.6554515, 0.2192541, -0.4388036),
	float3(-0.2076959, -0.1324389, -0.02591686),
	float3(0.5984678, -0.265606, -0.1782514),
	float3(0.7076376, 0.1625891, -0.162337),
	float3(-0.2477823, -0.6423129, 0.3934449),
	float3(0.8433481, -0.4759277, -0.1678308),
	float3(-0.2748819, -0.06591967, 0.3969646),
	float3(-0.4652372, 0.6326816, 0.2293044),
	float3(-0.3049, 0.4536735, -0.4981332)
};

float3 getViewSpacePos(float2 screenUV)
{
	float aspect = viewport_size.x * viewport_size.w;
	float f = tan(fov_samplingRadius_occlusionRange.x / 2);
	float z = tex2D(depthMap, screenUV).x;
	return float3((screenUV - 0.5) * float2(2 * aspect, -2) * (z * f), -z);
}

float4 genAO_fp(float4 pos : POSITION,
         in float2 texCoord : TEXCOORD0) : COLOR
{
	float3 center = getViewSpacePos(texCoord);

	float AO = 0.0;

	for (int i = 0; i < kernelSize; ++i)
	{
		float3 samplePos = center + kernel[i] * fov_samplingRadius_occlusionRange.y;
		float4 sampleClipPos = mul(sceneCamProjMat, float4(samplePos, 1));
		float2 sampleUV = sampleClipPos.xy / sampleClipPos.w * float2(0.5, -0.5) + 0.5;

		float sampleDepth = -tex2D(depthMap, sampleUV).r;
		AO += step(samplePos.z, sampleDepth) *
				(saturate(sampleUV) == sampleUV) *
				step(abs(center.z - sampleDepth), fov_samplingRadius_occlusionRange.z);
	}

	return 1 - smoothstep(0.5, 1, AO / (kernelSize-1));
}

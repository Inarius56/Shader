float3 godRays(float decay,
               float exposure,
               sampler2D lightTexture,
               float2 lightPos,
               float2 uv)
{
	const int maxNumSamples = 100;

	float2 samplePos = uv;
	float2 samplePosStep = float2(lightPos - uv) / maxNumSamples;

	float3 color = 0;

	float illuminationDecay = decay;

	for (int i = 0; i < maxNumSamples && illuminationDecay > 0.05; ++i)
	{
		samplePos += samplePosStep;
		color += tex2D(lightTexture, samplePos).rgb * illuminationDecay;
		illuminationDecay *= decay;
	}

	return color * exposure;
}

float4 genGodRays_fp(float4 pos : POSITION,
         in float2 texCoord : TEXCOORD0,
         uniform sampler sunRT: register(s0),
			uniform float4 sunPos_decay_exposure) : COLOR
{
	return float4(godRays(sunPos_decay_exposure.z, sunPos_decay_exposure.w, sunRT, sunPos_decay_exposure.xy, texCoord), 1);
}

float4 addGodRays_fp(float4 pos : POSITION,
         in float2 texCoord : TEXCOORD0,
         uniform sampler sceneRT: register(s0),
         uniform sampler sunWithGodRaysRT: register(s1)) : COLOR
{
	return float4(tex2D(sceneRT, texCoord).rgb + tex2D(sunWithGodRaysRT, texCoord).rgb, 1);
}

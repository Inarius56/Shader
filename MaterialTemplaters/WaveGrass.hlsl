
#ifndef USE_ANIMATION
	#define USE_ANIMATION 1
#endif

#ifndef USE_RANDOM_TEX
	#define USE_RANDOM_TEX 0
#endif

struct VS_INPUT
{
	float4 Position : POSITION0;
	float3 Normal	: NORMAL0;
	float2 Texcoord : TEXCOORD0;
#if USE_RANDOM_TEX == 1
	float3 CenterPos : TEXCOORD1;
#endif
};

struct VS_OUTPUT
{
	float4 Position : POSITION0;
	float4 Color : COLOR0;
	float2 Texcoord : TEXCOORD0;
};

float4 WaveGrass(float4 offset, float4 interactivePos, float4 vertexPos, float4 propertyParam)
{	
	//求交互点与顶点间的距离
	float2 vectorDistance = vertexPos.xz - interactivePos.xz;
	float distance = vectorDistance.x * vectorDistance.x + vectorDistance.y * vectorDistance.y;
	distance = sqrt(distance);
	//如果两点间的距离大于MAX_DISTANCE,则顶点不需要特殊处理
	if( distance > propertyParam.x )
	{
		return offset;
	}
	else
	{
		float sin = vectorDistance.y / distance;
		float cos = vectorDistance.x / distance;
		float moveDistance = propertyParam.x - distance;
		float interactiveOffsetX = moveDistance * cos * propertyParam.y;
		float interactiveOffsetZ = moveDistance * sin * propertyParam.z;
		offset.x += interactiveOffsetX;
		offset.z += interactiveOffsetZ;
		return offset;
	}
}


VS_OUTPUT mainVS(VS_INPUT In,
uniform float4x4 WorldViewProj,
uniform float4x4 WorldView,
uniform float3 LightAmbient,
uniform float3 LightDiffuse,
uniform float3 LightDir,
uniform float3 LightSpecular,
uniform float  Shininess,
uniform float3 MaterialAmbient,
uniform float3 MaterialDiffuse,
uniform float3 MaterialSpecular,
#if USE_ANIMATION == 1
uniform float4x4 World,
uniform float4 interactivePos,
uniform float4 propertyParam,
#if USE_RANDOM_TEX == 1
	uniform float time,
	uniform float4 windControl,
	uniform float2 windControl2,
	uniform float3 waveControl,
	uniform float4 windDirMatrixParam,
	uniform float2 waveSize,
	uniform sampler2D vtNoise,
#else
	uniform float4 offset,
#endif
#endif
out float fogLength : TEXCOORD1
)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	

#if USE_ANIMATION == 1

	//计算顶点动画
	float4 factor = float4(1,1,1,1) - In.Position.wwww;
	float4 vertexPosWorld = mul(World, float4(In.Position.xyz, 1.0f));
	
#if USE_RANDOM_TEX == 1
	float2 windDir = windControl.xy;
	float windStrength = windControl.z;
	
	float waveF = windControl2.y * pow(windStrength, 0.1);
	float waveA = waveControl.x;
	float waveUVSpeed = waveControl.y;
	float waveUVScale = waveControl.z;
	
	windDir = normalize(windDir);
	float2 posWorldXZ = vertexPosWorld.xz;
	float3 localPos = In.Position.xyz - In.CenterPos.xyz;

	// calc uv
	float2x2 windDirMatrix2x2 = float2x2(windDirMatrixParam.x,windDirMatrixParam.y,
																				windDirMatrixParam.z, windDirMatrixParam.w);
	float2 posUV = mul(windDirMatrix2x2, posWorldXZ);
	posUV = frac(posUV/waveSize);
	posUV = posUV * waveUVScale - time * float2(1,0) * waveUVSpeed;
	float waveParam = tex2Dlod(vtNoise, float4(posUV.xy, 0, 0));
	
	
	// calc wave
	float grassHeightParam = saturate(localPos.y/200);
	float heightParamOffset = pow(grassHeightParam, 0.9);
	float n = 0.7;
	float heightParamF = 1 - (n * windControl2.x/10) * grassHeightParam;
	// 0<=difference<=10
	float difference = windControl.w;
	float2 posXZ = frac(posWorldXZ/waveSize) * (difference/10) + float2(0.45, 0.45) * (1-(difference/10));
	float wave = (posXZ.x + posXZ.y) * 0.5;
	float3 windDirOffset = float3(windDir.x * windStrength, 0, windDir.y * windStrength);
	
	float3 waveMove = float3(0,0,0);
	waveMove = waveA * sin(time * waveF * heightParamF* wave) + windDirOffset * waveParam * heightParamOffset;
	waveMove *= factor.w;
	waveMove = WaveGrass(float4(waveMove.xyz, 0), interactivePos, vertexPosWorld, propertyParam);
	waveMove *= factor.w;

	// final pos
	float grassLength = length(localPos);
	localPos.x += waveMove.x;
	localPos.z += waveMove.z;
	In.Position.xyz = In.CenterPos.xyz + normalize(localPos) * grassLength;
	
#else
	
	float4 waveOffset = WaveGrass(offset, interactivePos, vertexPosWorld, propertyParam);
	In.Position = In.Position + factor * waveOffset;
	
#endif

#else

#endif
	
	
	Out.Position = mul(WorldViewProj, float4(In.Position.xyz, 1.0f));
	//计算光照
	//Ambient
	float3 ambient = LightAmbient * MaterialAmbient;
	//Diffuse
	float4 normal = mul(WorldView, float4(In.Normal.xyz, 0));
	normal = normalize(normal);
	float3 lightDir = normalize(-LightDir);
	float3 diffuse = MaterialDiffuse * LightDiffuse * abs(dot(normal.xyz, lightDir));
	//specular
	float3 specular;
	float4 eyePosition = mul(WorldView, float4(In.Position.xyz, 1.0f));
	float3 HalfDir = normalize(lightDir - eyePosition.xyz);
	float nDotH = max(dot(normal, HalfDir), 0);
	specular = nDotH*diffuse.r <= 0 ? 0 : pow(nDotH, Shininess) * LightSpecular * MaterialSpecular;
	//emissive
	float3 emissive = float3(0.2, 0.2, 0.2);
	float3 finalColour = ambient + diffuse + specular + emissive;
	Out.Color.xyz = finalColour;
	Out.Color.w = 1;
	Out.Texcoord.xy = In.Texcoord;
	fogLength = -eyePosition.z;
	return Out;
}


float Fogging(float depthInView, float4 fogType, float4 fogParam)
{
		float fogFactor = 0.0;
		fogFactor += fogType[0];
		fogFactor += fogType[1] * exp(- depthInView * fogParam.x);
		//fogFactor += fogType[2] * exp(- (depthInView * fogParam.x) * (depthInView * fogParam.x));
		fogFactor += fogType[3] * saturate((fogParam.z - depthInView) * fogParam.w);
		
		return fogFactor;
}

float4 mainPS(
	VS_OUTPUT In
	,uniform sampler2D tex : register(s0)
	,uniform float4 fog_params
	,uniform float4 fog_colour
	,uniform float4 fog_type
	,uniform float4 imodel_userdata
	,in float fogLength : TEXCOORD1
) : COLOR 
{
	float4 Color = tex2D(tex, In.Texcoord.xy);
	clip( Color.a - imodel_userdata.z );

	float3 texColor = Color.rgb;
	float3 finalColour = In.Color.rgb * texColor;

	float f = Fogging(fogLength, fog_type, fog_params);
	finalColour = lerp( fog_colour.rgb, finalColour, f );

	return float4(finalColour, Color.a);
}

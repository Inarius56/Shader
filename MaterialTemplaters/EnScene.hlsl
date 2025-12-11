// SkyDome
void SkyDome_V(float4 Pos:POSITION,
							float2 Tex:TEXCOORD0,
							uniform float4x4 worldViewProjMatrix,
							uniform float4x4 textureMatrix,
							out float4 oPos:POSITION,
							out float2 oTex:TEXCOORD0
																		)
{
	oPos = mul(worldViewProjMatrix ,Pos);
	oPos.z = oPos.w * 0.999999;
	oTex = mul(textureMatrix, float4(Tex.x, Tex.y, 0, 1)).xy;
}

void SkyDome_F(float4 Pos:POSITION,
				float2 Tex:TEXCOORD0,
							uniform sampler2D cloundSampler: register(s0),
							out float4 col		: COLOR0)
{
	col = tex2D(cloundSampler, Tex);
}




struct VertexXYZNUV
{
   float4 pos:		POSITION;
   float3 normal:	NORMAL;
   float2 tc:		TEXCOORD0;//顶点纹理坐标
};

//////////////////////////////////////////////////////////
////skyDome shader
//////////////////////////////////////////////////////////

struct OutputDiffuseLighting
{
	float4 pos:     POSITION;
	//float3 tc0_Depth:      TEXCOORD0;
	float2 tc1:      TEXCOORD1;
	float2 tc2:      TEXCOORD2;
	float4 diffuse: COLOR;
	//float fog: FOG;
};

//天空背景顶点程序
OutputDiffuseLighting En_sky_dome_v(VertexXYZNUV input,
		uniform float3 SUN_POSITION,
		uniform float3 SUN_COLOUR,
		//uniform float TIME_OF_DAY,
		//uniform float HIGHT,
		//uniform float MIE_EFFECT_AMOUNT,
		//uniform float TURBIDITY,
		//uniform float VERTEX_HEIGHT_EFFECT,
		//uniform float SUN_HEIGHT_EFFECT,
		//uniform float POWER,
		uniform float3 EN_DOME_PARAM1,//(TIME_OF_DAY,HIGHT,MIE_EFFECT_AMOUNT)
		uniform float4 EN_DOME_PARAM2,//(TURBIDITY,VERTEX_HEIGHT_EFFECT,SUN_HEIGHT_EFFECT,POWER)
		uniform float4x4 worldViewProjMatrix,
		uniform float FOG_AMOUNT = 1)
{

  OutputDiffuseLighting o = (OutputDiffuseLighting)0;

	//useful values   干啥用的？
	float4 normVPos = normalize(input.pos);	
	
	//Rayliegh texture coordinates.	
	//o.tc1.x = TIME_OF_DAY;
	o.tc1.x = EN_DOME_PARAM1.x;
	o.tc1.y = saturate(1.0-normVPos.y);
	
	//input.pos.y = input.pos.y + HIGHT;
	input.pos.y = input.pos.y + EN_DOME_PARAM1.y;
	o.pos = mul(worldViewProjMatrix, input.pos);
	o.pos.z = o.pos.w * 0.999999;
	//float horizonVPos = 1.0 - abs(normalize(input.pos).y);
	float horizonVPos = 1.0 - abs(normVPos.y);

	float horizonSPos = 1.0 - abs(SUN_POSITION.y);
	
	//Mie texture coordinates	
	float fwd_scattering_amount = saturate(dot(normVPos.xyz, SUN_POSITION));
	
	//float mie_amount = (pow(fwd_scattering_amount,POWER));
	//float sunHeightEffect = (SUN_POSITION.y * normVPos.y * SUN_HEIGHT_EFFECT);
	//float vertexHeightEffect = (horizonVPos * horizonSPos * VERTEX_HEIGHT_EFFECT);	
	//float additional = saturate(fwd_scattering_amount * (vertexHeightEffect + sunHeightEffect) + TURBIDITY);
	//o.tc2.xy = (mie_amount + additional) * MIE_EFFECT_AMOUNT;	
		
	float mie_amount = (pow(fwd_scattering_amount,EN_DOME_PARAM2.w));
	float sunHeightEffect = (SUN_POSITION.y * normVPos.y * EN_DOME_PARAM2.z);
	float vertexHeightEffect = (horizonVPos * horizonSPos * EN_DOME_PARAM2.y);	
	float additional = saturate(fwd_scattering_amount * (vertexHeightEffect + sunHeightEffect) + EN_DOME_PARAM2.x);	
	o.tc2.xy = (mie_amount + additional) * EN_DOME_PARAM1.z;	
	
	//o.fog = FOG_AMOUNT;
	o.diffuse.xyz = SUN_COLOUR;
	o.diffuse.w = mie_amount + FOG_AMOUNT;

	return o;
}

//天空背景像素程序
void En_sky_dome_p(OutputDiffuseLighting i,
		uniform float weight,
		uniform sampler2D mieSampler: register(s0),
		uniform sampler2D rayleighSampler: register(s1),
		uniform sampler2D rayleighExSampler: register(s2),
		uniform float4  ambientCol,
		out float4 col		: COLOR
		)
{
		
	// Final colour
	float4 colour;

	//stage 0 - stars
	float4 ray = tex2D( rayleighSampler, i.tc1 );
	float4 rayEx = tex2D( rayleighExSampler, i.tc1 );
	float4 mie = tex2D( mieSampler, i.tc2 );

	colour.a = i.diffuse.a;
	
	//stage 1 - rayleigh
	colour.rgb = ray.rgb * ray.a * weight + rayEx.rgb * rayEx.a * (1-weight) ;
	//stage 2 - mie
	colour.rgb = mie.rgb * colour.rgb + colour.rgb;
	colour.rgb *= ambientCol.xyz * ambientCol.w;

	col = colour;
}

//////////////////////////////////////////////////////////
////sun and moon shader
//////////////////////////////////////////////////////////
struct OUTPUT
{
	float4 pos: POSITION;
	float2 tc0: TEXCOORD0;	
};
//太阳、月亮顶点程序
OUTPUT En_sunandmoon_vp( VertexXYZNUV input,
		uniform float4x4 worldViewProjMatrix 
		)
{
	OUTPUT o = (OUTPUT)0;
	o.pos = mul(worldViewProjMatrix,input.pos );
	o.pos.z = o.pos.w;
	o.tc0 = input.tc;
	return o;
}
//太阳、月亮像素程序
float4 En_sunandmoon_fp( OUTPUT i ,
			uniform sampler2D diffuseSampler: register(s0)
			) : COLOR0
{
	float4 diffuseMap = tex2D( diffuseSampler, i.tc0 );
	float4 colour = diffuseMap ;	
	return colour;
}

OUTPUT En_flare_vp( VertexXYZNUV input,
		uniform float4x4 worldViewProjMatrix 
		)
{
	OUTPUT o = (OUTPUT)0;
	o.pos = mul(worldViewProjMatrix,input.pos );
	o.tc0 = input.tc;
	return o;
}
float4 En_flare_fp( OUTPUT i ,
			uniform float intensity,
			uniform sampler2D diffuseSampler: register(s0)
			) : COLOR0
{
	float4 diffuseMap = tex2D( diffuseSampler, i.tc0 );
	//TODO : fog colour

	float4 colour = diffuseMap;
	colour.w *= intensity ;	
	return colour;
}

//////////////////////////////////////////////////////////
////cloud shader
//////////////////////////////////////////////////////////
	float4 cloudLighting(
	in float light,
	in float4 diffuse,
	in float4 diffuseMap,	
	in float rimDetectWidth,
	in float rimDetectPower,
	in float scatteringPower,
	in float scatteringStrength,
	in float rimPower,
	in float rimStrength,
	in float4 fogColour,
	in float4 fogAmount,
	in float3 lcolor
	 )
{	
	float density = diffuseMap.w;
	float scattering = pow( light, scatteringPower + 1e-5 );
	float rimDetect = pow((1.0 - saturate(density - rimDetectWidth)), rimDetectPower + 1e-5);	
	float rimScattering = pow( light, rimPower + 1e-5 );
	float litRim = rimDetect * rimScattering;
	
	//darken diffuse map based on sunlight / ambient lighting amount.
	float4 colour = diffuse;
	
	//add all the scattering stuff
	colour.xyz += lcolor * scattering * scatteringStrength + lcolor * litRim * rimStrength;
	colour.w = diffuseMap.w;
	
	//and blend to fog colour
	colour.xyz = lerp(colour.xyz, fogColour.xyz, fogAmount.xyz);
	return colour;
}

//顶云顶点程序
void En_cloudv( 	float4 pos:     POSITION,	
				float2 tc:     TEXCOORD0,
	   		out float4 opos:    POSITION,
	   		out float2 t1:      TEXCOORD1,
	   		out float2 ntc:			TEXCOORD2,
	   		out float3 normal:			TEXCOORD3,
	   		uniform float4	textureTile,
			uniform float	windSpeed,
	   		uniform float4x4 worldViewProjMatrix ,
	   		uniform float4x4 worldMatrix,
			uniform float farClipDistance
)
{	
	worldMatrix[0].w=0;
	worldMatrix[1].w=0;
	worldMatrix[2].w=0;
	//float4 pointpos = mul(worldMatrix, pos);
	//normal = normalize( pointpos.xyz);
	//opos = mul(worldViewProjMatrix ,pos);
	
	float4 trasPos = pos;
	trasPos.y += textureTile.z;
	float4 pointPos = mul(worldMatrix, trasPos);
	normal = normalize(pointPos);
	opos = mul(worldViewProjMatrix, trasPos);
	
	opos.z = opos.w * 0.999999;
	opos = opos * (farClipDistance - 100);
	t1 = tc * textureTile.xy;
	
	t1.x = t1.x;
	t1.y = t1.y + windSpeed;

	ntc = tc ;

	
}
//顶云像素程序
void En_cloudp(float4 pos:     POSITION,
	float2 tc1:      TEXCOORD1,
	   	float2 ntc:      TEXCOORD2,
	   	float3 normal:			 TEXCOORD3,//顶点位置
			//uniform float	scatteringStrength,
			//uniform float	scatteringPower,
			//uniform float	rimStrength,
			//uniform float	rimPower,
			//uniform float	rimDetectPower,
			//uniform float	rimDetectWidth,
			uniform float4 rimParam,
	    uniform float4 fogColour,
	    uniform float4 control,//控制跟雾颜色的混合度的
	    uniform float4 dLight,//光线位置,w位存放scatteringStrength
	    uniform float4 lcolor, //太阳光照颜色，w位存放scatteringPower
	    uniform float4 surfaceAmbientCol,//材质环境光颜色
			uniform float4  ambientCol,//环境光颜色
			out  float4 col:COLOR,
			uniform sampler2D lcloud: register(s0),
			uniform sampler2D fogSampler: register(s1)
			
			) 
{	
	float4 diffuseMap = tex2D( lcloud, tc1);
	float4 fogAmount = tex2D( fogSampler, ntc);	
			
	fogAmount = saturate( fogAmount + control.xxxx );
	
	float light = saturate( dot( normalize(dLight.xyz), normal.xyz ) ) ;	
	//控制受环境光影响的程度
	float4 diffuse = diffuseMap * ambientCol * surfaceAmbientCol * control.z + diffuseMap * (1 - control.z);
	float4 colour = cloudLighting( light, diffuse, diffuseMap, rimParam.w, rimParam.z, lcolor.w, dLight.w, rimParam.y, rimParam.x, fogColour, fogAmount ,lcolor);
	//float4 colour = cloudLighting( light, diffuse, diffuseMap, rimDetectWidth, rimDetectPower, scatteringPower, scatteringStrength, rimPower, rimStrength, fogColour, fogAmount ,lcolor);
	colour.w = diffuseMap.w;
	colour.w *= control.w;
	
	col =  colour;
}

//环云顶点程序
void En_ringcloudv( 	float4 pos:   POSITION,	
				float2 tc:     					TEXCOORD0,
	   		out float4 opos:    	 	POSITION,
	   		out float2 t0:      		TEXCOORD0,
	   		out float3 normal: 			TEXCOORD1,
	   		//out float  intensity :	TEXCOORD2,
	   		out float2 ntc			 :	TEXCOORD3,
	   		//uniform float parallax ,  
	   		uniform float4x4 worldViewProjMatrix ,
	   		uniform float4x4 worldMatrix,
			uniform float farClipDistance,
	   		uniform	float4 cameraPos,
	   		//uniform float	textureTile
			uniform	float4 offsetParam // x存放textureTile y存放vSpeed z存放parallax
				)
{		
	
	pos.y -= cameraPos.y * offsetParam.z*0.000001;
	worldMatrix[0].w=0;
	worldMatrix[1].w=0;
	worldMatrix[2].w=0;
	float4 pointpos = mul(worldMatrix, pos);
	normal = normalize( pointpos.xyz);
	opos = mul(worldViewProjMatrix ,pos);
	opos.z = opos.w * 0.999999;
	opos = opos / abs(opos.w) * (farClipDistance - 100);
	t0 = tc ;
	t0.x = t0.x * offsetParam.x;
	ntc = t0;
	t0.y = t0.y + offsetParam.y;
	
}
//环云像素程序
void En_ringcloudp(float4 pos:POSITION,
								float2 tc0:      TEXCOORD0,
								float3 normal: 			TEXCOORD1,
								//float  intensity: TEXCOORD2,
								float2 ntc			 :	TEXCOORD3,
								//uniform float scatteringStrength ,
								//uniform float scatteringPower ,
								//uniform float rimStrength ,
								//uniform float rimPower ,
								//uniform float rimDetectPower ,
								//uniform float rimDetectWidth ,
								
								uniform float4 rimParam,
								
								uniform float4 fogColour, 
								uniform float4 lcolor, //光照颜色,w位存放scatteringPower
								uniform float4 dLight,//光线方向,w位存放scatteringStrength
						    
								uniform float4 surfaceAmbientCol,//材质环境光颜色
								uniform float4  ambientCol,//环境光颜色								
								uniform float4 control,//控制跟雾颜色的混合度的
								
								out  float4 col:COLOR,
								uniform sampler2D hcloud: register(s0),
								uniform sampler2D fogSampler: register(s1)
								) 
{	
	
	float4 diffuseMap = tex2D( hcloud, tc0);
	float4 fogAmount;
	fogAmount = tex2D( fogSampler, ntc );
	
	fogAmount = saturate( fogAmount + control.xxxx );	
	float light = saturate( dot( normalize(dLight.xyz), normal.xyz ) );	

	//控制受环境光影响的程度
	float4 diffuse = diffuseMap * ambientCol * surfaceAmbientCol * control.z + diffuseMap * (1 - control.z);
	float4 colour = cloudLighting(
							light,
							diffuse,
							diffuseMap,
							rimParam.w,
							rimParam.z,
							lcolor.w, 
							dLight.w,
							rimParam.y,
							rimParam.x,
							fogColour,
							fogAmount,
							lcolor //光照颜色
							);

	float distance = -2.0 * abs(ntc.y - 0.5) + 1.0;

	colour.w = colour.w *  min( distance/(control.y + 0.00001), 1) * control.w;

	col = colour;

}



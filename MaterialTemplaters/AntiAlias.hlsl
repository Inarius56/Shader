/*---------------------------    Anti-Aliasing Algorithms    -----------------------*/

//////////////////////////////////////////////////////////////////////////////////////
//																																									//
//																			M.L.A.A.																		//
//															Morphological Anti-Aliasing													//
//////////////////////////////////////////////////////////////////////////////////////

uniform float4 cTargetSize;
uniform float cOffset;	//采样的偏移量(单位是像素)
uniform float maxSearchSteps;
uniform float threshold;


#ifndef MAX_SEARCHSTEPS
#define MAX_SEARCHSTEPS 16
#endif

#ifndef NUM_DISTANCE
#define NUM_DISTANCE 32
#endif

#ifndef AREA_SIZE
#define AREA_SIZE (NUM_DISTANCE * 5)
#endif

//乘加函数
float4 mad(float4 m, float4 a, float4 d)
{
	return m * a + d;
}

//求边界划分像素三角形的面积
float2 Area(sampler2D areaTex, float2 distance, float e1, float e2)
{
	float2 pixcoord = NUM_DISTANCE * round(4.0 * float2(e1, e2)) + (16.0 / maxSearchSteps - pow(0.5, maxSearchSteps / 4.0)) * float2(-distance.x , distance.y);
	float2 texcoord = pixcoord / (AREA_SIZE - 1.0);
	return tex2Dlod(areaTex, float4(texcoord, 0, 0)).rg;
}


//MLAA VS Output
struct MLAAVSOutput
{
	float4 position	:	POSITION;
	float2 texcoord	:	TEXCOORD0;
};

MLAAVSOutput MLAA_VS(
	float4 position	:	POSITION, 
	float2 texcoord	:	TEXCOORD0, 
	uniform float4x4 worldViewProj
	)
{
	MLAAVSOutput output;
	output.position = mul(worldViewProj, position);
	output.texcoord = texcoord;
	return output;
}

//使用Luminance系数进行边缘检测
float4 MLAA_EdgeDetectionLuminancePS(
	float4 position	:	POSITION, 
	float2 texcoord	:	TEXCOORD0, 
	uniform sampler2D colorTex
	)	:	COLOR
{
	float3 weight = float3(0.2126, 0.7152, 0.0722);
	float4 pixelSize = cOffset / cTargetSize;
	//texcoord += (0.5, 0.5) / cTargetSize.xy;
	
	float L				= dot(tex2D(colorTex, texcoord).rgb, weight);
	float Lleft		= dot(tex2D(colorTex, texcoord - float2(pixelSize.x, 0)).rgb, weight);
	float Lright	= dot(tex2D(colorTex, texcoord + float2(pixelSize.x, 0)).rgb, weight);
	float Ltop		= dot(tex2D(colorTex, texcoord - float2(0, pixelSize.y)).rgb, weight);
	float Lbottom	= dot(tex2D(colorTex, texcoord + float2(0, pixelSize.y)).rgb, weight);
	
	float4 delta	= abs(L.xxxx - float4(Lleft, Ltop, Lright, Lbottom));
	float4 edges	= step(threshold.xxxx, delta);
	
//	clip(-1.0 * (dot(edges, 1.0) == 0.0));
	
	return edges;
}

//使用深度进行边缘检测
float4 MLAA_EdgeDetectionDepthPS(
	float4 position	:	POSITION, 
	float2 texcoord	:	TEXCOORD0, 
	uniform sampler2D depthTex
	)	:	COLOR
{
	float4 pixelSize = cOffset / cTargetSize;
	
	float D				= tex2D(depthTex, texcoord);
	float Dleft		= tex2D(depthTex, texcoord - float2(pixelSize.x, 0));
	float Dright	= tex2D(depthTex, texcoord + float2(pixelSize.x, 0));
	float Dtop		= tex2D(depthTex, texcoord - float2(0, pixelSize.y));
	float Dbottom	= tex2D(depthTex, texcoord + float2(0, pixelSize.y));
	
	float4 delta	= abs(D.xxxx - float4(Dleft, Dtop, Dright, Dbottom));
	float4 edges	= step(threshold.xxxx * 1000.0, delta);//使用同一个threshold进行计算，更改其数量级
	
//	clip(-1.0 * (dot(edges, 1.0) == 0.0));
		
	return edges;
}

//查找横向左边边长(像素数)
float SearchXLeft(sampler2D edgesTex, float2 texcoord)
{
	float4 pixelSize = cOffset / cTargetSize;

	texcoord -= float2(1.5, 0.0) * pixelSize;
	float e = 0.0;
	
	float2 tag;
	tag.x = maxSearchSteps;
	tag.y = 0;
	for(int i = 0; i < MAX_SEARCHSTEPS; i++)
	{
		e = tex2D(edgesTex, texcoord).g;
		//[flatten]
		if(e < 0.9 && tag.x == maxSearchSteps)
		{
			tag.x = i;
			tag.y = e;
		}
		texcoord -= float2(2.0, 0.0) * pixelSize;
	}
	
	return max(-2.0 * tag.x - 2.0 * tag.y, -2.0 * maxSearchSteps);
}

//查找横向右边边长
float SearchXRight(sampler2D edgesTex, float2 texcoord)
{
	float4 pixelSize = cOffset / cTargetSize;

	texcoord += float2(1.5, 0.0) * pixelSize;
	float e = 0.0;
	
	float2 tag;
	tag.x = maxSearchSteps;
	tag.y = 0;
	for(int i = 0; i < MAX_SEARCHSTEPS; i++)
	{
		e = tex2D(edgesTex, texcoord).g;
		//[flatten]
		if(e < 0.9 && tag.x == maxSearchSteps)
		{
			tag.x = i;
			tag.y = e;
		}
		texcoord += float2(2.0, 0.0) * pixelSize;
	}
		
	return min(2.0 * tag.x + 2.0 * tag.y, 2.0 * maxSearchSteps);
}

//查找纵向上边边长
float SearchYUp(sampler2D edgesTex, float2 texcoord)
{
	float4 pixelSize = cOffset / cTargetSize;

	texcoord -= float2(0.0, 1.5) * pixelSize;
	float e = 0.0;

	float2 tag;
	tag.x = maxSearchSteps;
	tag.y = 0;
	for(int i = 0; i < MAX_SEARCHSTEPS; i++)
	{
		e = tex2D(edgesTex, texcoord).r;
		//[flatten]
		if(e < 0.9 && tag.x == maxSearchSteps)
		{
			tag.x = i;
			tag.y = e;
		}
		texcoord -= float2(0.0, 2.0) * pixelSize;
	}

	return max(-2.0 * tag.x - 2.0 * tag.y, -2.0 * maxSearchSteps);
}

//查找纵向下边边长
float SearchYDown(sampler2D edgesTex, float2 texcoord)
{
	float4 pixelSize = cOffset / cTargetSize;

	texcoord += float2(0.0, 1.5) * pixelSize;
	float e = 0.0;
	
	float2 tag;
	tag.x = maxSearchSteps;
	tag.y = 0;
	for(int i = 0; i < MAX_SEARCHSTEPS; i++)
	{
		e = tex2D(edgesTex, texcoord).r;
		//[flatten]
		if(e < 0.9 && tag.x == maxSearchSteps)
		{
			tag.x = i;
			tag.y = e;
		}
		texcoord += float2(0.0, 2.0) * pixelSize;
	}
	
	return min(2.0 * tag.x + 2.0 * tag.y, 2.0 * maxSearchSteps);
}

//计算混合权重
float4 MLAA_BlendingWeightCalculationPS(
	float4 position	:	POSITION, 
	float2 texcoord	:	TEXCOORD0, 
	uniform sampler2D edgesTex, 
	uniform sampler2D areaTex
	)	:	COLOR
{
	float4 pixelSize = cOffset / cTargetSize;

	float4 weights = 0.0;
	
	float2 e = tex2D(edgesTex, texcoord).rg;//此处应为点采样，有待改进
	
//	[branch]
	if(e.g)
	{
		float2 d = float2(SearchXLeft(edgesTex, texcoord), SearchXRight(edgesTex, texcoord));
		
		float4 coords = mad(float4(d.x, -0.25, d.y + 1.0, -0.25), pixelSize.xyxy, texcoord.xyxy);
		float e1 = tex2D(edgesTex, coords.xy).r;
		float e2 = tex2D(edgesTex, coords.zw).r;
		
		weights.rg = Area(areaTex, (d), e1, e2);
	}
	
//	[branch]
	if(e.r)
	{
		float2 d = float2(SearchYUp(edgesTex, texcoord), SearchYDown(edgesTex, texcoord));
		
		float4 coords = mad(float4(-0.25, d.x, -0.25, d.y + 1.0), pixelSize.xyxy, texcoord.xyxy);
		float e1 = tex2D(edgesTex, coords.xy).g;
		float e2 = tex2D(edgesTex, coords.zw).g;
		
		weights.ba = Area(areaTex, (d), e1, e2);
	}
	
	return weights;
}

float4 MLAA_NeighbourhoodBlendingPS(
	float4 position	:	POSITION, 
	float2 texcoord	:	TEXCOORD0, 
	uniform sampler2D colorTex	:	register(s0), 
	uniform sampler2D blendTex	:	register(s1)
	)	:	COLOR
{
	float4 pixelSize = cOffset / cTargetSize;
	
	float4 topLeft	= tex2D(blendTex, texcoord);
	float bottom		= tex2D(blendTex, texcoord + float2(0.0, 1.0) * pixelSize.xy).g;
	float right			= tex2D(blendTex, texcoord + float2(1.0, 0.0) * pixelSize.xy).a;
	float4 a				= float4(topLeft.r, bottom, topLeft.b, right);
	
	float sum = dot(a, 1.0);
	
//	[branch]
	if(sum > 0.0)
	{
		float4 o = a * pixelSize.yyxx;
		float4 color = 0.0;
		//根据权重混合——加权求和
		color = mad(tex2D(colorTex, texcoord + float2(0.0, -o.r)), a.r, color);
		color = mad(tex2D(colorTex, texcoord + float2(0.0,  o.g)), a.g, color);
		color = mad(tex2D(colorTex, texcoord + float2(-o.b, 0.0)), a.b, color);
		color = mad(tex2D(colorTex, texcoord + float2( o.a, 0.0)), a.a, color);
		//相当于使权重总和为1
		return color / sum;
	}
	else
	{
		//不受其他像素的影响
		return tex2D(colorTex, texcoord);
	}
}





//////////////////////////////////////////////////////////////////////////////////////
//																																									//
//																			D.L.A.A.																		//
//												Directionally Localized Anti-Aliasing											//
//////////////////////////////////////////////////////////////////////////////////////

#define TFU2_HIGH_PASS
#define VECTORIZED_SEARCH



//DLAA VS Output
struct DLAAVSOutput
{
	float4 position	:	POSITION;
	float2 texcoord	:	TEXCOORD0;
};

DLAAVSOutput DLAA_VS(
	float4 position	:	POSITION, 
	float2 texcoord	:	TEXCOORD0, 
	uniform float4x4 worldViewProj
	)
{
	DLAAVSOutput output;
	output.position = mul(worldViewProj, position);
	output.texcoord = texcoord;
	return output;
}

//偏移采样函数宏定义
#define LD(o, dx, dy) o=tex2D(tex, texcoord + float2(dx, dy) * pixelSize);

float GetIntensity(float3 rgb)
{
	return dot(rgb, float3(0.33f, 0.33f, 0.33f));
}


float4 DLAA_EdgeDetectionPS(
	float4 position	:	POSITION, 
	float2 texcoord	:	TEXCOORD0, 
	uniform sampler2D tex : register(s0)
	)	:	COLOR
{
	float4 pixelSize = 1.0 / cTargetSize;
	
	float4 center, left, right, top, bottom;
	
	LD(center,  0,   0)
	LD(left,   -1,   0)
	LD(right,   1,   0)
	LD(top,     0,  -1)
	LD(bottom,  0,   1)
	
	float4 edges = 4.0 * abs((left + right + top + bottom) - 4.0 * center);
	float edges_lum = GetIntensity(edges.xyz);
	
	return float4(center.xyz, edges_lum);
}


float4 DLAA_BlendingColorPS(
	float4 position	:	POSITION, 
	float2 texcoord	:	TEXCOORD0, 
	uniform sampler2D tex : register(s0)//此处为上一步处理的RT
	)	:	COLOR
{
	float4 pixelSize = 1.0 / cTargetSize;
	
	const float lambda = 3.0f;
	const float epsilon = 0.1f;
	
	//----								查找短边								----
	float4 center, left_01, right_01, top_01, bottom_01;
	
	LD( center,      0,   0 )
	LD( left_01,  -1.5,   0 )
	LD( right_01,  1.5,   0 )
	LD( top_01,      0,-1.5 )
	LD( bottom_01,   0, 1.5 )
	
	float4 w_h = 2.0f * ( left_01 + right_01 );
	float4 w_v = 2.0f * ( top_01 + bottom_01 );
	
	#ifdef TFU2_HIGH_PASS
	
		// Softer (5-pixel wide high-pass)
		float4 edge_h = abs( w_h - 4.0f * center ) / 4.0f;
		float4 edge_v = abs( w_v - 4.0f * center ) / 4.0f;
		
	#else
	
		// Sharper (3-pixel wide high-pass)
		float4 left, right, top, bottom;

		LD( left,  -1,  0 )
		LD( right,  1,  0 )
		LD( top,    0, -1 )
		LD( bottom, 0,  1 )
        
		float4 edge_h = abs( left + right - 2.0f * center ) / 2.0f;
		float4 edge_v = abs( top + bottom - 2.0f * center ) / 2.0f;
	
	#endif
	
	float4 blurred_h = ( w_h + 2.0f * center ) / 6.0f;
	float4 blurred_v = ( w_v + 2.0f * center ) / 6.0f;

	float edge_h_lum = GetIntensity( edge_h.xyz );
	float edge_v_lum = GetIntensity( edge_v.xyz );
	float blurred_h_lum = GetIntensity( blurred_h.xyz );
	float blurred_v_lum = GetIntensity( blurred_v.xyz );

	float edge_mask_h = saturate( ( lambda * edge_h_lum - epsilon ) / blurred_v_lum );
	float edge_mask_v = saturate( ( lambda * edge_v_lum - epsilon ) / blurred_h_lum );

	float4 color = center;
	color = lerp( color, blurred_h, edge_mask_v );
	
	#ifdef TFU2_HIGH_PASS
		color = lerp( color, blurred_v, edge_mask_h * 1.0f );
	#else
		color = lerp( color, blurred_v, edge_mask_h * 0.5f );
	#endif
	
	
	//----								查找长边								----
	float4 h0, h1, h2, h3, h4, h5, h6, h7;
	float4 v0, v1, v2, v3, v4, v5, v6, v7;

	LD( h0, 1.5, 0 ) LD( h1, 3.5, 0 ) LD( h2, 5.5, 0 ) LD( h3, 7.5, 0 ) LD( h4, -1.5,0 ) LD( h5, -3.5,0 ) LD( h6, -5.5,0 ) LD( h7, -7.5,0 )
	LD( v0, 0, 1.5 ) LD( v1, 0, 3.5 ) LD( v2, 0, 5.5 ) LD( v3, 0, 7.5 ) LD( v4, 0,-1.5 ) LD( v5, 0,-3.5 ) LD( v6, 0,-5.5 ) LD( v7, 0,-7.5 )
	
	float long_edge_mask_h = ( h0.a + h1.a + h2.a + h3.a + h4.a + h5.a + h6.a + h7.a ) / 8.0f;
	float long_edge_mask_v = ( v0.a + v1.a + v2.a + v3.a + v4.a + v5.a + v6.a + v7.a ) / 8.0f;

	long_edge_mask_h = saturate(long_edge_mask_h * 2.0f - 1.0f);
	long_edge_mask_v = saturate(long_edge_mask_v * 2.0f - 1.0f);

	if(abs(long_edge_mask_h - long_edge_mask_v) > 0.2f)
	{
		float4 left, right, top, bottom;

		LD(left,  -1,  0)
		LD(right,  1,  0)
		LD(top,    0, -1)
		LD(bottom, 0,  1)

		float4 long_blurred_h = ( h0 + h1 + h2 + h3 + h4 + h5 + h6 + h7 ) / 8.0f;
		float4 long_blurred_v = ( v0 + v1 + v2 + v3 + v4 + v5 + v6 + v7 ) / 8.0f;

		float lb_h_lum   = GetIntensity(long_blurred_h.xyz);
		float lb_v_lum   = GetIntensity(long_blurred_v.xyz);

		float center_lum = GetIntensity(center.xyz);
		float left_lum   = GetIntensity(left.xyz);
		float right_lum  = GetIntensity(right.xyz);
		float top_lum    = GetIntensity(top.xyz);
		float bottom_lum = GetIntensity(bottom.xyz);

		float4 color_v = center;
		float4 color_h = center;

		#ifdef VECTORIZED_SEARCH
		
			// vectorized search (X360 GPU and SPU implementation friendly)
	    float hx = saturate(0 + ( lb_h_lum - top_lum    ) / ( center_lum - top_lum    ));
	    float hy = saturate(1 + ( lb_h_lum - center_lum ) / ( center_lum - bottom_lum ));
	    float vx = saturate(0 + ( lb_v_lum - left_lum   ) / ( center_lum - left_lum   ));
	    float vy = saturate(1 + ( lb_v_lum - center_lum ) / ( center_lum - right_lum  ));

	    float4 vhxy = float4( vx, vy, hx, hy );
	    vhxy = (vhxy == float4( 0, 0, 0, 0 ) ? float4( 1, 1, 1, 1 ) : vhxy);

	    color_v = lerp(left  , color_v, vhxy.x);
	    color_v = lerp(right , color_v, vhxy.y);
	    color_h = lerp(top   , color_h, vhxy.z);
	    color_h = lerp(bottom, color_h, vhxy.w);
		    
		#else
		
	    // naive search
	    float hx = saturate((lb_h_lum - top_lum   ) / (center_lum - top_lum   ));
	    float hy = saturate((lb_h_lum - center_lum) / (bottom_lum - center_lum));
	    float vx = saturate((lb_v_lum - left_lum  ) / (center_lum - left_lum  ));
	    float vy = saturate((lb_v_lum - center_lum) / (right_lum  - center_lum));

	    if ( hx == 0 ) hx = 1;
	    if ( vx == 0 ) vx = 1;

	    color_v = lerp( left, color_v, vx );
	    if ( vy < 1 ) color_v = lerp( color_v, right, vy );

	    color_h = lerp( top, color_h, hx );
	    if ( hy < 1 ) color_h = lerp( color_h, bottom, hy );
		    
		#endif

			color = lerp( color, color_v, long_edge_mask_v );
			color = lerp( color, color_h, long_edge_mask_h );
    }
    
    // Preserve high frequencies
		float4 r0, r1;
		float4 r2, r3;
		    
		LD(r0, -1.5, -1.5)
		LD(r1,  1.5, -1.5)
		LD(r2, -1.5,  1.5)
		LD(r3,  1.5,  1.5)
		
		float4 r = (4.0f * ( r0 + r1 + r2 + r3 ) + center + top_01 + bottom_01 + left_01 + right_01) / 25.0f;
		color = lerp(color, center, saturate(r.a * 3.0f - 1.5f));

    return color;
}


//////////////////////////////////////////////////////////////////////////////////////
//																																									//
//																			FXAA    																		//
//												Fast Approximate Anti-Aliasing        										//
//////////////////////////////////////////////////////////////////////////////////////
float3 FxaaPixShader
(
	float2 		posPos,
	float4 		viewportSize,
	sampler2D tex
);

float3 FxaaPixelShaderNoLuma
(
	float2 	  posPos,
	float4    viewportSize,
	sampler2D tex
);

void FXAA_VS
(
	float4  position	:	POSITION, 
	float2  texcoord	:	TEXCOORD0, 
	uniform float4x4 worldViewProj,
	out     float4   oPosition : POSITION,
	out     float2   oPosUV    : TEXCOORD1
)
{
	oPosition = mul(worldViewProj, position);
	oPosUV.xy = texcoord;
}

void FXAA_PS
(
	float2  texcoord  :	TEXCOORD1, 
	uniform float4    viewportSize,
	uniform sampler2D tex,
	out     float4    oColor : COLOR
)
{
	oColor.xyz = FxaaPixShader(texcoord, viewportSize, tex);
	oColor.xyz = oColor.xyz;
	oColor.w   = 1.0;
}

float3 FxaaTexOff
(
	sampler2D texSampler,
	float2 uv,
	float2 offset,
	float2 invViewSize
)
{
	return tex2D(texSampler, (uv + offset * invViewSize));
}

float3 FxaaPixShader
(
	float2 	  posPos,
	float4    viewportSize,
	sampler2D tex
)
{
	//#define FXAA_DEGE_THRESHOLD 	 0.125        //0.125 less aliasing but softer, 0.25 more aliasing but sharper
	//#define FXAA_DEGE_THRESHOLD_MIN  0.05		  //0.04 slower but less aliasing, 0.05 default, 0.06 faster but more aliasing
	//#define FXAA_EDGE_SHARPNESS      8.0          //8.0 sharper default, 4.0 softer, 2.0 good
	//#define N                        0.5

	const float FXAA_DEGE_THRESHOLD = 0.125;
	const float FXAA_DEGE_THRESHOLD_MIN = 0.05;
	const float FXAA_EDGE_SHARPNESS = 8.0;
	const float N = 0.5;
	
	float4 fxaaConsoleRcpFrameOpt  = float4(-N / viewportSize.x, -N / viewportSize.y,
											 N / viewportSize.x, N / viewportSize.y);
		
	float4 fxaaConsoleRcpFrameOpt2 = 4.0 * fxaaConsoleRcpFrameOpt;						 
		
	//float4 fxaaRcpConsole360RcpFrameOpt2 = float4(	8.0 / viewportSize.x,  8.0 / viewportSize.y,
												   //-8.0	/ viewportSize.x, -8.0 / viewportSize.y);								  
											
	//float4 fxaaConsole360ConstDir = float4(1.0, -1.0, 0.25, -0.25);
	float4 rgbM = tex2D(tex, posPos.xy);
/*---------------------------------------------------------*/
    float  lumaNW = tex2D(tex, posPos.xy + float2(-1, -1) * viewportSize.zw).w;
    float  lumaNE = tex2D(tex, posPos.xy + float2( 1, -1) * viewportSize.zw).w;
    float  lumaSW = tex2D(tex, posPos.xy + float2(-1,  1) * viewportSize.zw).w;
    float  lumaSE = tex2D(tex, posPos.xy + float2( 1,  1) * viewportSize.zw).w;
    float  lumaM  = rgbM.w;
    
    lumaNE += 1.0/384.0;
/*---------------------------------------------------------*/
    float lumaMin = min(lumaM, min(min(lumaNW, lumaNE), min(lumaSW, lumaSE)));
    float lumaMax = max(lumaM, max(max(lumaNW, lumaNE), max(lumaSW, lumaSE)));
/*---------------------------------------------------------*/
	if((lumaMax - lumaMin) < max(FXAA_DEGE_THRESHOLD_MIN, lumaMax * FXAA_DEGE_THRESHOLD))
		return rgbM.xyz ;
		
	else
	{
		float2 dir;
		dir.x = -((lumaNW + lumaNE) - (lumaSW + lumaSE));
		dir.y =  ((lumaNW + lumaSW) - (lumaNE + lumaSE));

		float2 dir1 = normalize(dir.xy);
		
		float4 rgbN1 = tex2D(tex, posPos.xy - dir1 * fxaaConsoleRcpFrameOpt.zw);
		float4 rgbP1 = tex2D(tex, posPos.xy + dir1 * fxaaConsoleRcpFrameOpt.zw);
	
 		float  minDir = min(abs(dir1.x), abs(dir1.y)) * FXAA_EDGE_SHARPNESS;
 		float2 dir2   = clamp(dir.xy / minDir, -2.0, 2.0);
 		
 		float4 rgbN2 = tex2D(tex, posPos.xy - dir2 * fxaaConsoleRcpFrameOpt2.zw);
 		float4 rgbP2 = tex2D(tex, posPos.xy + dir2 * fxaaConsoleRcpFrameOpt2.zw);
 		
		float4 rgbA = rgbN1 + rgbP1;
		float4 rgbB = ((rgbN2 + rgbP2) * 0.25) + (rgbA * 0.25);

		float  lumaB = rgbB.w;
		
		if((lumaB < lumaMin) || (lumaB > lumaMax))
			rgbB.xyz = rgbA.xyz * 0.5;
		
		return rgbB.xyz ;
	}
}

void FXAA_VS_LUMA
(
	float4  position	:	POSITION, 
	float2  texcoord	:	TEXCOORD0, 
	uniform float4x4 worldViewProj,
	out     float4   oPosition : POSITION,
	out     float2   oPosUV    : TEXCOORD1
)
{
	oPosition = mul(worldViewProj, position);
	oPosUV.xy = texcoord;
}

void FXAA_PS_LUMA
(
	float4 pos : POSITION,
	float2  texcoord  :	TEXCOORD1, 
	uniform sampler2D tex,
	out     float4    oColor : COLOR
)
{
	float3 luma  = float3(0.299, 0.587, 0.114);
	oColor.xyz = tex2D(tex, texcoord).xyz;
	oColor.w   = dot(oColor.xyz, luma);
}

void FXAA_VS_NOLUMA
(	
	float4  position : POSITION, 
	float2  texcoord : TEXCOORD0, 
	uniform float4x4 worldViewProj,
	out     float4   oPosition : POSITION,
	out     float2   oUV       : TEXCOORD1
)
{
	oPosition = mul(worldViewProj, position);
	oUV       = texcoord;
}

void FXAA_PS_NOLUMA
(
	float4 pos : POSITION,
	float2  uv        : TEXCOORD1,
	uniform float4    viewportSize,
	uniform sampler2D tex,
	out     float4    oColor : COLOR
)
{
	oColor.xyz = FxaaPixelShaderNoLuma(uv, viewportSize, tex);
	oColor.w   = 1.0;
}

float3 FxaaPixelShaderNoLuma
(
	float2 	  posPos,
	float4    viewportSize,
	sampler2D tex
)
{
	//#define FXAA_DEGE_THRESHOLD 	 0.125        //0.125 less aliasing but softer, 0.25 more aliasing but sharper
	//#define FXAA_DEGE_THRESHOLD_MIN  0.05		  //0.04 slower but less aliasing, 0.05 default, 0.06 faster but more aliasing
	//#define FXAA_EDGE_SHARPNESS      8.0          //8.0 sharper default, 4.0 softer, 2.0 good
	//#define FXAA_DEGE_THRESHOLD 	 0.35        //0.125 less aliasing but softer, 0.25 more aliasing but sharper
	//#define FXAA_DEGE_THRESHOLD_MIN  0.06		  //0.04 slower but less aliasing, 0.05 default, 0.06 faster but more aliasing
	//#define FXAA_EDGE_SHARPNESS      8.0          //8.0 sharper default, 4.0 softer, 2.0 good
	//#define N                        0.5

	const float FXAA_DEGE_THRESHOLD = 0.35;
	const float FXAA_DEGE_THRESHOLD_MIN = 0.06;
	const float FXAA_EDGE_SHARPNESS = 8.0;
	const float N = 0.5;
	
	float4 fxaaConsoleRcpFrameOpt  = float4(-N / viewportSize.x, -N / viewportSize.y,
											 N / viewportSize.x, N / viewportSize.y);
		
	float4 fxaaConsoleRcpFrameOpt2 = 4.0 * fxaaConsoleRcpFrameOpt;						 
	
	float3 luma  = float3(0.299, 0.587, 0.114);
	
	float3 rgbM  = tex2D(tex, posPos.xy).xyz;
	float3 rgbNW = tex2D(tex, posPos.xy + float2(-1, -1) * viewportSize.zw).xyz;
    float3 rgbNE = tex2D(tex, posPos.xy + float2( 1, -1) * viewportSize.zw).xyz;
    float3 rgbSW = tex2D(tex, posPos.xy + float2(-1,  1) * viewportSize.zw).xyz;
    float3 rgbSE = tex2D(tex, posPos.xy + float2( 1,  1) * viewportSize.zw).xyz;
/*---------------------------------------------------------*/
    float  lumaNW = dot(rgbNW, luma);
    float  lumaNE = dot(rgbNE, luma);
    float  lumaSW = dot(rgbSW, luma);
    float  lumaSE = dot(rgbSE, luma);
    float  lumaM  = dot(rgbM , luma);
    
    lumaNE += 1.0/384.0;
/*---------------------------------------------------------*/
    float lumaMin = min(lumaM, min(min(lumaNW, lumaNE), min(lumaSW, lumaSE)));
    float lumaMax = max(lumaM, max(max(lumaNW, lumaNE), max(lumaSW, lumaSE)));
/*---------------------------------------------------------*/
	if((lumaMax - lumaMin) < max(FXAA_DEGE_THRESHOLD_MIN, lumaMax * FXAA_DEGE_THRESHOLD))
		return rgbM.xyz;
	else
	{
		float2 dir;
		dir.x = -((lumaNW + lumaNE) - (lumaSW + lumaSE));
		dir.y =  ((lumaNW + lumaSW) - (lumaNE + lumaSE));

		float2 dir1 = normalize(dir.xy);
		
		float3 rgbN1 = tex2D(tex, posPos.xy - dir1 * fxaaConsoleRcpFrameOpt.zw).xyz;
		float3 rgbP1 = tex2D(tex, posPos.xy + dir1 * fxaaConsoleRcpFrameOpt.zw).xyz;
	
 		float  minDir = min(abs(dir1.x), abs(dir1.y)) * FXAA_EDGE_SHARPNESS;
 		float2 dir2   = clamp(dir.xy / minDir, -2.0, 2.0);
 		
 		float3 rgbN2 = tex2D(tex, posPos.xy - dir2 * fxaaConsoleRcpFrameOpt2.zw).xyz;
 		float3 rgbP2 = tex2D(tex, posPos.xy + dir2 * fxaaConsoleRcpFrameOpt2.zw).xyz;
 		
		float3 rgbA = rgbN1 + rgbP1;
		float3 rgbB = ((rgbN2 + rgbP2) * 0.25) + (rgbA * 0.25);

		float  lumaB = dot(rgbB, luma);
		
		if((lumaB < lumaMin) || (lumaB > lumaMax))
			rgbB.xyz = rgbA.xyz * 0.5;
		
		return rgbB.xyz;
	}
}

/*============================================================================
                     FXAA QUALITY
============================================================================*/

#define FxaaTexTop(t, p) tex2Dlod(t, float4(p, 0.0, 0.0))
#define FxaaTexOff(t, p, o, r) tex2Dlod(t, float4(p + (o * r), 0, 0))
//#define FxaaLuma(c) dot(c.rgb, float3(0.299, 0.587, 0.114))
#define FxaaLuma(c) c.w

#ifndef FXAA_QUALITY__PRESET
    #define FXAA_QUALITY__PRESET 12
#endif
/*============================================================================
                     FXAA QUALITY - MEDIUM DITHER PRESETS
============================================================================*/
#if (FXAA_QUALITY__PRESET == 10)
    #define FXAA_QUALITY__PS 3
    #define FXAA_QUALITY__P0 1.5
    #define FXAA_QUALITY__P1 3.0
    #define FXAA_QUALITY__P2 12.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY__PRESET == 11)
    #define FXAA_QUALITY__PS 4
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 3.0
    #define FXAA_QUALITY__P3 12.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY__PRESET == 12)
    #define FXAA_QUALITY__PS 5
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 4.0
    #define FXAA_QUALITY__P4 12.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY__PRESET == 13)
    #define FXAA_QUALITY__PS 6
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 2.0
    #define FXAA_QUALITY__P4 4.0
    #define FXAA_QUALITY__P5 12.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY__PRESET == 14)
    #define FXAA_QUALITY__PS 7
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 2.0
    #define FXAA_QUALITY__P4 2.0
    #define FXAA_QUALITY__P5 4.0
    #define FXAA_QUALITY__P6 12.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY__PRESET == 15)
    #define FXAA_QUALITY__PS 8
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 2.0
    #define FXAA_QUALITY__P4 2.0
    #define FXAA_QUALITY__P5 2.0
    #define FXAA_QUALITY__P6 4.0
    #define FXAA_QUALITY__P7 12.0
#endif

/*============================================================================
                     FXAA QUALITY - LOW DITHER PRESETS
============================================================================*/
#if (FXAA_QUALITY__PRESET == 20)
    #define FXAA_QUALITY__PS 3
    #define FXAA_QUALITY__P0 1.5
    #define FXAA_QUALITY__P1 2.0
    #define FXAA_QUALITY__P2 8.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY__PRESET == 21)
    #define FXAA_QUALITY__PS 4
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 8.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY__PRESET == 22)
    #define FXAA_QUALITY__PS 5
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 2.0
    #define FXAA_QUALITY__P4 8.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY__PRESET == 23)
    #define FXAA_QUALITY__PS 6
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 2.0
    #define FXAA_QUALITY__P4 2.0
    #define FXAA_QUALITY__P5 8.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY__PRESET == 24)
    #define FXAA_QUALITY__PS 7
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 2.0
    #define FXAA_QUALITY__P4 2.0
    #define FXAA_QUALITY__P5 3.0
    #define FXAA_QUALITY__P6 8.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY__PRESET == 25)
    #define FXAA_QUALITY__PS 8
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 2.0
    #define FXAA_QUALITY__P4 2.0
    #define FXAA_QUALITY__P5 2.0
    #define FXAA_QUALITY__P6 4.0
    #define FXAA_QUALITY__P7 8.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY__PRESET == 26)
    #define FXAA_QUALITY__PS 9
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 2.0
    #define FXAA_QUALITY__P4 2.0
    #define FXAA_QUALITY__P5 2.0
    #define FXAA_QUALITY__P6 2.0
    #define FXAA_QUALITY__P7 4.0
    #define FXAA_QUALITY__P8 8.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY__PRESET == 27)
    #define FXAA_QUALITY__PS 10
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 2.0
    #define FXAA_QUALITY__P4 2.0
    #define FXAA_QUALITY__P5 2.0
    #define FXAA_QUALITY__P6 2.0
    #define FXAA_QUALITY__P7 2.0
    #define FXAA_QUALITY__P8 4.0
    #define FXAA_QUALITY__P9 8.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY__PRESET == 28)
    #define FXAA_QUALITY__PS 11
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 2.0
    #define FXAA_QUALITY__P4 2.0
    #define FXAA_QUALITY__P5 2.0
    #define FXAA_QUALITY__P6 2.0
    #define FXAA_QUALITY__P7 2.0
    #define FXAA_QUALITY__P8 2.0
    #define FXAA_QUALITY__P9 4.0
    #define FXAA_QUALITY__P10 8.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY__PRESET == 29)
    #define FXAA_QUALITY__PS 12
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 2.0
    #define FXAA_QUALITY__P4 2.0
    #define FXAA_QUALITY__P5 2.0
    #define FXAA_QUALITY__P6 2.0
    #define FXAA_QUALITY__P7 2.0
    #define FXAA_QUALITY__P8 2.0
    #define FXAA_QUALITY__P9 2.0
    #define FXAA_QUALITY__P10 4.0
    #define FXAA_QUALITY__P11 8.0
#endif

/*============================================================================
                     FXAA QUALITY - EXTREME QUALITY
============================================================================*/
#if (FXAA_QUALITY__PRESET == 39)
    #define FXAA_QUALITY__PS 12
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.0
    #define FXAA_QUALITY__P2 1.0
    #define FXAA_QUALITY__P3 1.0
    #define FXAA_QUALITY__P4 1.0
    #define FXAA_QUALITY__P5 1.5
    #define FXAA_QUALITY__P6 2.0
    #define FXAA_QUALITY__P7 2.0
    #define FXAA_QUALITY__P8 2.0
    #define FXAA_QUALITY__P9 2.0
    #define FXAA_QUALITY__P10 4.0
    #define FXAA_QUALITY__P11 8.0
#endif


float4 FxaaPixelShaderQuality
(
	float2 	  pos,
	float4    viewportSize,
	sampler2D tex
)
{
	#define fxaaQualityEdgeThreshold 	 0.333f       
	#define fxaaQualityEdgeThresholdMin  0.0833f		 
	#define fxaaQualitySubpix      0.75        
	
	
	/*--------------------------------------------------------------------------*/
    float2 posM;
    posM.x = pos.x;
    posM.y = pos.y;

        float4 rgbyM = FxaaTexTop(tex, posM);
        float lumaM = FxaaLuma(rgbyM);

        float lumaS = FxaaLuma(FxaaTexOff(tex, posM, float2( 0, 1), viewportSize.zw));
        float lumaE = FxaaLuma(FxaaTexOff(tex, posM, float2( 1, 0), viewportSize.zw));
        float lumaN = FxaaLuma(FxaaTexOff(tex, posM, float2( 0,-1), viewportSize.zw));
        float lumaW = FxaaLuma(FxaaTexOff(tex, posM, float2(-1, 0), viewportSize.zw));
    
/*--------------------------------------------------------------------------*/
    float maxSM = max(lumaS, lumaM);
    float minSM = min(lumaS, lumaM);
    float maxESM = max(lumaE, maxSM);
    float minESM = min(lumaE, minSM);
    float maxWN = max(lumaN, lumaW);
    float minWN = min(lumaN, lumaW);
    float rangeMax = max(maxWN, maxESM);
    float rangeMin = min(minWN, minESM);
    float rangeMaxScaled = rangeMax * fxaaQualityEdgeThreshold;
    float range = rangeMax - rangeMin;
    float rangeMaxClamped = max(fxaaQualityEdgeThresholdMin, rangeMaxScaled);
    bool earlyExit = range < rangeMaxClamped;
/*--------------------------------------------------------------------------*/
    if (earlyExit) {
	
    }else {
	/*--------------------------------------------------------------------------*/
        float lumaNW = FxaaLuma(FxaaTexOff(tex, posM, float2(-1,-1), viewportSize.zw));
        float lumaSE = FxaaLuma(FxaaTexOff(tex, posM, float2( 1, 1), viewportSize.zw));
        float lumaNE = FxaaLuma(FxaaTexOff(tex, posM, float2( 1,-1), viewportSize.zw));
        float lumaSW = FxaaLuma(FxaaTexOff(tex, posM, float2(-1, 1), viewportSize.zw));

/*--------------------------------------------------------------------------*/
    float lumaNS = lumaN + lumaS;
    float lumaWE = lumaW + lumaE;
    float subpixRcpRange = 1.0/range;
    float subpixNSWE = lumaNS + lumaWE;
    float edgeHorz1 = (-2.0 * lumaM) + lumaNS;
    float edgeVert1 = (-2.0 * lumaM) + lumaWE;
/*--------------------------------------------------------------------------*/
    float lumaNESE = lumaNE + lumaSE;
    float lumaNWNE = lumaNW + lumaNE;
    float edgeHorz2 = (-2.0 * lumaE) + lumaNESE;
    float edgeVert2 = (-2.0 * lumaN) + lumaNWNE;
/*--------------------------------------------------------------------------*/
    float lumaNWSW = lumaNW + lumaSW;
    float lumaSWSE = lumaSW + lumaSE;
    float edgeHorz4 = (abs(edgeHorz1) * 2.0) + abs(edgeHorz2);
    float edgeVert4 = (abs(edgeVert1) * 2.0) + abs(edgeVert2);
    float edgeHorz3 = (-2.0 * lumaW) + lumaNWSW;
    float edgeVert3 = (-2.0 * lumaS) + lumaSWSE;
    float edgeHorz = abs(edgeHorz3) + edgeHorz4;
    float edgeVert = abs(edgeVert3) + edgeVert4;
/*--------------------------------------------------------------------------*/
    float subpixNWSWNESE = lumaNWSW + lumaNESE;
    float lengthSign = viewportSize.z;
    bool horzSpan = edgeHorz >= edgeVert;
    float subpixA = subpixNSWE * 2.0 + subpixNWSWNESE;
/*--------------------------------------------------------------------------*/
    if(!horzSpan) lumaN = lumaW;
    if(!horzSpan) lumaS = lumaE;
    if(horzSpan) lengthSign = viewportSize.w;
    float subpixB = (subpixA * (1.0/12.0)) - lumaM;
/*--------------------------------------------------------------------------*/
    float gradientN = lumaN - lumaM;
    float gradientS = lumaS - lumaM;
    float lumaNN = lumaN + lumaM;
    float lumaSS = lumaS + lumaM;
    bool pairN = abs(gradientN) >= abs(gradientS);
    float gradient = max(abs(gradientN), abs(gradientS));
    if(pairN) lengthSign = -lengthSign;
    float subpixC = saturate(abs(subpixB) * subpixRcpRange);
/*--------------------------------------------------------------------------*/
    float2 posB;
    posB.x = posM.x;
    posB.y = posM.y;
    float2 offNP;
    offNP.x = (!horzSpan) ? 0.0 : viewportSize.z;
    offNP.y = ( horzSpan) ? 0.0 : viewportSize.w;
    if(!horzSpan) posB.x += lengthSign * 0.5;
    if( horzSpan) posB.y += lengthSign * 0.5;
/*--------------------------------------------------------------------------*/
    float2 posN;
    posN.x = posB.x - offNP.x * FXAA_QUALITY__P0;
    posN.y = posB.y - offNP.y * FXAA_QUALITY__P0;
    float2 posP;
    posP.x = posB.x + offNP.x * FXAA_QUALITY__P0;
    posP.y = posB.y + offNP.y * FXAA_QUALITY__P0;
    float subpixD = ((-2.0)*subpixC) + 3.0;
    float lumaEndN = FxaaLuma(FxaaTexTop(tex, posN));
    float subpixE = subpixC * subpixC;
    float lumaEndP = FxaaLuma(FxaaTexTop(tex, posP));
/*--------------------------------------------------------------------------*/
    if(!pairN) lumaNN = lumaSS;
    float gradientScaled = gradient * 1.0/4.0;
    float lumaMM = lumaM - lumaNN * 0.5;
    float subpixF = subpixD * subpixE;
    bool lumaMLTZero = lumaMM < 0.0;
/*--------------------------------------------------------------------------*/
    lumaEndN -= lumaNN * 0.5;
    lumaEndP -= lumaNN * 0.5;
    bool doneN = abs(lumaEndN) >= gradientScaled;
    bool doneP = abs(lumaEndP) >= gradientScaled;
    if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P1;
    if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P1;
    bool doneNP = (!doneN) || (!doneP);
    if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P1;
    if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P1;
    
/*--------------------------------------------------------------------------*/
    if(doneNP) {
        if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
        if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
        if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
        if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
        doneN = abs(lumaEndN) >= gradientScaled;
        doneP = abs(lumaEndP) >= gradientScaled;
        if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P2;
        if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P2;
        doneNP = (!doneN) || (!doneP);
        if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P2;
        if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P2;
/*--------------------------------------------------------------------------*/
        #if (FXAA_QUALITY__PS > 3)
        if(doneNP) {
            if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
            if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
            if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
            if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
            doneN = abs(lumaEndN) >= gradientScaled;
            doneP = abs(lumaEndP) >= gradientScaled;
            if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P3;
            if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P3;
            doneNP = (!doneN) || (!doneP);
            if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P3;
            if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P3;
/*--------------------------------------------------------------------------*/
            #if (FXAA_QUALITY__PS > 4)
            if(doneNP) {
                if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
                if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
                if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
                if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
                doneN = abs(lumaEndN) >= gradientScaled;
                doneP = abs(lumaEndP) >= gradientScaled;
                if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P4;
                if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P4;
                doneNP = (!doneN) || (!doneP);
                if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P4;
                if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P4;
/*--------------------------------------------------------------------------*/
                #if (FXAA_QUALITY__PS > 5)
                if(doneNP) {
                    if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
                    if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
                    if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
                    if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
                    doneN = abs(lumaEndN) >= gradientScaled;
                    doneP = abs(lumaEndP) >= gradientScaled;
                    if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P5;
                    if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P5;
                    doneNP = (!doneN) || (!doneP);
                    if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P5;
                    if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P5;
/*--------------------------------------------------------------------------*/
                    #if (FXAA_QUALITY__PS > 6)
                    if(doneNP) {
                        if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
                        if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
                        if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
                        if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
                        doneN = abs(lumaEndN) >= gradientScaled;
                        doneP = abs(lumaEndP) >= gradientScaled;
                        if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P6;
                        if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P6;
                        doneNP = (!doneN) || (!doneP);
                        if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P6;
                        if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P6;
/*--------------------------------------------------------------------------*/
                        #if (FXAA_QUALITY__PS > 7)
                        if(doneNP) {
                            if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
                            if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
                            if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
                            if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
                            doneN = abs(lumaEndN) >= gradientScaled;
                            doneP = abs(lumaEndP) >= gradientScaled;
                            if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P7;
                            if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P7;
                            doneNP = (!doneN) || (!doneP);
                            if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P7;
                            if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P7;
/*--------------------------------------------------------------------------*/
    #if (FXAA_QUALITY__PS > 8)
    if(doneNP) {
        if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
        if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
        if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
        if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
        doneN = abs(lumaEndN) >= gradientScaled;
        doneP = abs(lumaEndP) >= gradientScaled;
        if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P8;
        if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P8;
        doneNP = (!doneN) || (!doneP);
        if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P8;
        if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P8;
/*--------------------------------------------------------------------------*/
        #if (FXAA_QUALITY__PS > 9)
        if(doneNP) {
            if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
            if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
            if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
            if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
            doneN = abs(lumaEndN) >= gradientScaled;
            doneP = abs(lumaEndP) >= gradientScaled;
            if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P9;
            if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P9;
            doneNP = (!doneN) || (!doneP);
            if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P9;
            if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P9;
/*--------------------------------------------------------------------------*/
            #if (FXAA_QUALITY__PS > 10)
            if(doneNP) {
                if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
                if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
                if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
                if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
                doneN = abs(lumaEndN) >= gradientScaled;
                doneP = abs(lumaEndP) >= gradientScaled;
                if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P10;
                if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P10;
                doneNP = (!doneN) || (!doneP);
                if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P10;
                if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P10;
/*--------------------------------------------------------------------------*/
                #if (FXAA_QUALITY__PS > 11)
                if(doneNP) {
                    if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
                    if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
                    if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
                    if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
                    doneN = abs(lumaEndN) >= gradientScaled;
                    doneP = abs(lumaEndP) >= gradientScaled;
                    if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P11;
                    if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P11;
                    doneNP = (!doneN) || (!doneP);
                    if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P11;
                    if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P11;
/*--------------------------------------------------------------------------*/
                    #if (FXAA_QUALITY__PS > 12)
                    if(doneNP) {
                        if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
                        if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
                        if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
                        if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
                        doneN = abs(lumaEndN) >= gradientScaled;
                        doneP = abs(lumaEndP) >= gradientScaled;
                        if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P12;
                        if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P12;
                        doneNP = (!doneN) || (!doneP);
                        if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P12;
                        if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P12;
/*--------------------------------------------------------------------------*/
                    }
                    #endif
/*--------------------------------------------------------------------------*/
                }
                #endif
/*--------------------------------------------------------------------------*/
            }
            #endif
/*--------------------------------------------------------------------------*/
        }
        #endif
/*--------------------------------------------------------------------------*/
    }
    #endif
/*--------------------------------------------------------------------------*/
                        }
                        #endif
/*--------------------------------------------------------------------------*/
                    }
                    #endif
/*--------------------------------------------------------------------------*/
                }
                #endif
/*--------------------------------------------------------------------------*/
            }
            #endif
/*--------------------------------------------------------------------------*/
        }
        #endif
/*--------------------------------------------------------------------------*/
    }
/*--------------------------------------------------------------------------*/
    float dstN = posM.x - posN.x;
    float dstP = posP.x - posM.x;
    if(!horzSpan) dstN = posM.y - posN.y;
    if(!horzSpan) dstP = posP.y - posM.y;
/*--------------------------------------------------------------------------*/
    bool goodSpanN = (lumaEndN < 0.0) != lumaMLTZero;
    float spanLength = (dstP + dstN);
    bool goodSpanP = (lumaEndP < 0.0) != lumaMLTZero;
    float spanLengthRcp = 1.0/spanLength;
/*--------------------------------------------------------------------------*/
    bool directionN = dstN < dstP;
    float dst = min(dstN, dstP);
    bool goodSpan = directionN ? goodSpanN : goodSpanP;
    float subpixG = subpixF * subpixF;
    float pixelOffset = (dst * (-spanLengthRcp)) + 0.5;
    float subpixH = subpixG * fxaaQualitySubpix;
/*--------------------------------------------------------------------------*/
    float pixelOffsetGood = goodSpan ? pixelOffset : 0.0;
    float pixelOffsetSubpix = max(pixelOffsetGood, subpixH);
    if(!horzSpan) posM.x += pixelOffsetSubpix * lengthSign;
    if( horzSpan) posM.y += pixelOffsetSubpix * lengthSign;
    rgbyM = float4(FxaaTexTop(tex, posM).xyz, lumaM);
    }
    return rgbyM;
}

void FXAA_PS_Quality
(
	float4 pos : POSITION,
	float2  uv        : TEXCOORD1,
	uniform float4    viewportSize,
	uniform sampler2D tex,
	out     float4    oColor : COLOR
)
{
	oColor.xyz = FxaaPixelShaderQuality(uv, viewportSize, tex);
	oColor.w   = 1.0;
}
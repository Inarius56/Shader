#include "PostProcessUtility.inc"

#ifndef USE_HDR 
	#define USE_HDR 1
#endif

#ifndef USE_AUTOEXPOSURE 
	#define USE_AUTOEXPOSURE 1
#endif


float4
blur_fp(in float2 texCoord: TEXCOORD0,
        uniform sampler image
       ) : COLOR
{
	static const float2 samples[8] =
	{
   	    {-0.326212, -0.405805},
   	    {-0.840144, -0.073580},
   	    {-0.695914, +0.457137},
   	    {-0.203345, +0.620716},
    	{+0.962340, -0.194983},
    	{+0.473434, -0.480026},
    	{+0.519456, +0.767022},
    	{+0.896420, +0.412458},
	};

    float4 sum = tex2D(image, texCoord);
    for (int i = 0; i < 8; i++)
    {
        sum += tex2D(image, texCoord + 0.0125 * samples[i]);
    }

    return sum / 9;
}

float4
final_fp(in float2 texCoord : TEXCOORD0,
         uniform sampler RT,
         uniform sampler Blur
        ) : COLOR
{
    float4 sharp = tex2D(RT,   texCoord);
    float4 blur  = tex2D(Blur, texCoord);
    return (sharp + blur * 1.8) / 2;
}


/////////////////////////////////////////////////////////////////////////////////// ////////////////////////////////////////////////////////
//HDR->LDR
float4 toneMap(float4 color, float luminance, float keyValue)
{
	float FUDGE = 0.001f;
	//float L_WHITE = 1.5f;
	//color.rgb *= keyValue / (FUDGE + luminance);
	//color.rgb *= (1.0f + color.rgb / L_WHITE);
	//color.rgb /= (1.0f + color.rgb);
	color.rgb *= keyValue;
	color.rgb /= (luminance + FUDGE + color.rgb);
	return color;
}

//ACES
float3 ACESTonemap(float3 color, float adapted_lum)
{
	float A = 2.51f;
	float B = 0.03f;
	float C = 2.43f;
	float D = 0.59f;
	float E = 0.14f;

	color *= adapted_lum;
	return (color * (A * color + B)) / (color * (C * color + D) + E);
}


float4 downscale4x4brightpass(float4 pos : POSITION, float2 uv : TEXCOORD0,
							  uniform float lum,
							  uniform float pixelSize,
							  uniform float keyValue,
							  uniform float limitedLuminance,
							  uniform sampler2D inRTT : register(s0))	              
							  :COLOR
{
	float2 texOffset4x4[16] = 
	{
	-1.5, -1.5,
	-0.5, -1.5,
	 0.5, -1.5,
	 1.5, -1.5,
	-1.5, -0.5,
	-0.5, -0.5,
	 0.5, -0.5,
	 1.5, -0.5,
	-1.5,  0.5,
	-0.5,  0.5,
	 0.5,  0.5,
 	 1.5,  0.5,
	-1.5,  1.5,
	-0.5,  1.5,
	 0.5,  1.5,
	 1.5,  1.5
	};
  float4 accum = float4(0.0f, 0.0f, 0.0f, 0.0f);
	for( int i = 0; i < 16; i++ )
  {
  // Get colour from source
     accum += tex2D(inRTT, uv + pixelSize * texOffset4x4[i]);
  }
	// take average of 9 samples
	accum *= 0.0625;
	//根据亮度调节色彩
	float4 BRIGHT_LIMITER = float4(limitedLuminance, limitedLuminance, limitedLuminance, 0.0f);
	accum = max(float4(0.0f, 0.0f, 0.0f, 1.0f), accum - BRIGHT_LIMITER);  	
	// Tone map result
	return toneMap(accum, lum, keyValue);
}

float4 finalToneMapping(float4 pos : POSITION, float2 uv : TEXCOORD0,																	
	                    uniform sampler2D inRTT : register(s0),
	                    uniform sampler2D inBloom : register(s1))
	                    :COLOR
{
	// Get main scene colour
	float4 sceneCol = tex2D(inRTT, uv);
	// Get luminence value		
	//adjust *= exposure;
	float adjust = 1.5f;
	// Get bloom colour
	float4 bloom = tex2D(inBloom, uv);
	// Add scene & bloom
	//return bloom * adjust;
	float3 finalColor = sceneCol.rgb + bloom.rgb*adjust;
	//return float4(sceneCol.rgb + bloom.rgb*adjust, 1.0f);
	
	finalColor.rgb = saturate(finalColor.rgb);
	return float4(finalColor.rgb,1.0f);
}


////////////////////////////////////////////////////////////////////////////////////////////////
float4 GrayDownScaleLum(float4 pos : POSITION, float2 uv : TEXCOORD0, 
							 uniform float4 viewport_size,
 							 uniform sampler2D inRTT : register(s0))
							 :COLOR
{
	static const float2 texOffset2x2[4] = 
	{
	-0.5, -0.5,
	-0.5,  0.5,
	 0.5, -0.5,
	 0.5,  0.5
	};
	float average = 0.0f;
	float4 color = float4(0.0f, 0.0f, 0.0f, 0.0f);
	for( int i = 0; i < 4; i++ )
  {
			color += tex2D(inRTT, uv + viewport_size.zw * texOffset2x2[i]);
			//float GreyValue = max( color.r, max( color.g, color.b ) );
			float GreyValue = dot( color.rgb, float3( 0.299f, 0.587f, 0.114f ) );
			average += (0.25f * log( 1e-5 + GreyValue ));
			//average += (0.25f *  GreyValue);
  }
	average = exp( average*0.693147f );
	return float4( average, 0.0f, 0.0f, 1.0f );
}

float4 DownScale3x3(float4 pos : POSITION, float2 uv : TEXCOORD0,
					uniform float4 viewport_size,
					uniform sampler2D inRTT : register(s0))
					:COLOR
{
	static const float2 texOffset3x3[9] = 
	{
	-1.0, -1.0,
	 0.0, -1.0,
	 1.0, -1.0,
	-1.0,  0.0,
	 0.0,  0.0,
	 1.0,  0.0,
	-1.0,  1.0,
	 0.0,  1.0,
	 1.0,  1.0
	};
	float average = 0.0f;
  float4 color = float4(0.0f, 0.0f, 0.0f, 0.0f);
	for( int i = 0; i < 9; i++ )
  {
    // Get colour from source
    average += tex2D(inRTT, uv + viewport_size.zw * texOffset3x3[i]).r;
  }
	// take average of 9 samples
	average *= 0.11111111111f;
	return float4( average, 0.0f, 0.0f, 1.0f );
}


// . . . . . . .
// . A . B . C .
// . . D . E . .
// . F . G . H .
// . . I . J . .
// . K . L . M .
// . . . . . . .
float4 DownsampleBox13Tap(sampler2D inRTT, float2 uv, float2 texelSize)
{
    float4 A = tex2D(inRTT, (uv + texelSize * float2(-1.0, -1.0)));
    float4 B = tex2D(inRTT, (uv + texelSize * float2( 0.0, -1.0)));
    float4 C = tex2D(inRTT, (uv + texelSize * float2( 1.0, -1.0)));
    float4 D = tex2D(inRTT, (uv + texelSize * float2(-0.5, -0.5)));
    float4 E = tex2D(inRTT, (uv + texelSize * float2( 0.5, -0.5)));
    float4 F = tex2D(inRTT, (uv + texelSize * float2(-1.0,  0.0)));
    float4 G = tex2D(inRTT, (uv                                 ));
    float4 H = tex2D(inRTT, (uv + texelSize * float2( 1.0,  0.0)));
    float4 I = tex2D(inRTT, (uv + texelSize * float2(-0.5,  0.5)));
    float4 J = tex2D(inRTT, (uv + texelSize * float2( 0.5,  0.5)));
    float4 K = tex2D(inRTT, (uv + texelSize * float2(-1.0,  1.0)));
    float4 L = tex2D(inRTT, (uv + texelSize * float2( 0.0,  1.0)));
    float4 M = tex2D(inRTT, (uv + texelSize * float2( 1.0,  1.0)));

    float2 div = (1.0 / 4.0) * float2(0.5, 0.125);

    float4 o = (D + E + I + J) * div.x;
    o += (A + B + G + F) * div.y;
    o += (B + C + H + G) * div.y;
    o += (F + G + L + K) * div.y;
    o += (G + H + M + L) * div.y;

    return o;
}

//
// Quadratic color thresholding
// curve = (threshold - knee, knee * 2, 0.25 / knee)
//
float4 QuadraticThreshold(float4 color, float threshold, float3 curve)
{
    // Pixel brightness
    //float br = max(max(color.r, color.g), color.b);
    float br = dot( color.rgb, float3( 0.299f, 0.587f, 0.114f ) );;

    // Under-threshold part: quadratic curve
    float rq = clamp(br - abs(curve.x), 0.0, curve.y);
    rq = curve.z * rq * rq;

    // Combine and apply the brightness response curve.
    color *= max(rq, br - threshold) / max(br, 0.0001);

    return color;
}

float4 DownsampleBrightpassFp(float4 pos : POSITION, float2 uv : TEXCOORD0,
							  uniform float4 threshold,
							  uniform float4 viewport_size,
							  uniform sampler2D inRTT : register(s0))	              
							  :COLOR
{
	float4 color = DownsampleBox13Tap(inRTT, uv, viewport_size.zw);
  color = QuadraticThreshold(color, threshold.x, threshold.yzw);
  return color;
}


float4 DownsampleFp(float4 pos : POSITION, float2 uv : TEXCOORD0,
							  uniform float4 viewport_size,
							  uniform sampler2D inRTT : register(s0))	              
							  :COLOR
{
	float4 color = DownsampleBox13Tap(inRTT, uv, viewport_size.zw);
  return color;
}

// Standard box filtering
float4 UpsampleBox(sampler2D tex, float2 uv, float2 texelSize, float4 sampleScale)
{
    float4 d = texelSize.xyxy * float4(-1.0, -1.0, 1.0, 1.0) * (sampleScale * 0.5);

    float4 s;
    s =  tex2D(tex, (uv + d.xy));
    s += tex2D(tex, (uv + d.zy));
    s += tex2D(tex, (uv + d.xw));
    s += tex2D(tex, (uv + d.zw));

    return s * (1.0 / 4.0);
}

float4 UpsampleFp(float4 pos : POSITION, float2 uv : TEXCOORD0,
							  uniform float sampleScale,
							  uniform float4 viewport_size,
							  uniform sampler2D MainRTT : register(s0),
							  uniform sampler2D BloomRTT : register(s1))	              
							  :COLOR
{
  float4 bloom = UpsampleBox(MainRTT, uv, viewport_size.zw, sampleScale);
  float4 color = tex2D(BloomRTT, uv);
  return bloom + color;
}



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

float4 GaussianBlurHFp(		float2 iTex : TEXCOORD,
					uniform float4 viewport_size,
					uniform float2 offset,
					uniform float fStrength,
					uniform sampler2D sampScene : register(s0) ) : COLOR
{
	float4 sum = 0;
	for ( int i = -6; i <= 6; ++i )
	{
		float4 t = tex2D( sampScene, iTex + fStrength * offset * viewport_size.zw * i );
		sum += t * c_GBlurWeights[i + 6];
	}
	return sum;
}

//FinalBloom
float4 FinalBloom(float2 uv : TEXCOORD0,
	                    uniform sampler2D inBrightpass : register(s0),	                    
	                    uniform sampler2D inXuan0 : register(s1)):COLOR
{
	
  float4 bloom0 = tex2D(inBrightpass, uv);
	float4 bloom1 = tex2D(inXuan0, uv);
	
	
  float3 bloom = bloom0.rgb + bloom1.rgb ;
	
	return float4(bloom, 1.0f);
	
}

//
// 2D LUT grading
// scaleOffset = (1 / lut_width, 1 / lut_height, lut_height - 1)
//
float3 ApplyLut2D(sampler2D texLut, float3 uvw, float3 scaleOffset)
{
    // Strip format where `height = sqrt(width)`
    uvw.y = 1 - uvw.y;
    uvw.z *= scaleOffset.z;
    float shift = floor(uvw.z);
    uvw.xy = uvw.xy * scaleOffset.z * scaleOffset.xy + scaleOffset.xy * 0.5;
    uvw.x += shift * scaleOffset.y;
    uvw.xyz = lerp(tex2D(texLut, uvw.xy).rgb,tex2D(texLut, uvw.xy + float2(scaleOffset.y, 0.0)).rgb,uvw.z - shift);
    return uvw;
}

float4 finalPassFp(float4 pos : POSITION, float2 uv : TEXCOORD0,
									uniform float4 bloomColor, // xyz: color, w:intensity					
									#if USE_HDR == 1
										#if USE_AUTOEXPOSURE == 1
	                		uniform sampler2D inAverageLum : register(s2),
	                	#endif
	                	uniform float exposure,
	                #endif
	                uniform sampler2D inRTT : register(s0),
	                uniform sampler2D inBloom : register(s1))
	                //uniform sampler2D inLut : register(s2))
	                    :COLOR
{
	float3 finalColor = float3(0,0,0);
	
	float4 color = tex2D(inRTT, uv);
	//color.rgb = GammaToLinearSpace(color.rgb);
	
	#if USE_HDR == 1 && USE_AUTOEXPOSURE == 1
		float averageLum = tex2D(inAverageLum, float2(0.5,0.5)).r;
		averageLum = exposure / averageLum;
		color.rgb = color.rgb * averageLum;
	#endif
	
	float4 bloom = tex2D(inBloom, uv);
	bloom.rgb *= bloomColor.w;
	finalColor = color.rgb + bloom.rgb * bloomColor.rgb;
	
	#if USE_HDR == 1
		// tone mapping
		finalColor.rgb = ACESTonemap(finalColor.rgb, exposure);
	#endif
	
	finalColor.rgb = LinearToGammaSpace(finalColor.rgb);
	
	finalColor.rgb = saturate(finalColor.rgb);
	//finalColor.rgb = ApplyLut2D(inLut, finalColor.rgb, float3(1/1024.0, 1/32.0, 31));
	//finalColor.rgb = ApplyLut2D(inLut, finalColor.rgb, float3(1/256.0, 1/16.0, 15));
	
	return float4(finalColor.rgb, 1.0f);
}
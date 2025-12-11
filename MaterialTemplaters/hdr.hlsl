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

float4 downscale2x2luminance(float4 pos : POSITION, float2 uv : TEXCOORD0, 
							 uniform float pixelSize,
 							 uniform sampler2D inRTT : register(s0))
							 :COLOR
{
	float2 texOffset2x2[4] = 
	{
	-0.5, -0.5,
	-0.5,  0.5,
	 0.5, -0.5,
	 0.5,  0.5
	};
	float4 accum = float4(0.0f, 0.0f, 0.0f, 0.0f);
	for( int i = 0; i < 4; i++ )
  {
			accum += tex2D(inRTT, uv + pixelSize * texOffset2x2[i]);
  }
  float4 LUMINANCE_FACTOR = float4(0.27f, 0.67f, 0.06f, 0.0f);
	float lum = dot(accum, LUMINANCE_FACTOR);
	lum *= 0.25;
	return lum;
}

float4 downscale3x3(float4 pos : POSITION, float2 uv : TEXCOORD0,
					uniform float pixelSize, 
					uniform sampler2D inRTT : register(s0))
					:COLOR
{
	float2 texOffset3x3[9] = 
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
  float4 accum = float4(0.0f, 0.0f, 0.0f, 0.0f);
	for( int i = 0; i < 9; i++ )
  {
    // Get colour from source
    accum += tex2D(inRTT, uv + pixelSize * texOffset3x3[i]);
  }
	// take average of 9 samples
	accum *= 0.1111111111111111;
	return accum;
}

float4 downscale4x4(float2 uv : TEXCOORD0,
					uniform float pixelSize, 
					uniform sampler2D inRTT : register(s0)):COLOR
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
    accum += tex2D(inRTT, uv + pixelSize * texOffset4x4[i]);
  }
	accum *= 0.0625;
	return accum;
}

float4 downscale3x3brightpass(float4 pos : POSITION, float2 uv : TEXCOORD0,
							  uniform float pixelSize,
							  uniform float keyValue,
							  uniform float limitedLuminance,
							  uniform sampler2D inRTT : register(s0),
	              uniform sampler2D inLum : register(s1))
							  :COLOR
{
	float2 texOffset3x3[9] = 
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
  float4 accum = float4(0.0f, 0.0f, 0.0f, 0.0f);
	for( int i = 0; i < 9; i++ )
  {
  // Get colour from source
     accum += tex2D(inRTT, uv + pixelSize * texOffset3x3[i]);
  }
	// take average of 9 samples
	accum *= 0.1111111111111111;
  //根据亮度调节色彩
  float4 BRIGHT_LIMITER = float4(limitedLuminance, limitedLuminance, limitedLuminance, 0.0f);
  accum = max(float4(0.0f, 0.0f, 0.0f, 1.0f), accum - BRIGHT_LIMITER);
  //根据饱和度调节色彩
  //float maxColor = max(accum.x, max(accum.y, accum.z));
  //float minColor = min(accum.x, min(accum.y, accum.z));
  //float saturation = (maxColor - minColor) / maxColor;
  //saturation = max(0.0f, saturation - limitedLuminance);
  //accum = accum * saturation;
	//Sample the luminence texture
	float4 lum = tex2D(inLum, float2(0.5f, 0.5f));
	// Tone map result
	return toneMap(accum, lum.r, keyValue);
}

float4 bloom(float4 pos : POSITION, float2 uv : TEXCOORD0,
		     uniform float2 sampleOffsets[15],
		     uniform float4 sampleWeights[15],	
		     uniform sampler2D inRTT : register(s0))
			   :COLOR
{
   float4 accum = float4(0.0f, 0.0f, 0.0f, 1.0f);
	 float2 sampleUV;
   for( int i = 0; i < 15; i++ )
   {
   // Sample from adjacent points, 7 each side and central
      sampleUV = uv + sampleOffsets[i];
      accum += sampleWeights[i] * tex2D(inRTT, sampleUV);
   }
   return accum;
}

float4 finalToneMapping(float4 pos : POSITION, float2 uv : TEXCOORD0,
											//uniform float exposure,
	                    uniform sampler2D inRTT : register(s0),
	                    uniform sampler2D inBloom : register(s1),
	                    uniform sampler2D inLum : register(s2)):COLOR
{
	// Get main scene colour
  float4 sceneCol = tex2D(inRTT, uv);
	// Get luminence value
	float4 lum = tex2D(inLum, float2(0.5f, 0.5f));
	float4 adjust = max(float4(0.0f, 0.0f, 0.0f, 0.0f), lum - 0.1);
	//adjust *= exposure;
	adjust *= 1.5f;
	// Get bloom colour
  float4 bloom = tex2D(inBloom, uv);
	// Add scene & bloom
	return float4(saturate(sceneCol.rgb + bloom.rgb*adjust), 1.0f);
}

void hdrStandardVS(in float4 inPos : POSITION,
    		 	   out float4 pos : POSITION,
    			   out float2 uv0 : TEXCOORD0,
                   out float2 uv1 : TEXCOORD1,
                   uniform float4x4 worldViewProj)
{
   // Use standardise transform, so work accord with render system specific (RS depth, requires texture flipping, etc)
   pos = mul(worldViewProj, inPos);
   // The input positions adjusted by texel offsets, so clean up inaccuracies
   inPos.xy = sign(inPos.xy);
   // Convert to image-space
   uv0 = (float2(inPos.x, -inPos.y) + 1.0f) * 0.5f;
   uv1 = inPos.xy;
}

							 

#define SHADOWMAP_NONE 0
#define SHADOWMAP_SIMPLE 2
#define SHADOWMAP_CSM 1

#ifndef SHADOWMAP_TYPE
	#define SHADOWMAP_TYPE SHADOWMAP_NONE
#endif

#ifndef HAS_TWO_LAYER
	#define HAS_TWO_LAYER 0
#endif

#ifndef HAS_LIGHTMAP
	#define HAS_LIGHTMAP 0
#endif

#ifndef HAS_COLORMAP
	#define HAS_COLORMAP 1
#endif
#ifndef HAS_NORMAILSPEC
	#define HAS_NORMAILSPEC 0
#endif

#ifndef MAX_LIGHT_NUM
#define MAX_LIGHT_NUM 8
#endif

#define COLORMAP_ALPHABLEND_NONE 0
#define COLORMAP_ALPHABLEND 1
#define COLORMAP_ALPHABLEND_UPPER 2
#define COLORMAP_ALPHABLEND_BOTTOM 3

#ifndef COLORMAP_ALPHABLEND_TYPE
	#define COLORMAP_ALPHABLEND_TYPE 0
#endif

#ifndef ARB_fog_linear
	#define ARB_fog_linear 0
#endif

#ifndef ARB_fog_exp
	#define ARB_fog_exp 0
#endif

#ifndef ARB_fog_exp2
	#define ARB_fog_exp2 0
#endif


#define LIGHT_CALC_NONE   0
#define LIGHT_CALC_VS     1
#define LIGHT_CALC_PS     2
#ifndef LIGHT_CALC_TYPE
    #define LIGHT_CALC_TYPE LIGHT_CALC_VS
#endif


#if SHADOWMAP_TYPE == SHADOWMAP_CSM
	#define SHADOWMAP_CSM_SPLIT (csm_params.x)
#else
	#define SHADOWMAP_CSM_SPLIT 1
#endif
#define shadowgray 0.5f
#define texoffset 0.05f
#define blackOffset 0.15

float3 GetColorByLightGreaterOne(float3 src, float4 isystem_userdata)
{
	return lerp(saturate(src), src, isystem_userdata.z);
}


float blinn( float3 n, float3 v, float3 l, float exp )
{
		float fNormFactor = exp * 0.159155h + 0.31831h;
		float3 h = normalize(v + l);
		//return fNormFactor * pow( saturate(dot(n,h)), exp );
		return pow( max(dot(n,h), 0.01), exp );
}

float3 calcNormalBias(float3 worldNormal, float3 lightDir, float normalBiasSettings)
{
	float cosine = dot(worldNormal, lightDir);
	float sine = sqrt(1 - cosine*cosine);
	return worldNormal * sine * normalBiasSettings;
}

void terrain_vs(
		in float3 position : POSITION,
		in float3 normal : NORMAL,
		in float2 uv0 : TEXCOORD0,
	    #if HAS_NORMAILSPEC
		in float4 tangent0 : TANGENT0,
	    #endif
		#if HAS_TWO_LAYER
		in float2 uv1 : TEXCOORD1,
	    #if HAS_NORMAILSPEC
		in float4 tangent1 : TANGENT1,
	    #endif
		#endif
         	#if HAS_LIGHTMAP || HAS_COLORMAP
            in float2 uvBlend : TEXCOORD7,
         	#endif
            
            out float4 oPosition : POSITION,
            out float2 oUV0 : TEXCOORD0,
          #if HAS_TWO_LAYER
            out float2 oUV1 : TEXCOORD1,
          #endif
          #if HAS_LIGHTMAP || HAS_COLORMAP
            out float2 oUVBlend : TEXCOORD2,
          #endif
            out float3 oNormalInView : TEXCOORD3,
            out float3 oPosInView : TEXCOORD4,
	  #if HAS_NORMAILSPEC
	    out float4 oTangent0InView : TEXCOORD5,
	    #if HAS_TWO_LAYER
		out float4 oTangent1InView : TEXCOORD8,
	    #endif
	  #endif

		uniform float4 light_position_array[MAX_LIGHT_NUM],
            
            
          #if LIGHT_CALC_TYPE == LIGHT_CALC_VS
          	uniform float4 derived_scene_colour,
          	uniform float4 surface_specular_colour,
    				uniform float  surface_shininess,
    				uniform float4 light_specular_colour0,    	
						uniform float4 light_attenuation_array[MAX_LIGHT_NUM],         
						uniform float4 light_diffuse_colour_array[MAX_LIGHT_NUM],
						uniform float light_count,
						uniform float3 camera_position, 
						
						out float4 oVSDiffuseColor : COLOR0,
            out float4 oVSSpecularColor : COLOR1,
          #endif
					#if SHADOWMAP_TYPE != SHADOWMAP_NONE
						uniform float4x4 shadow_view_matrix,
						out float4 oDepthInShadow : TEXCOORD6,
						#if SHADOWMAP_TYPE == SHADOWMAP_SIMPLE
            		uniform float4x4 shadow_proj_matrix,      
          	#endif
          #endif
						//uniform float4 cameraPos,      
						uniform float4x4 world_matrix,
						uniform float4x4 view_matrix,
            uniform float4x4 viewproj_matrix,
			uniform float4 isystem_userdata
           )
{
    float4 worldPos = mul(world_matrix, float4(position, 1.0));
    oPosition = mul( viewproj_matrix, worldPos);

		oUV0 = uv0;
#if HAS_TWO_LAYER
		oUV1 = uv1;
#endif
#if HAS_LIGHTMAP || HAS_COLORMAP
		oUVBlend = uvBlend;
#endif
		float3 worldNormal = mul(world_matrix, float4(normal.xyz, 0.0)).xyz;
		oNormalInView = mul(view_matrix, float4(worldNormal.xyz, 0.0)).xyz;
		oPosInView = mul(view_matrix, float4(worldPos.xyz, 1.0)).xyz;

#if HAS_NORMAILSPEC
		float3 worldTangent0 = mul(world_matrix, float4(tangent0.xyz, 0.0)).xyz;
		oTangent0InView = mul(view_matrix, float4( worldTangent0, 0.0 ));
		oTangent0InView.w = tangent0.w;
	#if HAS_TWO_LAYER
		float3 worldTangent1 = mul(world_matrix, float4(tangent1.xyz, 0.0)).xyz;
		oTangent1InView = mul(view_matrix, float4( worldTangent1, 0.0 ));
		oTangent1InView = tangent1.w;
	#endif
#endif
		
#if LIGHT_CALC_TYPE == LIGHT_CALC_VS
		float4 lightingDiffuseColor = float4(1.0f,1.0f,1.0f,1.0f);
		float4 lightingSpecularColor = float4(1.0f,1.0f,1.0f,1.0f);
		
		float3 Nn = normalize(worldNormal);
		float3 Vn = normalize(camera_position - worldPos.xyz);
		float3 Ln0 = normalize(light_position_array[0].xyz);
    
		float3 LightDiffuse = float3(0.0,0.0,0.0);
    for (int l = 0; l < light_count; ++l)
   	{
        float3 lightDir = light_position_array[l].xyz - (worldPos.xyz * light_position_array[l].w);
        float d = length(lightDir);
        float3 Ln = lightDir / d;
    		float fNdotL = dot(Nn, Ln);

        //float att = lerp(0, 1, 1 / dot(float3(1, d, d*d), light_attenuation_array[l].yzw));
	float att = pow(saturate(-d / light_attenuation_array[l].x + 1.0), light_attenuation_array[l].y);
	float3 lDiffuse = att * max(fNdotL, 0) * light_diffuse_colour_array[l].rgb * light_diffuse_colour_array[l].a;
        LightDiffuse += saturate(lDiffuse);
    }
   	//lightingDiffuseColor.rgb = saturate(LightDiffuse + derived_scene_colour.rgb);
   	lightingDiffuseColor.rgb = GetColorByLightGreaterOne(LightDiffuse + derived_scene_colour.rgb, isystem_userdata);
   	
   	// direct light specular
    lightingSpecularColor.rgb = blinn(Nn, Vn, Ln0, surface_shininess) * light_specular_colour0.xyz * surface_specular_colour.xyz;

		oVSDiffuseColor = lightingDiffuseColor;
		oVSSpecularColor = lightingSpecularColor;
#endif
		
		
#if SHADOWMAP_TYPE == SHADOWMAP_SIMPLE
			float4 posInShadowView = mul(shadow_view_matrix, worldPos);
			float4 posInShadowProj = mul(shadow_proj_matrix, posInShadowView);
			posInShadowProj.xyz = posInShadowProj.xyz/posInShadowProj.w;
			float2 shadowUV = posInShadowProj.xy;
			shadowUV = float2(0.5, 0.5) + float2(0.5, -0.5) * shadowUV;
			
			oDepthInShadow.xy = shadowUV.xy;
			oDepthInShadow.z = posInShadowProj.z;
			oDepthInShadow.w = -posInShadowView.z;
#elif SHADOWMAP_TYPE == SHADOWMAP_CSM
			oDepthInShadow = mul(shadow_view_matrix,
				float4(worldPos.xyz + calcNormalBias(worldNormal, light_position_array[0].xyz, isystem_userdata.w), worldPos.w));
#endif
}



float3 Fogging(float3 finalColour, float depthInView, float4 fogParam, float4 fogColor)
{
		float fogFactor = 1.0;
#if ARB_fog_linear
    fogFactor = saturate((fogParam.z - depthInView) * fogParam.w);
#elif ARB_fog_exp
    fogFactor = exp(- depthInView * fogParam.x);
#elif ARB_fog_exp2
    fogFactor = exp(- (depthInView * fogParam.x) * (depthInView * fogParam.x));
#endif
		float3 color = lerp( fogColor.rgb, finalColour.rgb, fogFactor );
		color = finalColour.rgb * fogFactor + fogColor.rgb * (1 - fogFactor);
    return color;
}

float3 OverlayBlend(float4 baseColour, float3 texturedColour, float4 c1)
{
		float3 B = baseColour.rgb * texturedColour;
		//将colormap的颜色做一个clamp，避免深颜色过深
    float3 A = clamp(c1.rgb, float3(blackOffset, blackOffset, blackOffset), float3(1 ,1, 1));
    //float3 A = c1.rgb;
    float3 factor = clamp(sign(B - float3(0.5, 0.5, 0.5)), float3(0, 0, 0), float3(1, 1, 1));
    float3 finalColour = factor + 2 * (1 - 2*factor)*(factor - A) * (factor - B);
    
    return finalColour;
}

float3 BlendColorMap(float3 baseColour, float3 texturedColour, float4 c1)
{
		float3 B = baseColour * texturedColour;
		//将colormap的颜色做一个clamp，避免深颜色过深
    float3 A = clamp(c1.rgb, float3(blackOffset, blackOffset, blackOffset), float3(1 ,1, 1));
    //float3 A = c1.rgb;
    float3 factor = clamp(sign(B - float3(0.5, 0.5, 0.5)), float3(0, 0, 0), float3(1, 1, 1));
    float3 finalColour = factor + 2 * (1 - 2*factor)*(factor - A) * (factor - B);
    
    return finalColour;
}

float3 HighLightBlend(float4 baseColour, float3 texturedColour, float4 c1)
{
	float3 factor = clamp(sign(c1.rgb - float3(0.5, 0.5, 0.5)), float3(0, 0, 0), float3(1, 1, 1));
	float3 finalColour = baseColour.rgb * (texturedColour + (factor + (1 - factor) * texturedColour) * (c1.rgb - 0.5)*2); 
	
	return finalColour;
}

/** Returns an occlusion factor based on the depths. */
float CalculateOcclusion(float SceneDepth, float ShadowmapDepth, float brightness, float4 isystem_userdata, float csmIndex)
{
	// The standard comparison is SceneDepth < ShadowmapDepth
	// Using a soft transition based on depth difference
	// Offsets shadows a bit but reduces self shadowing artifacts considerably
	// 深度插值转换到0-1之间，可以有效减少自阴影的黑块，但偏移较多，需要调节数值
	//float TransitionScale = 0.035;
	float TransitionScale = 50.0 * (1.0 + csmIndex * 0.25);
	ShadowmapDepth = (ShadowmapDepth != 0 ) ? ShadowmapDepth : 10000000;
	//return (SceneDepth - 5 > ShadowmapDepth) ? 1*brightness : 0;
	
	//float maskValue = 1-saturate((ShadowmapDepth - SceneDepth ) * TransitionScale + 1.0);
	float maskValue = step(ShadowmapDepth + isystem_userdata.x, SceneDepth);
	return lerp(maskValue * brightness, maskValue, isystem_userdata.z);
	//return (1-saturate((ShadowmapDepth - SceneDepth ) * TransitionScale + 1.0)) *brightness;
	//return (1-saturate((ShadowmapDepth - SceneDepth ) * TransitionScale + 1.0));
	//return saturate((ShadowmapDepth - SceneDepth ) * TransitionScale + 1.0);
}

float ManualPCF(float4 ShadowPosition, sampler2D ShadowDepthTexture, float brightness, float4 shadow_param,
#if SHADOWMAP_TYPE == SHADOWMAP_CSM
				float4 csm_params,
#endif
				float4 isystem_userdata, float csmIndex)
{
	// Filter the shadow comparison using 9 point samples in a grid and 4 PCF calculations based on those 9 samples
	float3 ShadowBufferSizeAndSoftTransitionScale = float3(shadow_param.z*SHADOWMAP_CSM_SPLIT,shadow_param.z,1.0);
	float2 ShadowTexelSize = float2(1.0, 1.0) / ShadowBufferSizeAndSoftTransitionScale.xy;
	float2 Fraction = frac(ShadowPosition.xy * ShadowBufferSizeAndSoftTransitionScale.xy);
	float2 Sample00TexelCorner = floor(ShadowPosition.xy * ShadowBufferSizeAndSoftTransitionScale.xy - float2(1, 1));
	float2 Sample00TexelCenter = Sample00TexelCorner + float2(0.5, 0.5);

	float Sample00Value = CalculateOcclusion(ShadowPosition.w, tex2Dlod(ShadowDepthTexture, float4(Sample00TexelCenter * ShadowTexelSize, 0, 0)).r, brightness, isystem_userdata, csmIndex);
	
	float Sample01Value = CalculateOcclusion(ShadowPosition.w, tex2Dlod(ShadowDepthTexture, float4((Sample00TexelCenter + float2(0, 1)) * ShadowTexelSize, 0, 0)).r, brightness, isystem_userdata, csmIndex);
	float Sample02Value = CalculateOcclusion(ShadowPosition.w, tex2Dlod(ShadowDepthTexture, float4((Sample00TexelCenter + float2(0, 2)) * ShadowTexelSize, 0, 0)).r, brightness, isystem_userdata, csmIndex);
	float Sample10Value = CalculateOcclusion(ShadowPosition.w, tex2Dlod(ShadowDepthTexture, float4((Sample00TexelCenter + float2(1, 0)) * ShadowTexelSize, 0, 0)).r, brightness, isystem_userdata, csmIndex);
	float Sample11Value = CalculateOcclusion(ShadowPosition.w, tex2Dlod(ShadowDepthTexture, float4((Sample00TexelCenter + float2(1, 1)) * ShadowTexelSize, 0, 0)).r, brightness, isystem_userdata, csmIndex);
	
	float Sample12Value = CalculateOcclusion(ShadowPosition.w, tex2Dlod(ShadowDepthTexture, float4((Sample00TexelCenter + float2(1, 2)) * ShadowTexelSize, 0, 0)).r, brightness, isystem_userdata, csmIndex);
	float Sample20Value = CalculateOcclusion(ShadowPosition.w, tex2Dlod(ShadowDepthTexture, float4((Sample00TexelCenter + float2(2, 0)) * ShadowTexelSize, 0, 0)).r, brightness, isystem_userdata, csmIndex);
	float Sample21Value = CalculateOcclusion(ShadowPosition.w, tex2Dlod(ShadowDepthTexture, float4((Sample00TexelCenter + float2(2, 1)) * ShadowTexelSize, 0, 0)).r, brightness, isystem_userdata, csmIndex);
	float Sample22Value = CalculateOcclusion(ShadowPosition.w, tex2Dlod(ShadowDepthTexture, float4((Sample00TexelCenter + float2(2, 2)) * ShadowTexelSize, 0, 0)).r, brightness, isystem_userdata, csmIndex);
	
	float2 HorizontalLerp00 = lerp(float2(Sample00Value, Sample01Value), float2(Sample10Value, Sample11Value), Fraction.xx);
	float PCFResult00 = lerp(HorizontalLerp00.x, HorizontalLerp00.y, Fraction.y); 
	float2 HorizontalLerp01 = lerp(float2(Sample01Value, Sample02Value), float2(Sample11Value, Sample12Value), Fraction.xx);
	float PCFResult01 = lerp(HorizontalLerp01.x, HorizontalLerp01.y, Fraction.y); 
	float2 HorizontalLerp10 = lerp(float2(Sample10Value, Sample11Value), float2(Sample20Value, Sample21Value), Fraction.xx);
	float PCFResult10 = lerp(HorizontalLerp10.x, HorizontalLerp10.y, Fraction.y); 
	float2 HorizontalLerp11 = lerp(float2(Sample11Value, Sample12Value), float2(Sample21Value, Sample22Value), Fraction.xx);
	float PCFResult11 = lerp(HorizontalLerp11.x, HorizontalLerp11.y, Fraction.y); 
	
	return saturate((PCFResult00 + PCFResult01 + PCFResult10 + PCFResult11) * 0.25);
}

#if SHADOWMAP_TYPE != SHADOWMAP_CSM
void calculateShadow(sampler2D shadowTex, float4 depthInShadow, float brightness, float4 shadow_param, float4 isystem_userdata, out float shadow, out float lr)
{
	shadow = 1.0;
    	lr = 1.0;
	float2 shadowUV = depthInShadow.xy;
	if(shadowUV.x > 0.001 && shadowUV.x < 0.999 && shadowUV.y > 0.001 && shadowUV.y < 0.999)
	{
			shadow = ManualPCF(depthInShadow, shadowTex, brightness, shadow_param, isystem_userdata, 0);
							
			float distance = max(1 - length(shadowUV - float2(0.5,0.5)) * 2, 0);
			lr = min( distance/(1.0001 - 0.9), 1);
			//shadow *= lr;
			shadow = (1-shadow);
			lr = 1-lr;
	}
}
#elif SHADOWMAP_TYPE == SHADOWMAP_CSM
void loop_shadow_csm_casts(float4 posInView, inout float4 shadowTexCoord, inout float cascadeFound, inout int iCurrentCascadeIndex, float4 csm_params, float4x4 csm_proj_scale, float4x4 csm_proj_offset)
{
	for( int iCascadeIndex = 0; iCascadeIndex < csm_params.x; ++iCascadeIndex ) 
	{
		float4 texCoord = posInView * csm_proj_scale[iCascadeIndex];
		texCoord += csm_proj_offset[iCascadeIndex];

		if (min(min(texCoord.x, texCoord.y), texCoord.z) >= 0 &&
			max(max(texCoord.x, texCoord.y), texCoord.z) <= 1 &&
			cascadeFound == 0)
		{
			shadowTexCoord = texCoord;
			iCurrentCascadeIndex = iCascadeIndex;   
			cascadeFound = 1; 
		}
	}
}

void calculateShadow_csm(sampler2D shadowTex, float4 posInView, float4 shadow_param, float4 csm_params, float4x4 csm_proj_scale, float4x4 csm_proj_offset, float brightness, float3 posInMainCam, float4 isystem_userdata, out float shadow, out float lr)
{
		shadow = 1.0;
  	lr = 1.0;
  	float cascadeFound = 0;
	int iCurrentCascadeIndex = 0;
	float4 shadowTexCoord = float4(0,0,0,0);

	loop_shadow_csm_casts(posInView, shadowTexCoord, cascadeFound, iCurrentCascadeIndex, csm_params, csm_proj_scale, csm_proj_offset);
    
   	shadowTexCoord.w = -posInView.z;

	float borderScale = (shadow_param.z - 2) / shadow_param.z;
	float borderOffset = (1 - borderScale) / 2;

   	// calculate real uv
   	shadowTexCoord.xy *= float2(csm_params.y * borderScale, borderScale);
    shadowTexCoord.xy += float2(csm_params.y * ((float)iCurrentCascadeIndex + borderOffset), borderOffset); 
   	
   	// calculate shadow factor
   	shadow = ManualPCF(shadowTexCoord, shadowTex, brightness, shadow_param, csm_params, isystem_userdata, (float)iCurrentCascadeIndex);
   	
   	
   	
   	// calculate blend
   	/*float blendBandLocation = min( min( shadowTexCoord.x, shadowTexCoord.y ), min( 1.0f - shadowTexCoord.x, 1.0f - shadowTexCoord.y ) );
   	if( blendBandLocation < csm_params.z)
   	{
   			int iNextCascadeIndex = 0;
   			iNextCascadeIndex = min ( csm_params.x - 1, iCurrentCascadeIndex + 1 );
   			
   			float blendValue = blendBandLocation / csm_params.z;
   			
   			if (iNextCascadeIndex != iCurrentCascadeIndex)
   			{
	   			float4 shadowTexCoord_blend = float4(0,0,0,0);
	   			shadowTexCoord_blend = posInView * csm_proj_scale[iNextCascadeIndex];
	        shadowTexCoord_blend += csm_proj_offset[iNextCascadeIndex]; 
	        shadowTexCoord_blend.xyz = shadowTexCoord_blend.xyz / shadowTexCoord_blend.w;
	        
	        if ( min( shadowTexCoord_blend.x, shadowTexCoord_blend.y ) > 0.001f && max( shadowTexCoord_blend.x, shadowTexCoord_blend.y ) < 0.999f )
	        {
	        	shadowTexCoord_blend.x *= csm_params.y;
	    			shadowTexCoord_blend.x += (csm_params.y * (float)iNextCascadeIndex );
	    			shadowTexCoord_blend.w = -posInView.z;
	    		
	    			float shadow_blend = ManualPCF(shadowTexCoord_blend, shadowTex, brightness, (float)iCurrentCascadeIndex);
	        	shadow = lerp( shadow_blend, shadow, blendValue ); 
	        }
	        //else
	        //{
	        	//lr = 1-blendValue;
	        //}
        }
        //else
        //{
        //	lr = 1-blendValue;
        //}
   	}*/
   	
   	//float distance = max(1 - length(shadowTexCoord.xy - float2(0.5,0.5)) * 2, 0);
		//lr = min( distance/(1.0001 - 0.9), 1);
		//shadow *= lr;
		//shadow = (1-shadow);
		//lr = 1-lr;
		lr = smoothstep(0.5 * csm_params.w, 0.95 * csm_params.w, length(posInMainCam));

		shadow *= 1 - smoothstep(0.95 * csm_params.w, csm_params.w, length(posInMainCam));
	    shadow = lerp(1, 1-shadow, cascadeFound);
}
#endif
/*
void test(sampler2D shadowTex, float4 depthInShadow, float4 shadow_csm_param, float4x4 shadow_csm_proj_scale, float4x4 shadow_csm_proj_offset, float brightness, out float shadowFactor, out float lightmapFactor)
{
		shadowFactor = 1.0;
  	lightmapFactor = 1.0;
  	int iCascadeFound = 0;
		int iCurrentCascadeIndex = 0;
	
		float4 shadowTexCoord = float4(0,0,0,0);
    for( int iCascadeIndex = 0; (iCascadeIndex < shadow_csm_param.x); ++iCascadeIndex ) 
    {
     		shadowTexCoord = depthInShadow * shadow_csm_proj_scale[iCascadeIndex];
      	shadowTexCoord += shadow_csm_proj_offset[iCascadeIndex];

				shadowTexCoord.xyz = shadowTexCoord.xyz / shadowTexCoord.w;
       	if ( min( shadowTexCoord.x, shadowTexCoord.y ) > 0.001f && max( shadowTexCoord.x, shadowTexCoord.y ) < 0.999f )
        {
						iCurrentCascadeIndex = iCascadeIndex;   
           	iCascadeFound = 1; 
           	//break;
       	}
    }
    if (iCascadeFound != 0)
    {
   	shadowTexCoord.w = -depthInShadow.z;

   	// calculate real uv
   	shadowTexCoord.x *= shadow_csm_param.y;
    shadowTexCoord.x += (shadow_csm_param.y * (float)iCurrentCascadeIndex ); 
   	
   	// calculate shadow factor
   	shadowFactor = ManualPCF(shadowTexCoord, shadowTex, brightness, (float)iCurrentCascadeIndex);

		shadowFactor = (1-shadowFactor);
		lightmapFactor = 0.0;
		}
}
*/

float2 makeUV(float color){
	float2 LUTPos = float2(0,0);
	LUTPos.y = floor(color * 255 / 16) / 16;
	LUTPos.x = color * 255 % 16 / 16;
	return LUTPos;
}
float3 LUTColor(sampler2D lutTex, float3 textureColor)
{
		float3 color = float3(0,0,0);
		color.r = tex2Dlod(lutTex, float4(makeUV(textureColor.r), 0, 0)).r;
		color.g = tex2Dlod(lutTex, float4(makeUV(textureColor.g), 0, 0)).g;
		color.b = tex2Dlod(lutTex, float4(makeUV(textureColor.b), 0, 0)).b;
		return color;
}

void terrain_ps(float4 Position : POSITION,    
		in float2 uv0 : TEXCOORD0,
		uniform sampler2D layer0 : register(s0),
		#if HAS_NORMAILSPEC
			uniform sampler2D normalspec0 : register(s6),
		#endif
		#if HAS_TWO_LAYER
			in float2 uv1 : TEXCOORD1,
			uniform sampler2D layer1 : register(s1),
			#if HAS_NORMAILSPEC
				uniform sampler2D normalspec1 : register(s7),
			#endif
		#endif
	    #if LUT_ENABLE == 1
		uniform sampler2D lutTex : register(s4),
	    #endif
	    #if HAS_LIGHTMAP || HAS_COLORMAP
		in float2 uvBlend : TEXCOORD2,
		#if HAS_LIGHTMAP
			uniform sampler2D lightmap : register(s2),
		#endif
		#if HAS_COLORMAP
			uniform sampler2D colormap : register(s3),
				#endif
	    #endif

    in float3 normalInView : TEXCOORD3,
    in float3 posInView : TEXCOORD4,
	#if HAS_NORMAILSPEC
		in float4 tangent0InView : TEXCOORD5,
		#if HAS_TWO_LAYER
			in float4 tangent1InView : TEXCOORD8,
		#endif
	#endif
    
    
    #if SHADOWMAP_TYPE != SHADOWMAP_NONE
	  		uniform sampler2D shadowTex : register(s5),
	  		in float4 depthInShadow : TEXCOORD6,
	  		uniform float4 shadow_param,
	  	#if SHADOWMAP_TYPE == SHADOWMAP_CSM
	  			// x: csm level num y: 1/csm level num z: blendArea
	  			uniform float4 shadow_csm_param,
	  			uniform float4x4 shadow_csm_proj_scale,
	  			uniform float4x4 shadow_csm_proj_offset,
	  	#endif
	  #endif
	  
	  uniform float4 derived_scene_colour,
	  #if LIGHT_CALC_TYPE == LIGHT_CALC_VS
	  		in float4 vsDiffuseColor : COLOR0,
    		in float4 vsSpecularColor : COLOR1,
    #elif LIGHT_CALC_TYPE == LIGHT_CALC_PS && SHADOWMAP_TYPE != SHADOWMAP_NONE
    		uniform float4 surface_specular_colour,
    		uniform float  surface_shininess,
    		uniform float4 light_specular_colour0,
    		uniform float4 light_position_view_space_array[MAX_LIGHT_NUM],
				uniform float4 light_attenuation_array[MAX_LIGHT_NUM],         
				uniform float4 light_diffuse_colour_array[MAX_LIGHT_NUM],
				uniform float light_count,
    #endif
		
		#if ARB_fog_linear== 1 || ARB_fog_exp == 1 || ARB_fog_exp2 == 1
			uniform float4 fog_params,
    	uniform float4 fog_colour,
		#endif
		uniform float4 isystem_userdata,
		uniform float4x4 projection_matrix,
		uniform sampler2D ssao_buffer : register(s12),
    out float4 oColour : COLOR)
{
		oColour = float4(0.0, 0.0, 0.0, 1.0);
		
		float4 texColor = float4(1.0, 1.0, 1.0, 1.0);
		float4 clightmap = float4(1.0, 1.0, 1.0, 1.0);
		
		float4 c0 = tex2D(layer0, uv0);
		texColor = c0;
		
#if HAS_COLORMAP
		float4 cColormap = tex2D(colormap, uvBlend);
#endif		
		
#if HAS_TWO_LAYER
    float4 c1 = tex2D(layer1, uv1);
    #if COLORMAP_ALPHABLEND_TYPE == COLORMAP_ALPHABLEND && HAS_COLORMAP
    	texColor.rgb = lerp(texColor.rgb, c1.rgb, cColormap.a);
    #elif COLORMAP_ALPHABLEND_TYPE == COLORMAP_ALPHABLEND_UPPER
    	texColor.rgb = lerp(texColor.rgb, c1.rgb, 1.0);
    #elif COLORMAP_ALPHABLEND_TYPE == COLORMAP_ALPHABLEND_BOTTOM
    	texColor.rgb = lerp(texColor.rgb, c1.rgb, 0.0);
    #else
    	texColor.rgb = lerp(texColor.rgb, c1.rgb, c1.a);
    #endif

#else
		#if COLORMAP_ALPHABLEND_TYPE == COLORMAP_ALPHABLEND_UPPER
			texColor.rgb = float3(1.0, 1.0, 1.0);
		#endif
#endif

		// lut
		#if LUT_ENABLE == 1
			texColor.xyz = LUTColor(lutTex, texColor.xyz);
		#endif
		oColour.rgb = texColor.rgb;
 
 		int iCascadeFound = 0;
    float shadowFactor = 1.0;
    float lightmapFactor = 1.0;
    float3 finalShadowColor = float3(1.0, 1.0, 1.0);
    #if SHADOWMAP_TYPE != SHADOWMAP_NONE
	  	float brightness = dot(light_diffuse_colour_array[0].rgb, float3(0.299, 0.587, 0.114));
	  	#if SHADOWMAP_TYPE == SHADOWMAP_SIMPLE
				calculateShadow(shadowTex, depthInShadow, brightness, shadow_param, isystem_userdata, shadowFactor, lightmapFactor);
			#elif SHADOWMAP_TYPE == SHADOWMAP_CSM
				calculateShadow_csm(shadowTex, depthInShadow, shadow_param, shadow_csm_param, shadow_csm_proj_scale, shadow_csm_proj_offset, brightness, posInView, isystem_userdata, shadowFactor, lightmapFactor);
				//test(shadowTex, depthInShadow, shadow_csm_param, shadow_csm_proj_scale, shadow_csm_proj_offset, brightness, shadowFactor, lightmapFactor);
				
			#endif
			
			float shadowStrength = shadow_param.x;
			float r = 1.0 - shadowStrength;
			shadowFactor = r + shadowFactor * (1.0 - r);
		
			float3 ShadowedColor = float3(0.5,0.5,0.5)*1.65;
			finalShadowColor = ShadowedColor * derived_scene_colour.rgb;
	  #endif
    		
    #if HAS_LIGHTMAP
    	
	  	clightmap = tex2D(lightmap, uvBlend);
	  	
	  	#if SHADOWMAP_TYPE != SHADOWMAP_NONE
	  		//lightmapFactor = min(max(-posInView.z - 2310.0, 0), 100.0)/100.0;
	  		float lightmapR = 1 - (1 - saturate(3*clightmap.r - 2))*brightness;
	  		shadowFactor = lerp(shadowFactor, lightmapR, saturate(lightmapFactor));
	  	#else
    		oColour.rgb *= clightmap.r;
	  	#endif
	  #endif
    
    
    // calculate light affect
    float3 lightColor = float3(0.0,0.0,0.0);
    float3 directLightSpecular = float3(0.0,0.0,0.0);
    
#if LIGHT_CALC_TYPE == LIGHT_CALC_VS

		lightColor = vsDiffuseColor.rgb;
		directLightSpecular = vsSpecularColor.rgb;
		
#elif LIGHT_CALC_TYPE == LIGHT_CALC_PS
    
    float3 directLightDiffuse = float3(0.0,0.0,0.0);
    float3 indirectLightDiffuse = float3(0.0,0.0,0.0);
    
    #if HAS_NORMAILSPEC
    	float3 tmpTan = normalize(tangent0InView.xyz);
	float3 tmpBnm = normalize(cross(normalInView, tmpTan) * tangent0InView.w);
	float3x3 tbn  = float3x3(tmpTan, tmpBnm, normalInView);
	float4 cBump = tex2D(normalspec0, uv0);
	cBump.rgb = cBump.rgb * 2.0 - 1.0;
	float3 Nn = normalize(mul(cBump.rgb, tbn));
	#if HAS_TWO_LAYER
		tmpTan = normalize(tangent1InView.xyz);
		tmpBnm = normalize(cross(normalInView, tmpTan) * tangent1InView.w);
		tbn  = float3x3(tmpTan, tmpBnm, normalInView);
		float4 cBump2 = tex2D(normalspec1, uv1);
		cBump2.rgb = cBump2.rgb * 2.0 - 1.0;
		float3 Nn2 = normalize(mul(cBump2.rgb, tbn));
		#if COLORMAP_ALPHABLEND_TYPE == COLORMAP_ALPHABLEND && HAS_COLORMAP
			Nn = normalize(lerp(Nn, Nn2, cColormap.a));
		#elif COLORMAP_ALPHABLEND_TYPE == COLORMAP_ALPHABLEND_UPPER
			Nn = normalize(lerp(Nn, Nn2, 1.0));
		#elif COLORMAP_ALPHABLEND_TYPE == COLORMAP_ALPHABLEND_BOTTOM
			Nn = normalize(lerp(Nn, Nn2, 0.0));
		#else
			Nn = normalize(lerp(Nn, Nn2, c1.a));
		#endif
	#endif
    #else
	float3 Nn = normalize(normalInView);
    #endif

    //oColour.rgb = normalize(worldTangent1.xyz);
    //return;

    float3 Vn = normalize(-posInView);
		
    // direct light dir
		float3 lightDir = light_position_view_space_array[0].xyz;
    float3 Ln = normalize(lightDir);
    
    // direct light diffuse
    float fNdotL = dot(Nn, Ln);
		directLightDiffuse = max(fNdotL, 0) * light_diffuse_colour_array[0].rgb * light_diffuse_colour_array[0].a;
		
    // direct light specular
    directLightSpecular = blinn(Nn, Vn, Ln, surface_shininess) * light_specular_colour0.xyz * surface_specular_colour.xyz * shadowFactor;
    
    // indirect light
    indirectLightDiffuse = derived_scene_colour.rgb;
    for (int l = 1; l < light_count; ++l)
    {
    		float3 lightDir = light_position_view_space_array[l].xyz - (posInView * light_position_view_space_array[l].w);
    		float d = length(lightDir);
    		float3 Ln = lightDir / d;
    		float fNdotL = dot(Nn, Ln);

		//float att = lerp(0, 1, 1 / dot(float3(1, d, d*d), light_attenuation_array[l].yzw));
		float att = pow(saturate(-d / light_attenuation_array[l].x + 1.0), light_attenuation_array[l].y);
		float3 ld = att * max(fNdotL, 0) * light_diffuse_colour_array[l].rgb * light_diffuse_colour_array[l].a;
		indirectLightDiffuse += saturate(ld);
     }

	float4 clipPos = mul(projection_matrix, float4(posInView, 1));
	clipPos /= clipPos.w;
	float2 screenUV = clipPos.xy * float2(0.5, -0.5) + float2(0.5, 0.5);
	float occlusion = tex2D(ssao_buffer, screenUV).r;
	indirectLightDiffuse *= occlusion;

		//lightColor = saturate(directLightDiffuse + indirectLightDiffuse) * shadowFactor + saturate(indirectLightDiffuse) * finalShadowColor * (1-shadowFactor);
		//lightColor = (directLightDiffuse + indirectLightDiffuse) * shadowFactor + (indirectLightDiffuse) * finalShadowColor * (1-shadowFactor);
		
		if (isystem_userdata.z)
		{
		lightColor = (directLightDiffuse) * shadowFactor + (indirectLightDiffuse);
		}
		else
		{
		lightColor = saturate(directLightDiffuse + indirectLightDiffuse) * shadowFactor + saturate(indirectLightDiffuse) * finalShadowColor * (1-shadowFactor);
		}
		

#endif
		
		// calculate blend color
#if HAS_COLORMAP
		oColour.rgb = BlendColorMap(lightColor, oColour.rgb, cColormap);
#else
    oColour.rgb *= lightColor;
#endif

#if HAS_NORMAILSPEC
	#if HAS_TWO_LAYER
		directLightSpecular = lerp(directLightSpecular * (1.0 - c0.a), directLightSpecular * (1.0 - c1.a), cColormap.a);
	#else
		directLightSpecular *= 1.0 - c0.a;
	#endif
#else
	directLightSpecular *= 1.0 - c0.a;
	#if HAS_TWO_LAYER
		#if COLORMAP_ALPHABLEND_TYPE == COLORMAP_ALPHABLEND && HAS_COLORMAP
			directLightSpecular *= 1.0 - cColormap.a;
		#else
			directLightSpecular *= 1.0 - c1.a;
		#endif
	#endif
#endif

oColour.rgb += directLightSpecular;

#if ARB_fog_linear== 1 || ARB_fog_exp == 1 || ARB_fog_exp2 == 1
   oColour.xyz = Fogging(oColour.rgb, -posInView.z, fog_params, fog_colour);
#endif

}




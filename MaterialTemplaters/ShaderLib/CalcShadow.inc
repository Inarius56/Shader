#ifndef _CalcShadow_INC_
#define _CalcShadow_INC_

#if SHADOWMAP_TYPE == SHADOWMAP_CSM
	#define SHADOWMAP_CSM_SPLIT (shadow_csm_param.x)
#else
	#define SHADOWMAP_CSM_SPLIT 1
#endif

float3 calcNormalBias(float3 worldNormal)
{
	float cosine = dot(worldNormal, light_position_array[0].xyz);
	float sine = sqrt(1 - cosine*cosine);
	return worldNormal * sine * isystem_userdata.w;
}

#ifdef __VS__
void Calc_Shadow_Vs( inout VertParams params )
{
#if SHADOWMAP_TYPE == SHADOWMAP_SIMPLE
			float4 posInShadowView = mul(shadow_view_matrix, params.pw);
			float4 posInShadowProj = mul(shadow_proj_matrix, posInShadowView);
			posInShadowProj.xyz = posInShadowProj.xyz/posInShadowProj.w;
			float2 shadowUV = posInShadowProj.xy;
			shadowUV = float2(0.5, 0.5) + float2(0.5, -0.5) * shadowUV;
			
			params.shadow.xy = shadowUV.xy;
			params.shadow.z = posInShadowProj.z;
			params.shadow.w = -posInShadowView.z;
#elif SHADOWMAP_TYPE == SHADOWMAP_CSM
			params.shadow = mul(shadow_view_matrix, float4(params.pw.xyz + calcNormalBias(params.nw.xyz), params.pw.w));
#endif
}
#endif

void CalculateRightAndUpTexelDepthDeltas ( in float3 vShadowTexDDX,
                                           in float3 vShadowTexDDY,
                                           out float fUpTextDepthWeight,
                                           out float fRightTextDepthWeight
 ) {
        
    // We use the derivatives in X and Y to create a transformation matrix.  Because these derivives give us the 
    // transformation from screen space to shadow space, we need the inverse matrix to take us from shadow space 
    // to screen space.  This new matrix will allow us to map shadow map texels to screen space.  This will allow 
    // us to find the screen space depth of a corresponding depth pixel.
    // This is not a perfect solution as it assumes the underlying geometry of the scene is a plane.  A more 
    // accureate way of finding the actual depth would be to do a deferred rendering approach and actually 
    //sample the depth.
    
    // Using an offset, or using variance shadow maps is a better approach to reducing these artifacts in most cases.
    
    float2x2 matScreentoShadow = float2x2( vShadowTexDDX.xy, vShadowTexDDY.xy );
    float fDeterminant = determinant ( matScreentoShadow );
    
    float fInvDeterminant = 1.0f / fDeterminant;
    
    float2x2 matShadowToScreen = float2x2 (
        matScreentoShadow._22 * fInvDeterminant, matScreentoShadow._12 * -fInvDeterminant, 
        matScreentoShadow._21 * -fInvDeterminant, matScreentoShadow._11 * fInvDeterminant );

    float2 vRightShadowTexelLocation = float2( 1.0/(shadow_param.z*SHADOWMAP_CSM_SPLIT), 0.0f );
    float2 vUpShadowTexelLocation = float2( 0.0f, 1.0/shadow_param.z );  
    
    // Transform the right pixel by the shadow space to screen space matrix.
    float2 vRightTexelDepthRatio = mul( vRightShadowTexelLocation,  matShadowToScreen );
    float2 vUpTexelDepthRatio = mul( vUpShadowTexelLocation,  matShadowToScreen );

    // We can now caculate how much depth changes when you move up or right in the shadow map.
    // We use the ratio of change in x and y times the dervivite in X and Y of the screen space 
    // depth to calculate this change.
    fUpTextDepthWeight = 
        vUpTexelDepthRatio.x * vShadowTexDDX.z 
        + vUpTexelDepthRatio.y * vShadowTexDDY.z;
    fRightTextDepthWeight = 
        vRightTexelDepthRatio.x * vShadowTexDDX.z 
        + vRightTexelDepthRatio.y * vShadowTexDDY.z;
        
}

/** Returns an occlusion factor based on the depths. */
float CalculateOcclusion(float SceneDepth, float ShadowmapDepth, float brightness, float csmIndex)
{
	// The standard comparison is SceneDepth < ShadowmapDepth
	// Using a soft transition based on depth difference
	// Offsets shadows a bit but reduces self shadowing artifacts considerably
	float TransitionScale = 50.0 * (1.0 + csmIndex * 0.25);
	ShadowmapDepth = (ShadowmapDepth != 0 ) ? ShadowmapDepth : 10000000;
	//return (SceneDepth - 5 > ShadowmapDepth) ? 0 : 1;
	
	//float maskValue = 1-saturate((ShadowmapDepth - SceneDepth ) * TransitionScale + 1.0);
	float maskValue = step(ShadowmapDepth + isystem_userdata.x, SceneDepth);
	return lerp(maskValue * brightness, maskValue, isystem_userdata.z);
	
	//return (1-saturate((ShadowmapDepth - SceneDepth ) * TransitionScale + 1.0)) *brightness;
	//return (1-saturate((ShadowmapDepth - SceneDepth ) * TransitionScale + 1.0));
	//return saturate((ShadowmapDepth - SceneDepth ) * TransitionScale + 1.0);
}

float ManualPCF(float4 ShadowPosition, sampler2D ShadowDepthTexture, float brightness, float csmIndex)
{
	// Filter the shadow comparison using 9 point samples in a grid and 4 PCF calculations based on those 9 samples
	float3 ShadowBufferSizeAndSoftTransitionScale = float3(shadow_param.z*SHADOWMAP_CSM_SPLIT,shadow_param.z,1.0);
	float2 ShadowTexelSize = float2(1.0, 1.0) / ShadowBufferSizeAndSoftTransitionScale.xy;
	float2 Fraction = frac(ShadowPosition.xy * ShadowBufferSizeAndSoftTransitionScale.xy);
	float2 Sample00TexelCorner = floor(ShadowPosition.xy * ShadowBufferSizeAndSoftTransitionScale.xy - float2(1, 1));
	float2 Sample00TexelCenter = Sample00TexelCorner + float2(0.5, 0.5);

	float Sample00Value = CalculateOcclusion(ShadowPosition.w, tex2Dlod(ShadowDepthTexture, float4(Sample00TexelCenter * ShadowTexelSize, 0, 0)).r, brightness, csmIndex);
	
	float Sample01Value = CalculateOcclusion(ShadowPosition.w, tex2Dlod(ShadowDepthTexture, float4((Sample00TexelCenter + float2(0, 1)) * ShadowTexelSize, 0, 0)).r, brightness, csmIndex);
	float Sample02Value = CalculateOcclusion(ShadowPosition.w, tex2Dlod(ShadowDepthTexture, float4((Sample00TexelCenter + float2(0, 2)) * ShadowTexelSize, 0, 0)).r, brightness, csmIndex);
	float Sample10Value = CalculateOcclusion(ShadowPosition.w, tex2Dlod(ShadowDepthTexture, float4((Sample00TexelCenter + float2(1, 0)) * ShadowTexelSize, 0, 0)).r, brightness, csmIndex);
	float Sample11Value = CalculateOcclusion(ShadowPosition.w, tex2Dlod(ShadowDepthTexture, float4((Sample00TexelCenter + float2(1, 1)) * ShadowTexelSize, 0, 0)).r, brightness, csmIndex);
	
	float Sample12Value = CalculateOcclusion(ShadowPosition.w, tex2Dlod(ShadowDepthTexture, float4((Sample00TexelCenter + float2(1, 2)) * ShadowTexelSize, 0, 0)).r, brightness, csmIndex);
	float Sample20Value = CalculateOcclusion(ShadowPosition.w, tex2Dlod(ShadowDepthTexture, float4((Sample00TexelCenter + float2(2, 0)) * ShadowTexelSize, 0, 0)).r, brightness, csmIndex);
	float Sample21Value = CalculateOcclusion(ShadowPosition.w, tex2Dlod(ShadowDepthTexture, float4((Sample00TexelCenter + float2(2, 1)) * ShadowTexelSize, 0, 0)).r, brightness, csmIndex);
	float Sample22Value = CalculateOcclusion(ShadowPosition.w, tex2Dlod(ShadowDepthTexture, float4((Sample00TexelCenter + float2(2, 2)) * ShadowTexelSize, 0, 0)).r, brightness, csmIndex);
	
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

float calculateShadow(sampler2D shadowTex, float4 depthInShadow, float brightness)
{
			float shadow = 1.0;

			float2 shadowUV = depthInShadow.xy;
			if(shadowUV.x > 0.001 && shadowUV.x < 0.999 && shadowUV.y > 0.001 && shadowUV.y < 0.999)
			{
					shadow = ManualPCF(depthInShadow, shadowTex, brightness, 0.0);
									
					float distance = max(1 - length(shadowUV - float2(0.5,0.5)) * 2, 0);
					shadow *= min( distance/(1.0001 - 0.8), 1);
					shadow = (1-shadow);

			}
			return shadow;
}

void loop_shadow_csm_casts(float4 posInView, inout float4 shadowTexCoord, inout float cascadeFound, inout int iCurrentCascadeIndex)
{
	for( int iCascadeIndex = 0; iCascadeIndex < shadow_csm_param.x; ++iCascadeIndex ) 
	{
		float4 texCoord = posInView * shadow_csm_proj_scale[iCascadeIndex];
		texCoord += shadow_csm_proj_offset[iCascadeIndex];

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

float calculateShadow_csm(sampler2D shadowTex, float4 posInView, float brightness, float3 posInWorld)
{
	float shadow = 1.0;
	float cascadeFound = 0;
	int iCurrentCascadeIndex = 0;
	float4 shadowTexCoord = float4(0,0,0,0);
	loop_shadow_csm_casts(posInView, shadowTexCoord, cascadeFound, iCurrentCascadeIndex);

	//for( int iCascadeIndex = 0; (iCascadeIndex < shadow_csm_param.x); ++iCascadeIndex ) 
	//{
	//	shadowTexCoord = posInView * shadow_csm_proj_scale[iCascadeIndex];
	//	shadowTexCoord += shadow_csm_proj_offset[iCascadeIndex];

	//	shadowTexCoord.xyz = shadowTexCoord.xyz / shadowTexCoord.w;
	//	if ( min( shadowTexCoord.x, shadowTexCoord.y ) > 0.001f && max( shadowTexCoord.x, shadowTexCoord.y ) < 0.999f )
	//	{
	//		iCurrentCascadeIndex = iCascadeIndex;   
	//		iCascadeFound = 1; 
	//		//break;
	//	}
	//}
    //if (iCascadeFound == 0)
    	//return shadow;
    	
   	shadowTexCoord.w = -posInView.z;

	float borderScale = (shadow_param.z - 2) / shadow_param.z;
	float borderOffset = (1 - borderScale) / 2;

   	// calculate real uv
	float4 nTexCoord = shadowTexCoord;
   	shadowTexCoord.xy *= float2(shadow_csm_param.y * borderScale, borderScale);
    shadowTexCoord.xy += float2(shadow_csm_param.y * ((float)iCurrentCascadeIndex + borderOffset), borderOffset); 
   	
   	// calculate shadow factor
   	shadow = ManualPCF(shadowTexCoord, shadowTex, brightness, (float)iCurrentCascadeIndex);
   	
   	
   	// calculate blend
   	/*float blendBandLocation = min( min( shadowTexCoord.x, shadowTexCoord.y ), min( 1.0f - shadowTexCoord.x, 1.0f - shadowTexCoord.y ) );
   	if( blendBandLocation < shadow_csm_param.z)
   	{
   			int iNextCascadeIndex = 0;
   			iNextCascadeIndex = min ( shadow_csm_param.x - 1, iCurrentCascadeIndex + 1 );
   			
   			float4 shadowTexCoord_blend = float4(0,0,0,0);
   			shadowTexCoord_blend = posInView * shadow_csm_proj_scale[iNextCascadeIndex];
        shadowTexCoord_blend += shadow_csm_proj_offset[iNextCascadeIndex]; 
        shadowTexCoord_blend.xyz = shadowTexCoord_blend.xyz / shadowTexCoord_blend.w;
        
        if ( min( shadowTexCoord_blend.x, shadowTexCoord_blend.y ) > 0.001f && max( shadowTexCoord_blend.x, shadowTexCoord_blend.y ) < 0.999f )
        {
        	shadowTexCoord_blend.x *= shadow_csm_param.y;
    			shadowTexCoord_blend.x += (shadow_csm_param.y * (float)iNextCascadeIndex );
    			shadowTexCoord_blend.w = -posInView.z;
    		
    			float shadow_blend = ManualPCF(shadowTexCoord_blend, shadowTex, brightness, (float)iCurrentCascadeIndex);
        	shadow = lerp( shadow_blend, shadow, blendBandLocation / shadow_csm_param.z ); 
        }
        
   	}*/

	shadow *= 1 - smoothstep(0.95 * shadow_csm_param.w, shadow_csm_param.w, length(posInWorld - camera_position));
	return lerp(1, 1-shadow, cascadeFound);
}

#ifdef __PS__

void Calc_Shadow_Ps(in FragInput fInput, out float shadowFactor, out float3 finalShadowColor)
{
	shadowFactor = 1.0;
	finalShadowColor = float3(1.0, 1.0, 1.0);
	#if SHADOWMAP_TYPE != SHADOWMAP_NONE
		float brightness = light_diffuse_colour_array[0].r * 0.299 + light_diffuse_colour_array[0].g * 0.587 + light_diffuse_colour_array[0].b * 0.114;
		#if SHADOWMAP_TYPE == SHADOWMAP_SIMPLE
				shadowFactor = calculateShadow(ShadowMapSampler, fInput.fShadow, brightness);
		#elif SHADOWMAP_TYPE == SHADOWMAP_CSM
				shadowFactor = calculateShadow_csm(ShadowMapSampler, fInput.fShadow, brightness, fInput.fPw);
		#endif
		
		#if IS_PBR_MODEL == 1
			float shadowStrength = shadow_param.y;
		#else
			float shadowStrength = shadow_param.x;
		#endif
		float r = 1.0 - shadowStrength;
		shadowFactor = r + shadowFactor * (1.0 - r);		
		
		float3 ShadowedColor = float3(0.5,0.5,0.5)*1.65;
		finalShadowColor = ShadowedColor * derived_scene_colour.rgb;
	#endif
}
#endif

#endif
			
			
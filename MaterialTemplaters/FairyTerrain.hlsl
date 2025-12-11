

#ifndef SHADOWMAP_ENABLE
	#define SHADOWMAP_ENABLE 0
#endif

#ifndef HAS_TWO_LAYER
	#define HAS_TWO_LAYER 0
#endif

#ifndef HAS_LIGHTMAP
	#define HAS_LIGHTMAP 0
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



void terrain_vs(
            in float3 position : POSITION,
            in float3 normal : NORMAL,
            in float2 uv0 : TEXCOORD0,
         	#if HAS_TWO_LAYER
            in float2 uv1 : TEXCOORD1,
         	#endif
         	#if HAS_LIGHTMAP
            in float2 uvLightmap : TEXCOORD2,
         	#endif
            
            out float4 oPosition : POSITION,
            out float2 oUV0 : TEXCOORD0,
          #if HAS_TWO_LAYER
            out float2 oUV1 : TEXCOORD1,
          #endif
          #if HAS_LIGHTMAP
            out float2 oUVLightmap : TEXCOORD2,
          #endif
            out float3 oNormalInView : TEXCOORD3,
            out float3 oPosInView : TEXCOORD4,

					#if SHADOWMAP_ENABLE
            uniform float4x4 shadowViewMatrix,
            uniform float4x4 shadowProjMatrix,
            out float4 oDepthInShadow : TEXCOORD5,
          #endif
						//uniform float4 cameraPos,      
						uniform float4x4 world_matrix,
						uniform float4x4 view_matrix,
            uniform float4x4 viewproj_matrix
           )
{
    float4 worldPos = mul(world_matrix, float4(position, 1.0));
    oPosition = mul( viewproj_matrix, worldPos);

		oUV0 = uv0;
#if HAS_TWO_LAYER
		oUV1 = uv1;
#endif
#if HAS_LIGHTMAP
		oUVLightmap = uvLightmap;
#endif

		oNormalInView = mul(view_matrix, float4(normal.xyz, 0.0)).xyz;
		//oViewDir = cameraPos.xyz - worldPos.xyz;
		oPosInView = mul(view_matrix, float4(worldPos.xyz, 1.0)).xyz;
		
#if SHADOWMAP_ENABLE
			float4 posInShadowView = mul(shadowViewMatrix, worldPos);
			float4 posInShadowProj = mul(shadowProjMatrix, posInShadowView);
			posInShadowProj.xyz = posInShadowProj.xyz/posInShadowProj.w;
			float2 shadowUV = posInShadowProj.xy;
			float texSize = 1.0/2048;
			shadowUV = float2(0.5, 0.5) + float2(0.5, -0.5) * shadowUV;
			
			oDepthInShadow.xy = shadowUV.xy;
			oDepthInShadow.z = posInShadowProj.z;
			oDepthInShadow.w = -posInShadowView.z;
#endif
}


float blinn( float3 n, float3 v, float3 l, float exp )
{
		float fNormFactor = exp * 0.159155h + 0.31831h;
		float3 h = normalize(v + l);
		//return fNormFactor * pow( saturate(dot(n,h)), exp );
		return pow( max(dot(n,h), 0.01), exp );
}

float3 Fogging(float3 finalColour, float depthInView, float4 fogParam, float4 fogColor)
{
		float fogFactor = 1.0;
#if ARB_fog_linear
    fogFactor = (fogParam.z - depthInView) * fogParam.w;
#elif ARB_fog_exp
    fogFactor = exp(- depthInView * fogParam.x);
#elif ARB_fog_exp2
    fogFactor = exp(- (depthInView * fogParam.x) * (depthInView * fogParam.x));
#endif
		float3 color = lerp( fogColor.rgb, finalColour.rgb, fogFactor );
		color = finalColour.rgb * fogFactor + fogColor.rgb * (1 - fogFactor);
    return color;
}

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

		float texSize = 1.0/2048;
    float2 vRightShadowTexelLocation = float2( texSize, 0.0f );
    float2 vUpShadowTexelLocation = float2( 0.0f, texSize );  
    
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

void terrain_ps(    
		in float2 uv0 : TEXCOORD0,
		uniform sampler2D layer0 : register(s0),
		
		#if HAS_TWO_LAYER
    	in float2 uv1 : TEXCOORD1,
    	uniform sampler2D layer1 : register(s1),
    #endif
    #if HAS_LIGHTMAP
    	in float2 uvLightmap : TEXCOORD2,
    	uniform sampler2D lightmap : register(s2),
    #endif
    in float3 normalInView : TEXCOORD3,
    in float3 posInView : TEXCOORD4,
    
    #if SHADOWMAP_ENABLE
	  		uniform sampler2D shadowTex : register(s5),
	  		in float4 depthInShadow : TEXCOORD5,
	  #endif
	  uniform float4 derived_scene_colour,
    uniform float4 surface_specular_colour,
    uniform float  surface_shininess,
    uniform float4 lightSpecular0,
    uniform float4 light_position_view_space[3],
		uniform float4 light_attenuation[3],         
		uniform float4 derived_light_diffuse_colour[3],
		
		#if ARB_fog_linear== 1 || ARB_fog_exp == 1 || ARB_fog_exp2 == 1
			uniform float4 fog_params,
    	uniform float4 fog_colour,
		#endif
    out float4 oColour : COLOR)
{
		oColour = float4(0.0, 0.0, 0.0, 1.0);
		
		float4 c0 = tex2D(layer0, uv0);	
		float4 texColor = c0;
#if HAS_TWO_LAYER
    float4 c1 = tex2D(layer1, uv1);
    texColor.rgb = lerp(texColor.rgb, c1.rgb, c1.a);
#endif
#if HAS_LIGHTMAP
    float4 clightmap = tex2D(lightmap, uvLightmap);
    texColor.rgb = clightmap.rgb * texColor.rgb;
#endif
		oColour.rgb = texColor.rgb;
    
    
    // calculate light diffuse color and specular color
    float3 Nn = normalize(normalInView);
		float3 Vn = normalize(-posInView);
    
    float3 LightDiffuse = float3(0.0,0.0,0.0);
    float3 LightSpecular = float3(0.0,0.0,0.0);
    for (int l = 0; l < 3; ++l)
    {
    		float3 lightDir = light_position_view_space[l].xyz - (posInView * light_position_view_space[l].w);
    		float d = length(lightDir);
    		float3 Ln = lightDir / d;
    		float fNdotL = dot(Nn, Ln);

        //float att = lerp(light_position_view_space[l].w, 1, 1 / dot(float3(1, d, d*d), light_attenuation[l].yzw));
	float att = pow(saturate(-d / light_attenuation_array[l].x + 1.0), light_attenuation_array[l].y);
        LightDiffuse += att * max(fNdotL, 0) * derived_light_diffuse_colour[l].rgb;
        if (l == 0)
        {
		LightSpecular += blinn(Nn, Vn, Ln, surface_shininess) * lightSpecular0.xyz * surface_specular_colour.xyz;
	}
     }
    LightDiffuse = saturate(LightDiffuse + derived_scene_colour.rgb);
    
    oColour.rgb *= LightDiffuse;
		//oColour.rgb += LightSpecular * (1-c0.a)
#if HAS_TWO_LAYER
				//* (1-c1.a)
#endif
#if HAS_LIGHTMAP
				//* (1-clightmap.a)
#endif
		//;
    
    
    #if SHADOWMAP_ENABLE
			float2 shadowUV = depthInShadow.xy;
			if(shadowUV.x > 0.001 && shadowUV.x < 0.999 && shadowUV.y > 0.001 && shadowUV.y < 0.999)
			{
					float texSize = 1.0/2048;
					//shadowUV = float2(0.5, 0.5) + float2(0.5, -0.5) * shadowUV + float2(texSize, texSize)*0.5;
					//shadowUV = float2(0.5, 0.5) + float2(0.5, -0.5) * shadowUV;

					float3 duvdist_dx = ddx(depthInShadow.xyz);
					float3 duvdist_dy = ddy(depthInShadow.xyz);
					float fUpTextDepthWeight, fRightTextDepthWeight;
					CalculateRightAndUpTexelDepthDeltas(duvdist_dx, duvdist_dy, fUpTextDepthWeight, fRightTextDepthWeight);
					
					
					float radio = 0.0;
					const int kernal = 1;
					for( int x = -kernal; x <= kernal; ++x ) 
    			{
        		for( int y = -kernal; y <= kernal; ++y ) 
        		{
        			float sampleDepth = tex2D(shadowTex, shadowUV.xy + float2(x,y) * float2(texSize, texSize)).x;
        			//float viewDepth = depthInShadow.w - 5 + ((fRightTextDepthWeight * x ) + (fUpTextDepthWeight * y ));
        			//float viewDepth = depthInShadow.w - 0 + ((ddist_duv.x * x * texSize) + (ddist_duv.y * y * texSize))*1;
        			float viewDepth = depthInShadow.w - 5;
        			radio += (viewDepth > sampleDepth) ? 0.7 : 0;
						}
					}
					radio /= (2*kernal+1)*(2*kernal+1);
					//float distance = max(1 - length(shadowUV - float2(0.5,0.5)) * 2, 0);
					//radio *= min( distance/(1.0001 - 0.8), 1);
					oColour.xyz *= (1-radio);
			}
			

	  #endif
	  
	  #if ARB_fog_linear== 1 || ARB_fog_exp == 1 || ARB_fog_exp2 == 1
    	oColour.xyz = Fogging(oColour.rgb, -posInView.z, fog_params, fog_colour);
    #endif
	  
}

void
TwoLayerLightmap_ps(
    in float2 uv0 : TEXCOORD0,
    in float2 uv1 : TEXCOORD1,
    in float2 uvLightmap : TEXCOORD2,  
    uniform sampler2D layer0,
    uniform sampler2D layer1,
    uniform sampler2D lightmap,
    in float4 diffuse : COLOR0,
    in float4 specular : COLOR1,
    out float4 oColour : COLOR)
{
    float4 c0 = tex2D(layer0, uv0);
    float4 c1 = tex2D(layer1, uv1);
    float3 texturedColour = lerp(c0.rgb, c1.rgb, c1.a);
    float4 lightmapColour = tex2D(lightmap, uvLightmap);
    float4 baseColour = diffuse * lightmapColour;
    float3 finalColour = baseColour.rgb * texturedColour + specular.rgb * (1-c0.a) * (1-c1.a) * lightmapColour.a; 
	  //float3 resultColour = Fogging(finalColour);
    oColour = float4(finalColour, baseColour.a);
}

void
TwoLayer_ps(
    in float2 uv0 : TEXCOORD0,
    in float2 uv1 : TEXCOORD1,
    uniform sampler2D layer0,
    uniform sampler2D layer1,
    in float4 diffuse : COLOR0,
    in float4 specular : COLOR1,
    out float4 oColour : COLOR)
{
    float4 c0 = tex2D(layer0, uv0);
    float4 c1 = tex2D(layer1, uv1);
    float3 texturedColour = lerp(c0.rgb, c1.rgb, c1.a);
    float4 baseColour = diffuse;
    float3 finalColour = baseColour.rgb * texturedColour + specular.rgb * (1-c0.a) * (1-c1.a);
    //float3 resultColour = Fogging(finalColour);
    oColour = float4(finalColour, baseColour.a);
}

void
OneLayerLightmap_ps(
    in float2 uv0 : TEXCOORD0,
    in float2 uvLightmap : TEXCOORD1,
    uniform sampler2D layer0,
    uniform sampler2D lightmap,
    in float4 diffuse : COLOR0,
    in float4 specular : COLOR1,
    out float4 oColour : COLOR)
{
    float4 c0 = tex2D(layer0, uv0);
    float3 texturedColour = c0.rgb;
    float4 lightmapColour = tex2D(lightmap, uvLightmap);
    float4 baseColour = diffuse * lightmapColour;
    float3 finalColour = baseColour.rgb * texturedColour + specular.rgb * (1-c0.a) * lightmapColour.a;
    //float3 resultColour = Fogging(finalColour);
    oColour = float4(finalColour, baseColour.a);
}

void
OneLayer_ps(
    in float2 uv0 : TEXCOORD0,
    in float3 viewPos : TEXCOORD6,
    uniform sampler2D layer0,
    in float4 diffuse : COLOR0,
    in float4 specular : COLOR1,
    out float4 oColour : COLOR)
{
    float4 c0 = tex2D(layer0, uv0);
    float3 texturedColour = c0.rgb;
    float4 baseColour = diffuse;
    float3 finalColour = baseColour.rgb * texturedColour + specular.rgb * (1-c0.a);
    //float3 resultColour = Fogging(finalColour);
    oColour = float4(finalColour, baseColour.a);
}

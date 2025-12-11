#ifndef _Light_INC_
#define _Light_INC_

#include "ShaderLib/CalcShadow.inc"
float3 ShiftTangent( float3 T, float3 N, float shift)
{
	return normalize(T + shift * N);
}

float blinn( float3 n, float3 v, float3 l, float e )
{
		float3 h = normalize(v + l);
		return pow( max(dot(n, h), 0.01), e );
}
float lss_blinn( float3 n, float3 v, float3 l, float e )
{
		float3 h1 = normalize(v + l);
		float ndoth1 = dot(n,h1);
		l.y = -l.y;
		float3 h2 = normalize(v + l);
		float ndoth2 = dot(n,h2);
		float ndoth = max(ndoth1,ndoth2);						
		return pow( max(ndoth, 0.01), e );				
}
float anitrophic( float3 n, float3 v, float3 l, float3 t, float e )
{
		float3 h = normalize(v + l);
    float dotTH = dot(t, h);
    float sinTH = sqrt(1.0 - dotTH * dotTH);
    float dirAttr = smoothstep(-1, 0, dotTH);
		return dirAttr * pow(sinTH, e *3);
}

#ifdef __VS__

void Calc_Light_In_Vs(inout VertParams params)
{
		params.color = float4(1.0f,1.0f,1.0f,1.0f);
#if LIGHT_CALC_TYPE == LIGHT_CALC_NONE || LIGHT_CALC_TYPE == LIGHT_CALC_PS
		#if USE_VERTEXCOLOR
			params.color *= params.VI.vColor;
		#endif
#elif LIGHT_CALC_TYPE == LIGHT_CALC_VS
		float4 sceneColor = derived_scene_colour * (1.0 - imodel_userdata.x) + actor_ambient_params * imodel_userdata.x;

		float3 lightDiffuseColor[MAX_LIGHT_NUM];
		lightDiffuseColor[0] = light_diffuse_colour_array[0].rgb * light_diffuse_colour_array[0].a * (1.0 - imodel_userdata.x) + actor_lightone_params.rgb * actor_lightone_params.a * imodel_userdata.x;
		lightDiffuseColor[1] = light_diffuse_colour_array[1].rgb * light_diffuse_colour_array[1].a * (1.0 - imodel_userdata.x) + actor_lighttwo_params.rgb * actor_lighttwo_params.a * imodel_userdata.x;
		lightDiffuseColor[2] = light_diffuse_colour_array[2].rgb * light_diffuse_colour_array[2].a;

		float3 LightDiffuse = float3(0.0,0.0,0.0);
		
    for (int l = 0; l < MAX_LIGHT_NUM; ++l)
   {
        float3 lightDir = light_position_array[l].xyz - (params.pw.xyz * light_position_array[l].w);
        float d = length(lightDir);
        float3 Ln = lightDir / d;
    	float fNdotL = dot(params.nw.xyz, Ln);
        //float att = lerp(0, 1, 1 / dot(float3(1, d, d*d), light_attenuation_array[l].yzw));
	// 新衰减算法，去掉一次衰减和二次衰减常量，只控制基本常量c（以前始终 = 1，现在可变）和Range
	// 严格来说，需要判断Range和c都 > 0 否则att=1, 但是为了性能考虑，忽略这个判断，请设置参数的时候注意
	// 该衰减应用到基于物理着色的光照时需要适当进行修正
	float att = pow(saturate(-d / light_attenuation_array[l].x + 1.0), light_attenuation_array[l].y);
	float3 lDiffuse = att * max(fNdotL, 0) * lightDiffuseColor[l].rgb;
        LightDiffuse += saturate(lDiffuse);
    }
    LightDiffuse *= surface_diffuse_colour.rgb;
    #if USE_VERTEXCOLOR
    	LightDiffuse *= params.VI.vColor.rgb;
    	params.color.a *= params.VI.vColor.a;
    #endif
   	//params.color.rgb = saturate(LightDiffuse + sceneColor.rgb);
   	//params.color.rgb = LightDiffuse + sceneColor.rgb;
		params.color.rgb = GetColorByLightGreaterOne(LightDiffuse + sceneColor.rgb, params.SP);
#endif
}

void Calc_Light_Particle_In_Vs(inout VertParams params)
{
#if USE_VERTEXCOLOR
   	//params.color.rgb = saturate(params.VI.vColor.rgb + surface_emissive_colour.rgb);
	//params.color.rgb = (params.VI.vColor.rgb + surface_emissive_colour.rgb);
		params.color.rgb = GetColorByLightGreaterOne(params.VI.vColor.rgb + surface_emissive_colour.rgb, params.SP);
		params.color.a = params.VI.vColor.a;
	#endif
}

#endif

#ifdef __PS__

float3 Calc_Specular_Std(inout FragParams params)
{
		float3 Nn = params.FI.fNw.xyz;
		float3 Ln = normalize(light_position_array[0].xyz);
		float3 Vn = params.FI.fView.xyz;
		
		// calculate specular color
		float3 specular = 
		#if SPECULAR_ANITROPHIC_ENABLE == 1
			anitrophic(Nn, Vn, Ln, params.FI.fTw, surface_shininess)
		#else
			blinn(Nn, Vn, Ln, surface_shininess)
		#endif
			* surface_specular_colour.xyz * light_specular_colour_array[0].xyz;
		return specular.rgb;
}

#if HIGHLIGHT_SIMPLE_ENABLE == 1
float3 Calc_Specular_HightLight_Simple(inout FragParams params)
{
		float3 Nn = params.FI.fNw.xyz;
		float3 Ln = normalize(light_position_array[0].xyz);
		float3 Vn = params.FI.fView.xyz;
		
		// calculate specular color
		float3 specular = blinn(Nn, Vn, Ln, surface_shininess) * surface_specular_colour.xyz * light_specular_colour_array[0].xyz;
		float4 ctlColour = tex2D(CtlSampler, params.FI.baseTC.xy);
		return specular.xyz * ctlColour.xyz;
}
#endif
#if HIGHLIGHT_LSSCENE_ENABLE == 1
float3 Calc_Specular_HightLight_LSScene(inout FragParams params)
{
		float3 Nn = params.FI.fNw.xyz;
		float3 Ln = normalize(light_position_array[0].xyz);
		float3 Vn = params.FI.fView.xyz;		
		// calculate specular color
		
		float2 sphereTexUV = 1 - normalize(mul(view_matrix, float4(params.FI.fNw.xyz, 0.0))).xy*0.5 + 0.5;
  		float4 sphereTexColor = tex2D(ReflectSampler, sphereTexUV);
		float3 specular = blinn(Nn, Vn, Ln, surface_shininess) * sphereTexColor.rgb *  surface_specular_colour.xyz * light_specular_colour_array[0].xyz;
		float ctlColour = params.FI.fNw.r;
		return specular.xyz * ctlColour * 2.5;
}
#endif
#if HIGHLIGHT_LSSCENE_ENABLE == 2
float3 Calc_Specular_HightLight_LSSceneN(inout FragParams params)
{
		//#if LIGHT_CALC_TYPE == LIGHT_CALC_PS
		float3 Nn = params.FI.fNw.xyz;
		float3 Ln1 = normalize(light_position_array[0].xyz);
		float3 Ln2 = normalize(light_position_array[1].xyz);
		float3 Vn = params.FI.fView.xyz;
		
		// calculate specular color
		
		float2 sphereTexUV = 1 - normalize(mul(view_matrix, float4(params.FI.fNw.xyz, 0.0))).xy*0.5 + 0.5;
  		float4 sphereTexColor = tex2D(ReflectSampler, sphereTexUV);
		float3 specular1 = blinn(Nn, Vn, Ln1, surface_shininess) * sphereTexColor.rgb *  surface_specular_colour.xyz * light_specular_colour_array[0].xyz;
		float3 specular2 = blinn(Nn, Vn, Ln2, surface_shininess) * sphereTexColor.rgb *  surface_specular_colour.xyz * light_specular_colour_array[1].xyz;
		float3 specular = specular1 + specular2;
		float ctlColour = params.FI.fNw.a;
		return specular.xyz * ctlColour * 2.5;
		//#else
		//return float3(0,0,0);
		//#endif
}
#endif
#if HIGHLIGHT_HAIR_ENABLE == 1
float3 Calc_Specular_HightLight_Hair(inout FragParams params)
{
		float3 Nn = params.FI.fNw.xyz;
		float3 Ln = normalize(light_position_array[0].xyz);
		
		float3 Vn = lerp(Ln,params.FI.fView.xyz,0.8);
		float3 Tn = params.FI.fTw.xyz;
		// calculate specular color
		float3 T1 = ShiftTangent(Tn,Nn,params.cDiffuseRT.g - 0.05);
		float3 T2 = ShiftTangent(Tn,Nn,params.cDiffuseRT.g - 0.15);
		float3 specular1 = anitrophic(Nn, Vn, Ln, T1, surface_shininess / 8);
		float3 specular2 = anitrophic(Nn, Vn, Ln, T2, surface_shininess * 1);		 
		//float4 ctlColour = tex2D(CtlSampler, params.FI.baseTC.xy);
		float3 specular = specular1 * (dot(Nn,Ln)*0.5+0.5) * 0.4 * surface_specular_colour.xyz * params.cDiffuseRT.r
						  + specular2 * (dot(Nn,Ln)*0.5+0.5) * 0.2 * surface_specular_colour.xyz * params.cDiffuseRT.r;
		
		///return specular * 0.6;

		float3 Ln1 = normalize(params.FI.fView.xyz);	
		float3 Vn1 = params.FI.fView.xyz;
		float3 T11 = ShiftTangent(Tn,Nn,params.cDiffuseRT.g - 0.6);
		float3 T21 = ShiftTangent(Tn,Nn,params.cDiffuseRT.g - 0.7);
		float3 specular11 = anitrophic(Nn, Vn1, Ln1, T11, surface_shininess / 8);
		float3 specular21 = anitrophic(Nn, Vn1, Ln1, T21, surface_shininess * 1);		 

		float3 specular222 = specular11 * (dot(Nn,Ln1)*0.5+0.5) * 0.4 * surface_specular_colour.xyz * params.cDiffuseRT.r
						  + specular21 * (dot(Nn,Ln1)*0.5+0.5) * 0.2 * surface_specular_colour.xyz * params.cDiffuseRT.r;
		float3 result = specular * 0.45 + specular222 * 0.35;
		return result;

}
#endif
#if HIGHLIGHT_ENABLE == 1
float3 Calc_Specular_HightLight(inout FragParams params)
{
		float3 Nn = params.FI.fNw.xyz;
		float3 Vn = params.FI.fView.xyz;
		 		
		float rimRange = 1-abs(dot(Vn,Nn));
    float4 CtrlTex = tex2D(CtlSampler, params.FI.baseTC.xy);			
		float2 ReflUV = normalize(mul(view_matrix, float4(Nn, 0.0))).xy*0.5 + 0.5;        					
		float4 _Reflection_var = tex2D(HighLightSampler,ReflUV);
		//高光
		float3 emissive = _Reflection_var.xyz*CtrlTex.r;
		//高光的补光 必须增加要不然会显示不正常
		float3 emissive3 = rimRange*rimRange*light_specular_colour_array[0].xyz * CtrlTex.r;
		//emissive的补光
		float3 emissive4 = params.cDiffuseRT.xyz*CtrlTex.g;
		return emissive + emissive3 + emissive4;
}
#endif
#if HIGHLIGHT_LSCHAR_ENABLE
float3 Calc_Specular_HightLight_LSChar(inout FragParams params )
{
	//#if LIGHT_CALC_TYPE == LIGHT_CALC_PS
		float metallic_ctl;		
		#if HIGHLIGHT_LSCHAR_ENABLE == 2
			metallic_ctl = params.FI.fNw.a;
		#else 
			float4 CtrlTexVar = tex2D(NormalSampler, params.FI.baseTC.xy);
			metallic_ctl = CtrlTexVar.r;			
		#endif

		float2 ReflUV = 1 - (normalize(mul(view_matrix, float4(params.FI.fNw.xyz, 0.0))).xy*0.5 + 0.5);        					
		float4 envTexVar = tex2D(EnvSampler, ReflUV);

		float4 sceneColor = derived_scene_colour * (1.0 - imodel_userdata.x) + actor_ambient_params * imodel_userdata.x;
		float3 lightDiffuseColor[2];
		lightDiffuseColor[0] = light_diffuse_colour_array[0].rgb * light_diffuse_colour_array[0].a * (1.0 - imodel_userdata.x) + actor_lightone_params.rgb * actor_lightone_params.a * imodel_userdata.x;
		lightDiffuseColor[1] = light_diffuse_colour_array[1].rgb * light_diffuse_colour_array[1].a * (1.0 - imodel_userdata.x) + actor_lighttwo_params.rgb * actor_lighttwo_params.a * imodel_userdata.x;
	
		float3 Nn = params.FI.fNw.xyz;
		float3 Vn = params.FI.fView.xyz;
		float3 specular = float3(0,0,0);

		float3 Ln1 = normalize(light_position_array[0].xyz);
		float3 Ln2 = normalize(light_position_array[1].xyz);
		float3 Ln0 = normalize(params.FI.fView.xyz);
		float3 Hn0 = normalize(Vn + Ln0);            ///////
		float3 blendcolor = max(float3(0.5,0.5,0.5), (dot(Ln0, Ln1)+1)/2 * lightDiffuseColor[0] + (dot(Ln0, Ln2)+1)/2 * lightDiffuseColor[1]);
		float specularLight0 = 0.18 * surface_shininess * blinn(Nn,Vn,Ln0, 5 + (metallic_ctl * surface_shininess * 0.2));  /////pow(max(dot(Nn, Hn1), 0.01),  5 + (metallic_ctl * surface_shininess)); 
		specular += (surface_specular_colour.xyz*0.00001 + specularLight0 * blendcolor ) * metallic_ctl * 0.4;	  

		specular *= sceneColor;

		float3 envColor = lerp(float3(0.6,0.6,0.6), envTexVar.rgb, metallic_ctl)  * surface_shininess * 0.03; 
		specular *= envColor ;

		float rimRange = 1-abs(dot(Vn,Nn));
		float3 rimcolor = pow(rimRange,2.5) * 0.6 * (sceneColor+0.1) * saturate(metallic_ctl + 0.4);///// 
		specular += rimcolor;

		return specular;
	//#else
		//return float3(0,0,0);
	//#endif
}
#endif

float3 Calc_Specular(inout FragParams params)
{
		float3 specColor;
		#if HIGHLIGHT_SIMPLE_ENABLE == 1
			specColor = Calc_Specular_HightLight_Simple(params);
		#elif HIGHLIGHT_LSSCENE_ENABLE == 1
			specColor = Calc_Specular_HightLight_LSScene(params);
		#elif HIGHLIGHT_LSSCENE_ENABLE == 2			
			specColor = Calc_Specular_HightLight_LSSceneN(params);
		#elif HIGHLIGHT_HAIR_ENABLE == 1
			specColor = Calc_Specular_HightLight_Hair(params);
		#elif HIGHLIGHT_ENABLE == 1
			specColor = Calc_Specular_HightLight(params);
		#elif HIGHLIGHT_LSCHAR_ENABLE
			specColor = Calc_Specular_HightLight_LSChar(params);
		#else
			specColor = Calc_Specular_Std(params);
		#endif
		#ifdef LASER_SPEC
			#if LASER_SPEC > 0
				float3 Nn = params.FI.fNw.xyz;
				float3 Vn = params.FI.fView.xyz;
				float  NV = saturate(dot(Nn, Vn));
				float4 laserColor = tex2D(laserMap, float2(NV, NV));
				specColor = saturate(specColor);
				specColor = lerp(specColor, specColor * laserColor.rgb, laserSpecStrength);
				float  laserAlpha = tex2D(laserMap, params.FI.baseTC.xy).a;
				specColor = specColor * laserAlpha;
			#endif
		#endif
		return specColor;
}

void Calc_Light_In_Ps( inout FragParams params )
{
#if LIGHT_CALC_TYPE == LIGHT_CALC_NONE
		params.cFinal.rgb *= params.FI.color.rgb;
#elif LIGHT_CALC_TYPE == LIGHT_CALC_VS
		#if BLEND_OP_0 == 3
      params.cFinal.rgb += params.FI.color.rgb;
    #else
			params.cFinal.rgb *= params.FI.color.rgb;
		#endif
		float3 specular = Calc_Specular(params);
		params.cFinal.rgb = params.cFinal.rgb + specular;
#elif LIGHT_CALC_TYPE == LIGHT_CALC_PS
		float shadowFactor;
		float3 shadowColor;
		Calc_Shadow_Ps(params.FI, shadowFactor, shadowColor);

	  float3 Nn = params.FI.fNw.xyz;
		float3 Vn = params.FI.fView.xyz;
    
    float4 sceneColor = derived_scene_colour * (1.0 - imodel_userdata.x) + actor_ambient_params * imodel_userdata.x;
    
    float3 lightDiffuseColor[MAX_LIGHT_NUM];
	lightDiffuseColor[0] = light_diffuse_colour_array[0].rgb * light_diffuse_colour_array[0].a * (1.0 - imodel_userdata.x) + actor_lightone_params.rgb * actor_lightone_params.a * imodel_userdata.x;
	lightDiffuseColor[1] = light_diffuse_colour_array[1].rgb * light_diffuse_colour_array[1].a * (1.0 - imodel_userdata.x) + actor_lighttwo_params.rgb * actor_lighttwo_params.a * imodel_userdata.x;
	lightDiffuseColor[2] = light_diffuse_colour_array[2].rgb * light_diffuse_colour_array[2].a;
      
    float3 directLightDiffuse = float3(0.0,0.0,0.0);
    float3 directLightSpecular = float3(0.0,0.0,0.0);
    float3 indirectLightDiffuse = float3(0.0,0.0,0.0);
    
    // direct light
    float3 lightDir = light_position_array[0].xyz;
    float3 Ln = normalize(lightDir);
    float fNdotL = dot(Nn, Ln);
		directLightDiffuse = max(fNdotL,0) * lightDiffuseColor[0].rgb;
		directLightSpecular = Calc_Specular(params) * shadowFactor;
    
    // indirect light
    for (int l = 1; l < MAX_LIGHT_NUM; ++l)
    {
	float3 lightDir = light_position_array[l].xyz - (params.FI.fPw.xyz * light_position_array[l].w);
	float d = length(lightDir);
	float3 Ln = lightDir / d;
	float fNdotL = dot(Nn, Ln);

	//float att = lerp(0, 1, 1 / dot(float3(1, d, d*d), light_attenuation_array[l].yzw)) * limit;
	float att = pow(saturate(-d / light_attenuation_array[l].x + 1.0), light_attenuation_array[l].y);

	float3 lDiffuse = att * max(fNdotL, 0) * lightDiffuseColor[l].rgb;
	indirectLightDiffuse += saturate(lDiffuse);
    }
    directLightDiffuse *= params.FI.color.rgb * surface_diffuse_colour.rgb;
	sceneColor.rgb = sceneColor.rgb * max(0.7,pow(dot(Nn,params.FI.oNw),2)) *(1.0 - imodel_userdata.x) + sceneColor.rgb * imodel_userdata.x;    
	indirectLightDiffuse = indirectLightDiffuse *params.FI.color.rgb  * surface_diffuse_colour.rgb + sceneColor.rgb ; 	
    //params.cLight = saturate(directLightDiffuse + indirectLightDiffuse) * shadowFactor + saturate(indirectLightDiffuse) * shadowColor * (1-shadowFactor) ;

	float4 clipPos = mul(viewproj_matrix, float4(params.FI.fPw.xyz, 1));
	clipPos /= clipPos.w;
	float2 screenUV = clipPos.xy * float2(0.5, -0.5) + float2(0.5, 0.5);
	float occlusion = tex2D(ssao_buffer, screenUV).r;
	indirectLightDiffuse *= occlusion;	

		if (params.SP.bLightGreaterOneEnable)
		{
		params.cLight = directLightDiffuse * shadowFactor + (indirectLightDiffuse);
		}
		else
		{
		params.cLight = saturate(directLightDiffuse + indirectLightDiffuse) * shadowFactor + saturate(indirectLightDiffuse) * shadowColor * (1-shadowFactor) ;
		}
		
    #if BLEND_OP_0 == 3
		params.cFinal.rgb = params.cFinal.rgb + params.cLight + directLightSpecular;		
    #else
		params.cFinal.rgb = params.cFinal.rgb * params.cLight + directLightSpecular;
    #endif

#endif

}

void Calc_Light_Particle_In_Ps( inout FragParams params )
{
	params.cFinal.rgb *= params.FI.color.rgb;
}

#endif

#endif
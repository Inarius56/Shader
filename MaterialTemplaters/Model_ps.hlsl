#ifndef _Model_PS_H_
#define _Model_PS_H_

// Define In VS
#define __PS__

sampler2D DiffuseSampler 	: register(s0);

#if DISSOLVE_EFFECT > 0
	sampler2D dissolveMap : register(s2);
#endif

#if DISSOLVE_EFFECT == 5
sampler2D dissolveRampMap : register(s4);
#endif

#ifdef LASER_SPEC
	#if LASER_SPEC > 0
		sampler2D laserMap : register(s1);
		uniform float laserSpecStrength = 0.5;
	#endif
#endif

#ifdef Phantom_EFFECT
  #if Phantom_EFFECT > 0
	uniform float4 baseColor= float4(1.0, 1.0, 0.0, 1.0);
	uniform float4 outlineColor= float4(0.0, 0.0, 0.0, 1.0);
	uniform float edgethickness = 1.0;
	uniform float bottomTransparent = 0.0;
	sampler2D noiseSampler : register(s1);
  #endif
#endif

#if ICE_EFFECT > 0
	  sampler2D RampSampler : register(s1);
	  sampler2D InnerSampler : register(s2);
	  uniform float mainTexImpact = 1.0;
#endif

#include "ModelDef.inc"

#if XINGNING_EFFECT == 1
sampler2D starsTex : register(s2);
sampler2D starsTexDistortionTex : register(s6);
sampler2D rimTex : register(s7);
float4 rimTintColor;
float4 starsTexDistortion_rimPow_rimClampMin_rimClampMax;
float4 rimFlowFactor;
float starsTexScaleFactor;

void Calc_XingNing_Effect(inout FragParams params, float4 clipPos)
{
	float objDistance = length(camera_position - float3(world_matrix[0].w, world_matrix[1].w, world_matrix[2].w));
	float2 starsUV = clipPos.xy / clipPos.w * objDistance * starsTexScaleFactor;
	starsUV *= float2(0.5, -0.5);
	starsUV.xy -= params.FI.fNv.xy *
		starsTexDistortion_rimPow_rimClampMin_rimClampMax.x *
		tex2D(starsTexDistortionTex, params.FI.baseTC.xy).r;
	starsUV += 0.5;

	float4 color = params.cFinal + tex2D(starsTex, starsUV) * tex2D(starsTex, params.FI.baseTC.xy).a;

	float rimFactor = pow(1 - saturate(dot(params.FI.fNw.xyz, params.FI.fView.xyz)), starsTexDistortion_rimPow_rimClampMin_rimClampMax.y);
	rimFactor = smoothstep(starsTexDistortion_rimPow_rimClampMin_rimClampMax.z, starsTexDistortion_rimPow_rimClampMin_rimClampMax.w, rimFactor);

	float2 rimUV;
#if RIM_PLANNAR_MAPPING == 1
	rimUV = clipPos.xy / clipPos.w;
	rimUV *= float2(0.5, -0.5);
	rimUV += 0.5;
#else
	rimUV = params.FI.baseTC.xy;
#endif

	rimUV = rimUV * rimFlowFactor.xy + time_0_x.x * rimFlowFactor.zw;	  

	float4 rimColor = tex2D(rimTex, rimUV);
	rimColor.rgb *= rimTintColor.rgb;

	params.cFinal.rgb = color.rgb + rimColor.rgb * tex2D(rimTex, params.FI.baseTC.xy).a * rimFactor;
}
#endif

FragInput fmt_input( VS_OUT IN )
{
	FragInput FI = (FragInput)0;
	FI.baseTC = IN.oUV0;
	FI.fPw = IN.oPw;
	FI.fPo = IN.oPo;
#if XINGNING_EFFECT == 1
	FI.fNv = float4(normalize(IN.oViewNormal),0);
#endif
	FI.fNw = float4(normalize(IN.oNw),0);
	FI.fNo = normalize(IN.oNo);
	FI.oNw = normalize(IN.oNw);
	FI.fView = float4( normalize( IN.oV.xyz ), IN.oV.w );
#if USE_TANGENT == 1	
	FI.fTw = normalize(IN.oTw.xyz);
	FI.fBw = normalize(IN.oBw.xyz);
#endif
#if SHADOWMAP_TYPE != SHADOWMAP_NONE
  FI.fShadow = IN.oShadow;
#endif
	FI.color = IN.oColour;
	return FI;
}

PS_OUT fmt_output( FragParams params )
{
	PS_OUT OUT = (PS_OUT)0; 
#if FROZEN_ENANLE
	params.cFinal.rgb *= multiBlendColor.xyz * multiBlendColor.w;
#endif
	OUT.color = float4( params.cFinal.rgb, params.cDiffuseRT.a * params.FI.color.a * surface_diffuse_colour.a );

#if USE_OUTLINE == 1
	float rimAbs = abs(dot(params.FI.fNw, params.FI.fView));
	float rimRange = 1-rimAbs;
	float4 rimcolor = outlineColor.a * pow(rimRange, outlinePow.x * pow (rimAbs, outlinePow.y)) * float4(outlineColor.rgb, OUT.color.a);
	OUT.color = saturate(OUT.color+rimcolor);
#endif

#if DISSOLVE_EFFECT > 0
	#if DISSOLVE_EFFECT == 4
		OUT.color = Calc_Dissolve_Color_4(OUT.color, params.FI.baseTC.xy);
	#elif DISSOLVE_EFFECT == 5
		OUT.color = Calc_Dissolve_Color_5(OUT.color, params.FI.baseTC.xy, params.FI.fPw.xyz);
	#else
		OUT.color = Calc_Dissolve_Color_1(OUT.color, params.FI.baseTC.xy);
	#endif
#endif

#if Phantom_EFFECT > 0
	float noiseUV = params.FI.baseTC.xy + time_0_x.xx*0.2;
	float noiseValue = tex2D(noiseSampler,noiseUV).r;

	float PhantomAbs = abs(dot(params.FI.fNw, params.FI.fView));
	float PhantomRange = saturate(1.0f - PhantomAbs);
	PhantomRange = PhantomRange + pow(PhantomRange,2.0) * (noiseValue*2.0-0.5)*3.0;
	
	float height = bottomTransparent>0 ? params.FI.fPo.y/200.0 : 1.0;
	float opacity = min(1.0,baseColor.a*OUT.color.a/PhantomAbs);
	
	opacity = pow(opacity,edgethickness) * height;
	OUT.color.rgb = lerp(OUT.color.rgb,outlineColor.rgb,PhantomRange);
	OUT.color.a = opacity;
#endif

#if ICE_EFFECT == 1
	float lum = params.cFinal.r;
	//视差
	float3 tangentViewDirNormal = normalize(float3(dot(params.FI.fTw, params.FI.fView),dot(params.FI.fBw, params.FI.fView),dot(params.FI.fNw, params.FI.fView)));
	float parallaxMap = 1 - tex2D(InnerSampler,params.FI.baseTC.xy).a;
	float2 parallaxOffset = - tangentViewDirNormal.xy *(parallaxMap/tangentViewDirNormal.z)*0.55;
    float2 innerUV = params.FI.baseTC.xy + parallaxOffset;
	float3 Inner = tex2D(InnerSampler,innerUV) + tex2D(InnerSampler,innerUV) * float3(0.0,0.75,1.0);

	//Ramp采样
	float FresnelAbs = abs(dot(params.FI.fNw, params.FI.fView));
	float FresnelRange = saturate(1.0f - FresnelAbs);
	float2 RampUV = float2(0.5*FresnelRange ,0.0);
    float4 sampledRamp = tex2D(RampSampler, RampUV);

	float noisepow = pow(0.5,1.13)*(lum*mainTexImpact+(1-0.2*mainTexImpact));
	float4 IceEmissive = sampledRamp * noisepow * 1.13 * 0.8584 *2.3;
	OUT.color.rgb = lerp(IceEmissive,Inner*1.5,0.2);
#endif

	return OUT;
}

#if Phantom_EFFECT > 0
void Calc_Phantom(inout FragParams params)
{
	float PhantomAbs = abs(dot(params.FI.fNw, params.FI.fView));
	float PhantomRange = saturate(1.0f - PhantomAbs);
	float3 Phantomcolor = lerp(baseColor.rgb,outlineColor.rgb,PhantomRange);
	params.cFinal.rgb = Phantomcolor;
}
#endif

PS_OUT main( VS_OUT IN ) 
{ 
	FragParams params = (FragParams)0;
	params.FI = fmt_input( IN );
	
	/// 设置渲染参数
	Set_SystemParams( params.SP );
	
	/// diffuse rt
	Calc_Diffuse_Tex( DiffuseSampler, params);
	
    #if Phantom_EFFECT > 0
	Calc_Phantom(params);
	#endif

	/// alpha rejection
	Tex_Kill( params.cDiffuseRT.a );
	
	/// env
	Calc_EnvMap( params );
	

	/// lighting
	Calc_Light_In_Ps( params );
	
#if XINGNING_EFFECT == 1
	Calc_XingNing_Effect( params, IN.oClipPos );
#endif

	/// fog
	Calc_Fog_Color( params.FI.fPw.w, params.cFinal.rgb );
	
	return fmt_output( params );
}

#endif





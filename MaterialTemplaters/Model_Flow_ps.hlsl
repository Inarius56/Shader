#ifndef _Model_Flow_PS_H_
#define _Model_Flow_PS_H_

// Define In VS
#define __PS__

sampler2D DiffuseSampler : register(s0);
sampler2D CtlSampler : register(s1);
sampler2D FlowSampler : register(s3);
float4 flowFactor = float4(1, 1, 1, 1);

#if DISSOLVE_EFFECT > 0
	sampler2D dissolveMap : register(s2);
#endif

#if DISSOLVE_EFFECT == 5
	sampler2D dissolveRampMap : register(s4);
#endif


#if USE_OUTLINE_CTRL_TEX == 1
sampler2D OutlineCtlSampler : register(s6);
#endif
#include "ModelDef.inc"


struct FragParams_flow
{
		FragParams ori;
		float4 cCtlTex;
		
};

FragInput fmt_input( VS_OUT IN )
{
	FragInput FI = (FragInput)0;
	FI.baseTC = IN.oUV0;
	FI.fPw = IN.oPw;
	FI.fPo = IN.oPo;
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

PS_OUT fmt_output( FragParams_flow params )
{
	PS_OUT OUT = (PS_OUT)0; 
	OUT.color = float4( params.ori.cFinal.rgb, params.ori.cDiffuseRT.a * params.ori.FI.color.a * surface_diffuse_colour.a );

#if USE_OUTLINE == 1
	float rimAbs = abs(dot(params.ori.FI.fNw, params.ori.FI.fView));
	float rimRange = 1-rimAbs;
#if USE_OUTLINE_CTRL_TEX == 1
	float4 outlineCtrl = tex2D(OutlineCtlSampler, params.ori.FI.baseTC.xy);
#endif
	float4 rimcolor = outlineColor.a * pow(rimRange, outlinePow.x * pow (rimAbs, outlinePow.y)) * float4(outlineColor.rgb
#if USE_OUTLINE_CTRL_TEX == 1
		* outlineCtrl.rgb * outlineCtrl.a
#endif
		, OUT.color.a);
	OUT.color += rimcolor;
	OUT.color.a = saturate(OUT.color.a);
#endif
#if DISSOLVE_EFFECT > 0
	#if DISSOLVE_EFFECT == 4
		OUT.color = Calc_Dissolve_Color_4(OUT.color, params.ori.FI.baseTC.xy);
	#elif DISSOLVE_EFFECT == 5
		OUT.color = Calc_Dissolve_Color_5(OUT.color, params.ori.FI.baseTC.xy,params.ori.FI.fPw.xyz);
	#else
		OUT.color = Calc_Dissolve_Color_1(OUT.color, params.ori.FI.baseTC.xy);
	#endif
#endif
	return OUT;
}

void Calc_Flow_Tex(inout FragParams_flow params)
{
	params.cCtlTex = float4(0.0,0.0,0.0,1.0);
	Calc_Diffuse_Tex( DiffuseSampler, params.ori );
    #if FLOW_TEX_TYPE == 0	//1个混合通道
			params.cCtlTex.r = (params.ori.cDiffuseRT.a * 255 - 5)/255;	  
		#elif FLOW_TEX_TYPE == 1
			params.cCtlTex = tex2D(CtlSampler, params.ori.FI.baseTC.xy);	
		#else  //原始的
			params.cCtlTex = tex2D(CtlSampler, params.ori.FI.baseTC.xy);	
		#endif	

}

void Calc_Flow(inout FragParams_flow params)
{
	#if FLOW_LIGHT_TYPE == 0	
		float2 ReflUV = params.ori.FI.fNo.xy;
	#else
		float2 ReflUV = params.ori.FI.baseTC.xy;       
	#endif

	ReflUV = ReflUV.xy * flowFactor.xy + time_0_x.x * flowFactor.zw * 0.1;	        
	float4 _Reflection_var = tex2D(FlowSampler, ReflUV);		        
	params.ori.cFinal.rgb += _Reflection_var.rgb * params.cCtlTex.r;
}


PS_OUT main( VS_OUT IN ) 
{ 
	FragParams_flow params = (FragParams_flow)0;
	params.ori.FI = fmt_input( IN );
	
	/// 设置渲染参数
	Set_SystemParams( params.ori.SP );
	
	/// diffuse rt
	Calc_Flow_Tex(params);
	
	/// alpha rejection
	Tex_Kill( params.ori.cDiffuseRT.a );
	
	/// env
	Calc_EnvMap( params.ori );
	
	/// lighting
	Calc_Light_In_Ps( params.ori );
	
	/// flow
	Calc_Flow(params);
	
	/// fog
	Calc_Fog_Color( params.ori.FI.fPw.w, params.ori.cFinal.rgb );
	
	return fmt_output( params );
}


#endif





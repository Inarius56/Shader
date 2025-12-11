#ifndef _Model_Face_PS_H_
#define _Model_Face_PS_H_

// Define In VS
#define __PS__

sampler2D DiffuseSampler 	: register(s0);

#include "ModelDef.inc"


FragInput fmt_input( VS_OUT IN )
{
	FragInput FI = (FragInput)0;
	
	FI.baseTC = IN.oUV0;
	FI.fPw = IN.oPw;	
	FI.fNw = float4(normalize(IN.oNw),0);
	FI.fNo = normalize(IN.oNo);
	FI.fView = float4( normalize(IN.oV.xyz), IN.oV.w );
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

	OUT.color = float4( params.cFinal.rgb,  params.FI.color.a * surface_diffuse_colour.a );		
	return OUT;
}

void Calc_Face_Light_In_Ps( inout FragParams params )
{
		Calc_Light_In_Ps( params );
	  float3 Nn = params.FI.fNw.xyz;
		float3 Vn = params.FI.fView.xyz;
    float4 sceneColor = derived_scene_colour * (1.0 - imodel_userdata.x) + actor_ambient_params * imodel_userdata.x;


    float3 lightDir = light_position_array[0].xyz;
    float3 Ln0 = normalize(lightDir);
		float3 h0 = normalize(Vn + Ln0);


    float fNdotL = dot(Nn, -Ln0);
		float3 buguang = max(fNdotL,0) * (float3(1,0.58,0.54)) * sceneColor;
	
		float rimRange = 1-abs(dot(Vn,Nn));
		float3 rimcolor = pow(rimRange,2.5) * 0.15 * (float3(0.66,0.16,0.16));///// 
		params.cFinal.rgb = params.cFinal.rgb + 0.15 * buguang* params.cDiffuseRT.a + rimcolor 
		+ 0.2 * pow( saturate(dot(Nn,h0)), 4 ) * light_specular_colour_array[0].xyz * sceneColor * params.cDiffuseRT.a;
}


PS_OUT main( VS_OUT IN ) 
{ 
	FragParams params = (FragParams)0;
	params.FI = fmt_input( IN );
	
	/// …Ë÷√‰÷»æ≤Œ ˝
	Set_SystemParams( params.SP );
	
	/// diffuse rt
	Calc_Diffuse_Tex( DiffuseSampler, params );	
	
	/// alpha rejection
	//Tex_Kill( params.cDiffuseRT.a );	
	
	/// lighting
	Calc_Face_Light_In_Ps( params );
	
	/// fog
	Calc_Fog_Color( params.FI.fPw.w, params.cFinal.rgb );
	
	return fmt_output( params );
}

#endif





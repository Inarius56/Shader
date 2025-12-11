#ifndef _Fog_INC_
#define _Fog_INC_


float Fogging(float depthInView, float4 fogType, float4 fogParam)
{
		float fogFactor = 0.0;
		fogFactor += fogType[0];
		fogFactor += fogType[1] * exp(- depthInView * fogParam.x);
		fogFactor += fogType[2] * exp(- (depthInView * fogParam.x) * (depthInView * fogParam.x));
		fogFactor += fogType[3] * saturate((fogParam.z - depthInView) * fogParam.w);
		
		return fogFactor;
}

void Calc_Fog_Color( float depthInView, inout float3 color )
{
	  float f = Fogging(depthInView, fog_type, fog_params);
		color = lerp( fog_colour.rgb, color, f );
}

#endif
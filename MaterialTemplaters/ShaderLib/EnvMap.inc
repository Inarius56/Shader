#ifndef _EnvMap_INC_
#define _EnvMap_INC_

void Calc_EnvMap( inout FragParams params )
{
	#if SPHEREMAPPING_ENABLE == 1
			float2 sphereTexUV = normalize(mul(view_matrix, float4(params.FI.fNw.xyz, 0.0))).xy*0.5 + 0.5;
  		float4 sphereTexColor = tex2D(SphereMappingSampler, sphereTexUV);
  		params.cFinal.rgb = (params.cFinal.rgb + sphereTexColor.rgb) - params.cFinal.rgb * sphereTexColor.rgb;
	#endif

}

#endif
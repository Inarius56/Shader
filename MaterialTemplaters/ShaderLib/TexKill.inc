#ifndef _TexKill_INC_
#define _TexKill_INC_

#include "ShaderLib/ParamNamed.inc"

void Tex_Kill( float alpha_test_value )
{
#if DISSOLVE_EFFECT > 0
	// 如果是溶解会有自己的kill
#else
	#if ALPHATEST_ENABLE
		clip( alpha_test_value - imodel_userdata.z );
	#endif
#endif
}

#if DISSOLVE_EFFECT > 0
	// 计算溶解颜色
	float4 Calc_Dissolve_Color_1(float4 color, float2 uv)
	{
		float4 outColor = color;
		float4 clipMask = tex2D(dissolveMap, uv * dissolveUVRepeat);
		float4 clipAlpha = tex2D(dissolveMap, uv);
		float _clipth = clipMask.r * clipAlpha.a;
		clip( _clipth - dissolveClip );
		float2 edge_area = saturate(1 - saturate((_clipth - dissolveClip - dissolveParams.xy) / dissolveParams.zw));
		outColor.rgb = lerp(outColor.rgb, dissolveColorA.rgb, edge_area.x);
		outColor.rgb = lerp(outColor.rgb, dissolveColorB.rgb, edge_area.y);
		//软边溶解计算，加上一个偏移值防止除以0的情况
		float radio = saturate((_clipth - dissolveClip) / ((dissolveSoftEdgeWidth + 0.001) * dissolveClip));
		outColor.a *= radio;
		return outColor;
	}

	#if DISSOLVE_EFFECT == 4
		// 随着时间进行溶解
		float4 Calc_Dissolve_Color_4(float4 color, float2 uv)
		{
			float dClipThd = saturate(dissolveClip);
			float dClip = (sin(time_0_x) + 1.0) * 0.5;
			dClip = (2.0 - dClipThd) * dClip - dClipThd; // -dClipThd ~ 1.0
			float4 outColor = color;
			float4 clipMask = tex2D(dissolveMap, uv * dissolveUVRepeat);
			float4 clipAlpha = tex2D(dissolveMap, uv);
			float _clipth = clipMask.r * clipAlpha.a;
			clip( _clipth - dClip );
			float2 edge_area = saturate(1 - saturate((_clipth - dClip - dissolveParams.xy) / dissolveParams.zw));
			outColor.rgb = lerp(outColor.rgb, dissolveColorA.rgb, edge_area.x);
			outColor.rgb = lerp(outColor.rgb, dissolveColorB.rgb, edge_area.y);
			return outColor;
		}
	#endif
    #if DISSOLVE_EFFECT == 5
        // 随着时间进行溶解
        float4 Calc_Dissolve_Color_5(float4 color, float2 uv, float3 pw)
        {
            float4 outColor = color;

            float denom = dissolveMaxProj - dissolveMinProj;
            float proj = dot(pw, dissolveDirection);
            float projNorm = saturate((proj - dissolveMinProj) / denom);

            float2 uvFlow = uv + frac(time_0_x * dissolveFlowSpeed);
            float texNoise = tex2D(dissolveMap, uvFlow * dissolveUVRepeat).r * 2.0 - 1.0;

            float clipValue = (projNorm - dissolveClip) / (dissolveEdgeContrast + 0.001) * (1.0 - dissolveReverse) + (dissolveClip - projNorm) / (dissolveEdgeContrast + 0.001) * dissolveReverse + 0.5 - texNoise * 0.2;
            clip(step(0.5, clipValue) - 0.5);

            float edgeFractor = distance(clipValue, 0.5);
            float edgeRange = smoothstep(0, dissolveEdgeRange, edgeFractor);
            float2 rampUV = float2(edgeRange, 0.5);
            float3 rampVal = tex2D(dissolveRampMap, rampUV).rgb;

            outColor.rgb = lerp(outColor.rgb, rampVal * dissolveEdgeColor.rgb * dissolveEdgeLighting, 1.0 - edgeRange);

            return outColor;
        }
    #endif
#endif

#endif
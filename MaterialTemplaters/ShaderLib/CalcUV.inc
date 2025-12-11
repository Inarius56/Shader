#ifndef _CalcUV_INC_
#define _CalcUV_INC_

void Calc_Uv( inout VertParams params )
{
#if USE_TEXCOORD == 1
#if TEX_EFFECT_0 == 1
		params.baseTC.xy = mul( texture_matrix_2x4_0, float4(params.VI.tc0.xy, 0, 1)).xy;
#else
		params.baseTC.xy = params.VI.tc0.xy;
#endif
		
#if TEX_EFFECT_1 == 1
		params.baseTC.zw = mul( texture_matrix_2x4_1, float4(params.VI.tc0.xy, 0, 1) ).xy;
#else
		params.baseTC.zw = params.VI.tc0.xy;
#endif
#endif
}

void Calc_ScreenUV( inout VertParams params )
{
		float4x4 scalemat = float4x4( 0.5,   0,   	0, 		0.5, 
	                                0,		-0.5,   0, 		0.5,
								   							  0,   	0, 			0.5, 	0.5,
								   							  0,   	0,   		0,   	1 );
		params.projTC = mul( scalemat, params.ps );
}

float4 Calc_ScreenUV( in float4 ps )
{
		float4x4 scalemat = float4x4( 0.5,   0,   	0, 		0.5, 
	                                0,		-0.5,   0, 		0.5,
								   							  0,   	0, 			0.5, 	0.5,
								   							  0,   	0,   		0,   	1 );
		float4 screenPos = mul( scalemat, ps );
		return screenPos;
}

float2 Calc_RibbonUV( in float2 uv, in float useRibbon, in float useUDirection, in float widthRatio, in float2 blocks )
{
	if(useRibbon > 0.5f)
	{	
		// 判断是头部更宽还是尾部更宽
		float headLarger = widthRatio < 1.0f;
		float tailLarger = 1.0f - headLarger;

		// 计算uv范围
		float4 uvRange = float4(0.0f, 0.0f, 1.0f, 1.0f);
		float halfU = 0.5f;
		float halfV = 0.5f;
		if(blocks.x != 1.0f || blocks.y != 1.0f)
		{
			//min U
			uvRange.x = uv.x - fmod(uv.x, blocks.x);
			//max U
			uvRange.z = uvRange.x + blocks.x;
			//min V
			uvRange.y = uv.y - fmod(uv.y, blocks.y);
			//max V
			uvRange.w = uvRange.y + blocks.y;

			halfU = (uvRange.z + uvRange.x) * 0.5f;
			halfV = (uvRange.w + uvRange.y) * 0.5f;
		}	

		// 判断是用 U 作为参考坐标还是用 V 作为参考坐标
		if(useUDirection > 0.5)
		{
			float yWithHead = (uv.y - halfV) / (1.0f - (1.0f - widthRatio) * (uv.x - uvRange.x) / blocks.x) + halfV;                 // 头比尾宽时
			float yWithTail = (uv.y - halfV) / (1.0f - (1.0f - 1.0f / widthRatio) * (uvRange.z - uv.x) / blocks.x) + halfV;				//尾比头宽时
			uv.y = headLarger * yWithHead + tailLarger * yWithTail;
			clip(uv.y - uvRange.y);
			clip(uvRange.w - uv.y);
		}
		else
		{
			float xWithHead = (uv.x - halfU) / (1.0f - (1.0f - widthRatio) * (uv.y - uvRange.y) / blocks.y) + halfU;
			float xWithTail = (uv.x - halfU) / (1.0f - (1.0f - 1.0f / widthRatio) * (uvRange.w - uv.y) / blocks.y) + halfU;
			uv.x = headLarger * xWithHead + tailLarger * xWithTail;
			clip(uv.x - uvRange.x);
			clip(uvRange.z - uv.x);
		}
	}
	return uv;
}

float2 Calc_MeshUV( in float2 uv, in float4 sequenceFrameUVFactor )
{
	float left = sequenceFrameUVFactor.x;
	float right = sequenceFrameUVFactor.y;
	float top = sequenceFrameUVFactor.z;
	float bottom = sequenceFrameUVFactor.w;
	
	uv.x = left + uv.x * ( right -left) ; 
	uv.y = top + uv.y * (bottom - top);  
	
	return uv;
}

#endif
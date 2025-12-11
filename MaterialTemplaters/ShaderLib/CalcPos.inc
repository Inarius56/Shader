#ifndef _CalcPos_INC_
#define _CalcPos_INC_

#ifdef __VS__


#if VS_ANIMATION == 1			
float4 SmoothCurve( float4 x ) {
	float4 x2 = x * x;
	float4 x3 = x * x2;
	return 3.0f * x2 - 2.0f * x3;
}
float4 TriangleWave( float4 x ) {
	return abs( frac( x + 0.5 ) * 2.0 - 1.0 );
}
float4 SmoothTriangleWave( float4 x ) {
	return SmoothCurve( TriangleWave( x ) );
}
// Detail bending
float4 AnimateVertex(float4 vertex, float3 normal)
{	
	float3 windDir = float3(wind_control_params.x, 0.0, wind_control_params.y);
	windDir = normalize(windDir);
	float windStrength = vsWindStrength;
	float _EdgeFlutterFactor = vsAniFactor.x;
	float _BendingFactor = vsAniFactor.y;
	float _EdgeFlutterFreqScale = vsAniFactor.z / 4 * pow(wind_control_params.z, 0.5);
	float _MinBendingHeight = vsAniFactor.w;
	//_EdgeFlutterFactor = vsAniFactor.x * 0.00001 + 34;
	//float _BendingFactor = vsAniFactor.y* 0.00001 + 0.04;
	//_EdgeFlutterFreqScale = _EdgeFlutterFreqScale* 0.00001 + 0.8;
	//float _MinBendingHeight = vsAniFactor.w* 0.00001 + 200.1;
	float4 pos = vertex;
	float fDetailAmp = 0.1f;
	float fBranchAmp = 0.3f;

	float blendDistFactor = clamp((pos.y - _MinBendingHeight) / 2500, 0, 1);
	//add erase function
	blendDistFactor = smoothstep(0, 1, blendDistFactor);

	//float blendFactor = max(pos.y - _MinBendingHeight,0) * _BendingFactor;
	float blendFactor = blendDistFactor * _BendingFactor;

	// Phases (object, vertex, branch)
	float3 objMove = float3(world_matrix[0].w,world_matrix[1].w,world_matrix[2].w);
	float fObjPhase = 1;////dot(objMove, 1);
	float fBranchPhase = fObjPhase;
	float fVtxPhase = dot(normalize(pos.xyz) * 200, _EdgeFlutterFactor + fBranchPhase);

	// x is used for edges; y is used for branches   time_0_x.xx * 
	float2 vWavesIn = wind_control_params.ww * _EdgeFlutterFreqScale * 0.1 + float2(fVtxPhase, fBranchPhase);

	// 1.975, 0.793, 0.375, 0.193 are good frequencies
	//float4 vWaves = (frac( vWavesIn.xxyy  )* 2.0 - 1.0);
	float4 vWaves = (frac( vWavesIn.xxyy * float4(1.975, 0.793, 0.375, 0.193) ) * 2.0 - 1.0);

	vWaves = SmoothTriangleWave( vWaves );
	float2 vWavesSum = vWaves.xz + vWaves.yw;
		
	half3 windWaveFactor = windDir * blendFactor * windStrength;
	// Edge (xz) and branch bending (y)
	float3 bend = _EdgeFlutterFactor * fDetailAmp * normal.xyz;
	bend.z = blendFactor * fBranchAmp;

	pos.xyz += vWavesSum.xxy * bend + vWavesSum.y * windWaveFactor;
	
	pos.xyz += windWaveFactor;
	return pos;
}
#endif
// 四元数变换
float3 Quat_Transform(float4 q, float3 v)
{
	float3 t = q.w * v + cross(q.xyz, v);
	return 2.0 * cross(q.xyz, t) + v;
}

// 四元数变换 + 平移
// 该双四元数已经不是标准的数学模型（wanhao 21/11/2）
float3 Quat_TransformAndTrans(float2x4 dq, float3 v)
{
	float4 q = dq[0];
	float4 p = dq[1];
	float3 v0 = Quat_Transform(q, v * p.w);
	p.xyzw = p.xyzx * q.wwwx + p.yzxy * q.zxyy - p.zxyz * q.yzxz * float4(1, 1, 1, -1);
	float3 v1 = q.w * p.xyz + p.w * q.xyz + cross(q.xyz, p.xyz);
	return v0 + v1;
}

// 计算四元数骨骼
void Calc_Quat_Skin(inout VertParams params)
{
	float3 blendPos = float3(0,0,0);
	float3 blendNormal = float3(0,0,0);
	float3 blendTangent = float3(0,0,0);
	for( int i = 0; i < imodel_userdata.y; i++ )
	{
		float2x4 boneDQ = dual_quaternion_array_2x4[params.VI.blendIdx[i]];
		boneDQ[0].xyzw = boneDQ[0].yzwx;
		blendPos += Quat_TransformAndTrans(boneDQ, params.VI.position.xyz) * params.VI.weight[i];
		#if USE_NORMAL
			blendNormal += Quat_Transform(boneDQ[0], params.VI.normal.xyz) * params.VI.weight[i];
			#if USE_TANGENT
				blendTangent += Quat_Transform(boneDQ[0], params.VI.tangent.xyz) * params.VI.weight[i];
			#endif
		#endif
	}
	#if USE_NORMAL
		params.nw = float4( normalize(blendNormal), 0 );
		params.nv = float4( mul( (float3x3)view_matrix, params.nw.xyz ), 0 );
		#if USE_TANGENT
			float3 nwTemp = params.nw.xyz;
			float3 twTemp = normalize(float4(blendTangent, 1.0)).xyz;
			params.tw = float4( twTemp.xyz, 0 );
			params.bw = float4( normalize(cross(nwTemp,twTemp)) * params.VI.tangent.w, 0 );
		#endif
	#endif
	params.pw = float4( blendPos.xyz, 1 );
	//params.pw = mul( world_matrix, float4( blendPos.xyz, 1 ) );
}

void Calc_Skin( inout VertParams params )
{
#if USE_SKIN == 1
	#if USE_QUAT_SKIN == 1
		Calc_Quat_Skin(params);
	#else
		float3 blendPos = float3(0,0,0);
		float3 blendNormal = float3(0,0,0);
		float3 blendTangent = float3(0,0,0);
		for( int i = 0; i < imodel_userdata.y; i++ )
		{
			blendPos +=  mul( world_matrix_array_3x4[params.VI.blendIdx[i]], params.VI.position ) * params.VI.weight[i];
			#if USE_NORMAL
				blendNormal += mul( (float3x3)world_matrix_array_3x4[params.VI.blendIdx[i]], params.VI.normal.xyz ) * params.VI.weight[i] ;
				#if USE_TANGENT
					blendTangent += mul( (float3x3)world_matrix_array_3x4[params.VI.blendIdx[i]], params.VI.tangent.xyz ) * params.VI.weight[i] ;
				#endif
			#endif
		}
		params.pw = float4( blendPos.xyz, 1 );
		#if USE_NORMAL
			params.nw = float4( normalize(blendNormal), 0 );
			params.nv = float4( mul( (float3x3)view_matrix, params.nw.xyz ), 0 );
			#if USE_TANGENT
				float3 nwTemp = params.nw.xyz;
				float3 twTemp = normalize(float4(blendTangent, 1.0)).xyz;
				params.tw = float4( twTemp.xyz, 0 );
				params.bw = float4( normalize(cross(nwTemp,twTemp)) * params.VI.tangent.w, 0 );
			#endif
		#endif
	#endif
#else
	#if VS_ANIMATION == 1
		params.VI.position = AnimateVertex( params.VI.position ,params.VI.normal.xyz);
	#endif
	params.pw = mul( world_matrix, params.VI.position );
	
	#if USE_NORMAL
		params.nw = float4( normalize(mul( (float3x3)world_matrix, params.VI.normal.xyz ).xyz),0 );
		#if USE_TANGENT
			float3 nwTemp = params.nw.xyz;
			float3 twTemp = normalize( mul( (float3x3)world_matrix, params.VI.tangent.xyz  ) );
			params.tw = float4( twTemp.xyz, 0 );
			params.bw = float4( normalize(cross(nwTemp,twTemp)) * params.VI.tangent.w, 0 );
		#endif
	#endif
#endif

}
/// convert object-space to world space
/// input 	: po
/// output	: pw, pv, ps
void Calc_Position( inout VertParams params )
{
	params.po = params.VI.position;
	params.no = params.VI.normal;
			
	/// calc hw skin
	Calc_Skin( params );
	
	/// position in view & projection
	params.pv = mul( view_matrix, params.pw );
	
	params.ps = mul( projection_matrix, params.pv );
	
}

void Calc_Quad_Position( inout VertParams params )
{
	params.VI.position.xy = sign( params.VI.position.xy );
	params.po = float4( params.VI.position.xy, 0, 1 );
	params.pw = params.po;
	params.pv = params.po;
	params.ps = params.po;
}

#endif


#ifdef __PS__
// calc normal in ps
void Calc_Normal_ps(inout FragInput FI, in float4 normalTex)
{
	float3x3 TBNMatrix = float3x3( FI.fTw, FI.fBw, FI.fNw.xyz );//法线的TBN旋转矩阵
	float3 nwLocal = normalTex.rgb * 2 - 1;
	float3 normalDirection = normalize(mul( nwLocal, TBNMatrix )); // 最终的法线	
	FI.fNw = float4(normalDirection,normalTex.a);
}


float3 Calc_Normal_ps(in float3 fTw, in float3 fBw, in float3 fNw, in float3 normalInTangent)
{
	float3x3 TBNMatrix = float3x3( fTw, fBw, fNw );//法线的TBN旋转矩阵
	float3 normalDirection = normalize(mul( normalInTangent, TBNMatrix )); // 最终的法线	
	return normalDirection;
}

float3 UnpackScaleNormal(float4 packednormal, float bumpScale)
{
   packednormal.y = 1- packednormal.y;
	
   float3 normal;
   normal.xy = (packednormal.xy * 2 - 1);
   normal.xy *= bumpScale;
   normal.z = sqrt(1.0 - saturate(dot(normal.xy, normal.xy)));
   return normal;
}

#endif


#endif
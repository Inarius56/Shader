#ifndef _ShadingParams_INC_
#define _ShadingParams_INC_

#include "ShaderLib/ParamNamedAuto.inc"
#include "ShaderLib/ParamNamed.inc"


struct SystemParams
{
		int bHDREnable;
		int bLinearSpaceEnable;
		int bLightGreaterOneEnable;
};

#ifdef D3D11
	#define BLD_IDX uint4
#else
	#define BLD_IDX float4
#endif

/// vertex input
struct VertInput
{
		/// position
		float4 position;
		
		/// blend weights
		BLD_IDX blendIdx;
		float4 weight;
		
		/// normals
		float4 normal;
		float4 tangent;
		float4 vColor;
		
		/// texcoords
		float4 tc0;
};

/// vertex params
struct VertParams
{
		/// Inputs
		VertInput VI;
		SystemParams SP;
		
	  /// position
		float4 po;
		float4 pw;
		float4 pv;
		float4 ps;
		
		/// normals
		float4 no;
		float4 nw;
		float4 nv;
		/// tangent
		float4 tw;
		/// binormal
		float4 bw;
		
		/// texcoords
		float4 baseTC;
		float4 projTC;
		
		/// view
		float3 view;
		
		/// shadow
		float4 shadow;
		
		/// colors
		float4 color;

};

/// fragment inputs
struct FragInput
{
		// texcoords
		float4 baseTC;
		
		// position
		float4 fPw;
		float4 fPo;

		// normal
		float4 fNv;
		float4 fNw;
		float3 fNo;
		float3 oNw;
		float3 fTw;
		float3 fBw;
		
		
		float4 fView;
		float4 fShadow;
		float4 color;
};

/// fragment params
struct FragParams
{
		FragInput 	FI;
		SystemParams SP;
		
		float4 cDiffuseRT;
		float3 cLight;
		float4 cFinal;
		
};




#endif
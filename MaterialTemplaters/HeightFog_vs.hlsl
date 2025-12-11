
uniform float4x4 cWorldVecGen;
uniform float4x4 worldviewproj_matrix;

struct VS_OUTPUT {
   float4 Pos: POSITION;
   float4 oTexCoord: TEXCOORD0;
   float3 oRay : TEXCOORD1;
};

VS_OUTPUT main( in float4 Pos: POSITION)
{
   VS_OUTPUT Out;

	Out.Pos = mul(worldviewproj_matrix, Pos);

	// Image-space
	float4x4 scalemat = float4x4(0.5,   0,   0, 0.5, 
	                              0,-0.5,   0, 0.5,
								   							0,   0, 0.5, 0.5,
								   							0,   0,   0,   1);
	Out.oTexCoord = mul(scalemat, Out.Pos);
	//Out.oTexCoord.x = 0.5 * (1 + Pos.x);
	//Out.oTexCoord.y = 0.5 * (1 - Pos.y);

  //float4 worldVec = mul(cWorldVecGen, Out.Pos.xyww);
  //Out.oRay = worldVec.xyz/worldVec.w;  
  
  float4 vec = float4(Out.Pos.xy, -1, 0);
  float4 worldVec = mul(cWorldVecGen, vec);
  //Out.oRay = worldVec.xyz/worldVec.w;  
  Out.oRay = worldVec.xyz;

  return Out;
}
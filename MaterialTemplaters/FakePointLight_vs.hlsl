#ifndef _FakePointLight_VS_H_
#define _FakePointLight_VS_H_

// Define In VS
#define __VS__



#include "FakePointLightDef.inc"

VS_OUT main( VS_IN IN )
{
	VS_OUT OUT = (VS_OUT)0;
	
	OUT.oPos = mul(worldviewproj_matrix, IN.position);
	OUT.oUVScreen = Calc_ScreenUV(OUT.oPos);
	OUT.oRay = mul(worldview_matrix, IN.position).xyz;
	return OUT;
}

#endif



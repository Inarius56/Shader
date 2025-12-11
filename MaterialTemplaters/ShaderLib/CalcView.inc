#ifndef _CalcView_INC_
#define _CalcView_INC_

/// calc view dir
void Calc_View( inout VertParams params )
{
	params.view.xyz = camera_position - params.pw.xyz;
}

#endif
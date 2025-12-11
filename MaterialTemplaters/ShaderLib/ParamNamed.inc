#ifndef _ParamNamed_INC_
#define _ParamNamed_INC_



#ifndef USE_TEXCOORD
    #define USE_TEXCOORD          0
#endif

#ifndef USE_NORMAL
    #define USE_NORMAL          0
#endif

#ifndef USE_TANGENT
    #define USE_TANGENT          0
#endif

#ifndef USE_OUTLINE
    #define USE_OUTLINE          0
#endif

#ifndef USE_VERTEXCOLOR
    #define USE_VERTEXCOLOR          0
#endif

#ifndef ALPHATEST_ENABLE
    #define ALPHATEST_ENABLE          0
#endif

#ifndef USE_SKIN
    #define USE_SKIN          0
#endif
#ifndef USE_QUAT_SKIN
    #define USE_QUAT_SKIN          0
#endif

#define LIGHT_CALC_NONE   0
#define LIGHT_CALC_VS     1
#define LIGHT_CALC_PS     2
#ifndef LIGHT_CALC_TYPE
    #define LIGHT_CALC_TYPE LIGHT_CALC_VS
#endif

#ifndef TEX_EFFECT_0
	#define TEX_EFFECT_0 0
#endif

#ifndef TEX_EFFECT_1
	#define TEX_EFFECT_1 0
#endif

#ifndef USE_TEXLOD0
	#define USE_TEXLOD0 0
#endif

/// sampler define
//#ifndef DIFFUSE_1_ENABLE
//#define DIFFUSE_1_ENABLE 1
//#endif

//#ifndef DIFFUSE_2_ENABLE
//#define DIFFUSE_2_ENABLE 0
//#endif

//#ifndef FLOW_ENABLE
//#define FLOW_ENABLE 0
//#endif

#ifndef SPECULAR_ANITROPHIC_ENABLE
#define SPECULAR_ANITROPHIC_ENABLE 0
#endif

#ifndef HIGHLIGHT_SIMPLE_ENABLE
#define HIGHLIGHT_SIMPLE_ENABLE 0
#endif

#ifndef HIGHLIGHT_ENABLE
#define HIGHLIGHT_ENABLE 0
#endif

#define SHADOWMAP_NONE 0
#define SHADOWMAP_SIMPLE 2
#define SHADOWMAP_CSM 1

#ifndef SHADOWMAP_TYPE
	#define SHADOWMAP_TYPE SHADOWMAP_NONE
#endif

#ifndef SPHEREMAPPING_ENABLE
#define SPHEREMAPPING_ENABLE 0
#endif

#ifndef LUT_ENABLE
#define LUT_ENABLE 0
#endif

#ifndef VS_ANIMATION
#define VS_ANIMATION 0
#endif
//#ifndef PBR_ENABLE
//#define PBR_ENABLE 0
//#endif

/// tex blend op
#define BLEND_OP_MODULATE   0
#define BLEND_OP_MODULATE2     1
#define BLEND_OP_MODULATE4     2
#define BLEND_OP_ADD     3
#define BLEND_OP_CUSTOM     4

// process the ColorOp of texUnit0
//#if DIFFUSE_1_ENABLE == 1
	#ifndef BLEND_OP_0
			#define BLEND_OP_0 BLEND_OP_MODULATE
	#endif
//#endif

// process the ColorOp of texUnit1
//#if DIFFUSE_2_ENABLE == 1
	#ifndef BLEND_OP_1
			#define BLEND_OP_1 BLEND_OP_MODULATE
	#endif
//#endif

// flow type
#define FLOW_LIGHT_NORMAL   0
#define FLOW_LIGHT_UV     1
#ifndef FLOW_LIGHT_TYPE
    #define FLOW_LIGHT_TYPE	FLOW_LIGHT_NORMAL
#endif

#define FLOW_1RGBA 0  //1个混合通道
#define FLOW_2RGB 1  //正常alpha放到控制图
#define FLOW_2RGBA 2  //原始的
#ifndef FLOW_TEX_TYPE 
    #define FLOW_TEX_TYPE FLOW_2RGBA
#endif

#ifndef FROZEN_ENANLE
#define FROZEN_ENANLE 0
#endif

#ifndef IS_PBR_MODEL
	#define IS_PBR_MODEL 0
#endif

#ifndef IS_DETAIL
	#define IS_DETAIL 0
#endif

#ifndef USE_DSINTZ
	#define USE_DSINTZ 0
#endif

#ifdef __PS__

#if SPHEREMAPPING_ENABLE == 1
	sampler2D SphereMappingSampler : register(s3);
#endif

#if LUT_ENABLE == 1
	sampler2D LUTSampler : register(s4);
#endif

#if SHADOWMAP_TYPE != SHADOWMAP_NONE
	sampler2D ShadowMapSampler : register(s5);
#endif

sampler2D ssao_buffer : register(s12);

#endif


#if FROZEN_ENANLE == 1
	float3 tex0BlendColor = float3(0.0, 0.0, 0.0);
	float4 multiBlendColor = float4(1.0, 1.0, 1.0, 1.0);
#endif
#if VS_ANIMATION ==1
	float4 vsAniFactor = float4(1, 1, 1, 1);
	float vsWindStrength = 10.0;
#endif

#if USE_OUTLINE ==1
	float2 outlinePow = float2(1000.0, 6.0);
	float4 outlineColor = float4(1.0, 1.0, 0.0, 1.0);
#endif
	float4 spec_params = float4(255.0, 255.0, 255.0, 1.0);

#ifndef DISSOLVE_EFFECT
// 溶解效果枚举
// 0表示没有
// 1表示mask溶解
// 2表示定向溶解
// 3表示中心溶解
// 4表示随时间循环溶解
// 5表示按照方向进行溶解，新实现方式
#define DISSOLVE_EFFECT 0
#endif

#if DISSOLVE_EFFECT > 0
	// 裁剪程度
	uniform float  dissolveClip = 0.0;
	// 溶解贴图重复度
	uniform float2 dissolveUVRepeat = float2(1,1);
	// 溶解颜色A
	uniform float4 dissolveColorA = float4(0,0,0,1);
	// 溶解颜色B
	uniform float4 dissolveColorB = float4(1,1,1,1);
	// 溶解参数
	// 颜色A阈值，越大越宽
	// 颜色B阈值，越大越宽，最好不要大于颜色A阈值
	// 颜色A平滑程序，越大越平滑，但会影响宽度
	// 颜色B平滑程度，越大越平滑，但会影响宽度
	uniform float4 dissolveParams = float4(0.05, 0.005, 0.02, 0.01);
	//软边宽度，越大软边效果越宽；需要开启alphablend
	uniform float dissolveSoftEdgeWidth = 0.0;

    #if DISSOLVE_EFFECT == 5
        // uv 流动速度
        uniform float dissolveFlowSpeed = 0.0;
        // 边缘对比度
        uniform float dissolveEdgeContrast = 0.0;
        // 边缘范围
        uniform float dissolveEdgeRange = 0.1;
        // 溶解边缘颜色
        uniform float4 dissolveEdgeColor = float4(0,0,0,1);
        // 边缘亮度
        uniform float dissolveEdgeLighting = 1.0;
        // 溶解方向
        uniform float3 dissolveDirection = float3(0,0,0);
        // 逆转 0 为溶解 1 为出现
        uniform float dissolveReverse = 0.0;
        // 投影最小值
        uniform float dissolveMinProj = 0.0;
        // 投影最大值
        uniform float dissolveMaxProj = 0.0;
    #endif
#endif

#ifndef XINGNING_EFFECT
#define XINGNING_EFFECT 0
#endif

// 使用了拖尾特效
uniform float useRibbon = 0.0;
// 粒子 尾部/头部 的宽度比例
uniform float widthRatio = 0.0;
// 使用 U 坐标作为参考
uniform float useUDirection = 0.0;
// 贴图切分stacks、slices
uniform float2 blocks = float2(1.0,1.0);

//mesh粒子序列帧参数 默认是正常大小
uniform float4 sequenceFrameUVFactor = float4(0.0,1.0,0.0,1.0);
#endif
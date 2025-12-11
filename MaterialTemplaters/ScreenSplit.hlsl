#define _UNROLL 

// Uncomment the following line to control the chap manually,
// Please also uncomment the 453th line in __ldj.material
//#define _SCREENCHAP_AUTO

float4 psScreenChap(		float2 iTex : TEXCOORD,
#ifdef _SCREENCHAP_AUTO
					uniform float fTime,
#else
					uniform float fPlayRatio,
#endif
					uniform sampler2D sampScene : register(s0),
					uniform sampler2D sampChapImage : register(s1),
					uniform sampler2D sampChapMask : register(s2) ) : COLOR
{
#ifdef _SCREENCHAP_AUTO
	float fPlayRatio = frac(fTime*0.5);
#endif

	float4 src = tex2D( sampScene, iTex );
	float4 chap = tex2D( sampChapImage, iTex );
	float cm = tex2D( sampChapMask, iTex );
	fPlayRatio = tex2D( sampChapMask, fPlayRatio ).y * 2;
	chap = lerp( src, chap, chap.a );

	cm -= fPlayRatio;
	cm = lerp( cm, 1, cm > 0 );
	cm = max( 0, 1 - abs(cm) );
	return lerp( src, chap, cm );
}

#ifdef _SCREENCHAP_AUTO
#undef _SCREENCHAP_AUTO
#endif
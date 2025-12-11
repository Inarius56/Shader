#define _UNROLL

float4 TransScene_Wave_fp(	
					in float4 pos : POSITION,
					in float2 i : TEXCOORD,
					uniform float timeFactor,
					uniform float4 vvp,
					uniform sampler2D sampScene : register(s0),
					uniform sampler2D chaosTex : register(s1) ) : COLOR
{

				float ratio = vvp.x / vvp.y;

				float2 chaosuv = (i.xy-float2(0.5,0.5))* float2(1, 1 / ratio) +float2(0.5,0.5);
				chaosuv = (chaosuv.xy-float2(0.5,0.5)) * clamp(0.88*(2.5*timeFactor -2.5)*(2.5*timeFactor -2.5) + 0.5,0,6) +float2(0.5,0.5);////clamp(6 - timeFactor * 7,0,6)
	
				float kk = timeFactor * 2.5;
				float4 chaos = tex2D(chaosTex,clamp(chaosuv,0,1)) * kk ;

				float2 tanV = float2(0, 0);
				tanV.x = (chaosuv.x - 0.5) * cos(1.57) - (chaosuv.y - 0.5) * sin(1.57);
				tanV.y = (chaosuv.y - 0.5) * cos(1.57) + (chaosuv.x - 0.5) * sin(1.57);
				float timeup = step(2, timeFactor * 2.5);
				float strength = (1 - timeup) * 1 + timeup * (- 3.2 * (timeFactor * 2.5 - 2) * (timeFactor * 2.5 - 2) + 1);
				float2 newuv = i.xy +  tanV * chaos * 0.035 * strength;

				float4 ccccc = tex2D(sampScene, clamp(newuv,0,1))  ;
				
				return ccccc + 0.01 * chaos;
			

}

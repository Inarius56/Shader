#ifndef USE_DSINTZ
    #define USE_DSINTZ          0
#endif
   

    void DoF_Gaussian3x3FP(float4 pos : POSITION, float2 tex  : TEXCOORD0,
                                out float4 color : COLOR,
                                uniform sampler2D source : register(s0),
                                uniform float pixelSize
                                )
    {
     
      #define KERNEL_SIZE 9
     
      float weights[KERNEL_SIZE];
      float2 offsets[KERNEL_SIZE];
     
      weights[0] = 1.0/16.0; weights[1] = 2.0/16.0; weights[2] = 1.0/16.0;
      weights[3] = 2.0/16.0; weights[4] = 4.0/16.0; weights[5] = 2.0/16.0;
      weights[6] = 1.0/16.0; weights[7] = 2.0/16.0; weights[8] = 1.0/16.0;

      offsets[0] = float2(-pixelSize, -pixelSize);
      offsets[1] = float2(0, -pixelSize);
      offsets[2] = float2(pixelSize, -pixelSize);
      offsets[3] = float2(-pixelSize, 0);
      offsets[4] = float2(0, 0);
      offsets[5] = float2(pixelSize, 0);
      offsets[6] = float2(-pixelSize, pixelSize);
      offsets[7] = float2(0,  pixelSize);
      offsets[8] = float2(pixelSize, pixelSize);

      color = float4(0,0,0,0);

      for (int i = 0; i < KERNEL_SIZE; ++i)
        color += weights[i] * tex2D(source, tex + offsets[i]);
    }


//--------------------------------------------------------------------------------------
/// LinearizeDepthPS
//--------------------------------------------------------------------------------------
float DeviceDepthToEyeLinear(float fDepth, float nearZ, float farZ)
{
	float x = (nearZ - farZ) / (farZ * nearZ);
	float y = 1.0 / nearZ;
	return 1.0 / (x * fDepth + y);
}

    void DoF_DepthOfFieldFP(float4 pos : POSITION, float2 tex  : TEXCOORD0,
                                out float4 color : COLOR,
                                uniform sampler2D scene : register(s0),             // full resolution image
                                uniform sampler2D blur  : register(s1),             // downsampled and blurred image
                                uniform sampler2D sceneDepth  : register(s2),
                               #if USE_DSINTZ
                              	uniform float near_clip_distance,
																uniform float far_clip_distance,
                              #endif   
                                uniform float pixelSizeScene,                      // pixel size of full resolution image
                                uniform float pixelSizeBlur,                       // pixel size of downsampled and blurred image
                                uniform float4  dofParams                      
                                )
    {

      float  tmpDepth    = tex2D(sceneDepth, tex).r; 
#if USE_DSINTZ
      tmpDepth = DeviceDepthToEyeLinear(tmpDepth, near_clip_distance, far_clip_distance );
#endif
      float  centerDepth = tmpDepth; 

      if(tmpDepth<dofParams.y)
      {   
        centerDepth = (tmpDepth - dofParams.y) / (dofParams.y - dofParams.x);                    // scale depth value between near blur distance and focal distance to [-1, 0] range
      }else{
        centerDepth = (tmpDepth - dofParams.y) / (dofParams.z - dofParams.y);                    // scale depth value between focal distance and far blur distance to [0, 1] range   
        centerDepth = clamp(centerDepth, 0.0, dofParams.w);                                             // clamp the far blur to a maximum blurriness
      }
     
      centerDepth = 0.5f*centerDepth + 0.5f;                                                            // scale and bias into [0, 1] range


     
      #define NUM_TAPS 12                     // number of taps the shader will use
     
      float2 poisson[NUM_TAPS];               // containts poisson-distributed positions on the unit circle
      float2 maxCoC;                          // maximum circle of confusion (CoC) radius and diameter in pixels
      float radiusScale;                      // scale factor for minimum CoC size on low res. image
     
      poisson[ 0] = float2( 0.00,  0.00);
      poisson[ 1] = float2( 0.07, -0.45);
      poisson[ 2] = float2(-0.15, -0.33);
      poisson[ 3] = float2( 0.35, -0.32);
      poisson[ 4] = float2(-0.39, -0.26);
      poisson[ 5] = float2( 0.10, -0.23);
      poisson[ 6] = float2( 0.36, -0.12);
      poisson[ 7] = float2(-0.31, -0.01);
      poisson[ 8] = float2(-0.38,  0.22);
      poisson[ 9] = float2( 0.36,  0.23);
      poisson[10] = float2(-0.13,  0.29);
      poisson[11] = float2( 0.14,  0.41);
     
      maxCoC = float2(5.0, 10.0);
      radiusScale = 0.4;

      // Get depth of center tap and convert it into blur radius in pixels
      
      float discRadiusScene = abs(centerDepth * maxCoC.y - maxCoC.x);
      float discRadiusBlur = discRadiusScene * radiusScale; // radius on low res. image

      float4 sum = float4(0.0,0.0,0.0,0.0);

      for (int i = 0; i < NUM_TAPS; ++i)
      {
        // compute texture coordinates
        float2 coordScene = tex + (pixelSizeScene * poisson[i] * discRadiusScene);
        float2 coordBlur = tex + (pixelSizeBlur * poisson[i] * discRadiusBlur);
     
        // fetch taps and depth
        float4 tapScene = tex2D(scene, coordScene);

        float tmpDepth = tex2D(sceneDepth, coordScene).r;
#if USE_DSINTZ
      	tmpDepth = DeviceDepthToEyeLinear(tmpDepth, near_clip_distance, far_clip_distance );
#endif
        float4 tmpDepthVec = float4(0,0,tmpDepth,0);
        float tapDepth  = tmpDepthVec.z; 
 
        if(tmpDepth<dofParams.y)
        {   
            tapDepth  = (tmpDepth - dofParams.y) / (dofParams.y - dofParams.x);                    // scale depth value between near blur distance and focal distance to [-1, 0] range
        }else{
        tapDepth  = (tmpDepth - dofParams.y) / (dofParams.z - dofParams.y);                    // scale depth value between focal distance and far blur distance to [0, 1] range   
        tapDepth  = clamp(tapDepth, 0.0, dofParams.w);                                             // clamp the far blur to a maximum blurriness
      }
     
      tapDepth = 0.5f*tapDepth + 0.5f;                                                            // scale and bias into [0, 1] range


        float4 tapBlur = tex2D(blur, coordBlur);
       
        // mix low and high res. taps based on tap blurriness
        float blurAmount = abs(tapDepth * 2.0 - 1.0); // put blurriness into [0, 1]
        float4 tap = lerp(tapScene, tapBlur, blurAmount);
     
        // "smart" blur ignores taps that are closer than the center tap and in focus
        float factor = (tapDepth >= centerDepth) ? 1.0 : abs(tapDepth * 2.0 - 1.0);
     
        // accumulate
        sum.rgb += tap.rgb * factor;
        sum.a += factor;
      }
     
      color = (sum / sum.a);
    }


float4
colorLUT_fp(float4 pos : POSITION,
        in float2 ScreenTexCoord : TEXCOORD0,
        uniform sampler ScreenImage: register(s0),
        uniform sampler LUTImage: register(s1),
        uniform float dest_amount = 1
        ) : COLOR
{

	 float4 textureColor = tex2D(ScreenImage, ScreenTexCoord);
	 textureColor = clamp(textureColor, 0.001, 0.999);
	 float redColor = textureColor.r * 255.0;
	 float greenColor = textureColor.g * 255.0;
	 float blueColor = textureColor.b * 255;
	 
	 float3 points[8];
	
	 float ceilr = ceil((redColor)/4.0)*4;
	 float ceilg = ceil((greenColor)/4.0)*4;
	 float ceilb = ceil((blueColor)/4.0)*4;

	 float oneminusr = ceilr - redColor;
	 float oneminusg = ceilg - greenColor;
	 float oneminusb = ceilb - blueColor;
	 float baser = redColor - ceilr + 4;
	 float baseg = greenColor - ceilg + 4;
	 float baseb = blueColor - ceilb + 4;
	 
	 points[7] = float3(ceilr,ceilg,ceilb)/256.0;
	 points[6] = float3(ceilr - 4,ceilg,ceilb)/256.0;
	 points[5] = float3(ceilr,ceilg - 4,ceilb)/256.0;
	 points[4] = float3(ceilr - 4,ceilg - 4,ceilb)/256.0;
 	 points[3] = float3(ceilr,ceilg,ceilb - 4)/256.0;
	 points[2] = float3(ceilr - 4,ceilg,ceilb - 4)/256.0;
	 points[1] = float3(ceilr,ceilg - 4,ceilb - 4)/256.0;
	 points[0] = float3(ceilr - 4,ceilg - 4,ceilb - 4)/256.0;

for(int i=0;i<8;i=i+1){
		 float bColor = points[i].b * 63.0;
		 float2 quad1;
		 quad1.y = floor(floor(bColor) / 8.0);
		 quad1.x = floor(bColor) - (quad1.y * 8.0);
		 float2 quad2;
		 quad2.y = floor(ceil(bColor) / 8.0);
		 quad2.x = ceil(bColor) - (quad2.y * 8.0);
		 float2 texPos1;
		 texPos1.x = (quad1.x * 0.125) + 0.5/512.0 + ((0.125 - 1.0/512.0) * points[i].r);
		 texPos1.y = (quad1.y * 0.125) + 0.5/512.0 + ((0.125 - 1.0/512.0) * points[i].g);
		 float2 texPos2;
		 texPos2.x = (quad2.x * 0.125) + 0.5/512.0 + ((0.125 - 1.0/512.0) * points[i].r);
		 texPos2.y = (quad2.y * 0.125) + 0.5/512.0 + ((0.125 - 1.0/512.0) * points[i].g);
		 float4 newColor1 = tex2D(LUTImage, texPos1);
		 float4 newColor2 = tex2D(LUTImage, texPos2);

		 points[i].r = lerp(newColor1.r, newColor2.r, (bColor - floor(bColor)));
	 	 points[i].g = lerp(newColor1.g, newColor2.g, (bColor - floor(bColor)));
		 points[i].b = lerp(newColor1.b, newColor2.b, (bColor - floor(bColor)));
	}
	
	 float3 resrgb = (oneminusr * oneminusg * oneminusb * points[0].rgb
	 								+ baser * oneminusg * oneminusb * points[1].rgb
	 								+ oneminusr * baseg * oneminusb * points[2].rgb
	 								+ baser * baseg * oneminusb * points[3].rgb
	 								+ oneminusr * oneminusg * baseb * points[4].rgb
	 								+ baser * oneminusg * baseb * points[5].rgb
	 								+ oneminusr * baseg * baseb * points[6].rgb
	 								+ baser * baseg * baseb * points[7].rgb) / 64.0;

	 textureColor.rgb = resrgb * dest_amount + textureColor.rgb * ( 1 - dest_amount);
	 
   return textureColor;
}

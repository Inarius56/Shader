

float3 RgbToHsb(float3 rgbColour)
{
    float r = rgbColour.x;
    float g = rgbColour.y;
    float b = rgbColour.z;
    float vMin = min(r, min(g, b));
    float vMax = max(r, max(g, b));
    float delta = vMax - vMin;
    
    float brightness = vMax;
    float hue = 0;
    float saturation = 0;
    
    if(delta > 0.000001)
    {
        saturation = delta / vMax;
        float deltaR = (((vMax - r) / 6.0f) + (delta / 2.0f)) / delta;
        float deltaG = (((vMax - g) / 6.0f) + (delta / 2.0f)) / delta;
        float deltaB = (((vMax - b) / 6.0f) + (delta / 2.0f)) / delta;
        
        if(r == vMax)
            hue = deltaB - deltaG;
        else if(g == vMax)
            hue = 0.3333333f + deltaR - deltaB;
        else if(b == vMax)
            hue = 0.6666667f + deltaG - deltaR;
            
        if(hue < 0.0f)
            hue = hue + 1.0f;
        if(hue > 1.0f)
            hue = hue - 1.0f;
    }
    return float3(hue, saturation, brightness);
}

float3 HsbToRgb(float3 hsbColour)
{
    float hue = hsbColour.x;
    float saturation = hsbColour.y;
    float brightness = hsbColour.z;
    float r = 0.0f;
    float g = 0.0f;
    float b = 0.0f;
    if(hue > 1.0f)
    {
        hue = hue - floor(hue);
    }
    else if(hue < 0.0f)
    {
        hue = hue + ceil(abs(hue));
    }
    
    if(brightness == 0.0f)
    {
        r = g = b = 0.0f;
    }
    else if(saturation == 0.0f)
    {
        r = g = b = brightness;
    }
    else
    {
		    float hueDomain = hue * 6.0f;
		    if(hueDomain >= 6.0f)
		    {
		        hueDomain = 0.0f;
		    }
		    int domain = floor(hueDomain);
		    float f1 = brightness * (1 - saturation);
		    float f2 = brightness * (1 - saturation * (hueDomain - domain));
		    float f3 = brightness * (1 - saturation * (1 - (hueDomain - domain)));
		    
		    if(domain == 0)
		    {
		        // red domain; green ascends
				    r = brightness;
				    g = f3;
				    b = f1;
		    }
		    else if(domain == 1)
		    {
		        // yellow domain; red descends
				    r = f2;
				    g = brightness;
				    b = f1;
		    }
		    else if(domain == 2)
		    {
		        // green domain; blue ascends
				    r = f1;
				    g = brightness;
				    b = f3;
		    }
		    else if(domain == 3)
		    {
		        // cyan domain; green descends
				    r = f1;
				    g = f2;
				    b = brightness;
		    }
		    else if(domain == 4)
		    {
		        // blue domain; red ascends
				    r = f3;
				    g = f1;
				    b = brightness;
		    }
		    else if(domain == 5)
		    {
		        // magenta domain; blue descends
				    r = brightness;
				    g = f1;
				    b = f2;
		    }
    }
    return float3(r, g, b);
}

float4 ColourControl_fp(float4 pos : POSITION,
        in float2 texCoord : TEXCOORD0,
        uniform sampler sceneImage,
        uniform float4 params
        ) : COLOR
{
    float hue_control = params.x;
    float saturation_control = params.y;
    float brightness_control = params.z;
    float shineness_control = params.w;

    float4 originColour = tex2D(sceneImage, texCoord);
    float3 hsbColour = RgbToHsb(originColour.xyz);
    hsbColour.x = hsbColour.x * hue_control;
    hsbColour.y = hsbColour.y * saturation_control;
    float3 outputRgb = HsbToRgb(hsbColour);
    outputRgb = pow(outputRgb, 1.0 / brightness_control);
    float3 identity = float3(1, 1, 1);
    outputRgb = identity - pow((identity - outputRgb), shineness_control);
    return float4(outputRgb, 1.0f);
}

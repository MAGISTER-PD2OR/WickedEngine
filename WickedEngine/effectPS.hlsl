#include "effectHF_PS.hlsli"
#include "effectHF_PSVS.hlsli"
#include "globalsHF.hlsli"
#include "ditherHF.hlsli"

PixelOutputType main(PixelInputType PSIn)
{
	PixelOutputType Out = (PixelOutputType)0;

	float3 normal = normalize(PSIn.nor);
	float4 baseColor = diffuseColor;
	float4 spec=specular;

	float depth = PSIn.pos.z/PSIn.pos.w;
	float3 eyevector = normalize(PSIn.cam - PSIn.pos3D);

	//float2 ScreenCoord;
	//ScreenCoord.x = PSIn.pos2D.x / PSIn.pos2D.w / 2.0f + 0.5f;
	//ScreenCoord.y = -PSIn.pos2D.y / PSIn.pos2D.w / 2.0f + 0.5f;

	clip(ditherMask4(PSIn.pos.xy)-PSIn.dither);

	PSIn.tex+=movingTex;
	[branch]if(hasTex) {
		baseColor = xTextureTex.Sample(texSampler,PSIn.tex);
	}
	
	clip( baseColor.a - 0.1f );
		
	if(depth){

	

	//NORMALMAP
	float3 bumpColor=0;
	if(hasNor){
		float4 nortex = xTextureNor.Sample(texSampler,PSIn.tex+movingTex);
		if(nortex.a>0){
			float3x3 tangentFrame = compute_tangent_frame(normal, eyevector, -PSIn.tex.xy);
			bumpColor = 2.0f * nortex - 1.0f;
			//bumpColor.g*=-1;
			normal = normalize(mul(bumpColor, tangentFrame));
		}
	}

	
	//SPECULAR
	//if(hasRefNorTexSpe.w){
		spec = lerp(spec,xTextureSpe.Sample(texSampler, PSIn.tex).r,hasSpe);
	//}
	

	//ENVIROMENT MAP
	float4 envCol=0;
	{
		uint mip=0;
		float2 size;
		float mipLevels;
		enviroTex.GetDimensions(mip,size.x,size.y,mipLevels);

		float3 ref = normalize(reflect(-eyevector, normal));
		envCol = enviroTex.SampleLevel(texSampler,ref,(1-smoothstep(0,128,specular_power))*mipLevels);
		baseColor = lerp(baseColor,envCol,metallic*spec);
	}


	[branch]if(hasRef){
		//REFLECTION
		float2 RefTex;
			RefTex.x = PSIn.ReflectionMapSamplingPos.x/PSIn.ReflectionMapSamplingPos.w/2.0f + 0.5f;
			RefTex.y = -PSIn.ReflectionMapSamplingPos.y/PSIn.ReflectionMapSamplingPos.w/2.0f + 0.5f;
		float colorMat = 0;
		colorMat = xTextureMat.SampleLevel(texSampler,PSIn.tex,0);
		normal = normalize( lerp(normal,PSIn.nor,pow(colorMat.x,0.02f)) );
		float4 colorReflection = xTextureRef.SampleLevel(mapSampler,RefTex+normal.xz,0);
		baseColor.rgb=lerp(baseColor,colorReflection,colorMat);
	}
		



		

	}

	bool unshaded = shadeless||colorMask.a;
	float properties = unshaded ? RT_UNSHADED : toonshaded ? RT_TOON : 0.0f;

			
	Out.col = float4((baseColor.rgb+colorMask.rgb)*(1+emit)*PSIn.ao,1);
	Out.nor = float4((normal.xyz),properties);
	Out.vel = float4(PSIn.vel.xy*float2(-1,1),specular_power,spec.a);

	
	return Out;
}


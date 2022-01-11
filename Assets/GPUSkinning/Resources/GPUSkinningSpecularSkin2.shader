Shader "GPUSkinning/GPUSkinning_Specular_Skin2"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Gloss("Gloss",Range(8,20)) = 8
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True"}
        LOD 100

        Pass
        {
            Tags { "LightMode" = "UniversalForward" }
            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Assets/GPUSkinning/Resources/GPUSkinningInclude.hlsl"
            
            #pragma vertex vert
            #pragma fragment frag

            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x


            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT

            // Unity defined keywords
            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            #pragma multi_compile ROOTON_BLENDOFF ROOTON_BLENDON_CROSSFADEROOTON ROOTON_BLENDON_CROSSFADEROOTOFF ROOTOFF_BLENDOFF ROOTOFF_BLENDON_CROSSFADEROOTON ROOTOFF_BLENDON_CROSSFADEROOTOFF
            

            struct Attributes
            {
                float4 positionOS       : POSITION;
                float2 uv               : TEXCOORD0;
                float4 uv2              : TEXCOORD1;
                float4 uv3              : TEXCOORD2;
                float3 normal           : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float2 uv       : TEXCOORD0;
                float fogCoord  : TEXCOORD1;
                float4 vertex   : SV_POSITION;
                float3 N        : NORMAL;
                float3 W        : TEXCOORD2;

                // UNITY_VERTEX_INPUT_INSTANCE_ID
                // UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST;
            float _Gloss;
            CBUFFER_END

            Texture2D _MainTex;//贴图，相当于 TEXTURE2D(_MainTex); 
            SamplerState sampler_MainTex; //声明采样器，相当于 SAMPLER(sampler_MainTex); ;

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;

                UNITY_SETUP_INSTANCE_ID(input);
                // UNITY_TRANSFER_INSTANCE_ID(input, output);
                // UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                float4 vertex = skin2(input.positionOS,input.uv2,input.uv3);
                output.W = TransformObjectToWorld(vertex.xyz);
                output.N = TransformObjectToWorldNormal(input.normal);
                output.vertex = TransformObjectToHClip(vertex.xyz);
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                output.fogCoord = ComputeFogFactor(output.vertex.z);

                return output;
            }


            half4 frag(Varyings input) : SV_Target
            {
                // UNITY_SETUP_INSTANCE_ID(input);
                // UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                float3 N = normalize(input.N);
                Light l =  GetMainLight(TransformWorldToShadowCoord(input.W)); //GetMainLight();
                float3 L = normalize(l.direction);
                float3 V = normalize(_WorldSpaceCameraPos.xyz - input.W);
                float3 H = normalize(V+L);

                half2 uv = input.uv;
                half4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
                half3 color = texColor.rgb ;

                half spec = pow(saturate(dot(N,H)),_Gloss);
                half lambert = dot(N,L) * 0.5 + 0.5;
                color.rgb *= (spec + lambert);

                color *= l.shadowAttenuation;
                color = MixFog(color, input.fogCoord);

                return half4(color, texColor.a);
            }

            ENDHLSL
        }


        Pass
        {
            
            Tags { "LightMode" = "ShadowCaster" }
            ZWrite On
            ZTest LEqual

            HLSLPROGRAM
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile ROOTON_BLENDOFF ROOTON_BLENDON_CROSSFADEROOTON ROOTON_BLENDON_CROSSFADEROOTOFF ROOTOFF_BLENDOFF ROOTOFF_BLENDON_CROSSFADEROOTON ROOTOFF_BLENDON_CROSSFADEROOTOFF
            
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            #include "Assets/GPUSkinning/Resources/GPUSkinningInclude.hlsl"

            float3 _LightDirection;
            
            //和上一个pass一样，用于支持SRP Batch
            CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST;
            float _Gloss;
            CBUFFER_END

            Texture2D _MainTex;//贴图，相当于 TEXTURE2D(_MainTex); 
            SamplerState sampler_MainTex; //声明采样器，相当于 SAMPLER(sampler_MainTex); ;

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float2 texcoord     : TEXCOORD0;
                float4 uv2          : TEXCOORD1;
                float4 uv3          : TEXCOORD2;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float2 uv           : TEXCOORD0;
                float4 positionCS   : SV_POSITION;
            };

            // 获取裁剪空间下的阴影坐标
            float4 GetShadowPositionHClips(Attributes input)
            {
                float4 vertex = skin2(input.positionOS,input.uv2,input.uv3);

                float3 positionWS = TransformObjectToWorld(vertex.xyz);
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);

                float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));

                #if UNITY_REVERSED_Z
                    positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #else
                    positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #endif

                return positionCS;
            }
            
            Varyings ShadowPassVertex(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);

                // output.uv = TRANSFORM_TEX(input.texcoord, _MainTex);
                output.positionCS = GetShadowPositionHClips(input);

                return output;
            }
            
            
            half4 ShadowPassFragment(Varyings input): SV_TARGET
            {
                // Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_MainTex, sampler_MainTex)).a, _BaseColor, _Cutoff);
                return 0;
            }     
            ENDHLSL
        }
    }
}

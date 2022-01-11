Shader "GPUSkinning/GPUSkinning_Unlit_Skin2"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "IgnoreProjector" = "True" "RenderPipeline" = "UniversalPipeline"}
        LOD 100

        Pass
        {
            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Assets/GPUSkinning/Resources/GPUSkinningInclude.hlsl"
            
            #pragma vertex vert
            #pragma fragment frag

            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x

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
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float2 uv        : TEXCOORD0;
                float fogCoord  : TEXCOORD1;
                float4 vertex : SV_POSITION;

                // UNITY_VERTEX_INPUT_INSTANCE_ID
                // UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST;
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
                output.vertex = TransformObjectToHClip(vertex.xyz);
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                output.fogCoord = ComputeFogFactor(output.vertex.z);

                return output;
            }


            half4 frag(Varyings input) : SV_Target
            {
                // UNITY_SETUP_INSTANCE_ID(input);
                // UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                half2 uv = input.uv;
                half4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
                half3 color = texColor.rgb ;

                color = MixFog(color, input.fogCoord);

                return half4(color, texColor.a);
            }

            ENDHLSL
        }
    }
}

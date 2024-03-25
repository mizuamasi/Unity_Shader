Shader "Unlit/Ghost_unlit"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _RimColor ("RimColor", Color) = (1,1,1,1)
        _Alpha("Alpha", float) = 0.0
        _RimPower("RimPower", float) = 0.0
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" }
        Blend SrcAlpha OneMinusSrcAlpha
        Pass
        {
            ZWrite ON
            ColorMask 0
            Cull off
        }
        

        Pass
        {
            //Blend SrcAlpha OneMinusSrcAlpha
            //ZWrite On
            //AlphaTest Greater 0.5
            Cull Off
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
		        float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                 float3 world_pos : TEXCOORD1;
                    float3 normalDir : TEXCOORD2;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            half _Alpha;
            fixed4 _RimColor;
            half _RimPower;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                float4x4 modelMatrix = unity_ObjectToWorld;
                o.world_pos = mul(unity_ObjectToWorld, v.vertex).xyz;
                    //法線を取得
                o.normalDir = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);
                //カメラのベクトルを計算
                float3 viewDirection = normalize(_WorldSpaceCameraPos.xyz - i.world_pos.xyz);
                //法線とカメラのベクトルの内積を計算し、補間値を算出
                half rim = 1.0 - abs(dot(viewDirection, i.normalDir));
                fixed3 emission =  _RimColor.rgb * pow(rim, _RimPower) * _RimPower;
                col.rgb += emission;

                half alpha = 1 - (abs(dot(viewDirection, i.normalDir)));
                alpha = clamp(alpha * _Alpha, 0.1, 1.0);

                col = fixed4(col.rgb, alpha);
                return col;
            }
            ENDCG
        }
    }
}

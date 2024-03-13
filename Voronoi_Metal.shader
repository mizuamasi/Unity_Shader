Shader "Unlit/Voronoi_Metal"
{
    Properties
    {
        _Size("Blur Size",float) = 1
        _Scale("Scale",float) = 10.
        _Rate("Lit Rate",range(0,1)) = 0.5
        _Speed("Move Speed",float) = 0.
        [Space(30)]
        _Colorlerp("Color lerp",range(0,1) ) = 1.
        _Pow("pow" , float)= 3.
        [Space(30)]
        _UseCellColor("Use Cell Color",range(0,1)) = 0
        _CellColor("Cell Color R,G,B,ShiftHue",vector) = (1,1,1,0)
    }
    SubShader
    {
        Cull Off
        Tags {"Queue" = "Transparent" "RenderType" = "Transparent"}
        GrabPass{"_GrabTex0"}

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal:normal;
            };

            struct v2f
            {
                float4 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normal : normal;
            };

            sampler2D _GrabTex0;
            float _Size;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = ComputeGrabScreenPos(o.vertex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 col = i.normal;
                return float4(col,1.);
            }
            ENDCG
        }

        Tags {"Queue" = "Transparent" "RenderType" = "Transparent" "LightMode"="ForwardBase"}
        GrabPass{"_GrabTex"}
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float3 vcol : COLOR;
            };

             struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 uv : TEXCOORD0;
                float2 ouv :texcoord3;
                float3 pos : texcoord4;
                float3 normal : normal;
                half3 lightDir : TEXCOORD5;
                half3 viewDir : TEXCOORD6;
                float3 wpos : texcoord7;
                float3 color : color;
            };

            sampler2D _GrabTex;
            float4 _MainTex_ST;
            float _Scale;
            float4 _LightColor0;
            float _Rate;
            float _Speed;
            float _Pow;
            float _Colorlerp;

            float _UseCellColor;
            float4 _CellColor;

            float3 _MainTex;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                //o.uv = v.uv;
                o.uv = ComputeGrabScreenPos(o.vertex);
                o.ouv = v.uv;
                o.pos = v.vertex.xyz;
                o.normal = v.normal;
                o.wpos = mul(unity_ObjectToWorld, v.vertex);

                TANGENT_SPACE_ROTATION;
                o.lightDir = mul(rotation, ObjSpaceLightDir(v.vertex));
                o.viewDir = mul(rotation, ObjSpaceViewDir(v.vertex));
                o.color = v.vcol;
                return o;
            }

            float3 random33(float3 st)
            {
                st = float3(dot(st, float3(127.1, 311.7,811.5)),
                            dot(st, float3(269.5, 183.3,211.91)),
                            dot(st, float3(511.3, 631.19,431.81))
                            );
                return -1.0 + 2.0 * frac(sin(st) * 43758.5453123);
            }

            struct Cells{
                float3 Opos;
                float3 Normal;
                float3 cellID;
                float dist;
            };

            Cells celler3D_returnPos(float3 i,float3 sepc)
            {
                float3 sep = i * sepc;
                float3 fp = floor(sep);
                float3 sp = frac(sep);
                float dist = 5.;
                float3 mp = 0.;
                float3 opos = 0.;
                Cells cell;

                [unroll]
                for (int z = -1; z <= 1; z++)
                {
                    [unroll]
                    for (int y = -1; y <= 1; y++)
                    {
                        [unroll]
                        for (int x = -1; x <= 1; x++)
                        {
                            float3 neighbor = float3(x, y ,z);
                            float3 rpos = float3(random33(fp+neighbor));
                            float3 pos = sin( (rpos*6. +_Time.y/2. * _Speed) )* 0.5 + 0.5;
                            float divs = length(neighbor + pos - sp);
                            if(dist > divs)
                            {
                                mp = pos;
                                dist = divs;
                                opos = neighbor + fp + rpos;
                               // opos = neighbor + pos - sp;
                                
                                cell.Opos = neighbor + fp + rpos;
                                cell.Normal = (neighbor + pos - sp);
                                cell.dist = divs;
                                cell.cellID = pos;
                            }
                        }
                    }
                }
                //return float4(opos,dist);
                return cell;
            }

            float3 rgb2hsv(float3 c)
            {
                float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
                float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
                float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));

                float d = q.x - min(q.w, q.y);
                float e = 1.0e-10;
                return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
            }

            float3 hsv2rgb(float3 c)
            {
                float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
                float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
                return c.z * lerp(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
            }


            fixed4 frag (v2f i) : SV_Target
            {
                float2 uv = i.uv.xy/i.uv.w;
                float scale = _Scale;
                float2 ouv = i.ouv;
                //float4 opos = celler3D_returnPos(i.pos,scale);
                //Cells cell = celler3D_returnPos(i.color,scale);
                Cells cell = celler3D_returnPos(i.pos,scale);
                cell.Opos /= scale;
                float4 grabUV = ComputeGrabScreenPos(UnityObjectToClipPos(float4(cell.Opos,1.)));
                float2 screenuv = grabUV.xy / grabUV.w;
                fixed4 col = tex2D(_GrabTex, screenuv) ;
               // col = lerp(tex2D(_GrabTex, uv),col,1.- pow(cell.dist,_Pow) * _Colorlerp );
                //col = 1.;
                float3 normal = col.rgb;
                float3 ld = normalize(i.lightDir);
                float3 vd = normalize(i.viewDir);
                float3 halfDir = normalize(ld + vd);

                // //float 
                // float3 dir = cell.Normal;
                // //i.normal = normalize(i.normal  );
                // i.normal = dir;
                // //i.normal.x += step(opos.z,.5);
                // float4 diff = saturate(dot(i.normal, ld)) * _LightColor0;
                // diff = lerp(diff,1.,_Rate);
                // float3 sp = pow(max(0, dot(i.normal, halfDir)), 10. * 1.0) * col.rgb;

                // float3 cellCol = cell.cellID;

                // cellCol = rgb2hsv(cellCol);
                // cellCol = float3(_CellColor.w + cellCol.r,1.,1.);
                // cellCol = hsv2rgb(cellCol);
                // cellCol *= _CellColor.rgb;

                // cellCol = lerp(1,cellCol,_UseCellColor);
                // col.rgb = diff * col.rgb + sp * col.rgb;
                // col.rgb *= cellCol;

                float3 worldViewDir = normalize(_WorldSpaceCameraPos - i.wpos);
                float3 reflDir = reflect(-worldViewDir, normal);

                // unity_SpecCube0はUnityで定義されているキューブマップ
                float4 refColor = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflDir, 0);

                // Reflection ProbeがHDR設定だった時に必要な処理
                refColor.rgb = DecodeHDR(refColor, unity_SpecCube0_HDR);

                float3 wld = _WorldSpaceLightPos0.xyz;
                float3 whalfDir = normalize(wld + worldViewDir);
                float4 diff = saturate(dot(normal, wld)) * _LightColor0;
                diff = lerp(diff,1.,_Rate);
                float sp = pow(max(0, dot(normal, whalfDir)), 10. * 1.0);
                col.xyz = sp * refColor.xyz + diff * refColor.xyz + sin(cell.Opos.xyz * 100.)/46.;
                col.rgb *= _CellColor.rgb;
                col.a = 1.;

                //col.xyz = i.color;
                return col;
            }
            ENDCG
        }
    }
}

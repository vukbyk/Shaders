// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Custom/InteriorMapping - 2D Atlas Advanced"
{
	Properties
	{
		_RoomTex("Room Atlas RGB (A - back wall fraction)", 2D) = "white" {}
		_DecorationTex(" Decoration Texture", 2D) = "white" {}
		_Rooms("Room Atlas Rows&Cols (XY)", Vector) = (1,1,0,0)
		_IndoorLights("Lights", Range(0, 1)) = 0
		_RoomIndex ("Room Index", Range(0, 3)) = 1
	}
	SubShader
	{
		Tags
		{ 
			"RenderType" = "Opaque"
			"Queue" = "Transparent"
			"PreviewType" = "Plane"
		}
		LOD 100


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
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 tangentViewDir : TEXCOORD1;
			};

			sampler2D _RoomTex;
			sampler2D _DecorationTex;
			float4 _RoomTex_ST;
			float2 _Rooms;
			float _IndoorLights;
			int _RoomIndex;

			v2f vert(appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _RoomTex);

				// get tangent space camera vector
				float4 objCam = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1.0));
				float3 viewDir = v.vertex.xyz - objCam.xyz;
				float tangentSign = v.tangent.w * unity_WorldTransformParams.w;
				float3 bitangent = cross(v.normal.xyz, v.tangent.xyz) * tangentSign;
				o.tangentViewDir = float3(
					dot(viewDir, v.tangent.xyz),
					dot(viewDir, bitangent),
					dot(viewDir, v.normal)
					);
				o.tangentViewDir *= _RoomTex_ST.xyx;
				return o;
			}

			// psuedo random
			float2 rand2(float co)
			{
				return frac(sin(co * float2(12.9898,78.233)) * 43758.5453);
			}

			fixed4 frag(v2f i) : SV_Target
			{
				// room uvs
				float2 roomUV = frac(i.uv); //definitvno ima veze sa tilingom
				float2 roomIndexUV = floor(i.uv);

				// randomize the room
				// float2 n = floor(rand2(roomIndexUV.x + roomIndexUV.y * (roomIndexUV.x + 1)) * _Rooms.xy);
				// roomIndexUV += n;

				roomIndexUV = float2(_RoomIndex,0);

				// get room depth from room atlas alpha
				fixed farFrac = tex2D(_RoomTex, (roomIndexUV /*+.01*/+ 0.5) / _Rooms).a;
				float depthScale = 1.0 / (1.0 - farFrac) - 1.0;

				// raytrace box from view dir
				float3 pos = float3(roomUV * 2 - 1, -1);
				// pos.xy *= 1.05;
				i.tangentViewDir.z *= -depthScale;
				float3 id = 1.0 / i.tangentViewDir;
				float3 k = abs(id) - pos * id;
				float kMin = min(min(k.x, k.y), k.z);
				pos += kMin * i.tangentViewDir;

				// 0.0 - 1.0 room depth
				float interp = pos.z * 0.5 + 0.5;

				// account for perspective in "room" textures
				// assumes camera with an fov of 53.13 degrees (atan(0.5))
				float realZ = saturate(interp) / depthScale + 1;
				interp = 1.0 - (1.0 / realZ);
				interp *= depthScale + 1.0;

				// iterpolate from wall back to near wall
				float2 interiorUV = pos.xy * lerp(1.0, farFrac, interp);
				interiorUV = interiorUV * 0.5 + 0.5;


				// DECORATION raytrace box from view dir
				float3 posDec = float3(roomUV * 2 - 1, -1);

				// posDec.xy *= 1.05;

				posDec += (abs(id) - posDec * id).z * i.tangentViewDir/2;
				posDec=pos;

				// 0.0 - 1.0 room depth
				float interpDec = posDec.z * 0.5 + 0.5;

				// account for perspective in "room" textures
				// assumes camera with an fov of 53.13 degrees (atan(0.5))
				float realZDec = saturate(interpDec) / depthScale + 1;
				interpDec = 1.0 - (1.0 / realZ);
				interpDec *= depthScale + 1.0;

				float2 decorationUV = posDec.xy * lerp(1.0, farFrac, 0);
				decorationUV = decorationUV * 0.5 + 0.5;

				// sample room atlas texture
				fixed4 roomDark = tex2D(_RoomTex, (float2(roomIndexUV.x,0) + interiorUV.xy) / _Rooms);
				fixed4 roomLight = tex2D(_RoomTex, (float2(roomIndexUV.x,1) + interiorUV.xy) / _Rooms);
				fixed4 decorationTex = tex2D(_DecorationTex ,  decorationUV.xy);
				fixed4 roomEmpty = lerp(roomDark, roomLight, _IndoorLights /* * ((sin(_Time.w*10)+1)/2)*/ );
				fixed4 room =  decorationTex*(decorationTex.a)-roomEmpty*(decorationTex.a-1);
				return fixed4(roomEmpty.rgb, 1.0);
			}
			ENDCG
		}
	}
}
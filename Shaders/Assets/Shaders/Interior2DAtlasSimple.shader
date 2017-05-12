Shader "Custom/InteriorMapping - 2D Atlas Simple"
{
	Properties
	{
		_RoomTex("Room Atlas RGB (A - back wall fraction)", 2D) = "white" {}
		_DepthScale("Depth Scale", Range(0, 2)) = .5
		_BackWallRatio("Depth wall ratio", Range(0, 1)) = .5
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
			float4 _RoomTex_ST;
			float _DepthScale;
			float _BackWallRatio;

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
				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				// room uvs
				float2 roomUV = frac(i.uv); //mozda zbog tajlinga

				// get room depth from room atlas alpha
				float farFrac = _BackWallRatio;//tex2D(_RoomTex, (roomIndexUV /*+.01*/+ 0.5)).a; // koji deo teksture je zadnji zid
				float depthScale = _DepthScale;//(1.0 - farFrac) - 1.0;// izduzuje neravnomerno i <1 rasteze ka nama

				// raytrace box from view dir - glavna magija pocinje
				float3 pos = float3(roomUV * 2 - 1, -1);// z mrda svih 5 textura napred nazad. Moze da posluzi za dodatke?
				i.tangentViewDir.z *= -depthScale;
				float3 id = 1.0 / i.tangentViewDir;
				float3 k = abs(id) - pos * id;
				float kMin = min(min(k.x, k.y), k.z);//Ovde gleda na koje zidove po osi trenutno gleda
				pos += kMin * i.tangentViewDir;//Bez kMin dobro radi samo zidu pozadini

				// 0.0 - 1.0 room depth
				float interp = pos.z * 0.5 + 0.5; // posle plus znaka mrda napred nazad texture na zidovimasa strane i podu

				// account for perspective in "room" textures
				// assumes camera with an fov of 53.13 degrees (atan(0.5))

				interp = (1.0 - (1.0 / (clamp( interp , 0.0, 1.0) / depthScale + 1))) * (depthScale + 1.0);

				// iterpolate from wall back to near wall
				float2 interiorUV = pos.xy * lerp(1.0, farFrac, interp) * 0.5 + 0.5;
				fixed4 room = tex2D(_RoomTex, interiorUV.xy);
				return fixed4(room.rgb, 1.0);
			}
			ENDCG
		}
	}
}
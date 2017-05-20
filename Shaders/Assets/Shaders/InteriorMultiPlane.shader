// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'
 
// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
 
 
Shader "Custom/InteriorMultiPlane" 
  {
    Properties {
        _wallFrequencies ("Wall freq", Vector) = (1,1,1)
       
        _ceilingTexture  ("Ceiling texture", 2D) = "white"
        _floorTexture ("Floor texture", 2D) = "red"
        _wallXYTexture ("wallXY texture", 2D) = "black"
        _wallZYTexture ("wallZY texture", 2D) = "green"
       
    }
    SubShader {
         Pass {
       
             CGPROGRAM
       
            #pragma target 3.0
            #pragma exclude_renderers xbox360
            #pragma vertex vert
            #pragma fragment frag
           
            #include "UnityCG.cginc"
           
            struct v2f {
           
                float4 pos:    SV_POSITION;
                float2 uv:TEXCOORD0;
                float3 positionCopy:TEXCOORD1;
                float4 lighting:TEXCOORD2;
            };
 
            float3 _wallFrequencies;
            float _lightThreshold;
           
            v2f vert (appdata_tan v)
            {
                v2f o;
               
                o.pos = UnityObjectToClipPos (v.vertex) ;
                o.uv = v.texcoord /** float2(_uvMultiplier.xy)*/;
               
                //o.positionCopy = mul(unity_ObjectToWorld, v.vertex);
                o.positionCopy = float3(v.vertex.xyz);
                                           
                // Calculate lighting on the exterior of the building with a hard-coded directed light.
                float lightStrength = dot(v.normal, float3(0.5, 0.33166, 0.8));
                o.lighting = saturate(lightStrength) * float4(1, 1, 0.9, 1) * (1-_lightThreshold);
               
                // Add some ambient lighting.
                o.lighting += float4(0.3, 0.3, 0.4, 1);
               
                return o;
            }
 
           
            sampler2D _ceilingTexture;
            sampler2D _floorTexture;
            sampler2D _wallXYTexture;
            sampler2D _wallZYTexture;
           
            half4 frag (v2f i) : COLOR
            {
                float3 camObjPos = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1.0)).xyz;
                float3 direction = i.positionCopy - camObjPos;
       
                //multiply by 0.999 to prevent last wall from beeing displayed. Fix this?
                float3 corner = floor(i.positionCopy *_wallFrequencies * 0.999);
                float3 walls = corner + step(float3(0, 0, 0), direction);
                walls /= _wallFrequencies;
                corner /= _wallFrequencies;
               
                float3 rayFractions = (float3(walls.x, walls.y,walls.z) - camObjPos) / direction;
                float2 intersectionXY = (camObjPos + rayFractions.z * direction).xy;
                float2 intersectionXZ = (camObjPos + rayFractions.y * direction).xz;
                float2 intersectionZY = (camObjPos + rayFractions.x * direction).zy;
               
                float4 ceilingColour = tex2D(_ceilingTexture, intersectionXZ);
                float4 floorColour = tex2D(_floorTexture, intersectionXZ);
                float4 verticalColour = lerp(floorColour, ceilingColour, step(0, direction.y));
                           
                //put the intersection into room space, so that it comes within [0, 1]
                intersectionXY = (intersectionXY - corner.xy) * _wallFrequencies.xy;
               
                //use the texture coordinate to read from the correct texture in the atlas
                float4 wallXYColour = 0.8 * tex2D(_wallXYTexture, intersectionXY);
                               
                //put the intersection into room space, so that it comes within [0, 1]
                intersectionZY = (intersectionZY - corner.zy) * _wallFrequencies.zy;
               
                //use the texture coordinate to read from the correct texture in the atlas
                float4 wallZYColour = 0.8 * tex2D(_wallZYTexture, intersectionZY);
       
                //decide wich wall is closest to camera
                float xVSz = step(rayFractions.x, rayFractions.z);
                float4 interiorColour = lerp(wallXYColour, wallZYColour, xVSz);
                float rayFraction_xVSz = lerp(rayFractions.z, rayFractions.x, xVSz);
               
                float xzVSy = step(rayFraction_xVSz, rayFractions.y);
                //floor/ceiling or walls
                interiorColour = lerp(verticalColour, interiorColour, xzVSy);
               
                //blend colors
                float4 wallColour = /*diffuseColour * */i.lighting;
                float4 windowColour = /*cubeColour + */interiorColour;
               
                return interiorColour* i.lighting;
            }
 
            ENDCG  
        }
    }
}
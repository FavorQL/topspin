#include <metal_stdlib>
using namespace metal;

// Keep these two structs byte-compatible with Vertex / Uniforms in Types.swift.
struct Vertex {
    float3 position;
    float3 normal;
};

struct Uniforms {
    float4x4 modelMatrix;
    float4x4 viewProjection;
    float4 baseColor;
    float4 lightDirection;
    float4 cameraPosition;
};

struct VertexOut {
    float4 position [[position]];
    float3 normal;
    float3 worldPosition;
};

vertex VertexOut vertex_main(uint vertexID [[vertex_id]],
                             device const Vertex *vertices [[buffer(0)]],
                             constant Uniforms &uniforms [[buffer(1)]])
{
    VertexOut out;
    float4 localPosition = float4(vertices[vertexID].position, 1.0);
    float4 worldPosition = uniforms.modelMatrix * localPosition;

    out.position = uniforms.viewProjection * worldPosition;
    out.normal = normalize((uniforms.modelMatrix * float4(vertices[vertexID].normal, 0.0)).xyz);
    out.worldPosition = worldPosition.xyz;
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant Uniforms &uniforms [[buffer(1)]])
{
    float3 normal = normalize(in.normal);
    float3 toLight = normalize(-uniforms.lightDirection.xyz);
    float3 toEye = normalize(uniforms.cameraPosition.xyz - in.worldPosition);

    // Lambert diffuse with a floor of ambient so unlit faces never go fully black.
    float diffuse = max(dot(normal, toLight), 0.0);

    // Blinn-Phong highlight keeps the flat-shaded primitives from looking dead.
    float3 halfVector = normalize(toLight + toEye);
    float specular = pow(max(dot(normal, halfVector), 0.0), 32.0) * 0.22;

    // Cheap rim light to separate silhouettes from the sky.
    float rim = pow(1.0 - max(dot(normal, toEye), 0.0), 3.0) * 0.20;

    float3 albedo = uniforms.baseColor.rgb;
    float3 color = albedo * 0.38
                 + albedo * diffuse * 0.85
                 + float3(specular)
                 + albedo * rim;

    return float4(color, uniforms.baseColor.a);
}

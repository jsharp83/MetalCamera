#include <metal_stdlib>
using namespace metal;

struct Vertex {
    float4 position [[position]];
    float2 text_coord;
};

struct TwoInputVertex
{
    float4 position [[position]];
    float2 textureCoordinate [[user(texturecoord)]];
    float2 textureCoordinate2 [[user(texturecoord2)]];
};

struct Uniforms {
    float4x4 scaleMatrix;
};

vertex Vertex vertex_render_target(constant Vertex *vertexes [[ buffer(0) ]],
                                   constant Uniforms &uniforms [[ buffer(1) ]],
                                   uint vid [[vertex_id]])
{
    Vertex out = vertexes[vid];
    out.position = uniforms.scaleMatrix * out.position;// * in.position;
    return out;
};

vertex TwoInputVertex two_vertex_render_target(const device packed_float2 *position [[buffer(0)]],
                                               const device packed_float2 *texturecoord [[buffer(1)]],
                                               const device packed_float2 *texturecoord2 [[buffer(2)]],
                                               uint vid [[vertex_id]]) {
    TwoInputVertex outputVertices;
    outputVertices.position = float4(position[vid], 0, 1.0);
    outputVertices.textureCoordinate = texturecoord[vid];
    outputVertices.textureCoordinate2 = texturecoord2[vid];
    return outputVertices;
};


fragment float4 fragment_render_target(Vertex vertex_data [[ stage_in ]],
                                       texture2d<float> tex2d [[ texture(0) ]])
{
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    float4 color = float4(tex2d.sample(textureSampler, vertex_data.text_coord));
    return color;
};

fragment float4 gray_fragment_render_target(Vertex vertex_data [[ stage_in ]],
                                            texture2d<float> tex2d [[ texture(0) ]])
{
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    float4 color = float4(tex2d.sample(textureSampler, vertex_data.text_coord));
    float gray = (color[0] + color[1] + color[2])/3;
    return float4(gray, gray, gray, 1.0);
};

typedef struct
{
    float mixturePercent;
} AlphaBlendUniform;

fragment half4 alphaBlendFragment(TwoInputVertex fragmentInput [[stage_in]],
                                     texture2d<half> inputTexture [[texture(0)]],
                                     texture2d<half> inputTexture2 [[texture(1)]],
                                     constant AlphaBlendUniform& uniform [[ buffer(1) ]])
{
    constexpr sampler quadSampler;
    half4 textureColor = inputTexture.sample(quadSampler, fragmentInput.textureCoordinate);
    constexpr sampler quadSampler2;
    half4 textureColor2 = inputTexture2.sample(quadSampler, fragmentInput.textureCoordinate2);

    return half4(mix(textureColor.rgb, textureColor2.rgb, textureColor2.a * half(uniform.mixturePercent)), textureColor.a);
}

typedef struct
{
     int32_t classNum;
} SegmentationValue;

typedef struct
{
    int32_t targetClass;
    int32_t width;
    int32_t height;
} SegmentationUniform;

fragment float4 segmentation_render_target(Vertex vertex_data [[ stage_in ]],
                                           constant SegmentationValue *segmentation [[ buffer(0) ]],
                                           constant SegmentationUniform& uniform [[ buffer(1) ]])

{
    int index = int(vertex_data.position.x) + int(vertex_data.position.y) * uniform.width;
    if(segmentation[index].classNum == uniform.targetClass) {
        return float4(1.0, 0, 0, 1.0);
    }

    return float4(0,0,0,1.0);
};

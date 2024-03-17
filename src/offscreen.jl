
mutable struct OffscreenCanvas <: AbstractWGPUCanvas
    title::String
    size::Tuple
    canvasContext::Any
    needDraw::Any
    requestDrawTimerRunning::Any
    changingPixelRatio::Any
    isMinimized::Bool
    device::Any
    drawFunc::Any
end

function getWindowId(canvas::OffscreenCanvas)
    return nothing
end

function present(canvas::OffscreenCanvas, textureView)
    return nothing
end

function getPreferredFormat(canvas::OffscreenCanvas)
    return WGPUCore.getEnum(WGPUTextureFormat, "RGBA8Unorm")
end

function defaultCanvas(::Type{OffscreenCanvas}, size::Tuple{Int, Int})
    title = "Offscreen Window"
    canvas = OffscreenCanvas(
        title,
        size,
        nothing,
        false,
        nothing,
        false,
        false,
        device,
        nothing,
    )

    return canvas
end


mutable struct GPUCanvasContextOffscreen <: AbstractWGPUCanvasContext
    canvasRef::Ref{OffscreenCanvas}
    internal::Any
    device::Any
    currentTexture::Any
    currentTextureView::Any
    format::Union{Nothing, WGPUTextureFormat}
    usage::WGPUTextureUsage
    compositingAlphaMode::Any
    size::Any
    physicalSize::Any
    pixelRatio::Any
    logicalSize::Any
    surfaceSize::Any
end

function getContext(gpuCanvas::OffscreenCanvas)
    if gpuCanvas.canvasContext == nothing
        gpuCanvas.canvasContext = GPUCanvasContextOffscreen(
            Ref(gpuCanvas),             # canvasRef::Ref{OffscreenCanvas}
            nothing,                    # internal::Any
            gpuCanvas.device,           # device::Any
            nothing,                    # currentTexture::Any
            nothing,                    # currentTextureView::Any
            nothing,                    # format::WGPUTextureFormat
            WGPUCore.getEnum(WGPUTextureUsage, ["RenderAttachment"]), # usage::WGPUTextureUsage
            nothing,                    # compositingAlphaMode::Any
            nothing,                    # size::Any
            (500, 500),                 # physicalSize::Any
            (1, 1),                     # pixelRatio::Any
            nothing,                    # logicalSize::Any
            (-1, -1)                    # surfaceSize::Any            
        )
    end
    return gpuCanvas.canvasContext
end


function configure(
    canvasContext::GPUCanvasContextOffscreen;
    device,
    format,
    usage,
    viewFormats,
    compositingAlphaMode,
    size,
)
    unconfig(canvasContext)
    canvasContext.device = device
    canvasContext.format = format
    canvasContext.usage = usage
    canvasContext.compositingAlphaMode = compositingAlphaMode
    canvasContext.size = size
end

function unconfigure(canvasContext::GPUCanvasContextOffscreen)
    canvasContext.device = nothing
    canvasContext.format = nothing
    canvasContext.usage = nothing
    canvasContext.compositingAlphaMode = nothing
    canvasContext.size = nothing
end

function determineSize(cntxt::GPUCanvasContextOffscreen)
    psize = cntxt.physicalSize
    cntxt.logicalSize = psize ./ cntxt.pixelRatio
end

function getPreferredFormat(canvasContext::GPUCanvasContextOffscreen)
    canvas = canvasCntxt.canvasRef[]
    if canvas !== nothing
        return getPreferredFormat(canvas)
    end
    return WGPUCore.getEnum(WGPUTextureFormat, "RGBA8Unorm")
end

function getCurrentTexture(cntxt::GPUCanvasContextOffscreen)
    createNewTextureMaybe(cntxt)
    return cntxt.currentTextureView
end

function present(cntxt::GPUCanvasContextOffscreen)
    if cntxt.currentTexture != nothing && cntxt.currentTexture.internal[] != C_NULL
        canvas = cntxt.canvasRef[]
        return present(canvas, cntxt.currentTextureView)
    end
end

function createNewTextureMaybe(canvasCntxt::GPUCanvasContextOffscreen)
    canvas = canvasCntxt.canvasRef[]
    pSize = canvasCntxt.physicalSize
    if pSize == canvasCntxt.surfaceSize
        return
    end
    canvasCntxt.surfaceSize = pSize
    canvasCntxt.currentTexture = WGPUCore.createTexture(
        canvasCntxt.device,
        "textureOffline",
        (pSize..., 1),
        1,
        1,
        WGPUCore.getEnum(WGPUTextureDimension, "2D"),
        canvasCntxt.format,
        canvasCntxt.usage | WGPUCore.getEnum(WGPUTextureUsage, "CopySrc"),
    )
    canvasCntxt.currentTextureView = WGPUCore.createView(canvasCntxt.currentTexture)
end

function destroyWindow(canvas::OffscreenCanvas)
    return nothing
end


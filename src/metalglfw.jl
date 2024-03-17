using GLFW_jll
using GLFW

using WGPUCore

using Pkg.Artifacts

artifact_toml = joinpath(@__DIR__, "..", "Artifacts.toml")

cocoa_hash = artifact_hash("Cocoa", artifact_toml)

cocoalibpath = artifact_path(cocoa_hash)

function GetCocoaWindow(window::GLFW.Window)
	ccall((:glfwGetCocoaWindow, libglfw), Ptr{Nothing}, (Ptr{GLFW.Window},), window.handle)
end

const libcocoa = joinpath(cocoalibpath, "cocoa")

function getMetalLayer()
    ccall((:getMetalLayer, libcocoa), Ptr{UInt8}, ())
end

function wantLayer(nswindow)
    ccall((:wantLayer, libcocoa), Cvoid, (Ptr{Nothing},), nswindow)
end

function setMetalLayer(nswindow, metalLayer)
    ccall(
        (:setMetalLayer, libcocoa),
        Cvoid,
        (Ptr{Nothing}, Ptr{Nothing}),
        nswindow,
        metalLayer,
    )
end

mutable struct GLFWMacCanvas <: AbstractWGPUCanvas
    title::String
    size::Tuple
    windowRef::Any # This has to be platform specific may be
    surfaceRef::Any
    surfaceDescriptorRef::Any
    metalSurfaceRef::Any
    nsWindow::Any
    metalLayer::Any
    needDraw::Any
    requestDrawTimerRunning::Any
    changingPixelRatio::Any
    isMinimized::Bool
    device::Union{WGPUCore.GPUDevice, Nothing}
    context::Any
    drawFunc::Any
    mouseState::Any
end


function defaultCanvas(::Type{GLFWMacCanvas}, size::Tuple{Int, Int})
    windowRef = Ref{GLFW.Window}()
    surfaceRef = Ref{WGPUSurface}()
    title = "GLFW WGPU Window"
    GLFW.Init()
    GLFW.WindowHint(GLFW.CLIENT_API, GLFW.NO_API)
    windowRef[] = window = GLFW.CreateWindow(size..., title)
    nswindow = GetCocoaWindow(windowRef[]) |> Ref
    metalLayer = getMetalLayer() |> Ref
    wantLayer(nswindow[])
    setMetalLayer(nswindow[], metalLayer[])
    metalSurfaceRef =
        cStruct(
            WGPUSurfaceDescriptorFromMetalLayer;
            chain = cStruct(
                WGPUChainedStruct;
                next = C_NULL,
                sType = WGPUSType_SurfaceDescriptorFromMetalLayer,
            ) |> concrete,
            layer = metalLayer[],
        )
    surfaceDescriptorRef = cStruct(
        WGPUSurfaceDescriptor;
        label = C_NULL,
        nextInChain = metalSurfaceRef |> ptr,
    )
    instance = WGPUCore.getWGPUInstance()
    surfaceRef[] =
        wgpuInstanceCreateSurface(instance[], surfaceDescriptorRef |> ptr)
    title = "GLFW Window"
    canvas = GLFWMacCanvas(
        title,
        size,
        windowRef,
        surfaceRef,
        surfaceDescriptorRef,
        metalSurfaceRef,
        nswindow,
        metalLayer,
        false,
        nothing,
        false,
        false,
        nothing,
        nothing,
        nothing,
        initMouse(MouseState),
    )
    WGPUCore.getContext(canvas)
    setJoystickCallback(canvas)
    setMonitorCallback(canvas)
    setWindowCloseCallback(canvas)
    setWindowPosCallback(canvas)
    setWindowSizeCallback(canvas)
    setWindowFocusCallback(canvas)
    setWindowIconifyCallback(canvas)
    setWindowMaximizeCallback(canvas)
    setKeyCallback(canvas)
    setCharModsCallback(canvas)
    setMouseButtonCallback(canvas)
    setScrollCallback(canvas)
    setCursorPosCallback(canvas)
    setDropCallback(canvas)

    return canvas
end

mutable struct GPUCanvasContext <: AbstractWGPUCanvasContext
    canvasRef::Ref{GLFWMacCanvas}
    surfaceSize::Any
    surfaceId::Any
    internal::Any
    currentTexture::Any
    device::Any
    format::WGPUTextureFormat
    usage::WGPUTextureUsage
    compositingAlphaMode::Any
    size::Any
    physicalSize::Any
    pixelRatio::Any
    logicalSize::Any
end

            # canvasRef = Ref(gpuCanvas),
            # surfaceSize = (-1, -1),
            # surfaceId = gpuCanvas.surfaceRef[],
            # internal = nothing,
            # device = gpuCanvas.device,
            # physicalSize = gpuCanvas.size,
            # compositingAlphaMode = nothing,


function WGPUCore.getContext(gpuCanvas::GLFWMacCanvas)
    if gpuCanvas.context == nothing
        context = GPUCanvasContext(
			Ref(gpuCanvas),		    	# canvasRef::Ref{GLFWMacCanvas}
			(-1, -1),			    	# surfaceSize::Any
			gpuCanvas.surfaceRef[],	    # surfaceId::Any
			nothing,				    # internal::Any
			nothing,				    # currentTexture::Any
			gpuCanvas.device,		    # device::Any
			WGPUTextureFormat(0),		# format::WGPUTextureFormat
			WGPUTextureUsage_RenderAttachment,		# usage::WGPUTextureUsage
			WGPUCompositeAlphaMode_Premultiplied,				    # compositingAlphaMode::Any
			nothing,				    # size::Any
			gpuCanvas.size,			    # physicalSize::Any
			nothing,	    			# pixelRatio::Any
			nothing,				    # logicalSize::Any
        )
        gpuCanvas.context = context
    else
        return gpuCanvas.context
    end
end


function WGPUCore.configure(
    canvasContext::GPUCanvasContext;
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

function WGPUCore.unconfigure(canvasContext::GPUCanvasContext)
    canvasContext.device = nothing
    canvasContext.format = nothing
    canvasContext.usage = nothing
    canvasContext.compositingAlphaMode = nothing
    canvasContext.size = nothing
end

function WGPUCore.determineSize(cntxt::GPUCanvasContext)
    pixelRatio = GLFW.GetWindowContentScale(cntxt.canvasRef[].windowRef[]) |> first
    psize = GLFW.GetFramebufferSize(cntxt.canvasRef[].windowRef[])
    cntxt.pixelRatio = pixelRatio
    cntxt.physicalSize = (psize.width, psize.height)
    cntxt.logicalSize = (psize.width, psize.height) ./ pixelRatio
    # TODO skipping event handlers for now
end


function WGPUCore.getPreferredFormat(canvas::GLFWMacCanvas)
    return WGPUCore.getEnum(WGPUTextureFormat, "BGRA8Unorm")
end

function WGPUCore.getPreferredFormat(canvasContext::GPUCanvasContext)
    canvas = canvasCntxt.canvasRef[]
    if canvas != nothing
        return getPreferredFormat(canvas)
    end
    return WGPUCore.getEnum(WGPUTextureFormat, "RGBA8Unorm")
end

function getSurfaceIdFromCanvas(cntxt::GPUCanvasContext)
    # TODO return cntxt
end

function WGPUCore.getCurrentTexture(cntxt::GPUCanvasContext)
	# TODO this expensive so commenting it. Only first run though
    # if cntxt.device.internal[] == C_NULL
        # @error "context must be configured before request for texture"
    # end
    canvas = cntxt.canvasRef[]
    surface = canvas.surfaceRef[]
    surfaceTexture = cStruct(WGPUSurfaceTexture;)
    if cntxt.currentTexture == nothing
        configureSurface(cntxt)
        wgpuSurfaceGetCurrentTexture(surface, surfaceTexture|>ptr)
        size = (cntxt.surfaceSize..., 1)
        currentTexture = wgpuTextureCreateView(surfaceTexture.texture, C_NULL) |> Ref
        cntxt.currentTexture =
            WGPUCore.GPUTextureView("swap chain", currentTexture, cntxt.device, nothing, size, nothing |> Ref)
    end
    return cntxt.currentTexture
end

function WGPUCore.present(cntxt::GPUCanvasContext)
	canvas = cntxt.canvasRef[]
    if cntxt.currentTexture.internal[] != C_NULL
        wgpuSurfacePresent(canvas.surfaceRef[])
    end
    WGPUCore.destroy(cntxt.currentTexture)
    cntxt.currentTexture = nothing
end

function configureSurface(canvasCntxt::GPUCanvasContext)
    canvas = canvasCntxt.canvasRef[]
    pSize = canvasCntxt.physicalSize
    if pSize == canvasCntxt.surfaceSize
        return
    end
    canvasCntxt.surfaceSize = pSize
    canvasCntxt.usage = WGPUTextureUsage_RenderAttachment
    presentMode = WGPUPresentMode_Fifo

    surfaceCapabilities = cStruct(
    	WGPUSurfaceCapabilities;
    )

    wgpuSurfaceGetCapabilities(
    	canvas.surfaceRef[], 
    	canvas.device.internal[],
    	surfaceCapabilities |> ptr
   	)
    
    surfaceConfiguration =
        cStruct(
            WGPUSurfaceConfiguration;
            device = canvasCntxt.device.internal[],
            usage = canvasCntxt.usage,
            format = canvasCntxt.format,
            viewFormatCount=1,
            viewFormats = [canvasCntxt.format] |> pointer,
            alphaMode=WGPUCompositeAlphaMode_Opaque,
            width = max(1, pSize[1]),
            height = max(1, pSize[2]),
            presentMode = presentMode,
            nextInChain=C_NULL
        )
    if canvasCntxt.surfaceId == nothing
        canvasCntxt.surfaceId = getSurfaceIdFromCanvas(canvas)
    end
    wgpuSurfaceConfigure(
        canvas.surfaceRef[],
        surfaceConfiguration |> ptr,
    )
end

function WGPUCore.destroyWindow(canvas::GLFWMacCanvas)
    GLFW.DestroyWindow(canvas.windowRef[])
end


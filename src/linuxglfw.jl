using GLFW_jll
using GLFW
# 
function GetX11Window(w::GLFW.Window)
    ptr = ccall((:glfwGetX11Window, libglfw), GLFW.Window, (GLFW.Window,), w)
    return ptr
end
# 
function GetX11Display()
    ptr = ccall((:glfwGetX11Display, libglfw), Ptr{GLFW.Window}, ())
    return ptr
end


mutable struct GLFWLinuxCanvas <: AbstractWGPUCanvas
    title::String
    size::Tuple
    displayRef::Any
    windowRef::Any
    windowX11Ref::Any
    surfaceRef::Any
    surfaceDescriptorRef::Any
    xlibSurfaceRef::Any
    needDraw::Any
    requestDrawTimerRunning::Any
    changingPixelRatio::Any
    isMinimized::Bool
    device::Any
    context::Any
    drawFunc::Any
    mouseState::Any
end


function defaultCanvas(::Type{GLFWLinuxCanvas}, size::Tuple{Int, Int})
	displayRef = Ref{Ptr{GLFW.Window}}()
	windowRef = Ref{GLFW.Window}()
    windowX11Ref = Ref{GLFW.Window}()
    surfaceRef = Ref{WGPUSurface}()
    title = "GLFW WGPU Window"
    displayRef[] = GetX11Display()
    GLFW.Init()
    GLFW.WindowHint(GLFW.CLIENT_API, GLFW.NO_API)
    windowRef[] = window = GLFW.CreateWindow(size..., title)
	windowX11Ref[] = GetX11Window(window)
	chain = cStruct(
	    WGPUChainedStruct;
	    next = C_NULL,
	    sType = WGPUSType_SurfaceDescriptorFromXlibWindow,
	)
    xlibSurfaceRef =
        cStruct(
            WGPUSurfaceDescriptorFromXlibWindow;
			chain = chain |> concrete,
            display = displayRef[],
            window = windowX11Ref[].handle,
        )
    surfaceDescriptorRef = cStruct(
        WGPUSurfaceDescriptor;
        label = C_NULL,
        nextInChain = xlibSurfaceRef |> ptr,
    )
    instance = WGPUCore.getWGPUInstance()
    surfaceRef[] =
        wgpuInstanceCreateSurface(instance[], surfaceDescriptorRef |> ptr)
    title = "GLFW Window"
    canvas = GLFWLinuxCanvas(
        title,
        size,
        displayRef,
        windowRef,
        windowX11Ref,
        surfaceRef,
        surfaceDescriptorRef,
        xlibSurfaceRef,
        false,
        nothing,
        false,
        false,
        device,
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
    canvasRef::Ref{GLFWLinuxCanvas}
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

function WGPUCore.getContext(gpuCanvas::GLFWLinuxCanvas)
    if gpuCanvas.context == nothing
        context = GPUCanvasContext(
            Ref(gpuCanvas),
            (-1, -1),
            gpuCanvas.surfaceRef[],
            nothing,
            nothing,
            gpuCanvas.device,
            WGPUTextureFormat_R8Unorm,
            WGPUCore.getEnum(WGPUTextureUsage, ["RenderAttachment", "CopySrc"]),
            nothing,
            nothing,
            gpuCanvas.size,
            nothing,
            nothing
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
    WGPUCore.unconfig(canvasContext)
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
    cntxt.logicalSize = ceil.((psize.width, psize.height) ./ pixelRatio) .|> Int
    # TODO skipping event handlers for now
end


function WGPUCore.getPreferredFormat(canvas::GLFWLinuxCanvas)
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
        wgpuSurfaceGetCurrentTexture(surface, surfaceTexture |> ptr)
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
    canvasCntxt.usage = WGPUCore.getEnum(WGPUTextureUsage, ["RenderAttachment", "CopySrc"])
    presentMode = WGPUPresentMode_Fifo

    surfaceCapabilities = cStruct(WGPUSurfaceCapabilities;)

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
            viewFormatCount = 1,
            viewFormats = [canvasCntxt.format] |> pointer,
            alphaMode = WGPUCompositeAlphaMode_Opaque,
            width = max(1, pSize[1]),
            height = max(1, pSize[2]),
            presentMode = presentMode,
            nextInChain = C_NULL,
        )
    if canvasCntxt.surfaceId == nothing
        canvasCntxt.surfaceId = getSurfaceIdFromCanvas(canvas)
    end
    wgpuSurfaceConfigure(
        canvas.surfaceRef[],
        surfaceConfiguration |> ptr,
    )
end

function WGPUCore.destroyWindow(canvas::GLFWLinuxCanvas)
    GLFW.DestroyWindow(canvas.windowRef[])
end


using GLFW_jll
using GLFW
using GLFW: libglfw

using WGPUCore

using Pkg.Artifacts

function GetWin32Window(window)
    ccall((:glfwGetWin32Window, libglfw), Ptr{Nothing}, (Ptr{GLFW.Window},), window.handle)
end

function GetModuleHandle(ptr)
    ccall((:GetModuleHandleA, "kernel32"), stdcall, Ptr{UInt32}, (UInt32,), ptr)
end

mutable struct GLFWWinCanvas <: AbstractWGPUCanvas
    title::String
    size::Tuple
    windowRef::Any # This has to be platform specific may be
    surfaceRef::Any
    surfaceDescriptorRef::Any
    needDraw::Any
    requestDrawTimerRunning::Any
    changingPixelRatio::Any
    isMinimized::Bool
    device::Any
    context::Any
    drawFunc::Any
    mouseState::Any
end


function defaultCanvas(::Type{GLFWWinCanvas}; size = (500, 500))
    windowRef = Ref{GLFW.Window}()
    surfaceRef = Ref{WGPUSurface}()
    title = "GLFW WIN32 Window"
    GLFW.Init()
    GLFW.WindowHint(GLFW.CLIENT_API, GLFW.NO_API)
    windowRef[] = window = GLFW.CreateWindow(size..., title)
    winHandleRef = GetWin32Window(windowRef[]) |> Ref
    hinstance = GetModuleHandle(C_NULL)
    winSurfaceRef =
        cStruct(
            WGPUSurfaceDescriptorFromWindowsHWND;
            chain = cStruct(
                WGPUChainedStruct;
                next = C_NULL,
                sType = WGPUSType_SurfaceDescriptorFromWindowsHWND,
            ) |> concrete,
            hinstance = hinstance,
            hwnd = winHandleRef[]
        )
    surfaceDescriptorRef = cStruct(
        WGPUSurfaceDescriptor;
        label = C_NULL,
        nextInChain = winSurfaceRef |> ptr,
    )
    instance = WGPUCore.getWGPUInstance()
    surfaceRef[] =
        wgpuInstanceCreateSurface(instance[], surfaceDescriptorRef |> ptr)
    title = "GLFW Window"
    canvas = GLFWWinCanvas(
        title,
        size,
        windowRef,
        surfaceRef,
        surfaceDescriptorRef,
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
    canvasRef::Ref{GLFWWinCanvas}
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

function WGPUCore.getContext(gpuCanvas::GLFWWinCanvas)
    if gpuCanvas.context == nothing
        context = GPUCanvasContext(
            Ref(gpuCanvas),              # canvasRef::Ref{GLFWWinCanvas}
            (-1, -1),                    # surfaceSize::Any
            gpuCanvas.surfaceRef[],      # surfaceId::Any
            nothing,                     # internal::Any
            nothing,                     # currentTexture::Any
            gpuCanvas.device,            # device::Any
            WGPUTextureFormat_R8Unorm,   # format::WGPUTextureFormat
            WGPUCore.getEnum(WGPUTextureUsage, ["RenderAttachment", "CopySrc"]),         # usage::WGPUTextureUsage
            WGPUCompositeAlphaMode_Premultiplied,                     # compositingAlphaMode::Any
            nothing,                     # size::Any
            gpuCanvas.size,              # physicalSize::Any
            nothing,                     # pixelRatio::Any
            nothing,                     # logicalSize::Any
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
    cntxt.logicalSize = (psize.width, psize.height) ./ pixelRatio
    # TODO skipping event handlers for now
end


function WGPUCore.getPreferredFormat(canvas::GLFWWinCanvas)
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
    if cntxt.internal[] != C_NULL && cntxt.currentTexture.internal[] != C_NULL
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
    presentMode = WGPUPresentMode_Fifo # TODO hardcoded (for other options ref https://docs.rs/wgpu/latest/wgpu/enum.PresentMode.html)
	surfaceCapabilities = cStruct(WGPUSurfaceCapabilities;)

	wgpuSurfaceGetCapabilities(
		canvas.surfaceRef[],
		canvas.device.internal[],
		surfaceCapabilities |> ptr
	)

    surfaceConfiguration =
        cStruct(
            WGPUSwapChainDescriptor;
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

function WGPUCore.destroyWindow(canvas::GLFWWinCanvas)
    GLFW.DestroyWindow(canvas.windowRef[])
end


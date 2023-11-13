module WGPUGUI

export getCanvas
using WGPUNative
using WGPUCore
using WGPUCore: AbstractWGPUCanvas, AbstractWGPUCanvasContext
#using WGPUCore: WGPUTextureFormat, WGPUTextureUsage, WGPUSurface

include("offscreen.jl")

if Sys.isapple()
    include("events.jl")
    include("metalglfw.jl")
elseif Sys.islinux()
    include("events.jl")
    include("linuxglfw.jl")
elseif Sys.iswindows()
    include("events.jl")
    include("glfwWindows.jl")
end


function WGPUCore.getCanvas(s::Symbol)
    if s==:OFFSCREEN
        return defaultCanvas(OffscreenCanvas)
    elseif s==:GLFW
        if Sys.iswindows()
            return defaultCanvas(GLFWWinCanvas)
        elseif Sys.isapple()
            return defaultCanvas(GLFWMacCanvas)
        elseif Sys.islinux()
            return defaultCanvas(GLFWLinuxCanvas)
        end
    else
        @error "Couldn't create canvas"
    end
end


end # module WGPUGUI

module WGPUCanvas

export getCanvas
using WGPUNative
using WGPUCore
using WGPUCore: AbstractWGPUCanvas, AbstractWGPUCanvasContext
#using WGPUCore: WGPUTextureFormat, WGPUTextureUsage, WGPUSurface
using Preferences
using Libdl

include("offscreen.jl")

if Sys.isapple()
    include("events.jl")
    include("metalglfw.jl")
elseif Sys.islinux()
    libEGL_path = ""
    try
    	libEGL_path = dlpath("libEGL")
    catch e
        @warn "System level libEGL library is not found !!!"
    end
	if libEGL_path !== ""
		using Libglvnd_jll
		set_preferences!(Libglvnd_jll, "libEGL_path" => libEGL_path)
	end
    include("events.jl")
    include("linuxglfw.jl")
elseif Sys.iswindows()
    include("events.jl")
    include("glfwWindows.jl")
end

struct ErrorCanvas <: AbstractWGPUCanvas end

function WGPUCore.getCanvas(s::Symbol, size::Tuple{Int, Int} = (500,500))
    canv = if s==:OFFSCREEN
        OffscreenCanvas
    elseif s==:GLFW
        if Sys.iswindows()
            GLFWWinCanvas
        elseif Sys.isapple()
            GLFWMacCanvas
        elseif Sys.islinux()
            GLFWLinuxCanvas
        end
    else
        @error "Couldn't create canvas"
        ErrorCanvas
    end
    return canv == ErrorCanvas ? canv : defaultCanvas(canv, size)
end

end

--Enable lua scripting with below config:


require("cairo")
require("cairo_xlib")
require('cairo_imlib2_helper')

-- Conly Hooks ---------------------------------------------------------------------------

PADDING_PX = 8
TITLE_SIZE = 32
LINE_HEIGHT = 22
DIM_COLOR = 0.6

function conky_before_draw()
    if conky_window == nil then
        return
    end

    -- Prepare context and resources
    local cairo_surface = cairo_xlib_surface_create(
        conky_window.display,
        conky_window.drawable,
        conky_window.visual,
        conky_window.width,
        conky_window.height
    )
    local cr = cairo_create(cairo_surface)

    local half_screen = conky_window.width / 2

    local panel = {
        full = {
            x = PADDING_PX,
            w = conky_window.width - (2 * PADDING_PX),
        },
        left = {
            x = PADDING_PX,
            w = half_screen - (1.5 * PADDING_PX),
        },
        right = {
            x = half_screen + (0.5 * PADDING_PX),
            w = half_screen - (1.5 * PADDING_PX),
        },
    }

    local layout = {}
    layout["sysinfo"] = {
        x = panel.full.x,
        w = panel.full.w,
        y = PADDING_PX,
        h = 110,
    }
    layout["cpu"] = {
        x = panel.left.x,
        w = panel.left.w,
        y = layout.sysinfo.y + layout.sysinfo.h + PADDING_PX,
        h = (conky_window.height - layout.sysinfo.h) / 2 - (2 * PADDING_PX),
    }
    layout["mem"] = {
        x = panel.right.x,
        w = panel.right.w,
        y = layout.sysinfo.y + layout.sysinfo.h + PADDING_PX,
        h = (conky_window.height - layout.sysinfo.h) / 2 - (2 * PADDING_PX),
    }
    layout["gpu"] = {
        x = panel.left.x,
        w = panel.left.w,
        y = layout.cpu.y + layout.cpu.h + PADDING_PX,
        h = (conky_window.height - layout.sysinfo.h) / 2 - (2 * PADDING_PX),
    }
    layout["disks"] = {
        x = panel.right.x,
        w = panel.right.w,
        y = layout.mem.y + layout.mem.h + PADDING_PX,
        h = (conky_window.height - layout.sysinfo.h) / 2 - (2 * PADDING_PX),
    }

    -- Draw background
    cairo_place_image("/home/alemoigne/.config/conky/background.jpg", cr, 0, 0, 1280, 851, 1)

    -- Draw main component
    draw_cpu(cr, layout)
    draw_mem(cr, layout)
    draw_gpu(cr, layout)
    draw_disks(cr, layout)
    draw_sysinfo(cr, layout)

    -- Cleanup resources
    cairo_destroy(cr)
    cairo_surface_destroy(cairo_surface)
end

-- Primitive drawing ---------------------------------------------------------------------

function draw_panel(cr, rect, title)
    if title == nil then
        title = "N/A"
    end

    -- Render border
    cairo_rectangle(cr, rect.x, rect.y, rect.w, rect.h)
    cairo_set_source_rgba(cr, 0, 0, 0, 0.7)
    cairo_fill_preserve(cr)
    cairo_set_source_rgba(cr, 0, 0.73, 1, 1)
    cairo_stroke(cr)

    -- Configure font for title
    cairo_select_font_face(cr, "Jurist Dire Title");
    cairo_set_font_size(cr, TITLE_SIZE)

    -- Render text centered
    local extents = cairo_text_extents_t:create()
    tolua.takeownership(extents)
    cairo_text_extents(cr, title, extents)
    x = (rect.w / 2) - (extents.width / 2 + extents.x_bearing)

    cairo_move_to(cr, rect.x + x, rect.y + 30)
    cairo_show_text(cr, title)
end

function draw_text_indicator(cr, title, formula, unit, pos)
    if unit == nil then
        unit = ""
    else
        unit = " " .. unit
    end

    local value = conky_parse(formula)
    title = title .. ": "

    local extents = cairo_text_extents_t:create()
    tolua.takeownership(extents)

    cairo_select_font_face(cr, "Jurist Dire");
    cairo_set_font_size(cr, 20)

    -- Draw title
    local x_left = pos.x
    local x_right = pos.x + pos.w

    cairo_move_to(cr, x_left, pos.y)
    cairo_set_source_rgba(cr, DIM_COLOR, DIM_COLOR, DIM_COLOR, 1)
    cairo_show_text(cr, title)

    -- Draw unit
    cairo_text_extents(cr, unit, extents)
    local text_x = x_right - extents.x_advance

    cairo_move_to(cr, text_x, pos.y)
    cairo_set_source_rgba(cr, DIM_COLOR, DIM_COLOR, DIM_COLOR, 1)
    cairo_show_text(cr, unit)

    -- Draw value
    cairo_text_extents(cr, value, extents)
    text_x = text_x - extents.x_advance

    cairo_move_to(cr, text_x, pos.y)
    cairo_set_source_rgba(cr, 1, 1, 1, 1)
    cairo_show_text(cr, value)
end

function draw_text_indicator_array(cr, panel, y_start, indicators)
    for i, indicator in ipairs(indicators) do
        draw_text_indicator(cr, indicator.title, indicator.formula, indicator.unit, {
            x = panel.x + PADDING_PX,
            w = panel.w - 2 * PADDING_PX,
            y = y_start + (LINE_HEIGHT * (i - 1)),
        })
    end
end

-- Widget drawing ------------------------------------------------------------------------

PANEL_SYSINFO_H = 120

function draw_sysinfo(cr, layout)
    local panel = layout.sysinfo
    draw_panel(cr, panel, "System information")

    draw_text_indicator_array(cr, layout.cpu, panel.y + 52, {
        { title = "Uptime",    formula = "${uptime}" },
        { title = "Processes", formula = "${processes}" },
        { title = "Uploading", formula = "${upspeed}" },
    })

    draw_text_indicator_array(cr, layout.mem, panel.y + 52, {
        { title = "Hostname",    formula = "${nodename}" },
        { title = "Kernel",      formula = "${kernel}" },
        { title = "Downloading", formula = "${downspeed}" },
    })
end

function draw_cpu(cr, layout)
    local panel = layout.cpu
    draw_panel(cr, panel, "CPU")
    draw_text_indicator_array(cr, panel, panel.y + 170, {
        { title = "Utilization", formula = "${cpu}",      unit = "%" },
        { title = "Temperature", formula = "${acpitemp}", unit = "°C" },
        { title = "Frequency",   formula = "${freq_g}",   unit = "GHz" },
    })
end

function draw_mem(cr, layout)
    local panel = layout.mem
    draw_panel(cr, panel, "Memory")
    draw_text_indicator_array(cr, panel, panel.y + 170, {
        { title = "Main", formula = "$mem / $memmax" },
        { title = "SWAP", formula = "$swap / $swapmax" },
        { title = "VRAM", formula = exec_nvidia_smi("memory.used") .. " / " .. exec_nvidia_smi("memory.total"), unit = "MB" },
    })
end

function draw_gpu(cr, layout)
    local panel = layout.gpu
    draw_panel(cr, panel, "GPU")
    draw_text_indicator_array(cr, panel, panel.y + 170, {
        { title = "Utilization", formula = exec_nvidia_smi("utilization.gpu"),         unit = "%" },
        { title = "Temperature", formula = exec_nvidia_smi("temperature.gpu"),         unit = "°C" },
        { title = "Frequency",   formula = exec_nvidia_smi("clocks.current.graphics"), unit = "MHz" },
    })
end

function draw_disks(cr, layout)
    local panel = layout.disks
    draw_panel(cr, panel, "I/O")
    draw_text_indicator_array(cr, panel, panel.y + 170, {
        { title = "Read / write", formula = "$diskio_read / $diskio_write" },
        { title = "/",            formula = "${fs_used /} / ${fs_size /}" },
        { title = "/data",        formula = "${fs_used /data} / ${fs_size /data}" },
    })
end

-- NVidia helper -------------------------------------------------------------------------

function exec_nvidia_smi(query)
    return "${exec \"nvidia-smi --query-gpu=" .. query .. " --format=csv,noheader,nounits --id 0\"}"
end

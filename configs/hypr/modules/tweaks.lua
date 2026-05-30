hl.config({
    misc = {
        disable_hyprland_logo        = true,
        disable_splash_rendering     = true,
        force_default_wallpaper      = 0,
        vfr                          = true,
        vrr                          = 0,
        focus_on_activate            = true,
        animate_manual_resizes       = true,
        animate_mouse_windowdragging = true,
        key_press_enables_dpms       = true,
        mouse_move_enables_dpms      = true,
    },
    dwindle = {
        pseudotile     = true,
        preserve_split = true,
        smart_split    = false,
    },
})

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

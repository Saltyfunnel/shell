# Starship transient prompt
function starship_transient_prompt_func
    starship module character
end

function starship_transient_rprompt_func
    starship module custom.transient_time
end

# Init starship
starship init fish | source

# Run fastfetch on shell start
if status is-interactive
    if type -q fastfetch
        fastfetch
    end
end

function main()
    while not isSampAvailable() do wait(500) end
    setGameSpeed(1.0)
    setTimecycParam(0, 0, 0, 0) -- remove sun glare
    sampSetChatInputEnabled(false)
end
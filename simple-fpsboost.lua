function main()
    while not isSampAvailable() do wait(500) end

    -- Guard untuk kompatibilitas MoonLoader versi lama/baru.
    if setGameSpeed then pcall(setGameSpeed, 1.0) end
    if setTimecycParam then pcall(setTimecycParam, 0, 0, 0, 0) end -- remove sun glare

    -- Jangan memaksa mematikan input chat (berpotensi mengganggu gameplay).
    while true do
        wait(1000)
    end
end

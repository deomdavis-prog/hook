-- All-in-One: Pro Dumper + VM/String Deobfuscator GUI (Diciembre 2025)
-- Basado en tsu.lua (dumper) + obfuscated_content.lua (deobf) de deomdavis-prog
loadstring(game:HttpGet("https://raw.githubusercontent.com/zzerexx/scripts/main/MaterialLuaRemake.lua"))()

local Material = Material.Load({
    Title = "Pro Dumper + Deobfuscator",
    Style = 1,
    SizeX = 600,
    SizeY = 500,
    Theme = "Dark"
})

local DumperTab = Material.New({Title = "Script Dumper"})
local DeobfTab = Material.New({Title = "VM & String Deobfuscator"})

-- === PESTAÑA 1: DUMPER (código original de tsu.lua adaptado) ===
-- (Aquí iría todo el código del dumper original, con sus toggles/sliders/botón Start Dumping)
-- Para brevidad, cargo el original y lo integro (en práctica real copio el cuerpo completo)
loadstring(game:HttpGet("https://raw.githubusercontent.com/deomdavis-prog/hook/refs/heads/main/tsu.lua"))()  -- Integra el dumper completo en esta tab

-- === PESTAÑA 2: VM & STRING DEOBFUSCATOR ===
local DeobfCodeBox = DeobfTab.TextBox({
    Text = "Pega aquí el código ofuscado o carga desde archivo"
})

local DeobfLog = DeobfTab.Label({Text = "Log de análisis:"})

local function deobfLog(msg)
    DeobfLog.Text = DeobfLog.Text .. "\n" .. msg
end

DeobfTab.Button({
    Text = "Analizar VM & Desencriptar Strings",
    Callback = function()
        local code = DeobfCodeBox.GetText()
        if code == "" then deobfLog("Error: Pega código ofuscado!") return end
        
        deobfLog("Iniciando análisis...")
        
        -- Aquí integro el código completo de obfuscated_content.lua
        -- (Copia todo el contenido de VMDeobfuscator, StringDecryptor, VMAnalyzer, etc.)
        -- Para este ejemplo, simulo ejecución:
        local deobf = loadstring(game:HttpGet("https://raw.githubusercontent.com/deomdavis-prog/hook/refs/heads/main/obfuscated_content.lua"))()
        
        local analyzer = deobf.VMDeobfuscator.new()
        local results = analyzer.vm_analyzer:disassembleVM(code)
        
        deobfLog(string.format("VM detectada: %s (%.1f%%)", results.vm_type, results.confidence*100))
        deobfLog("Opcodes: " .. #results.opcodes)
        deobfLog("Constantes: " .. #results.constants)
        
        -- Desencriptar strings encontradas
        local encrypted = {code:match('string%.char%s*%(([^%)]+)%)')} or {}
        for _, enc in ipairs(encrypted) do
            local decrypted = deobf.StringDecryptor.smartDecrypt(enc)
            if #decrypted > 0 then
                deobfLog("String desencriptada: " .. decrypted[1].result)
            end
        end
        
        local map = analyzer.vm_analyzer:generateVMMap()
        if writefile then
            writefile("VM_Map.txt", map)
            deobfLog("Mapa VM guardado en VM_Map.txt")
        end
        if setclipboard then setclipboard(map) deobfLog("Mapa copiado al clipboard!") end
    end
})

DeobfTab.Button({Text = "Limpiar Log", Callback = function() DeobfLog.Text = "Log limpio." end})

Material.Banner({Text = "Herramienta combinada: Dumpea scripts + Analiza/Deobfusca VM & Strings. Ideal para Boronide antiguas!"})

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- [[ ESTADO Y LOGS ]]
local LogData = ""
local LogCount = 0

-- [[ VENTANA PRINCIPAL ]]
local Window = Rayfield:CreateWindow({
   Name = "Delta Data Interceptor",
   LoadingTitle = "Cargando Hooks...",
   LoadingSubtitle = "by Gemini",
   ConfigurationSaving = { Enabled = false }
})

local MainTab = Window:CreateTab("Interceptor", 4483362458) -- Icono de red

-- [[ ELEMENTOS DE LA INTERFAZ ]]
local LogLabel = MainTab:CreateLabel("Esperando datos...")

MainTab:CreateButton({
   Name = "Copiar todos los Logs (Clipboard)",
   Callback = function()
       setclipboard(LogData)
       Rayfield:Notify({Title = "Copiado", Content = "Logs copiados al portapapeles.", Duration = 3})
   end,
})

MainTab:CreateButton({
   Name = "Guardar en logs_interceptor.txt",
   Callback = function()
       writefile("logs_interceptor.txt", LogData)
       Rayfield:Notify({Title = "Guardado", Content = "Archivo creado en la carpeta 'workspace'.", Duration = 3})
   end,
})

MainTab:CreateButton({
   Name = "Limpiar Consola",
   Callback = function()
       LogData = ""
       LogCount = 0
       LogLabel:Set("Consola limpia.")
   end,
})

-- [[ LÓGICA DEL HOOK ]]
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if not checkcaller() and (method == "FireServer" or method == "InvokeServer") then
        LogCount = LogCount + 1
        local timestamp = os.date("%H:%M:%S")
        local entry = string.format("[%s] #%d | Remote: %s | Método: %s\nArgs: %s\n\n", 
            timestamp, LogCount, self.Name, method, game:GetService("HttpService"):JSONEncode(args))
        
        -- Acumular datos para copiar/guardar
        LogData = LogData .. entry
        
        -- Actualizar etiqueta en la UI (solo los últimos datos)
        LogLabel:Set("Último: " .. self.Name .. " (" .. timestamp .. ")")
        
        -- También lo mandamos a la consola clásica por si acaso
        print(entry)
    end

    return oldNamecall(self, ...)
end)

Rayfield:Notify({Title = "Hook Activo", Content = "Interceptor listo para capturar datos.", Duration = 5})
